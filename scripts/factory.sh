#!/usr/bin/env bash

set -u
set -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Software Factory command center

Usage:
  ./scripts/factory.sh doctor
  ./scripts/factory.sh goals
  ./scripts/factory.sh run-goal <goal-file>
  ./scripts/factory.sh run-ready [--dry-run]
  ./scripts/factory.sh run-project [args...]
  ./scripts/factory.sh run-night [args...]
  ./scripts/factory.sh verify <project>
  ./scripts/factory.sh summarize
  ./scripts/factory.sh metrics
  ./scripts/factory.sh dashboard
  ./scripts/factory.sh runs
EOF
}

cmd="${1:-}"
if [[ -z "$cmd" || "$cmd" == "--help" || "$cmd" == "-h" ]]; then
  usage
  exit 0
fi
shift

case "$cmd" in
  doctor) exec "$SCRIPT_DIR/doctor.sh" "$@" ;;
  goals) exec "$SCRIPT_DIR/list-goals.sh" "$@" ;;
  run-goal) exec "$SCRIPT_DIR/run-goal.sh" "$@" ;;
  run-ready) exec "$SCRIPT_DIR/run-ready-goals.sh" "$@" ;;
  run-project) exec "$SCRIPT_DIR/run-project.sh" "$@" ;;
  run-night) exec "$SCRIPT_DIR/run-night.sh" "$@" ;;
  verify) exec "$SCRIPT_DIR/verify-project.sh" "$@" ;;
  summarize) exec "$SCRIPT_DIR/summarize.sh" "$@" ;;
  metrics) exec "$SCRIPT_DIR/metrics-summary.sh" "$@" ;;
  update-metrics) exec "$SCRIPT_DIR/update-metrics.sh" "$@" ;;
  dashboard) exec "$SCRIPT_DIR/dashboard.sh" "$@" ;;
  runs) exec "$SCRIPT_DIR/list-runs.sh" "$@" ;;
  show-run) exec "$SCRIPT_DIR/show-run.sh" "$@" ;;
  roles) exec "$SCRIPT_DIR/list-roles.sh" "$@" ;;
  *)
    usage
    printf '[FAIL] unknown command: %s\n' "$cmd" >&2
    exit 2
    ;;
esac

