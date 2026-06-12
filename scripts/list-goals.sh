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
# shellcheck source=lib/goals.sh
source "$SCRIPT_DIR/lib/goals.sh"

usage() {
  cat <<'EOF'
Software Factory goal list

Usage:
  ./scripts/list-goals.sh
  ./scripts/list-goals.sh --help

Lists local goals from goals/queue, goals/running, goals/blocked, and goals/completed.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ "$#" -gt 0 ]]; then
  usage
  sf_usage_error "list-goals does not accept arguments"
fi

[[ -f "$CONFIG_FILE" ]] || sf_die "factory.config.yaml is missing"

goals_root="$(sf_goals_root "$CONFIG_FILE" "$ROOT_DIR")"

if [[ ! -d "$goals_root" ]]; then
  sf_info "no goals directory found: $goals_root"
  exit 0
fi

printf 'Status\tPriority\tProject\tRole\tFile\tTitle\n'
sf_goal_files "$goals_root" | while IFS= read -r goal_file; do
  status="$(sf_goal_status "$goal_file")"
  priority="$(sf_goal_priority "$goal_file")"
  project="$(sf_goal_project "$goal_file")"
  role="$(sf_goal_role "$goal_file")"
  title="$(sf_goal_title "$goal_file")"
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$status" "$priority" "${project:-unknown}" "$role" "$goal_file" "${title:-untitled}"
done

