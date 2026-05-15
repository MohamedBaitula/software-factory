#!/usr/bin/env bash

set -u
set -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$ROOT_DIR/factory.config.yaml"
EXAMPLE_CONFIG_FILE="$ROOT_DIR/factory.config.example.yaml"

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
  - clean Git working trees for configured projects

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

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

parse_projects() {
  local config_file="$1"

  awk '
    function trim(s) {
      gsub(/^[ \t]+|[ \t]+$/, "", s)
      gsub(/^"|"$/, "", s)
      return s
    }

    function flush_project() {
      if (seen_project) {
        printf "%s\t%s\t%s\t%s\t%s\n", name, path, goal_file, branch_prefix, validation_count
      }
    }

    /^projects:[ \t]*$/ {
      in_projects = 1
      next
    }

    in_projects && /^[^ \t-][^:]*:/ {
      in_projects = 0
      in_validation = 0
      next
    }

    !in_projects {
      next
    }

    /^[ \t]*-[ \t]+name:[ \t]*/ {
      flush_project()
      seen_project = 1
      name = $0
      sub(/^[ \t]*-[ \t]+name:[ \t]*/, "", name)
      name = trim(name)
      path = ""
      goal_file = ""
      branch_prefix = ""
      validation_count = 0
      in_validation = 0
      next
    }

    !seen_project {
      next
    }

    /^[ \t]+path:[ \t]*/ {
      path = $0
      sub(/^[ \t]+path:[ \t]*/, "", path)
      path = trim(path)
      in_validation = 0
      next
    }

    /^[ \t]+goalFile:[ \t]*/ {
      goal_file = $0
      sub(/^[ \t]+goalFile:[ \t]*/, "", goal_file)
      goal_file = trim(goal_file)
      in_validation = 0
      next
    }

    /^[ \t]+branchPrefix:[ \t]*/ {
      branch_prefix = $0
      sub(/^[ \t]+branchPrefix:[ \t]*/, "", branch_prefix)
      branch_prefix = trim(branch_prefix)
      in_validation = 0
      next
    }

    /^[ \t]+validation:[ \t]*$/ {
      in_validation = 1
      next
    }

    in_validation && /^[ \t]+-[ \t]+/ {
      validation_count++
      next
    }

    /^[ \t]+[A-Za-z0-9_-]+:[ \t]*/ {
      in_validation = 0
      next
    }

    END {
      flush_project()
    }
  ' "$config_file"
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
  local path="$2"
  local goal_file="$3"
  local branch_prefix="$4"
  local validation_count="$5"
  local label="$name"

  if [[ -z "$label" ]]; then
    label="<unnamed project>"
  fi

  section "Project: $label"

  if [[ -z "$name" ]]; then
    fail "project is missing required field: name"
  else
    pass "name is set ($name)"
  fi

  if [[ -z "$path" ]]; then
    fail "$label is missing required field: path"
    return
  fi

  pass "path is set ($path)"

  if [[ -z "$goal_file" ]]; then
    fail "$label is missing required field: goalFile"
  else
    pass "goalFile is set ($goal_file)"
  fi

  if [[ -z "$branch_prefix" ]]; then
    fail "$label is missing required field: branchPrefix"
  else
    pass "branchPrefix is set ($branch_prefix)"
  fi

  if [[ "$validation_count" -gt 0 ]]; then
    pass "validation has $validation_count command(s)"
  else
    fail "$label must define at least one validation command"
  fi

  if [[ ! -d "$path" ]]; then
    fail "$label path does not exist: $path"
    return
  fi

  pass "$label path exists"

  if ! git -C "$path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    fail "$label path is not a Git repository: $path"
    return
  fi

  pass "$label is a Git repository"

  if [[ -n "$(git -C "$path" status --porcelain)" ]]; then
    fail "$label has uncommitted changes"
  else
    pass "$label working tree is clean"
  fi
}

check_projects() {
  local project_rows=()
  local row

  section "Projects"

  mapfile -t project_rows < <(parse_projects "$CONFIG_FILE")

  if [[ "${#project_rows[@]}" -eq 0 ]]; then
    fail "no projects were found in factory.config.yaml"
    return
  fi

  pass "found ${#project_rows[@]} configured project(s)"

  for row in "${project_rows[@]}"; do
    local name=""
    local path=""
    local goal_file=""
    local branch_prefix=""
    local validation_count="0"

    IFS=$'\t' read -r name path goal_file branch_prefix validation_count <<<"$row"
    validation_count="$(trim "$validation_count")"
    check_project_entry "$name" "$path" "$goal_file" "$branch_prefix" "$validation_count"
  done
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
