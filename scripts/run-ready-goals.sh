#!/usr/bin/env bash

set -u
set -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$ROOT_DIR/factory.config.yaml"
RUN_GOAL_SCRIPT="$SCRIPT_DIR/run-goal.sh"

# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"
# shellcheck source=lib/goals.sh
source "$SCRIPT_DIR/lib/goals.sh"
# shellcheck source=lib/runs.sh
source "$SCRIPT_DIR/lib/runs.sh"

dry_run=false
run_id=""
successes=0
failures=0

usage() {
  cat <<'EOF'
Software Factory ready-goal runner

Usage:
  ./scripts/run-ready-goals.sh [--dry-run] [--run-id <id>]
  ./scripts/run-ready-goals.sh --help

Runs all goals with status pending or ready.
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
      usage
      sf_usage_error "run-ready-goals does not accept positional arguments"
      ;;
  esac
done

[[ -f "$CONFIG_FILE" ]] || sf_die "factory.config.yaml is missing"
sf_require_executable "$RUN_GOAL_SCRIPT" "scripts/run-goal.sh is missing or not executable"

logs_root="$(sf_runs_root "$CONFIG_FILE" "$ROOT_DIR")"
goals_root="$(sf_goals_root "$CONFIG_FILE" "$ROOT_DIR")"

if [[ -z "$run_id" ]]; then
  run_id="$(sf_run_new_id "$logs_root")"
fi

if [[ "$dry_run" != "true" ]]; then
  mkdir -p "$logs_root/runs"
  sf_run_init "$logs_root" "$run_id" "run-ready-goals"
fi

mapfile -t goals < <(sf_goal_files "$goals_root")

for goal_file in "${goals[@]}"; do
  status="$(sf_goal_status "$goal_file")"
  case "$status" in
    pending | ready)
      ;;
    *)
      continue
      ;;
  esac

  printf '\n== Goal: %s ==\n' "$goal_file"
  args=("$RUN_GOAL_SCRIPT" "--run-id" "$run_id")
  if [[ "$dry_run" == "true" ]]; then
    args+=("--dry-run")
  fi
  args+=("$goal_file")

  if "${args[@]}"; then
    successes=$((successes + 1))
  else
    failures=$((failures + 1))
    sf_warn "goal failed: $goal_file"
  fi
done

printf '\n== Ready Goal Summary ==\n'
printf 'Run ID: %s\n' "$run_id"
printf 'Successful goals: %d\n' "$successes"
printf 'Failed goals: %d\n' "$failures"

if [[ "$dry_run" != "true" ]]; then
  if [[ "$failures" -gt 0 ]]; then
    sf_run_finish "$logs_root" "$run_id" "failed"
  else
    sf_run_finish "$logs_root" "$run_id" "completed"
  fi
fi

if [[ "$failures" -gt 0 ]]; then
  exit 1
fi

