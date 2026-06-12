#!/usr/bin/env bash

set -u
set -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$ROOT_DIR/factory.config.yaml"
EXAMPLE_CONFIG_FILE="$ROOT_DIR/factory.config.example.yaml"

# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"
# shellcheck source=lib/runs.sh
source "$SCRIPT_DIR/lib/runs.sh"

if [[ -s "$HOME/.nvm/nvm.sh" ]]; then
  # shellcheck source=/dev/null
  source "$HOME/.nvm/nvm.sh"
fi

dry_run=false
project_name=""
run_id=""
goal_file_override=""
role_override=""

config_name=""
config_enabled=""
config_path=""
config_goal_file=""
config_branch_prefix=""
config_validation_count="0"
goal_path=""
role_name=""
tmux_session=""
codex_command=""
window_name=""
attach_command=""
logs_root=""
branch_name=""
auto_start_goal="false"
goal_start_delay="4"

usage() {
  cat <<'EOF'
Software Factory single-project runner

Usage:
  ./scripts/run-project.sh [--dry-run] [--run-id <id>] [--goal-file <path>] [--role <role>] <project-name>
  ./scripts/run-project.sh --help

What it does:
  - reads the project from factory.config.yaml
  - verifies the project is enabled and safe to run
  - blocks if the project has uncommitted changes
  - creates a branch like codex/night-YYYY-MM-DD-project-name
  - starts or reuses the configured tmux session
  - creates a tmux window and starts Codex in the project folder
  - records launch status under logs/runs/<run-id>/

Examples:
  ./scripts/run-project.sh --dry-run homebase
  ./scripts/run-project.sh --goal-file goals/queue/homebase-dashboard.md homebase
  ./scripts/run-project.sh --role bug-fixer homebase

Exit codes:
  0  project was launched or an existing tmux window was reused
  1  blocking setup, config, Git, branch, tmux, or Codex failure
  2  invalid command-line usage
EOF
}

record_status() {
  local status="$1"
  local message="$2"

  if [[ "$dry_run" == "true" || -z "$run_id" || -z "$logs_root" || -z "${config_name:-}" ]]; then
    return
  fi

  sf_run_write_project_status "$logs_root" "$run_id" "$config_name" "$status" "${branch_name:-}" "${config_path:-}" "${window_name:-}" "$message"
  sf_run_append_project_log "$logs_root" "$run_id" "$config_name" "$message"
}

die() {
  record_status "failed" "$1"
  sf_die "$1"
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
      --goal-file)
        [[ -n "${2:-}" ]] || sf_usage_error "--goal-file requires a value"
        goal_file_override="$2"
        shift 2
        ;;
      --role)
        [[ -n "${2:-}" ]] || sf_usage_error "--role requires a value"
        role_override="$2"
        shift 2
        ;;
      -*)
        usage
        sf_usage_error "unknown option: $1"
        ;;
      *)
        if [[ -n "$project_name" ]]; then
          usage
          sf_usage_error "only one project name can be provided"
        fi
        project_name="$1"
        shift
        ;;
    esac
  done

  if [[ -z "$project_name" ]]; then
    usage
    sf_usage_error "missing project name"
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

load_runtime_settings() {
  logs_root="$(sf_runs_root "$CONFIG_FILE" "$ROOT_DIR")"
  tmux_session="$(sf_config_factory_value "$CONFIG_FILE" "tmuxSession" "software-factory")"
  codex_command="$(sf_config_factory_value "$CONFIG_FILE" "codexCommand" "codex")"
  auto_start_goal="$(sf_config_factory_value "$CONFIG_FILE" "autoStartGoal" "false")"
  goal_start_delay="$(sf_config_factory_value "$CONFIG_FILE" "goalStartDelaySeconds" "4")"
  role_name="${role_override:-$(sf_config_project_value_by_name "$CONFIG_FILE" "$config_name" "agentRole" "feature-builder")}"
  window_name="$(sf_config_slug "$config_name")"
  attach_command="tmux attach -t $tmux_session"

  if [[ -z "$run_id" ]]; then
    run_id="$(sf_run_new_id "$logs_root")"
  fi
}

