#!/usr/bin/env bash

set -u
set -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$ROOT_DIR/factory.config.yaml"
EXAMPLE_CONFIG_FILE="$ROOT_DIR/factory.config.example.yaml"

# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"

failures=0
warnings=0

usage() {
  cat <<'EOF'
Software Factory doctor

Usage:
  ./scripts/doctor.sh
  ./scripts/doctor.sh --help

Checks:
  - required tools: git, tmux, codex, node, npm
  - optional tools: pnpm, gh, shellcheck
  - local config file: factory.config.yaml
  - configured project paths
  - configured project Git repositories
  - clean Git working trees for enabled projects

Before your first run:
  cp factory.config.example.yaml factory.config.yaml
  edit factory.config.yaml for your local projects
EOF
}

section() {
  printf '\n== %s ==\n' "$1"
}

pass() {
  printf '[PASS] %s\n' "$1"
}

warn() {
  warnings=$((warnings + 1))
  printf '[WARN] %s\n' "$1"
}

fail() {
  failures=$((failures + 1))
  printf '[FAIL] %s\n' "$1"
}

version_for() {
  case "$1" in
    git) git --version 2>/dev/null | head -n 1 ;;
    tmux) tmux -V 2>/dev/null | head -n 1 ;;
    codex) codex --version 2>/dev/null | head -n 1 ;;
    node) node --version 2>/dev/null | head -n 1 ;;
    npm) npm --version 2>/dev/null | head -n 1 ;;
    pnpm) pnpm --version 2>/dev/null | head -n 1 ;;
    gh) gh --version 2>/dev/null | head -n 1 ;;
    shellcheck) shellcheck --version 2>/dev/null | head -n 1 ;;
    *) "$1" --version 2>/dev/null | head -n 1 ;;
  esac
}

check_required_tool() {
  local tool="$1"
  local version

  if command -v "$tool" >/dev/null 2>&1; then
    if ! version="$(version_for "$tool")"; then
      fail "$tool was found but could not run correctly"
      return
    fi

    if [[ -n "$version" ]]; then
      pass "$tool found ($version)"
    else
      fail "$tool was found but did not report a version"
    fi
  else
    fail "$tool is required but was not found on PATH"
  fi
}

check_optional_tool() {
  local tool="$1"
  local why="$2"
  local version

  if command -v "$tool" >/dev/null 2>&1; then
    if ! version="$(version_for "$tool")"; then
      warn "$tool was found but could not run correctly ($why)"
      return
    fi

    if [[ -n "$version" ]]; then
      pass "$tool found ($version)"
    else
      warn "$tool was found but did not report a version ($why)"
    fi
  else
    warn "$tool not found ($why)"
  fi
}

check_config_file() {
  section "Config"

  if [[ -f "$CONFIG_FILE" ]]; then
    pass "factory.config.yaml exists"
    return 0
  fi

  if [[ -f "$EXAMPLE_CONFIG_FILE" ]]; then
    fail "factory.config.yaml is missing"
    printf '       Copy the example before running the factory:\n'
    printf '       cp factory.config.example.yaml factory.config.yaml\n'
    printf '       Then edit factory.config.yaml for your local projects.\n'
  else
    fail "factory.config.yaml is missing and no factory.config.example.yaml was found"
  fi

  return 1
}

check_project_entry() {
  local name="$1"
  local enabled="$2"
  local path="$3"
  local goal_file="$4"
  local branch_prefix="$5"
  local validation_count="$6"
  local label="$name"
  local expanded_path=""
  local schema_failed=0

  if [[ -z "$label" ]]; then
    label="<unnamed project>"
  fi

  section "Project: $label"

  if [[ -z "$name" ]]; then
    fail "project is missing required field: name"
    schema_failed=1
  else
    pass "name is set ($name)"
  fi

  if [[ -z "$enabled" ]]; then
    fail "$label is missing required field: enabled"
    schema_failed=1
  elif sf_config_is_valid_enabled "$enabled"; then
    pass "enabled is set ($enabled)"
  else
    fail "$label has invalid enabled value: $enabled (use true or false)"
    schema_failed=1
  fi

  if [[ -z "$path" ]]; then
    fail "$label is missing required field: path"
    schema_failed=1
  else
    expanded_path="$(sf_config_expand_path "$path")"
    pass "path is set ($path)"
  fi

  if [[ -z "$goal_file" ]]; then
    fail "$label is missing required field: goalFile"
    schema_failed=1
  else
    pass "goalFile is set ($goal_file)"
  fi

  if [[ -z "$branch_prefix" ]]; then
    fail "$label is missing required field: branchPrefix"
    schema_failed=1
  else
    pass "branchPrefix is set ($branch_prefix)"
  fi

  if [[ "$validation_count" -gt 0 ]]; then
    pass "validation has $validation_count command(s)"
  else
    fail "$label must define at least one validation command"
    schema_failed=1
  fi

  if [[ "$schema_failed" -ne 0 ]]; then
    return
  fi

  if ! sf_config_is_enabled "$enabled"; then
    pass "$label is disabled; skipping repo readiness checks"
    return
  fi

  if [[ ! -d "$expanded_path" ]]; then
    fail "$label path does not exist: $expanded_path"
    return
  fi

  pass "$label path exists"

  if ! git -C "$expanded_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    fail "$label path is not a Git repository: $expanded_path"
    return
  fi

  pass "$label is a Git repository"

  if [[ -n "$(git -C "$expanded_path" status --porcelain)" ]]; then
    fail "$label has uncommitted changes"
  else
    pass "$label working tree is clean"
  fi
}

check_projects() {
  local project_rows=()
  local row
  local enabled_count=0

  section "Projects"

  mapfile -t project_rows < <(sf_config_project_rows "$CONFIG_FILE")

  if [[ "${#project_rows[@]}" -eq 0 ]]; then
    fail "no projects were found in factory.config.yaml"
    return
  fi

  pass "found ${#project_rows[@]} configured project(s)"

  for row in "${project_rows[@]}"; do
    local name=""
    local enabled=""
    local path=""
    local goal_file=""
    local branch_prefix=""
    local validation_count="0"

    IFS=$'\t' read -r name enabled path goal_file branch_prefix validation_count <<<"$row"
    validation_count="$(sf_config_trim "$validation_count")"

    if sf_config_is_enabled "$enabled"; then
      enabled_count=$((enabled_count + 1))
    fi

    check_project_entry "$name" "$enabled" "$path" "$goal_file" "$branch_prefix" "$validation_count"
  done

  pass "found $enabled_count enabled project(s)"
}

main() {
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
    exit 0
  fi

  if [[ "$#" -gt 0 ]]; then
    usage
    exit 2
  fi

  printf 'Software Factory doctor\n'
  printf 'Root: %s\n' "$ROOT_DIR"

  section "Required tools"
  check_required_tool git
  check_required_tool tmux
  check_required_tool codex
  check_required_tool node
  check_required_tool npm

  section "Optional tools"
  check_optional_tool pnpm "useful for projects that use pnpm"
  check_optional_tool gh "useful for opening pull requests later"
  check_optional_tool shellcheck "useful for linting shell scripts"

  if check_config_file; then
    check_projects
  else
    warn "project checks skipped until factory.config.yaml exists"
  fi

  section "Summary"
  printf 'Failures: %d\n' "$failures"
  printf 'Warnings: %d\n' "$warnings"

  if [[ "$failures" -gt 0 ]]; then
    printf '\nDoctor result: not ready yet. Fix the failures above, then run again.\n'
    exit 1
  fi

  printf '\nDoctor result: ready.\n'
  exit 0
}

main "$@"
