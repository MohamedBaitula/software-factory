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

dry_run=false
project_name=""
commit_message=""

usage() {
  cat <<'EOF'
Software Factory draft PR preparer

Usage:
  ./scripts/prepare-pr.sh [--dry-run] [--commit-message <message>] <project>
  ./scripts/prepare-pr.sh --help

Runs validation, commits only when validation passes, pushes the current branch,
and opens a draft pull request. It never auto-merges or deploys.
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
    --commit-message)
      [[ -n "${2:-}" ]] || sf_usage_error "--commit-message requires a value"
      commit_message="$2"
      shift 2
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
sf_require_tool git
sf_require_tool gh

row="$(sf_config_project_row_by_name "$CONFIG_FILE" "$project_name")" || sf_die "project '$project_name' was not found"
IFS=$'\t' read -r config_name config_enabled config_path config_goal_file config_branch_prefix config_validation_count <<<"$row"
config_path="$(sf_config_expand_path "$config_path")"

[[ -d "$config_path" ]] || sf_die "project path does not exist: $config_path"
git -C "$config_path" rev-parse --is-inside-work-tree >/dev/null 2>&1 || sf_die "project is not a Git repository"

branch="$(git -C "$config_path" branch --show-current)"
[[ -n "$branch" ]] || sf_die "project is in detached HEAD state"
repo="$(sf_config_project_value_by_name "$CONFIG_FILE" "$project_name" "githubRepo" "")"

if [[ -z "$repo" ]]; then
  repo="$(cd "$config_path" && gh repo view --json nameWithOwner --template '{{.nameWithOwner}}' 2>/dev/null || true)"
fi

[[ -n "$repo" ]] || sf_die "could not determine GitHub repo. Add githubRepo: owner/repo to factory.config.yaml"

if [[ "$branch" == "main" || "$branch" == "master" ]]; then
  sf_die "refusing to prepare a PR from protected base branch: $branch"
fi

if [[ -z "$(git -C "$config_path" status --porcelain)" ]]; then
  sf_die "no local changes to commit for project '$project_name'"
fi

printf 'Changed files:\n'
git -C "$config_path" status --short
printf '\nDiff stat:\n'
git -C "$config_path" diff --stat

validation_failed=0
while IFS= read -r command; do
  [[ -n "$command" ]] || continue
  printf '\n== Validation: %s ==\n' "$command"
  if [[ "$dry_run" == "true" ]]; then
    sf_info "would run validation command"
    continue
  fi
  if ! (cd "$config_path" && sf_run_shell_command "$command"); then
    validation_failed=1
    break
  fi
done < <(sf_config_project_validation_commands "$CONFIG_FILE" "$project_name")

if [[ "$validation_failed" -ne 0 ]]; then
  sf_die "validation failed; refusing to commit or open PR"
fi

if [[ -z "$commit_message" ]]; then
  commit_message="chore: software factory changes for $project_name"
fi

if [[ "$dry_run" == "true" ]]; then
  sf_info "would commit with message: $commit_message"
  sf_info "would push branch: $branch"
  sf_info "would open a draft PR"
  exit 0
fi

git -C "$config_path" add .
git -C "$config_path" commit -m "$commit_message"
git -C "$config_path" push -u origin "$branch"

pr_body="$(mktemp)"
{
  printf '## Summary\n\n'
  printf 'Prepared by Software Factory for `%s`.\n\n' "$project_name"
  printf '## Validation\n\n'
  printf 'Configured validation commands passed before this PR was opened.\n\n'
  printf '## Safety\n\n'
  printf '- This PR was opened as a draft.\n'
  printf '- Software Factory does not auto-merge.\n'
  printf '- Software Factory does not deploy.\n'
} >"$pr_body"

gh pr create --repo "$repo" --draft --title "$commit_message" --body-file "$pr_body"
rm -f "$pr_body"
