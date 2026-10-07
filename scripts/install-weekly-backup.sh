#!/bin/bash
# Installs (or updates) the weekly backup on this Mac: Sundays at 10:00, or
# when the Mac next wakes. macOS does not let scheduled jobs read the Desktop
# folder, so the job runs from a copy of the backup scripts and the Supabase
# link in ~/Library/Application Support/VriendTime/backup. Re-run this after
# changing scripts/backup.sh. Remove with:
#   launchctl bootout gui/$(id -u)/com.vriendtime.backup
set -euo pipefail
cd "$(dirname "$0")/.."
home="$HOME/Library/Application Support/VriendTime/backup"
plist="$HOME/Library/LaunchAgents/com.vriendtime.backup.plist"
mkdir -p "$home/scripts" "$home/supabase"
cp scripts/backup.sh scripts/backup-weekly.sh scripts/storage-policies.sql "$home/scripts/"
rm -rf "$home/supabase/.temp" && cp -R supabase/.temp "$home/supabase/.temp"
cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.vriendtime.backup</string>
  <key>ProgramArguments</key>
  <array><string>/bin/bash</string><string>$home/scripts/backup-weekly.sh</string></array>
  <key>StartCalendarInterval</key>
  <dict><key>Weekday</key><integer>0</integer><key>Hour</key><integer>10</integer><key>Minute</key><integer>0</integer></dict>
</dict>
</plist>
PLIST
launchctl bootout "gui/$(id -u)/com.vriendtime.backup" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$plist"
echo "Weekly backup installed. Test now with: launchctl kickstart gui/$(id -u)/com.vriendtime.backup"
