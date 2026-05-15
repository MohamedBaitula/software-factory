#!/usr/bin/env bash

set -u
set -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$ROOT_DIR/factory.config.yaml"
EXAMPLE_CONFIG_FILE="$ROOT_DIR/factory.config.example.yaml"

# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"

dry_run=false
project_name=""

usage() {
  cat <<'EOF'
Software Factory single-project runner

Usage:
  ./scripts/run-project.sh [--dry-run] <project-name>
  ./scripts/run-project.sh --help

What it does:
  - reads the project from factory.config.yaml
  - verifies the project is enabled and safe to run
  - blocks if the project has uncommitted changes
  - creates a branch like codex/night-YYYY-MM-DD-project-name
  - verifies the project goal file exists
  - starts or reuses the configured tmux session
  - creates a tmux window and starts Codex in the project folder

Examples:
  ./scripts/run-project.sh --dry-run homebase
  ./scripts/run-project.sh homebase

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
        if [[ -n "$project_name" ]]; then
          usage
          die "only one project name can be provided"
        fi
        project_name="$1"
        shift
        ;;
    esac
  done

  if [[ -z "$project_name" ]]; then
    usage
    die "missing project name"
  fi
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

require_tool() {
  local tool="$1"

  if ! command -v "$tool" >/dev/null 2>&1; then
    die "$tool is required but was not found on PATH"
  fi
}

read_project() {
  local row

  if ! row="$(sf_config_project_row_by_name "$CONFIG_FILE" "$project_name")"; then
    die "project '$project_name' was not found in factory.config.yaml"
  fi

  IFS=$'\t' read -r config_name config_enabled config_path config_goal_file config_branch_prefix config_validation_count <<<"$row"

  config_validation_count="$(sf_config_trim "$config_validation_count")"
  config_path="$(sf_config_expand_path "$config_path")"
}

validate_project_config() {
  [[ -n "${config_name:-}" ]] || die "project '$project_name' is missing required field: name"

  if [[ -z "${config_enabled:-}" ]]; then
    die "project '$project_name' is missing required field: enabled"
  fi

  if ! sf_config_is_valid_enabled "$config_enabled"; then
    die "project '$project_name' has invalid enabled value '$config_enabled' (use true or false)"
  fi

  if ! sf_config_is_enabled "$config_enabled"; then
    die "project '$project_name' is disabled in factory.config.yaml"
  fi

  [[ -n "${config_path:-}" ]] || die "project '$project_name' is missing required field: path"
  [[ -n "${config_goal_file:-}" ]] || die "project '$project_name' is missing required field: goalFile"
  [[ -n "${config_branch_prefix:-}" ]] || die "project '$project_name' is missing required field: branchPrefix"

  if [[ "${config_validation_count:-0}" -le 0 ]]; then
    die "project '$project_name' must define at least one validation command"
  fi
}

validate_project_repo() {
  [[ -d "$config_path" ]] || die "project path does not exist: $config_path"

  if ! git -C "$config_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    die "project path is not a Git repository: $config_path"
  fi

  if [[ -n "$(git -C "$config_path" status --porcelain)" ]]; then
    die "project has uncommitted changes: $config_path"
  fi

  goal_path="$config_path/$config_goal_file"

  [[ -f "$goal_path" ]] || die "goal file does not exist: $goal_path"
}

load_runtime_settings() {
  tmux_session="$(sf_config_factory_value "$CONFIG_FILE" "tmuxSession" "software-factory")"
  codex_command="$(sf_config_factory_value "$CONFIG_FILE" "codexCommand" "codex")"
  window_name="$(sf_config_slug "$config_name")"
  attach_command="tmux attach -t $tmux_session"
}

prepare_branch() {
  local date_stamp
  local slug

  date_stamp="$(date +%F)"
  slug="$(sf_config_slug "$config_name")"
  branch_name="${config_branch_prefix}-${date_stamp}-${slug}"

  if git -C "$config_path" show-ref --verify --quiet "refs/heads/$branch_name"; then
    die "branch already exists in project: $branch_name"
  fi

  current_branch="$(git -C "$config_path" branch --show-current)"

  if [[ "$dry_run" == "true" ]]; then
    info "would create branch '$branch_name' from '$current_branch'"
    return
  fi

  git -C "$config_path" switch -c "$branch_name" >/dev/null
  ok "created branch '$branch_name'"
}

tmux_window_exists() {
  local session="$1"
  local window="$2"

  tmux list-windows -t "$session" -F '#W' 2>/dev/null | grep -Fxq "$window"
}

send_startup_to_tmux() {
  local target="$1"
  local codex_command="$2"

  tmux send-keys -t "$target" "clear" C-m
  tmux send-keys -t "$target" "printf '%s\n' 'Software Factory project: $config_name'" C-m
  tmux send-keys -t "$target" "printf '%s\n' 'Branch: $branch_name'" C-m
  tmux send-keys -t "$target" "printf '%s\n' 'Goal file: $config_goal_file'" C-m
  tmux send-keys -t "$target" "printf '%s\n' ''" C-m
  tmux send-keys -t "$target" "printf '%s\n' 'When Codex opens, start with:'" C-m
  tmux send-keys -t "$target" "printf '%s\n' '/goal Read $config_goal_file and complete the objective. Follow the scope, validation, stop conditions, and delivery instructions in that file. Do not push or deploy.'" C-m
  tmux send-keys -t "$target" "printf '%s\n' ''" C-m
  tmux send-keys -t "$target" "$codex_command" C-m
}

start_tmux() {
  local target
  target="$tmux_session:$window_name"

  if [[ "$dry_run" == "true" ]]; then
    info "would ensure tmux session '$tmux_session' exists"
    info "would create tmux window '$window_name' in $config_path"
    info "would start Codex with command: $codex_command"
    printf '\nAttach command:\n  %s\n' "$attach_command"
    return
  fi

  if tmux has-session -t "$tmux_session" 2>/dev/null; then
    ok "tmux session exists: $tmux_session"
    if tmux_window_exists "$tmux_session" "$window_name"; then
      ok "tmux window already exists: $window_name"
      printf '\nReusing existing window. Attach with:\n  %s\n' "$attach_command"
      return
    fi
    tmux new-window -d -t "$tmux_session" -n "$window_name" -c "$config_path"
  else
    tmux new-session -d -s "$tmux_session" -n "$window_name" -c "$config_path"
    ok "created tmux session: $tmux_session"
  fi

  send_startup_to_tmux "$target" "$codex_command"

  ok "created tmux window: $window_name"
  printf '\nAttach with:\n  %s\n' "$attach_command"
}

main() {
  parse_args "$@"

  require_config
  require_tool git
  require_tool tmux

  read_project
  validate_project_config
  validate_project_repo
  load_runtime_settings
  prepare_branch
  start_tmux
}

main "$@"
