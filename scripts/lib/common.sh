#!/usr/bin/env bash

# Shared output and safety helpers for Software Factory scripts.

sf_info() {
  printf '[INFO] %s\n' "$1"
}

sf_ok() {
  printf '[ OK ] %s\n' "$1"
}

sf_warn() {
  printf '[WARN] %s\n' "$1"
}

sf_fail() {
  printf '[FAIL] %s\n' "$1" >&2
}

sf_die() {
  sf_fail "$1"
  exit 1
}

sf_usage_error() {
  sf_fail "$1"
  exit 2
}

sf_now_iso() {
  date '+%Y-%m-%dT%H:%M:%S%z'
}

sf_repo_root() {
  local script_dir="$1"
  cd -- "$script_dir/.." && pwd
}

sf_require_file() {
  local file="$1"
  local message="$2"

  [[ -f "$file" ]] || sf_die "$message"
}

sf_require_executable() {
  local file="$1"
  local message="$2"

  [[ -x "$file" ]] || sf_die "$message"
}

sf_require_tool() {
  local tool="$1"

  command -v "$tool" >/dev/null 2>&1 || sf_die "$tool is required but was not found on PATH"
}

sf_bool() {
  case "$1" in
    true | yes | 1) return 0 ;;
    *) return 1 ;;
  esac
}

sf_absolute_path() {
  local path="$1"
  local base_dir="${2:-$PWD}"

  case "$path" in
    /*) printf '%s\n' "$path" ;;
    "~") printf '%s\n' "$HOME" ;;
    "~/"*) printf '%s/%s\n' "$HOME" "${path#~/}" ;;
    *) printf '%s/%s\n' "$base_dir" "$path" ;;
  esac
}

sf_shell_quote() {
  printf '%q' "$1"
}

sf_run_shell_command() {
  local command="$1"

  bash -lc 'if [ -s "$HOME/.nvm/nvm.sh" ]; then . "$HOME/.nvm/nvm.sh"; fi; eval "$1"' _ "$command"
}
