#!/usr/bin/env bash

# Shared run logging helpers.

sf_runs_root() {
  local config_file="$1"
  local root_dir="$2"

  sf_config_factory_dir "$config_file" "logsDir" "logs" "$root_dir"
}

sf_run_new_id() {
  local logs_root="$1"
  local base
  local candidate
  local counter=2

  base="run-$(date '+%Y-%m-%d-%H%M')"
  candidate="$base"

  while [[ -e "$logs_root/runs/$candidate" ]]; do
    candidate="$base-$counter"
    counter=$((counter + 1))
  done

  printf '%s\n' "$candidate"
}

sf_run_dir() {
  local logs_root="$1"
  local run_id="$2"

  printf '%s/runs/%s\n' "$logs_root" "$run_id"
}

sf_run_project_dir() {
  local logs_root="$1"
  local run_id="$2"
  local project_name="$3"

  printf '%s/projects/%s\n' "$(sf_run_dir "$logs_root" "$run_id")" "$(sf_config_slug "$project_name")"
}

sf_run_init() {
  local logs_root="$1"
  local run_id="$2"
  local mode="$3"
  local run_dir

  run_dir="$(sf_run_dir "$logs_root" "$run_id")"
  mkdir -p "$run_dir/projects"

  if [[ -f "$run_dir/run.meta" ]]; then
    printf 'updatedAt=%s\n' "$(sf_now_iso)" >>"$run_dir/run.meta"
    return
  fi

  {
    printf 'runId=%s\n' "$run_id"
    printf 'mode=%s\n' "$mode"
    printf 'startedAt=%s\n' "$(sf_now_iso)"
  } >"$run_dir/run.meta"
}

sf_run_finish() {
  local logs_root="$1"
  local run_id="$2"
  local status="$3"
  local run_dir

  run_dir="$(sf_run_dir "$logs_root" "$run_id")"
  mkdir -p "$run_dir"
  {
    printf 'finishedAt=%s\n' "$(sf_now_iso)"
    printf 'status=%s\n' "$status"
  } >>"$run_dir/run.meta"
}

sf_run_write_project_status() {
  local logs_root="$1"
  local run_id="$2"
  local project_name="$3"
  local status="$4"
  local branch="$5"
  local project_path="$6"
  local tmux_window="$7"
  local message="$8"
  local project_dir
  local status_file
  local started_at

  project_dir="$(sf_run_project_dir "$logs_root" "$run_id" "$project_name")"
  mkdir -p "$project_dir"
  status_file="$project_dir/status.env"
  started_at="$(awk -F= '$1=="startedAt"{print $2; exit}' "$status_file" 2>/dev/null || true)"
  if [[ -z "$started_at" ]]; then
    started_at="$(sf_now_iso)"
  fi

  {
    printf 'project=%s\n' "$project_name"
    printf 'status=%s\n' "$status"
    printf 'branch=%s\n' "$branch"
    printf 'path=%s\n' "$project_path"
    printf 'tmuxWindow=%s\n' "$tmux_window"
    printf 'startedAt=%s\n' "$started_at"
    printf 'updatedAt=%s\n' "$(sf_now_iso)"
    printf 'message=%s\n' "$message"
  } >"$status_file"
}

sf_run_append_project_log() {
  local logs_root="$1"
  local run_id="$2"
  local project_name="$3"
  local message="$4"
  local project_dir

  project_dir="$(sf_run_project_dir "$logs_root" "$run_id" "$project_name")"
  mkdir -p "$project_dir"
  printf '[%s] %s\n' "$(sf_now_iso)" "$message" >>"$project_dir/events.log"
}

sf_run_latest_id() {
  local logs_root="$1"

  find "$logs_root/runs" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort | tail -n 1
}
