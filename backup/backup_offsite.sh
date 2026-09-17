#!/usr/bin/env bash

set -e -o pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <source_backup_conf> <offsite_backup_conf>"
  exit 1
fi

SOURCE_CONF_PATH=$1
OFFSITE_CONF_PATH=$2

EXPECTED_PERMS="400"

for CONF in "$SOURCE_CONF_PATH" "$OFFSITE_CONF_PATH"; do
  if [[ ! -f "$CONF" ]]; then
    echo "$CONF does not exist"
    exit 1
  fi
  PERMS=$(stat -c '%a' "$CONF")
  if [[ "$PERMS" != "$EXPECTED_PERMS" ]]; then
    echo "$CONF permissions are $PERMS instead of $EXPECTED_PERMS; please execute \`sudo chmod $EXPECTED_PERMS $CONF\` before running the backup script"
    exit 1
  fi
done

# We use a subshell to avoid clashing variables if they have the same names
SOURCE_REPO=$(source "$SOURCE_CONF_PATH"; echo "$RESTIC_REPOSITORY")
SOURCE_PASSWORD=$(source "$SOURCE_CONF_PATH"; echo "$RESTIC_PASSWORD")

source "$OFFSITE_CONF_PATH"
export RESTIC_REPOSITORY RESTIC_PASSWORD
if [[ -v AWS_ACCESS_KEY_ID ]]; then
  export AWS_ACCESS_KEY_ID
fi
if [[ -v AWS_SECRET_ACCESS_KEY ]]; then
  export AWS_SECRET_ACCESS_KEY
fi

BACKUP_TAG=auto
KEEP_LAST=7

RETENTION_DAYS=7
RETENTION_WEEKS=4
RETENTION_MONTHS=6
RETENTION_YEARS=2

# Only copy the newest snapshots each run; older history is expected to
# already be present offsite from a one-time initial full copy, and the
# forget policy below prunes it in place without needing to re-copy it.
readarray -t LATEST_SNAPSHOT_IDS < <(
  restic -r "$SOURCE_REPO" --password-file <(echo -n "$SOURCE_PASSWORD") \
    snapshots --tag $BACKUP_TAG --latest $KEEP_LAST --json |
    grep -oP '"id":"\K[0-9a-f]+'
)

# Copy snapshots from local to offsite
echo "Copying snapshots from $SOURCE_REPO to $RESTIC_REPOSITORY..."
restic copy \
  --verbose \
  --from-repo "$SOURCE_REPO" \
  --from-password-file <(echo -n "$SOURCE_PASSWORD") \
  "${LATEST_SNAPSHOT_IDS[@]}"

restic forget \
  --verbose \
  --tag $BACKUP_TAG \
  --prune \
  --keep-daily $RETENTION_DAYS \
  --keep-weekly $RETENTION_WEEKS \
  --keep-monthly $RETENTION_MONTHS \
  --keep-yearly $RETENTION_YEARS

restic check
