# Backup sync to Spaces

The `db-backup` container writes dumps to `./backups` on the droplet. Those
live on the same disk as the database, so they survive a bad migration but not
losing the droplet. This copies them to the `anishare-analytics` Space nightly.

### 1. Install rclone

```sh
sudo -v ; curl https://rclone.org/install.sh | sudo bash
rclone version
```

### 2. Install config and credentials

```sh
cp ops/rclone.conf.example ~/.config/rclone/rclone.conf
chown root:root ~/.config/rclone/rclone.conf
chmod 600 ~/.config/rclone/rclone.conf
vim ~/.config/rclone/rclone.conf # fill in the access key and secret
```

### 3. Install the script

```sh
sudo cp /root/umami/ops/sync-backups.sh /usr/local/bin/umami-sync-backups
sudo chmod 755 /usr/local/bin/umami-sync-backups
```

### 4. Verify before automating

Check the credentials and endpoint resolve at all:

```sh
sudo bash -c 'set -a; . /etc/umami-backup/rclone.env; set +a; rclone lsd spaces:anishare-analytics'
```

Then run the sync itself:

```sh
sudo /usr/local/bin/umami-sync-backups
```

On a first run before any dump exists, expect it to transfer nothing and exit
0. That is success — it means credentials and the endpoint resolved.

### 5. Install the cron job

```sh
sudo tee /etc/cron.d/umami-backup-sync >/dev/null <<'CRON'
SHELL=/bin/bash
PATH=/usr/local/bin:/usr/bin:/bin

0 0 * * * root /usr/local/bin/umami-sync-backups >> /var/log/umami-backup-sync.log 2>&1
CRON
sudo chmod 644 /etc/cron.d/umami-backup-sync
```

`/etc/cron.d` entries need the `root` user field and a trailing newline, both
of which the heredoc above provides. Runs at 00:00 in the droplet's timezone —
check with `timedatectl` if you care which.

### 6. Confirm it ran

The morning after:

```sh
tail /var/log/umami-backup-sync.log
```

## Verifying the bucket is private

`RCLONE_CONFIG_SPACES_ACL=private` covers uploaded objects, but the bucket's own
listing permission is separate and set in the DO control panel. Check it under
Spaces → anishare-analytics → Settings; "File Listing" should be **Restricted**.

Then confirm from outside:

```sh
curl -s -o /dev/null -w '%{http_code}\n' \
  https://anishare-analytics.nyc3.digitaloceanspaces.com/
```

Expect `403`. A `200` means the bucket lists publicly.

## Bounding cost

The script uses `rclone copy`, not `sync`, so local rotation deleting a dump
never deletes the bucket's copy — the bucket only ever grows. Dumps are small,
but add a lifecycle rule when you want a ceiling, the way
`anishare-bucket-lifecycle-policies.json` does for the main bucket.
