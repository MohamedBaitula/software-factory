#!/usr/bin/env bash

# Shared helpers for local goal queue files.

sf_goals_root() {
  local config_file="$1"
  local root_dir="$2"

  sf_config_factory_dir "$config_file" "goalsDir" "goals" "$root_dir"
}

sf_goal_value() {
  local goal_file="$1"
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

    $0 ~ "^[ \t]*" key ":[ \t]*" {
      value = $0
      sub("^[ \t]*[^:]+:[ \t]*", "", value)
      print trim(value)
      found = 1
      exit
    }

    END {
      if (!found) {
        print default_value
      }
    }
  ' "$goal_file"
}

sf_goal_status() {
  sf_goal_value "$1" "status" "pending"
}

sf_goal_project() {
  sf_goal_value "$1" "project" ""
}

sf_goal_role() {
  sf_goal_value "$1" "role" "feature-builder"
}

sf_goal_priority() {
  sf_goal_value "$1" "priority" "normal"
}

sf_goal_title() {
  local file="$1"
  local title

  title="$(sf_goal_value "$file" "title" "")"
  if [[ -n "$title" ]]; then
    printf '%s\n' "$title"
    return
  fi

  awk '/^# / { sub(/^# /, ""); print; exit }' "$file"
}

sf_goal_update_status() {
  local goal_file="$1"
  local new_status="$2"

  if grep -Eq '^[[:space:]]*status:[[:space:]]*' "$goal_file"; then
    sed -i -E "0,/^[[:space:]]*status:[[:space:]]*/s//status: $new_status/" "$goal_file"
  else
    sed -i "1istatus: $new_status" "$goal_file"
  fi
}

sf_goal_files() {
  local goals_root="$1"

  find "$goals_root/queue" "$goals_root/running" "$goals_root/blocked" "$goals_root/completed" \
    -type f \( -name '*.md' -o -name '*.goal' -o -name '*.goal.md' \) \
    -print 2>/dev/null | sort
}
