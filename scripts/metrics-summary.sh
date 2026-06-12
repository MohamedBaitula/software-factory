#!/usr/bin/env bash

set -u
set -o pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SUMMARY="$ROOT_DIR/metrics/summary.md"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Software Factory metrics summary

Usage:
  ./scripts/metrics-summary.sh
  ./scripts/metrics-summary.sh --help
EOF
  exit 0
fi

if [[ ! -f "$SUMMARY" ]]; then
  printf '[FAIL] metrics summary not found. Run ./scripts/update-metrics.sh first.\n' >&2
  exit 1
fi

cat "$SUMMARY"

