#!/usr/bin/env bash

# Shared config helpers for Software Factory scripts.
#
# The MVP intentionally supports a small, documented YAML subset instead of
# requiring a YAML parser. Supported project fields:
#   - name
#   - enabled
#   - path
#   - goalFile
#   - branchPrefix
#   - validation

sf_config_trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

sf_config_expand_path() {
  local path="$1"

  case "$path" in
    "~")
      printf '%s\n' "$HOME"
      ;;
    "~/"*)
      printf '%s/%s\n' "$HOME" "${path#~/}"
      ;;
    *)
      printf '%s\n' "$path"
      ;;
  esac
}

sf_config_is_valid_enabled() {
  case "$1" in
    true | false) return 0 ;;
    *) return 1 ;;
  esac
}

sf_config_is_enabled() {
  [[ "$1" == "true" ]]
}

sf_config_project_rows() {
  local config_file="$1"

  awk '
    function trim(s) {
      sub(/[ \t]*#.*/, "", s)
      gsub(/^[ \t]+|[ \t]+$/, "", s)
      gsub(/^"|"$/, "", s)
      gsub(/^'\''|'\''$/, "", s)
      return s
    }

    function flush_project() {
      if (seen_project) {
        printf "%s\t%s\t%s\t%s\t%s\t%s\n", name, enabled, path, goal_file, branch_prefix, validation_count
      }
    }

    /^projects:[ \t]*($|#)/ {
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
      enabled = ""
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

    /^[ \t]+enabled:[ \t]*/ {
      enabled = $0
      sub(/^[ \t]+enabled:[ \t]*/, "", enabled)
      enabled = trim(enabled)
      in_validation = 0
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

    /^[ \t]+validation:[ \t]*($|#)/ {
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

sf_config_enabled_project_rows() {
  local config_file="$1"
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
      printf '%s\n' "$row"
    fi
  done < <(sf_config_project_rows "$config_file")
}
