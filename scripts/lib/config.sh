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

sf_config_slug() {
  local value="$1"

  value="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')"
  value="$(printf '%s' "$value" | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"

  if [[ -z "$value" ]]; then
    value="project"
  fi

  printf '%s\n' "$value"
}

sf_config_factory_value() {
  local config_file="$1"
  local key="$2"
  local default_value="${3:-}"

  awk -v key="$key" -v default_value="$default_value" '
    function trim(s) {
      sub(/[ \t]*#.*/, "", s)
      gsub(/^[ \t]+|[ \t]+$/, "", s)
      gsub(/^"|"$/, "", s)
      gsub(/^'\''|'\''$/, "", s)
      return s
    }

    /^factory:[ \t]*($|#)/ {
      in_factory = 1
      next
    }

    in_factory && /^[^ \t-][^:]*:/ {
      in_factory = 0
      next
    }

    in_factory {
      line = $0
      sub(/^[ \t]+/, "", line)
      split(line, parts, ":")
      field = trim(parts[1])

      if (field == key) {
        sub(/^[^:]+:[ \t]*/, "", line)
        print trim(line)
        found = 1
        exit
      }
    }

    END {
      if (!found) {
        print default_value
      }
    }
  ' "$config_file"
}

sf_config_factory_dir() {
  local config_file="$1"
  local key="$2"
  local default_value="$3"
  local root_dir="$4"
  local configured_dir

  configured_dir="$(sf_config_factory_value "$config_file" "$key" "$default_value")"

  if [[ "$configured_dir" = /* ]]; then
    printf '%s\n' "$configured_dir"
  else
    printf '%s/%s\n' "$root_dir" "$configured_dir"
  fi
}

sf_config_project_row_by_name() {
  local config_file="$1"
  local project_name="$2"
  local row

  while IFS= read -r row; do
    local name=""
    local enabled=""
    local path=""
    local goal_file=""
    local branch_prefix=""
    local validation_count=""

    IFS=$'\t' read -r name enabled path goal_file branch_prefix validation_count <<<"$row"

    if [[ "$name" == "$project_name" ]]; then
      printf '%s\n' "$row"
      return 0
    fi
  done < <(sf_config_project_rows "$config_file")

  return 1
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
