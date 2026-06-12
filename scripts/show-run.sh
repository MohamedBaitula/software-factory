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
Software Factory run details

Usage:
  ./scripts/show-run.sh <run-id>
  ./scripts/show-run.sh --help

Shows metadata and per-project status for a local run.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ "$#" -ne 1 ]]; then
  usage
  sf_usage_error "show-run requires one run id"
fi

[[ -f "$CONFIG_FILE" ]] || sf_die "factory.config.yaml is missing"

run_id="$1"
logs_root="$(sf_runs_root "$CONFIG_FILE" "$ROOT_DIR")"
run_dir="$(sf_run_dir "$logs_root" "$run_id")"

[[ -d "$run_dir" ]] || sf_die "run not found: $run_id"

printf 'Run: %s\n\n' "$run_id"

if [[ -f "$run_dir/run.meta" ]]; then
  printf '== Metadata ==\n'
  cat "$run_dir/run.meta"
  printf '\n'
fi

printf '== Projects ==\n'
if [[ ! -d "$run_dir/projects" ]]; then
  sf_info "no project records found"
  exit 0
fi

find "$run_dir/projects" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort | while IFS= read -r project_slug; do
  status_file="$run_dir/projects/$project_slug/status.env"
  launch_file="$run_dir/projects/$project_slug/launch.env"

  printf '\n-- %s --\n' "$project_slug"
  if [[ -f "$status_file" ]]; then
    cat "$status_file"
  else
    printf 'status=unknown\n'
  fi

  if [[ -f "$launch_file" ]]; then
    printf '\nlaunch:\n'
    cat "$launch_file"
  fi
done

