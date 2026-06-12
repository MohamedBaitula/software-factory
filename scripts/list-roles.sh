#!/usr/bin/env bash

set -u
set -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
ROLES_DIR="$ROOT_DIR/templates/roles"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Software Factory role list

Usage:
  ./scripts/list-roles.sh
  ./scripts/list-roles.sh --help
EOF
  exit 0
fi

find "$ROLES_DIR" -maxdepth 1 -type f -name '*.md' -printf '%f\n' | sed 's/\.md$//' | sort

