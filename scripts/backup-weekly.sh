#!/bin/bash
# Weekly backup, run by macOS (launchd agent com.vriendtime.backup, Sundays
# 10:00; if the Mac is asleep then, it runs when it wakes). Starts Docker if
# needed, runs scripts/backup.sh into ~/VriendTime-backups, keeps the newest
# eight backups, and shows a notification. Log: ~/VriendTime-backups/backup.log
set -uo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/Library/Frameworks/Python.framework/Versions/3.13/bin:/usr/bin:/bin:/usr/sbin:/sbin"
root="$HOME/VriendTime-backups"
mkdir -p "$root"
exec >>"$root/backup.log" 2>&1
echo "=== $(date)"
notify() { osascript -e "display notification \"$1\" with title \"VriendTime backup\""; }

# Docker Desktop should start at login (Docker → Settings → General); if it
# is not running, start it and wait up to five minutes.
if ! docker info >/dev/null 2>&1; then
  open -a Docker
  for _ in $(seq 1 60); do docker info >/dev/null 2>&1 && break; sleep 5; done
fi

if "$(dirname "$0")/backup.sh" "$root"; then
  # Keep the newest eight weekly backups.
  ls -1d "$root"/20*Z 2>/dev/null | sort -r | tail -n +9 | while read -r old; do
    echo "Removing old backup $old"; rm -rf "$old"
  done
  notify "Backup done."
  status=0
else
  notify "Backup FAILED. See VriendTime-backups/backup.log"
  status=1
fi
exit $status
