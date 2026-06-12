#!/usr/bin/env bash

set -u
set -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$ROOT_DIR/factory.config.yaml"
EXAMPLE_CONFIG_FILE="$ROOT_DIR/factory.config.example.yaml"
RUN_PROJECT_SCRIPT="$SCRIPT_DIR/run-project.sh"

# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"
# shellcheck source=lib/runs.sh
source "$SCRIPT_DIR/lib/runs.sh"

dry_run=false
run_id=""
successes=0
failures=0
enabled_count=0
disabled_count=0
failed_projects=()
logs_root=""

usage() {
  cat <<'EOF'
Software Factory night runner

Usage:
  ./scripts/run-night.sh [--dry-run] [--run-id <id>]
  ./scripts/run-night.sh --help

What it does:
  - reads all projects from factory.config.yaml
  - skips projects with enabled: false
  - launches each enabled project through scripts/run-project.sh
  - uses one shared tmux session
  - uses one tmux window per project
  - records a run under logs/runs/<run-id>/
  - continues to the next project if one project fails

Examples:
  ./scripts/run-night.sh --dry-run
  ./scripts/run-night.sh

Exit codes:
  0  all enabled projects launched or reused successfully
  1  one or more enabled projects failed
  2  invalid command-line usage
EOF
}

parse_args() {
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
        sf_usage_error "run-night does not accept project names; use run-project.sh for one project"
        ;;
    esac
  done
}

require_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    return
  fi

  if [[ -f "$EXAMPLE_CONFIG_FILE" ]]; then
    sf_die "factory.config.yaml is missing. Run: cp factory.config.example.yaml factory.config.yaml"
  fi

  sf_die "factory.config.yaml is missing and no factory.config.example.yaml was found"
}

load_runtime() {
  logs_root="$(sf_runs_root "$CONFIG_FILE" "$ROOT_DIR")"

  if [[ -z "$run_id" ]]; then
    run_id="$(sf_run_new_id "$logs_root")"
  fi

  if [[ "$dry_run" != "true" ]]; then
    mkdir -p "$logs_root/runs"
    sf_run_init "$logs_root" "$run_id" "run-night"
  fi
}

load_project_counts() {
  local row

  while IFS= read -r row; do
    local name=""
    local enabled=""
    local path=""
    local goal_file=""
    local branch_prefix=""
    local validation_count=""

    IFS=$'\t' read -r name enabled path goal_file branch_prefix validation_count <<<"$row"

    if sf_config_is_enabled "$enabled"; then
      enabled_count=$((enabled_count + 1))
    else
      disabled_count=$((disabled_count + 1))
    fi
  done < <(sf_config_project_rows "$CONFIG_FILE")
}

run_project() {
  local project="$1"
  local args=("$RUN_PROJECT_SCRIPT" "--run-id" "$run_id")

  if [[ "$dry_run" == "true" ]]; then
    args+=("--dry-run")
  fi

  args+=("$project")

  printf '\n== Project: %s ==\n' "$project"

  if "${args[@]}" 2>&1; then
    successes=$((successes + 1))
    sf_ok "$project launched or reused"
  else
    failures=$((failures + 1))
    failed_projects+=("$project")
    sf_warn "$project failed; continuing with remaining projects"
  fi
}

run_enabled_projects() {
  local row

  while IFS= read -r row; do
    local name=""
    local enabled=""
    local path=""
    local goal_file=""
    local branch_prefix=""
    local validation_count=""

    IFS=$'\t' read -r name enabled path goal_file branch_prefix validation_count <<<"$row"
    run_project "$name"
  done < <(sf_config_enabled_project_rows "$CONFIG_FILE")
}

print_summary() {
  local tmux_session
  local attach_command

  tmux_session="$(sf_config_factory_value "$CONFIG_FILE" "tmuxSession" "software-factory")"
  attach_command="tmux attach -t $tmux_session"

  printf '\n== Night Run Summary ==\n'
  printf 'Run ID: %s\n' "$run_id"
  printf 'Enabled projects: %d\n' "$enabled_count"
  printf 'Disabled projects skipped: %d\n' "$disabled_count"
  printf 'Successful launches: %d\n' "$successes"
  printf 'Failed launches: %d\n' "$failures"

  if [[ "$failures" -gt 0 ]]; then
    printf 'Failed projects:\n'
    printf '  - %s\n' "${failed_projects[@]}"
  fi

  printf '\nAttach command:\n  %s\n' "$attach_command"
}

main() {
  parse_args "$@"
  require_config
  sf_require_executable "$RUN_PROJECT_SCRIPT" "scripts/run-project.sh is missing or not executable"
  load_runtime

  sf_info "reading enabled projects from factory.config.yaml"
  load_project_counts

  if [[ "$enabled_count" -eq 0 ]]; then
    sf_die "no enabled projects found in factory.config.yaml"
  fi

  run_enabled_projects
  print_summary

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
}

main "$@"
