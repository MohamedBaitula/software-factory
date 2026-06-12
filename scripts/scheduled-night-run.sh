#!/usr/bin/env bash

set -u
set -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"

cd "$ROOT_DIR"

if [[ -s "$HOME/.nvm/nvm.sh" ]]; then
  # shellcheck source=/dev/null
  source "$HOME/.nvm/nvm.sh"
fi

printf '[INFO] Scheduled run started at %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')"
printf '[INFO] Make sure the machine is plugged in, awake, and connected before using this from cron/systemd.\n'

./scripts/doctor.sh
./scripts/run-night.sh
./scripts/summarize.sh
./scripts/update-metrics.sh
./scripts/dashboard.sh

printf '[INFO] Scheduled run finished at %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')"
