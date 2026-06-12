#!/usr/bin/env bash

set -u
set -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$ROOT_DIR/factory.config.yaml"

# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"
# shellcheck source=lib/runs.sh
source "$SCRIPT_DIR/lib/runs.sh"

usage() {
  cat <<'EOF'
Software Factory run list

Usage:
  ./scripts/list-runs.sh
  ./scripts/list-runs.sh --help

Lists local run IDs recorded under logs/runs/.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ "$#" -gt 0 ]]; then
  usage
  sf_usage_error "list-runs does not accept arguments"
fi

[[ -f "$CONFIG_FILE" ]] || sf_die "factory.config.yaml is missing"

logs_root="$(sf_runs_root "$CONFIG_FILE" "$ROOT_DIR")"
runs_dir="$logs_root/runs"

if [[ ! -d "$runs_dir" ]]; then
  sf_info "no runs recorded yet"
  exit 0
fi

printf 'Run ID\tStatus\tMode\tStarted\n'
find "$runs_dir" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort | while IFS= read -r run_id; do
  meta="$runs_dir/$run_id/run.meta"
  status="$(awk -F= '$1=="status"{value=$2} END{print value}' "$meta" 2>/dev/null)"
  mode="$(awk -F= '$1=="mode"{print $2; exit}' "$meta" 2>/dev/null)"
  started="$(awk -F= '$1=="startedAt"{print $2; exit}' "$meta" 2>/dev/null)"
  printf '%s\t%s\t%s\t%s\n' "$run_id" "${status:-unknown}" "${mode:-unknown}" "${started:-unknown}"
done

