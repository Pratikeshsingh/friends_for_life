#!/usr/bin/env bash
# Back up VriendTime: database structure, all data (including sign-in
# accounts) and the profile photos, into a dated folder outside the project.
#
#   ./scripts/backup.sh                 # saves to ~/VriendTime-backups
#   ./scripts/backup.sh /Volumes/Drive  # or another folder
#
# Needs the Supabase CLI, logged in and linked to the project
# (`supabase login`, `supabase link`). The backup contains personal data:
# keep it somewhere private and encrypted, never in this repository.
# To prove it works, restore it into a separate, empty Supabase project once
# (see docs/RUNBOOK.md, "Backups and restore").
set -euo pipefail
cd "$(dirname "$0")/.."

root="${1:-$HOME/VriendTime-backups}"
stamp="$(date -u +%Y-%m-%dT%H%MZ)"
dest="$root/$stamp"
mkdir -p "$dest/photos"
chmod 700 "$root" "$dest"

echo "Backing up to $dest"
supabase db dump --linked --file "$dest/schema.sql"
supabase db dump --linked --role-only --file "$dest/roles.sql"
supabase db dump --linked --data-only --use-copy \
  --schema public,auth,storage --file "$dest/data.sql"
supabase storage cp --linked --experimental --recursive --jobs 4 \
  ss:///profile-photos "$dest/photos"

photos=$(find "$dest/photos" -type f | wc -l | tr -d ' ')
{
  echo "created_utc=$stamp"
  echo "git_commit=$(git rev-parse --short HEAD)"
  echo "photo_files=$photos"
  for f in schema.sql roles.sql data.sql; do
    echo "$f bytes=$(wc -c < "$dest/$f" | tr -d ' ')"
  done
} > "$dest/manifest.txt"
cat "$dest/manifest.txt"
echo "Done. Keep this folder private."
