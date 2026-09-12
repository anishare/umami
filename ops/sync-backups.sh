#!/bin/bash
# Copy local Postgres dumps to Spaces for off-droplet redundancy.
#
# Run from cron; see ops/README.md for installation. Cron provides almost no
# environment, so everything this needs is resolved here rather than inherited.

set -euo pipefail

BACKUP_DIR=${BACKUP_DIR:-/root/umami/backups}
DEST=${DEST:-spaces:anishare-analytics/backups}

if [[ ! -d $BACKUP_DIR ]]; then
	echo "$(date -Is) backup directory does not exist: $BACKUP_DIR" >&2
	exit 1
fi

echo "$(date -Is) syncing $BACKUP_DIR -> $DEST"

# copy, not sync: local rotation deleting an old dump must never delete the
# bucket's copy of it. Bound growth with a lifecycle rule on the bucket instead.
#
# --min-age skips a dump still being written, so a run that overlaps pg_dump
# uploads nothing rather than a truncated file.
rclone copy "$BACKUP_DIR" "$DEST" \
	--min-age 5m \
	--transfers 2 \
	--retries 3 \
	--stats-one-line \
	--log-level INFO

echo "$(date -Is) sync complete"
