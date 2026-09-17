#!/usr/bin/env bash

set -e -o pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

if [[ $EUID -ne 0 ]];
then
    exec sudo /bin/bash "$0" "$@"
fi

cat >/etc/systemd/system/backup-cleanup@.timer <<EOF
[Unit]
Description=Remove old Restic backups on schedule

[Timer]
OnCalendar=*-*-* 6:00:00
Persistent=true
RandomizedDelaySec=900

[Install]
WantedBy=timers.target
EOF

cat >/etc/systemd/system/backup-cleanup@.service <<EOF
[Unit]
Description=Remove old Restic backups
OnFailure=failure-notification@%n.service

StartLimitIntervalSec=30min
StartLimitBurst=4

[Service]
Type=simple
Nice=10
User=restic
Group=restic
ExecStart=/opt/m4tx-backup/backup_cleanup.sh /etc/%i.conf
# Grant read access to all files
AmbientCapabilities=CAP_DAC_READ_SEARCH

Restart=on-failure
RestartSec=5min
EOF

cat >/etc/systemd/system/backup-offsite@.timer <<EOF
[Unit]
Description=Copy Restic snapshots offsite on schedule

[Timer]
OnCalendar=*-*-* 7:00:00
Persistent=true
RandomizedDelaySec=900

[Install]
WantedBy=timers.target
EOF

cat >/etc/systemd/system/backup-offsite@.service <<EOF
[Unit]
Description=Copy Restic snapshots offsite
OnFailure=failure-notification@%n.service

StartLimitIntervalSec=30min
StartLimitBurst=4

[Service]
Type=simple
Nice=10
User=restic
Group=restic
ExecStart=/opt/m4tx-backup/backup_offsite.sh /etc/%i.conf /etc/%i-offsite.conf

Restart=on-failure
RestartSec=5min
EOF

systemctl daemon-reload
systemctl enable --now backup-cleanup@backup.timer
systemctl enable --now backup-offsite@backup.timer

cp -n "${SCRIPT_DIR}"/backup/backup-offsite.conf.example "/etc/backup-offsite.conf"
