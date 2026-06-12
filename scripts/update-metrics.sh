#!/usr/bin/env bash

set -u
set -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$ROOT_DIR/factory.config.yaml"
METRICS_DIR="$ROOT_DIR/metrics"

# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"
# shellcheck source=lib/runs.sh
source "$SCRIPT_DIR/lib/runs.sh"

usage() {
  cat <<'EOF'
Software Factory metrics updater

Usage:
  ./scripts/update-metrics.sh
  ./scripts/update-metrics.sh --help

Reads logs/runs and writes metrics/summary.md plus metrics/summary.json.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ "$#" -gt 0 ]]; then
  usage
  sf_usage_error "update-metrics does not accept arguments"
fi

[[ -f "$CONFIG_FILE" ]] || sf_die "factory.config.yaml is missing"

logs_root="$(sf_runs_root "$CONFIG_FILE" "$ROOT_DIR")"
runs_dir="$logs_root/runs"
mkdir -p "$METRICS_DIR"

total_runs=0
completed_runs=0
failed_runs=0
launched_projects=0
failed_projects=0
verified_projects=0
validation_passed=0
validation_failed=0
branches_created=0

if [[ -d "$runs_dir" ]]; then
  while IFS= read -r run_dir; do
    total_runs=$((total_runs + 1))
    status="$(awk -F= '$1=="status"{value=$2} END{print value}' "$run_dir/run.meta" 2>/dev/null)"
    case "$status" in
      completed | launched) completed_runs=$((completed_runs + 1)) ;;
      failed) failed_runs=$((failed_runs + 1)) ;;
    esac

    if [[ -d "$run_dir/projects" ]]; then
      while IFS= read -r launch_file; do
        [[ -n "$launch_file" ]] || continue
        launched_projects=$((launched_projects + 1))
      done < <(find "$run_dir/projects" -name launch.env -type f)

      while IFS= read -r status_file; do
        project_status="$(awk -F= '$1=="status"{print $2; exit}' "$status_file")"
        branch="$(awk -F= '$1=="branch"{print $2; exit}' "$status_file")"
        case "$project_status" in
          launched | skipped | branched) : ;;
          verified) verified_projects=$((verified_projects + 1)) ;;
          failed) failed_projects=$((failed_projects + 1)) ;;
        esac
        [[ -n "$branch" ]] && branches_created=$((branches_created + 1))
      done < <(find "$run_dir/projects" -name status.env -type f)

      while IFS= read -r validation_file; do
        validation="$(head -n 1 "$validation_file" 2>/dev/null)"
        case "$validation" in
          passed) validation_passed=$((validation_passed + 1)) ;;
          failed) validation_failed=$((validation_failed + 1)) ;;
        esac
      done < <(find "$run_dir/projects" -name validation.status -type f)
    fi
  done < <(find "$runs_dir" -mindepth 1 -maxdepth 1 -type d | sort)
fi

{
  printf '# Software Factory Metrics\n\n'
  printf 'Generated: %s\n\n' "$(sf_now_iso)"
  printf '| Metric | Value |\n'
  printf '|---|---:|\n'
  printf '| Total runs | %d |\n' "$total_runs"
  printf '| Completed runs | %d |\n' "$completed_runs"
  printf '| Failed runs | %d |\n' "$failed_runs"
  printf '| Project launches | %d |\n' "$launched_projects"
  printf '| Project failures | %d |\n' "$failed_projects"
  printf '| Verified projects | %d |\n' "$verified_projects"
  printf '| Validation passed | %d |\n' "$validation_passed"
  printf '| Validation failed | %d |\n' "$validation_failed"
  printf '| Branch records | %d |\n' "$branches_created"
} >"$METRICS_DIR/summary.md"

{
  printf '{\n'
  printf '  "generatedAt": "%s",\n' "$(sf_now_iso)"
  printf '  "totalRuns": %d,\n' "$total_runs"
  printf '  "completedRuns": %d,\n' "$completed_runs"
  printf '  "failedRuns": %d,\n' "$failed_runs"
  printf '  "projectLaunches": %d,\n' "$launched_projects"
  printf '  "projectFailures": %d,\n' "$failed_projects"
  printf '  "verifiedProjects": %d,\n' "$verified_projects"
  printf '  "validationPassed": %d,\n' "$validation_passed"
  printf '  "validationFailed": %d,\n' "$validation_failed"
  printf '  "branchRecords": %d\n' "$branches_created"
  printf '}\n'
} >"$METRICS_DIR/summary.json"

sf_ok "wrote $METRICS_DIR/summary.md"
sf_ok "wrote $METRICS_DIR/summary.json"