ensure_run_log() {
  if [[ "$dry_run" == "true" ]]; then
    return
  fi

  mkdir -p "$logs_root/runs"
  if [[ ! -d "$(sf_run_dir "$logs_root" "$run_id")" ]]; then
    sf_run_init "$logs_root" "$run_id" "run-project"
  fi
}

validate_codex_command() {
  local command_name

  read -r command_name _ <<<"$codex_command"

  if [[ -z "$command_name" ]]; then
    die "codexCommand is empty in factory.config.yaml"
  fi

  if ! command -v "$command_name" >/dev/null 2>&1; then
    die "configured codexCommand is not available on PATH: $command_name"
  fi

  if [[ "$command_name" == "codex" ]] && ! codex --version >/dev/null 2>&1; then
    die "codex was found but could not run. Install Linux-native Node/Codex inside WSL."
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

  if [[ -n "$goal_file_override" ]]; then
    goal_path="$(sf_absolute_path "$goal_file_override" "$ROOT_DIR")"
  else
    goal_path="$config_path/$config_goal_file"
  fi

  [[ -f "$goal_path" ]] || die "goal file does not exist: $goal_path"
}

prepare_branch() {
  local date_stamp
  local project_slug
  local goal_slug
  local branch_suffix
  local current_branch

  date_stamp="$(date +%F)"
  project_slug="$(sf_config_slug "$config_name")"
  branch_suffix="$project_slug"

  if [[ -n "$goal_file_override" ]]; then
    goal_slug="$(sf_config_slug "$(basename "$goal_path")")"
    if [[ -n "$goal_slug" && "$goal_slug" != "goal-md" ]]; then
      branch_suffix="$project_slug-$goal_slug"
    fi
  fi

  branch_name="${config_branch_prefix}-${date_stamp}-${branch_suffix}"

  if git -C "$config_path" show-ref --verify --quiet "refs/heads/$branch_name"; then
    die "branch already exists in project: $branch_name"
  fi

  current_branch="$(git -C "$config_path" branch --show-current)"

  if [[ "$dry_run" == "true" ]]; then
    sf_info "would create branch '$branch_name' from '$current_branch'"
    return
  fi

  git -C "$config_path" switch -c "$branch_name" >/dev/null || die "could not create branch: $branch_name"
  sf_ok "created branch '$branch_name'"
  record_status "branched" "created branch $branch_name"
}

tmux_window_exists() {
  local session="$1"
  local window="$2"

  tmux list-windows -t "$session" -F '#W' 2>/dev/null | grep -Fxq "$window"
}

handle_existing_tmux_window() {
  if tmux has-session -t "$tmux_session" 2>/dev/null && tmux_window_exists "$tmux_session" "$window_name"; then
    sf_ok "tmux window already exists: $window_name"
    record_status "skipped" "tmux window already exists"
    printf '\nReusing existing window. Attach with:\n  %s\n' "$attach_command"
    exit 0
  fi
}

role_instruction_path() {
  local role_slug
  role_slug="$(sf_config_slug "$role_name")"
  printf '%s/templates/roles/%s.md\n' "$ROOT_DIR" "$role_slug"
}

goal_prompt() {
  local prompt
  local role_file

  role_file="$(role_instruction_path)"
  prompt="/goal Read $goal_path and complete the objective. Use the $role_name role. If AGENTS.md or .agents/*.md files exist in the project, read them before changing code. Follow scope, validation, stop conditions, and delivery instructions. Do not push or deploy."

  if [[ -f "$role_file" ]]; then
    prompt="$prompt Also read $role_file for role-specific instructions."
  fi

  printf '%s\n' "$prompt"
}

