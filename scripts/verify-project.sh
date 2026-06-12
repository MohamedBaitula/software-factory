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

dry_run=false
project_name=""
run_id=""

usage() {
  cat <<'EOF'
Software Factory project verifier

Usage:
  ./scripts/verify-project.sh [--dry-run] [--run-id <id>] <project>
  ./scripts/verify-project.sh --help

Runs the configured validation commands for one project and records output under
logs/runs/<run-id>/projects/<project>/validation.log.
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
      if [[ -n "$project_name" ]]; then
        usage
        sf_usage_error "only one project can be provided"
      fi
      project_name="$1"
      shift
      ;;
  esac
done

[[ -n "$project_name" ]] || sf_usage_error "missing project"
[[ -f "$CONFIG_FILE" ]] || sf_die "factory.config.yaml is missing"
sf_require_tool git

row="$(sf_config_project_row_by_name "$CONFIG_FILE" "$project_name")" || sf_die "project '$project_name' was not found"
IFS=$'\t' read -r config_name config_enabled config_path config_goal_file config_branch_prefix config_validation_count <<<"$row"
config_path="$(sf_config_expand_path "$config_path")"

[[ -d "$config_path" ]] || sf_die "project path does not exist: $config_path"
git -C "$config_path" rev-parse --is-inside-work-tree >/dev/null 2>&1 || sf_die "project is not a Git repository"

logs_root="$(sf_runs_root "$CONFIG_FILE" "$ROOT_DIR")"
if [[ -z "$run_id" ]]; then
  run_id="$(sf_run_new_id "$logs_root")"
fi

project_dir="$(sf_run_project_dir "$logs_root" "$run_id" "$project_name")"
validation_log="$project_dir/validation.log"
validation_status="$project_dir/validation.status"

if [[ "$dry_run" == "true" ]]; then
  sf_info "would verify project: $project_name"
  sf_info "would write validation log: $validation_log"
  while IFS= read -r command; do
    [[ -n "$command" ]] || continue
    sf_info "would run: $command"
  done < <(sf_config_project_validation_commands "$CONFIG_FILE" "$project_name")
  exit 0
fi

mkdir -p "$project_dir"
sf_run_init "$logs_root" "$run_id" "verify-project"

{
  printf 'Validation for %s\n' "$project_name"
  printf 'Started: %s\n\n' "$(sf_now_iso)"
} >"$validation_log"

failed=0
while IFS= read -r command; do
  [[ -n "$command" ]] || continue
  {
    printf '\n== %s ==\n' "$command"
  } >>"$validation_log"

  if (cd "$config_path" && sf_run_shell_command "$command") >>"$validation_log" 2>&1; then
    printf 'PASS: %s\n' "$command" >>"$validation_log"
  else
    printf 'FAIL: %s\n' "$command" >>"$validation_log"
    failed=1
    break
  fi
done < <(sf_config_project_validation_commands "$CONFIG_FILE" "$project_name")

if [[ "$failed" -eq 0 ]]; then
  printf 'passed\n' >"$validation_status"
  sf_run_write_project_status "$logs_root" "$run_id" "$project_name" "verified" "$(git -C "$config_path" branch --show-current)" "$config_path" "" "validation passed"
  sf_run_finish "$logs_root" "$run_id" "completed"
  sf_ok "validation passed for $project_name"
else
  printf 'failed\n' >"$validation_status"
  sf_run_write_project_status "$logs_root" "$run_id" "$project_name" "failed" "$(git -C "$config_path" branch --show-current)" "$config_path" "" "validation failed"
  sf_run_finish "$logs_root" "$run_id" "failed"
  sf_die "validation failed for $project_name; see $validation_log"
fi
