#!/usr/bin/env bash

set -u
set -o pipefail

usage() {
  cat <<'EOF'
Software Factory WSL Codex setup helper

Usage:
  ./scripts/setup-wsl-codex.sh
  ./scripts/setup-wsl-codex.sh --help

Installs or verifies Linux-native Node 22 through nvm, then installs the Codex
CLI with npm. It does not perform Codex login for you.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ "$#" -gt 0 ]]; then
  usage
  printf '[FAIL] setup-wsl-codex does not accept arguments\n' >&2
  exit 2
fi

if [[ ! -s "$HOME/.nvm/nvm.sh" ]]; then
  printf '[INFO] nvm not found; installing nvm\n'
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
fi

# shellcheck source=/dev/null
source "$HOME/.nvm/nvm.sh"

nvm install 22
nvm alias default 22
nvm use 22
npm install -g @openai/codex@latest
codex features enable goals >/dev/null 2>&1 || true

printf '\nInstalled versions:\n'
node --version
npm --version
codex --version
codex features list | awk '$1=="goals"{print}'

printf '\nNext step if needed:\n'
printf '  codex login\n'
