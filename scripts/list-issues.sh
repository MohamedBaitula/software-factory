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

project_name=""

usage() {
  cat <<'EOF'
Software Factory GitHub issue list

Usage:
  ./scripts/list-issues.sh <project>
  ./scripts/list-issues.sh --help

Lists ready GitHub issues for a configured project. The project should define:
  githubRepo: owner/repo
  issueLabels:
    - software-factory
    - ready
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ "$#" -ne 1 ]]; then
  usage
  sf_usage_error "list-issues requires one project name"
fi

project_name="$1"
[[ -f "$CONFIG_FILE" ]] || sf_die "factory.config.yaml is missing"
sf_require_tool gh

repo="$(sf_config_project_value_by_name "$CONFIG_FILE" "$project_name" "githubRepo" "")"
[[ -n "$repo" ]] || sf_die "project '$project_name' is missing githubRepo in factory.config.yaml"

label_args=()
while IFS= read -r label; do
  [[ -n "$label" ]] || continue
  label_args+=("--label" "$label")
done < <(sf_config_project_list_values_by_name "$CONFIG_FILE" "$project_name" "issueLabels")

if [[ "${#label_args[@]}" -eq 0 ]]; then
  label_args=("--label" "software-factory" "--label" "ready")
fi

gh issue list --repo "$repo" --state open "${label_args[@]}" --limit 50

