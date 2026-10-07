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
# with scripts/restore.sh (see docs/RUNBOOK.md, "Backups and restore").
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
# The dump leaves out the storage schema, so save the photo access rules too.
supabase db query --linked -o json "$(grep -v '^--' scripts/storage-policies.sql)" |
  python3 -c 'import sys,json; t=sys.stdin.read(); i=min(x for x in (t.find("["), t.find("{")) if x >= 0); d,_=json.JSONDecoder().raw_decode(t[i:]); print((d["rows"] if isinstance(d, dict) else d)[0]["sql"])' \
  > "$dest/storage-policies.sql"
supabase storage cp --linked --experimental --recursive --jobs 4 \
  ss:///profile-photos "$dest/photos"

photos=$(find "$dest/photos" -type f | wc -l | tr -d ' ')
{
  echo "created_utc=$stamp"
  echo "git_commit=$(git rev-parse --short HEAD 2>/dev/null || echo n/a)"
  echo "photo_files=$photos"
  for f in schema.sql roles.sql data.sql storage-policies.sql; do
    echo "$f bytes=$(wc -c < "$dest/$f" | tr -d ' ')"
  done
} > "$dest/manifest.txt"
cat "$dest/manifest.txt"
echo "Done. Keep this folder private."
