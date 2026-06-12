#!/usr/bin/env bash

set -u
set -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$ROOT_DIR/factory.config.yaml"
DASHBOARD_PATH="$ROOT_DIR/reports/dashboard.html"

# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"
# shellcheck source=lib/runs.sh
source "$SCRIPT_DIR/lib/runs.sh"

usage() {
  cat <<'EOF'
Software Factory local dashboard generator

Usage:
  ./scripts/dashboard.sh
  ./scripts/dashboard.sh --help

Writes a local static HTML dashboard to reports/dashboard.html.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ "$#" -gt 0 ]]; then
  usage
  sf_usage_error "dashboard does not accept arguments"
fi

[[ -f "$CONFIG_FILE" ]] || sf_die "factory.config.yaml is missing"

logs_root="$(sf_runs_root "$CONFIG_FILE" "$ROOT_DIR")"
latest_run="$(sf_run_latest_id "$logs_root")"
mkdir -p "$(dirname "$DASHBOARD_PATH")"

{
  printf '<!doctype html>\n<html lang="en">\n<head>\n'
  printf '<meta charset="utf-8">\n<meta name="viewport" content="width=device-width, initial-scale=1">\n'
  printf '<title>Software Factory Dashboard</title>\n'
  printf '<style>body{font-family:system-ui,-apple-system,Segoe UI,sans-serif;margin:32px;background:#f8fafc;color:#111827}table{border-collapse:collapse;width:100%%;background:white}th,td{border:1px solid #d1d5db;padding:8px;text-align:left}th{background:#e5e7eb}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:16px}.card{background:white;border:1px solid #d1d5db;border-radius:8px;padding:16px}</style>\n'
  printf '</head>\n<body>\n'
  printf '<h1>Software Factory Dashboard</h1>\n'
  printf '<p>Generated: %s</p>\n' "$(sf_now_iso)"
  printf '<div class="grid">\n'
  printf '<div class="card"><strong>Latest run</strong><br>%s</div>\n' "${latest_run:-none}"
  printf '<div class="card"><strong>Config</strong><br>factory.config.yaml</div>\n'
  printf '</div>\n'
  printf '<h2>Projects</h2>\n<table><thead><tr><th>Name</th><th>Enabled</th><th>Path</th><th>Role</th><th>GitHub Repo</th></tr></thead><tbody>\n'

  while IFS= read -r row; do
    IFS=$'\t' read -r name enabled path goal_file branch_prefix validation_count <<<"$row"
    role="$(sf_config_project_value_by_name "$CONFIG_FILE" "$name" "agentRole" "feature-builder")"
    repo="$(sf_config_project_value_by_name "$CONFIG_FILE" "$name" "githubRepo" "")"
    printf '<tr><td>%s</td><td>%s</td><td><code>%s</code></td><td>%s</td><td>%s</td></tr>\n' "$name" "$enabled" "$(sf_config_expand_path "$path")" "$role" "${repo:-}"
  done < <(sf_config_project_rows "$CONFIG_FILE")

  printf '</tbody></table>\n'

  printf '<h2>Recent Runs</h2>\n<table><thead><tr><th>Run</th><th>Status</th><th>Mode</th><th>Started</th></tr></thead><tbody>\n'
  if [[ -d "$logs_root/runs" ]]; then
    find "$logs_root/runs" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort | tail -n 20 | while IFS= read -r run_id; do
      meta="$logs_root/runs/$run_id/run.meta"
      status="$(awk -F= '$1=="status"{value=$2} END{print value}' "$meta" 2>/dev/null)"
      mode="$(awk -F= '$1=="mode"{print $2; exit}' "$meta" 2>/dev/null)"
      started="$(awk -F= '$1=="startedAt"{print $2; exit}' "$meta" 2>/dev/null)"
      printf '<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n' "$run_id" "${status:-unknown}" "${mode:-unknown}" "${started:-unknown}"
    done
  fi
  printf '</tbody></table>\n'
  printf '</body>\n</html>\n'
} >"$DASHBOARD_PATH"

sf_ok "wrote $DASHBOARD_PATH"

