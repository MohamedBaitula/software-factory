#!/usr/bin/env bash

set -u
set -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$ROOT_DIR/factory.config.yaml"
RUN_PROJECT_SCRIPT="$SCRIPT_DIR/run-project.sh"

# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"
# shellcheck source=lib/goals.sh
source "$SCRIPT_DIR/lib/goals.sh"

dry_run=false
goal_file=""
run_id=""

usage() {
  cat <<'EOF'
Software Factory goal runner

Usage:
  ./scripts/run-goal.sh [--dry-run] [--run-id <id>] <goal-file>
  ./scripts/run-goal.sh --help

Runs one local goal by reading its project and role metadata, then delegating to
scripts/run-project.sh.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --help | -h)
      usage
      exit 0
      ;;
    --dry-run)
      dry_run=true
      shift
      ;;
    --run-id)
      [[ -n "${2:-}" ]] || sf_usage_error "--run-id requires a value"
      run_id="$2"
      shift 2
      ;;
    -*)
      usage
      sf_usage_error "unknown option: $1"
      ;;
    *)
      if [[ -n "$goal_file" ]]; then
        usage
        sf_usage_error "only one goal file can be provided"
      fi
      goal_file="$1"
      shift
      ;;
  esac
done

[[ -n "$goal_file" ]] || sf_usage_error "missing goal file"
[[ -f "$goal_file" ]] || sf_die "goal file not found: $goal_file"
[[ -f "$CONFIG_FILE" ]] || sf_die "factory.config.yaml is missing"
sf_require_executable "$RUN_PROJECT_SCRIPT" "scripts/run-project.sh is missing or not executable"

goal_file="$(sf_absolute_path "$goal_file" "$PWD")"
project="$(sf_goal_project "$goal_file")"
role="$(sf_goal_role "$goal_file")"
status="$(sf_goal_status "$goal_file")"

[[ -n "$project" ]] || sf_die "goal is missing required metadata: project"

case "$status" in
  pending | ready | running)
    ;;
  blocked | completed)
    sf_die "goal status is '$status'; move it back to pending before running"
    ;;
  *)
    sf_warn "unknown goal status '$status'; continuing carefully"
    ;;
esac

args=("$RUN_PROJECT_SCRIPT" "--goal-file" "$goal_file" "--role" "$role")
if [[ "$dry_run" == "true" ]]; then
  args+=("--dry-run")
fi
if [[ -n "$run_id" ]]; then
  args+=("--run-id" "$run_id")
fi
args+=("$project")

if [[ "$dry_run" != "true" ]]; then
  sf_goal_update_status "$goal_file" "running"
fi

if "${args[@]}"; then
  if [[ "$dry_run" == "true" ]]; then
    sf_ok "goal dry run complete: $goal_file"
  else
    sf_ok "goal is running: $goal_file"
  fi
else
  if [[ "$dry_run" != "true" ]]; then
    sf_goal_update_status "$goal_file" "blocked"
  fi
  sf_die "goal failed to launch: $goal_file"
fi
