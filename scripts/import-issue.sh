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
# shellcheck source=lib/goals.sh
source "$SCRIPT_DIR/lib/goals.sh"

usage() {
  cat <<'EOF'
Software Factory GitHub issue importer

Usage:
  ./scripts/import-issue.sh <project> <issue-number>
  ./scripts/import-issue.sh --help

Imports a GitHub Issue into goals/queue as a local goal file.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ "$#" -ne 2 ]]; then
  usage
  sf_usage_error "import-issue requires a project and issue number"
fi

project_name="$1"
issue_number="$2"

[[ -f "$CONFIG_FILE" ]] || sf_die "factory.config.yaml is missing"
sf_require_tool gh

repo="$(sf_config_project_value_by_name "$CONFIG_FILE" "$project_name" "githubRepo" "")"
[[ -n "$repo" ]] || sf_die "project '$project_name' is missing githubRepo in factory.config.yaml"

goals_root="$(sf_goals_root "$CONFIG_FILE" "$ROOT_DIR")"
mkdir -p "$goals_root/queue"

title="$(gh issue view "$issue_number" --repo "$repo" --json title --template '{{.title}}')"
url="$(gh issue view "$issue_number" --repo "$repo" --json url --template '{{.url}}')"
body="$(gh issue view "$issue_number" --repo "$repo" --json body --template '{{.body}}')"
labels="$(gh issue view "$issue_number" --repo "$repo" --json labels --template '{{range .labels}}{{.name}} {{end}}')"

case " $labels " in
  *" blocked "* | *" needs-human "*)
    sf_die "issue has a blocking label; do not import until it is ready"
    ;;
esac

goal_slug="$(sf_config_slug "$project_name-issue-$issue_number-$title")"
goal_file="$goals_root/queue/$goal_slug.md"

if [[ -e "$goal_file" ]]; then
  sf_die "goal file already exists: $goal_file"
fi

{
  printf '%s\n' '---'
  printf 'project: %s\n' "$project_name"
  printf 'title: %s\n' "$title"
  printf 'priority: normal\n'
  printf 'status: pending\n'
  printf 'role: feature-builder\n'
  printf 'issue: %s\n' "$url"
  printf '%s\n\n' '---'
  printf '# Goal\n\n'
  printf '## Objective\n\n'
  printf 'Implement GitHub Issue #%s: %s\n\n' "$issue_number" "$title"
  printf '## Source Issue\n\n'
  printf '%s\n\n' "$url"
  printf '## Context\n\n'
  printf '%s\n\n' "$body"
  printf '## Scope\n\n'
  printf 'Allowed:\n\n- Changes directly needed for this issue.\n\n'
  printf 'Forbidden:\n\n- Secrets or credentials.\n- Production deployment changes.\n- Destructive database migrations.\n- Unrelated refactors.\n\n'
  printf '## Validation\n\n'
  printf 'Run the validation commands configured for this project.\n\n'
  printf '## Stop Conditions\n\n'
  printf 'Pause if the issue is ambiguous, requires credentials, or conflicts with existing project rules.\n'
} >"$goal_file"

sf_ok "imported issue into $goal_file"

