#!/usr/bin/env bash

set -u
set -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$ROOT_DIR/factory.config.yaml"
EXAMPLE_CONFIG_FILE="$ROOT_DIR/factory.config.example.yaml"

# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"

report_path=""

usage() {
  cat <<'EOF'
Software Factory morning report generator

Usage:
  ./scripts/summarize.sh
  ./scripts/summarize.sh --help

What it does:
  - reads enabled projects from factory.config.yaml
  - writes a Markdown report under reports/
  - includes branch, Git status, changed files, recent commits, and diff stats
  - includes validation status when a matching status/log file exists
  - recommends a next action for each project

Before your first run:
  cp factory.config.example.yaml factory.config.yaml
  edit factory.config.yaml for your local projects
EOF
}

info() {
  printf '[INFO] %s\n' "$1"
}

die() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
}

parse_args() {
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
    exit 0
  fi

  if [[ "$#" -gt 0 ]]; then
    usage
    die "summarize does not accept arguments"
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

report_dir() {
  local configured_dir

  configured_dir="$(sf_config_factory_value "$CONFIG_FILE" "reportsDir" "reports")"

  if [[ "$configured_dir" = /* ]]; then
    printf '%s\n' "$configured_dir"
  else
    printf '%s/%s\n' "$ROOT_DIR" "$configured_dir"
  fi
}

logs_dir() {
  local configured_dir

  configured_dir="$(sf_config_factory_value "$CONFIG_FILE" "logsDir" "logs")"

  if [[ "$configured_dir" = /* ]]; then
    printf '%s\n' "$configured_dir"
  else
    printf '%s/%s\n' "$ROOT_DIR" "$configured_dir"
  fi
}

next_report_path() {
  local dir="$1"
  local today
  local base
  local candidate
  local counter=2

  today="$(date +%F)"
  base="$dir/morning-$today"
  candidate="$base.md"

  while [[ -e "$candidate" ]]; do
    candidate="$base-$counter.md"
    counter=$((counter + 1))
  done

  printf '%s\n' "$candidate"
}

append_command_output() {
  local command_label="$1"
  shift

  printf '```txt\n' >>"$report_path"
  if "$@" >>"$report_path" 2>&1; then
    :
  else
    printf '%s failed.\n' "$command_label" >>"$report_path"
  fi
  printf '```\n\n' >>"$report_path"
}

project_branch() {
  local project_path="$1"
  local branch

  branch="$(git -C "$project_path" branch --show-current 2>/dev/null || true)"

  if [[ -n "$branch" ]]; then
    printf '%s\n' "$branch"
  else
    git -C "$project_path" rev-parse --short HEAD 2>/dev/null || printf 'unknown\n'
  fi
}

project_clean_state() {
  local project_path="$1"

  if [[ -n "$(git -C "$project_path" status --porcelain 2>/dev/null)" ]]; then
    printf 'dirty\n'
  else
    printf 'clean\n'
  fi
}

find_validation_status() {
  local project_name="$1"
  local slug
  local dir
  local today
  local candidate

  slug="$(sf_config_slug "$project_name")"
  dir="$(logs_dir)"
  today="$(date +%F)"

  for candidate in \
    "$dir/$slug.status" \
    "$dir/$slug.validation" \
    "$dir/$today-$slug.status" \
    "$dir/$today/$slug.status" \
    "$dir/$slug.log" \
    "$dir/$today-$slug.log" \
    "$dir/$today/$slug.log"; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

validation_summary() {
  local project_name="$1"
  local status_file
  local first_line

  if status_file="$(find_validation_status "$project_name")"; then
    first_line="$(head -n 1 "$status_file" | tr -d '\r')"
    if [[ -z "$first_line" ]]; then
      first_line="status file exists but is empty"
    fi
    printf '%s (%s)\n' "$first_line" "$status_file"
  else
    printf 'not available\n'
  fi
}

recommended_action() {
  local project_path="$1"
  local clean_state="$2"
  local validation="$3"

  if [[ ! -d "$project_path" ]]; then
    printf 'Fix the configured project path.\n'
    return
  fi

  if ! git -C "$project_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf 'Fix the project path so it points to a Git repository.\n'
    return
  fi

  if [[ "$clean_state" == "dirty" ]]; then
    printf 'Review the diff, run validation manually, then commit, revise, or discard the branch.\n'
    return
  fi

  if [[ "$validation" == "not available" ]]; then
    printf 'Run the project validation commands or inspect the tmux window for status.\n'
    return
  fi

  printf 'Review recent commits and validation output before deciding whether to merge.\n'
}

write_project_report() {
  local name="$1"
  local enabled="$2"
  local configured_path="$3"
  local goal_file="$4"
  local branch_prefix="$5"
  local validation_count="$6"
  local project_path
  local branch="unknown"
  local clean_state="unknown"
  local validation="not available"
  local action

  project_path="$(sf_config_expand_path "$configured_path")"

  {
    printf '## Project: %s\n\n' "$name"
    printf '| Field | Value |\n'
    printf '|---|---|\n'
    printf '| Enabled | `%s` |\n' "$enabled"
    printf '| Path | `%s` |\n' "$project_path"
    printf '| Goal file | `%s` |\n' "$goal_file"
    printf '| Branch prefix | `%s` |\n' "$branch_prefix"
    printf '| Validation commands | `%s` configured |\n\n' "$validation_count"
  } >>"$report_path"

  if [[ ! -d "$project_path" ]]; then
    {
      printf '### Status\n\n'
      printf 'Configured path does not exist.\n\n'
      printf '### Recommended Next Action\n\n'
      printf 'Fix the configured project path.\n\n'
    } >>"$report_path"
    return
  fi

  if ! git -C "$project_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    {
      printf '### Status\n\n'
      printf 'Configured path is not a Git repository.\n\n'
      printf '### Recommended Next Action\n\n'
      printf 'Fix the project path so it points to a Git repository.\n\n'
    } >>"$report_path"
    return
  fi

  branch="$(project_branch "$project_path")"
  clean_state="$(project_clean_state "$project_path")"
  validation="$(validation_summary "$name")"
  action="$(recommended_action "$project_path" "$clean_state" "$validation")"

  {
    printf '### Current Branch\n\n'
    printf '`%s`\n\n' "$branch"
    printf '### Working Tree\n\n'
    printf '`%s`\n\n' "$clean_state"
    printf '### Validation Status\n\n'
    printf '%s\n\n' "$validation"
    printf '### Git Status\n\n'
  } >>"$report_path"

  append_command_output "git status" git -C "$project_path" status --short

  {
    printf '### Changed Files\n\n'
  } >>"$report_path"

  if [[ "$clean_state" == "clean" ]]; then
    printf 'No uncommitted changed files.\n\n' >>"$report_path"
  else
    append_command_output "git changed files" git -C "$project_path" status --short
  fi

  {
    printf '### Recent Commits\n\n'
  } >>"$report_path"
  append_command_output "git log" git -C "$project_path" log --oneline -5

  {
    printf '### Diff Stats\n\n'
    printf 'Uncommitted diff:\n\n'
  } >>"$report_path"
  append_command_output "git diff --stat" git -C "$project_path" diff --stat

  {
    printf 'Staged diff:\n\n'
  } >>"$report_path"
  append_command_output "git diff --cached --stat" git -C "$project_path" diff --cached --stat

  {
    printf '### Recommended Next Action\n\n'
    printf '%s\n\n' "$action"
  } >>"$report_path"
}

write_report_header() {
  local enabled_rows_count="$1"

  {
    printf '# Morning Report\n\n'
    printf 'Date: %s\n\n' "$(date +%F)"
    printf 'Generated by: `scripts/summarize.sh`\n\n'
    printf 'Enabled projects reviewed: %s\n\n' "$enabled_rows_count"
  } >"$report_path"
}

generate_report() {
  local rows=()
  local row
  local report_directory

  mapfile -t rows < <(sf_config_enabled_project_rows "$CONFIG_FILE")

  if [[ "${#rows[@]}" -eq 0 ]]; then
    die "no enabled projects found in factory.config.yaml"
  fi

  report_directory="$(report_dir)"
  mkdir -p "$report_directory"
  report_path="$(next_report_path "$report_directory")"

  write_report_header "${#rows[@]}"

  for row in "${rows[@]}"; do
    local name=""
    local enabled=""
    local path=""
    local goal_file=""
    local branch_prefix=""
    local validation_count=""

    IFS=$'\t' read -r name enabled path goal_file branch_prefix validation_count <<<"$row"
    write_project_report "$name" "$enabled" "$path" "$goal_file" "$branch_prefix" "$validation_count"
  done
}

main() {
  parse_args "$@"
  require_config
  generate_report

  info "wrote report: $report_path"
}

main "$@"
