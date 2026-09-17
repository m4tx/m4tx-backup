#!/usr/bin/env bash

set -e -o pipefail

BACKUP_CONF_PATH="${BACKUP_CONF_PATH:-/etc/backup.conf}"
EXPECTED_PERMS="400"
PERMS=$(stat -c '%a' "$BACKUP_CONF_PATH")

if [[ "$PERMS" != "$EXPECTED_PERMS" ]]; then
  echo "$BACKUP_CONF_PATH permissions are $PERMS instead of $EXPECTED_PERMS; please execute \`sudo chmod $EXPECTED_PERMS $BACKUP_CONF_PATH\` before running the backup script"
  exit 1
fi

source "$BACKUP_CONF_PATH"
export RESTIC_REPOSITORY RESTIC_PASSWORD
if [[ -v AWS_ACCESS_KEY_ID ]]; then
  export AWS_ACCESS_KEY_ID
fi
if [[ -v AWS_SECRET_ACCESS_KEY ]]; then
  export AWS_SECRET_ACCESS_KEY
fi

BACKUP_TAG=auto

BACKUP_PATHS=(/etc /home /root)
BACKUP_EXCLUDES=(
  --exclude='/home/*/projects/'
  --exclude='/home/*/Projects/'
  --exclude='/home/*/.local/share'
  --exclude='/home/*/Videos/'
  --exclude='/home/*/.cache'
  --exclude='/home/*/Downloads/'
  --exclude='/home/*/.debug/'
  --exclude='/home/*/.rustup/'
  --exclude='/home/*/.cargo/'
  --exclude='/home/*/Music/'
)
if [[ -d /var/lib/docker ]]; then
  BACKUP_PATHS+=(/var/lib/docker)
  BACKUP_EXCLUDES+=(--exclude='/var/lib/docker/overlay2')
fi

restic \
  backup \
  "${BACKUP_PATHS[@]}" \
  --verbose \
  --one-file-system \
  --no-scan \
  --tag=$BACKUP_TAG \
  "${BACKUP_EXCLUDES[@]}" \
  --exclude-caches
