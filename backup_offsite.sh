#!/usr/bin/env bash

set -e -o pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

if [[ -v BACKUP_AUTO_UPDATE ]]; then
  "${SCRIPT_DIR}"/update.sh
fi
"${SCRIPT_DIR}"/backup/backup_offsite.sh "$@"