write_launch_metadata() {
  local project_dir
  local prompt

  if [[ "$dry_run" == "true" ]]; then
    return
  fi

  project_dir="$(sf_run_project_dir "$logs_root" "$run_id" "$config_name")"
  mkdir -p "$project_dir"
  prompt="$(goal_prompt)"

  {
    printf 'runId=%s\n' "$run_id"
    printf 'project=%s\n' "$config_name"
    printf 'path=%s\n' "$config_path"
    printf 'branch=%s\n' "$branch_name"
    printf 'goalFile=%s\n' "$goal_path"
    printf 'role=%s\n' "$role_name"
    printf 'tmuxSession=%s\n' "$tmux_session"
    printf 'tmuxWindow=%s\n' "$window_name"
    printf 'codexCommand=%s\n' "$codex_command"
    printf 'autoStartGoal=%s\n' "$auto_start_goal"
  } >"$project_dir/launch.env"

  printf '%s\n' "$prompt" >"$project_dir/codex-prompt.txt"
}

send_startup_to_tmux() {
  local target="$1"
  local prompt

  prompt="$(goal_prompt)"

  tmux send-keys -t "$target" "clear" C-m
  tmux send-keys -t "$target" "printf '%s\n' 'Software Factory project: $config_name'" C-m
  tmux send-keys -t "$target" "printf '%s\n' 'Run ID: $run_id'" C-m
  tmux send-keys -t "$target" "printf '%s\n' 'Branch: $branch_name'" C-m
  tmux send-keys -t "$target" "printf '%s\n' 'Goal file: $goal_path'" C-m
  tmux send-keys -t "$target" "printf '%s\n' 'Role: $role_name'" C-m
  tmux send-keys -t "$target" "printf '%s\n' ''" C-m
  tmux send-keys -t "$target" "printf '%s\n' 'Goal command:'" C-m
  tmux send-keys -t "$target" "printf '%s\n' '$prompt'" C-m
  tmux send-keys -t "$target" "printf '%s\n' ''" C-m
  tmux send-keys -t "$target" "$codex_command" C-m

  if sf_bool "$auto_start_goal"; then
    sleep "$goal_start_delay"
    tmux send-keys -t "$target" "$prompt" C-m
  fi
}

start_tmux() {
  local target
  target="$tmux_session:$window_name"

  if [[ "$dry_run" == "true" ]]; then
    sf_info "would use run id '$run_id'"
    sf_info "would ensure tmux session '$tmux_session' exists"
    sf_info "would create tmux window '$window_name' in $config_path"
    sf_info "would start Codex with command: $codex_command"
    sf_info "would use role: $role_name"
    sf_info "would use goal file: $goal_path"
    printf '\nAttach command:\n  %s\n' "$attach_command"
    return
  fi

  if tmux has-session -t "$tmux_session" 2>/dev/null; then
    sf_ok "tmux session exists: $tmux_session"
    if tmux_window_exists "$tmux_session" "$window_name"; then
      sf_ok "tmux window already exists: $window_name"
      record_status "skipped" "tmux window already exists"
      printf '\nReusing existing window. Attach with:\n  %s\n' "$attach_command"
      return
    fi
    tmux new-window -d -t "$tmux_session" -n "$window_name" -c "$config_path" || die "could not create tmux window"
  else
    tmux new-session -d -s "$tmux_session" -n "$window_name" -c "$config_path" || die "could not create tmux session"
    sf_ok "created tmux session: $tmux_session"
  fi

  write_launch_metadata
  send_startup_to_tmux "$target"

  sf_ok "created tmux window: $window_name"
  record_status "launched" "launched tmux window $window_name"
  sf_run_finish "$logs_root" "$run_id" "launched"
  printf '\nRun ID: %s\n' "$run_id"
  printf 'Attach with:\n  %s\n' "$attach_command"
}

main() {
  parse_args "$@"
  require_config
  sf_require_tool git
  sf_require_tool tmux

  read_project
  validate_project_config
  load_runtime_settings
  ensure_run_log
  validate_project_repo
  validate_codex_command
  handle_existing_tmux_window
  prepare_branch
  start_tmux
}

main "$@"
