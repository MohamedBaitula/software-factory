#!/usr/bin/env bash

set -u
set -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$ROOT_DIR/factory.config.yaml"
TEMPLATE_DIR="$ROOT_DIR/templates/project-knowledge"

# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"

dry_run=false
force=false
project_name=""

usage() {
  cat <<'EOF'
Software Factory project knowledge initializer

Usage:
  ./scripts/init-project-agent-docs.sh [--dry-run] [--force] <project>
  ./scripts/init-project-agent-docs.sh --help

Copies AGENTS.md and .agents/*.md templates into a configured project.
Existing files are not overwritten unless --force is used.
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
    --force)
      force=true
      shift
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
[[ -d "$TEMPLATE_DIR" ]] || sf_die "template directory missing: $TEMPLATE_DIR"

row="$(sf_config_project_row_by_name "$CONFIG_FILE" "$project_name")" || sf_die "project '$project_name' was not found"
IFS=$'\t' read -r config_name config_enabled config_path config_goal_file config_branch_prefix config_validation_count <<<"$row"
config_path="$(sf_config_expand_path "$config_path")"

[[ -d "$config_path" ]] || sf_die "project path does not exist: $config_path"

copy_file() {
  local source_file="$1"
  local target_file="$2"

  if [[ -e "$target_file" && "$force" != "true" ]]; then
    sf_warn "exists, skipping: $target_file"
    return
  fi

  if [[ "$dry_run" == "true" ]]; then
    sf_info "would copy $source_file -> $target_file"
    return
  fi

  mkdir -p "$(dirname "$target_file")"
  cp "$source_file" "$target_file"
  sf_ok "wrote $target_file"
}

copy_file "$TEMPLATE_DIR/AGENTS.md" "$config_path/AGENTS.md"
copy_file "$TEMPLATE_DIR/.agents/architecture.md" "$config_path/.agents/architecture.md"
copy_file "$TEMPLATE_DIR/.agents/conventions.md" "$config_path/.agents/conventions.md"
copy_file "$TEMPLATE_DIR/.agents/quality.md" "$config_path/.agents/quality.md"
copy_file "$TEMPLATE_DIR/.agents/validation.md" "$config_path/.agents/validation.md"

