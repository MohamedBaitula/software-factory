#!/usr/bin/env bash

set -u
set -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$ROOT_DIR/factory.config.yaml"
EXAMPLE_CONFIG_FILE="$ROOT_DIR/factory.config.example.yaml"
RUN_PROJECT_SCRIPT="$SCRIPT_DIR/run-project.sh"

# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"

dry_run=false
successes=0
failures=0
enabled_count=0
disabled_count=0
failed_projects=()

usage() {
  cat <<'EOF'
Software Factory night runner

Usage:
  ./scripts/run-night.sh [--dry-run]
  ./scripts/run-night.sh --help

What it does:
  - reads all projects from factory.config.yaml
  - skips projects with enabled: false
  - launches each enabled project through scripts/run-project.sh
  - uses one shared tmux session
  - uses one tmux window per project
  - continues to the next project if one project fails
  - prints a final run summary and tmux attach command

Examples:
  ./scripts/run-night.sh --dry-run
  ./scripts/run-night.sh

Before your first run:
  cp factory.config.example.yaml factory.config.yaml
  edit factory.config.yaml for your local projects
EOF
}

info() {
  printf '[INFO] %s\n' "$1"
}

ok() {
  printf '[ OK ] %s\n' "$1"
}

warn() {
  printf '[WARN] %s\n' "$1"
}

die() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
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
      -*)
        usage
        die "unknown option: $1"
        ;;
      *)
        usage
        die "run-night does not accept project names; use run-project.sh for one project"
        ;;
    esac
  done
}

require_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    return
  fi

  if [[ -f "$EXAMPLE_CONFIG_FILE" ]]; then
    die "factory.config.yaml is missing. Run: cp factory.config.example.yaml factory.config.yaml"
  fi

  die "factory.config.yaml is missing and no factory.config.example.yaml was found"
}

require_runner() {
  if [[ ! -x "$RUN_PROJECT_SCRIPT" ]]; then
    die "scripts/run-project.sh is missing or not executable"
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
  local args=("$RUN_PROJECT_SCRIPT")

  if [[ "$dry_run" == "true" ]]; then
    args+=("--dry-run")
  fi

  args+=("$project")

  printf '\n== Project: %s ==\n' "$project"

  if "${args[@]}" 2>&1; then
    successes=$((successes + 1))
    ok "$project launched"
  else
    failures=$((failures + 1))
    failed_projects+=("$project")
    warn "$project failed; continuing with remaining projects"
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
  require_runner

  info "reading enabled projects from factory.config.yaml"
  load_project_counts

  if [[ "$enabled_count" -eq 0 ]]; then
    die "no enabled projects found in factory.config.yaml"
  fi

  run_enabled_projects
  print_summary

  if [[ "$failures" -gt 0 ]]; then
    exit 1
  fi

  exit 0
}

main "$@"
