#!/usr/bin/env bash

set -e -o pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

if [[ $EUID -ne 0 ]];
then
    exec sudo /bin/bash "$0" "$@"
fi

useradd -r -m -s /sbin/nologin restic || echo "System account 'restic' already exists; skipping creating one"

cat >/etc/systemd/system/backup.timer <<EOF
[Unit]
Description=Backup on schedule

[Timer]
OnCalendar=*-*-* 4:00:00
Persistent=true
RandomizedDelaySec=900

[Install]
WantedBy=timers.target
EOF

cat >/etc/systemd/system/backup.service <<EOF
[Unit]
Description=Backup with Restic
OnFailure=failure-notification@%n.service

StartLimitIntervalSec=30min
StartLimitBurst=4

[Service]
Type=simple
Nice=10
User=restic
Group=restic
ExecStart=/opt/m4tx-backup/backup.sh
# Grant read access to all files
AmbientCapabilities=CAP_DAC_READ_SEARCH

Restart=on-failure
RestartSec=5min
EOF

cat >/etc/systemd/system/failure-notification@.service <<EOF
[Unit]
Description=Send notification about a failed service %i

[Service]
Type=oneshot
ExecStart=/opt/m4tx-backup/notify_on_final_failure.sh "%i" "%H"
EOF

systemctl daemon-reload
systemctl enable --now backup.timer

BACKUP_CONF_PATH=/etc/backup.conf
cp -n "${SCRIPT_DIR}"/backup/backup.conf.example "$BACKUP_CONF_PATH"
cp -n "${SCRIPT_DIR}"/ntfy.conf.example "/etc/ntfy.conf"

chown -R restic:restic /opt/m4tx-backup
chown restic:restic "$BACKUP_CONF_PATH"

echo
echo "Backup config path is $BACKUP_CONF_PATH. Please edit if necessary (but remember to change the permissions to 400 after making any changes)."
echo
echo "Installation is now complete!"
