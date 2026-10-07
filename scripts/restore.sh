#!/usr/bin/env bash
# Restore a backup made by scripts/backup.sh into an EMPTY Supabase project.
#
#   ./scripts/restore.sh <backup-folder> <project-ref> <file-with-connection-string>
#
# The connection string is the target project's "Session pooler" address with
# the password filled in, saved as a one-line file so it never appears on
# screen. Needs Docker (for psql) and the Supabase CLI logged in with access
# to the target project. Refuses to run against the live project.
#
# Order: roles, structure, data (skipping empty tables, which include
# Supabase-managed ones we may not write to), photo access rules, then the
# photo files. The photo files go through the Storage API, which refuses a
# file whose database row already exists, so the restored rows are set aside,
# the files uploaded, and the original owners put back.
set -euo pipefail
cd "$(dirname "$0")/.."

backup="${1:?backup folder}"; ref="${2:?target project ref}"; urlfile="${3:?connection string file}"
live="sageyiqyvzgoayehahyq"
url="$(tr -d '\n' < "$urlfile")"
[[ "$ref" != "$live" && "$url" != *"$live"* ]] || { echo "Refusing: that is the live project."; exit 1; }
[[ "$url" == *"$ref"* ]] || { echo "The connection string is not for project $ref."; exit 1; }

psql() { docker run --rm -i -e PGURL="$url" -v "$(cd "$backup" && pwd)":/b:ro postgres:17-alpine \
  sh -c 'psql "$PGURL" -X -q -v ON_ERROR_STOP=1 "$@"' psql "$@"; }

existing=$(psql -A -t -c "select count(*) from auth.users")
[[ "$existing" == "0" ]] || { echo "The target project is not empty ($existing accounts)."; exit 1; }

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
python3 - "$backup/data.sql" "$work/data.sql" <<'PY'
import sys
lines = open(sys.argv[1]).read().split('\n'); out = []; i = 0
while i < len(lines):
    if lines[i].startswith('COPY ') and i + 1 < len(lines) and lines[i + 1] == '\\.':
        i += 2; continue
    out.append(lines[i]); i += 1
open(sys.argv[2], 'w').write('\n'.join(out))
PY
cp "$work/data.sql" "$backup/.data-restore.sql"; trap 'rm -rf "$work" "$backup/.data-restore.sql"' EXIT

echo "Restoring database…"
psql --single-transaction -f /b/roles.sql -f /b/schema.sql \
  -c "SET session_replication_role = replica" -f /b/.data-restore.sql
psql --single-transaction -f /b/storage-policies.sql

echo "Restoring photos…"
psql -1 -c "create table public._restore_photo_meta as select name, owner, owner_id, created_at from storage.objects where bucket_id = 'profile-photos'" \
  -c "set local storage.allow_delete_query = 'true'" \
  -c "delete from storage.objects where bucket_id = 'profile-photos'"
mkdir -p "$work/supabase"
SUPABASE_DB_PASSWORD="$(python3 -c 'import sys,urllib.parse; print(urllib.parse.unquote(urllib.parse.urlsplit(sys.argv[1]).password or ""))' "$url")" \
  supabase link --project-ref "$ref" --workdir "$work" >/dev/null
photos="$backup/photos/profile-photos"
(cd "$photos" && find . -type f | sed 's|^\./||') | while read -r f; do
  supabase storage cp --linked --experimental --workdir "$work" "$photos/$f" "ss:///profile-photos/$f" >/dev/null
done
psql -1 -c "update storage.objects o set owner = m.owner, owner_id = m.owner_id, created_at = m.created_at from public._restore_photo_meta m where o.bucket_id = 'profile-photos' and o.name = m.name" \
  -c "drop table public._restore_photo_meta"

psql -A -t -c "select 'accounts=' || (select count(*) from auth.users) || ' profiles=' || (select count(*) from public.profiles) || ' photos=' || (select count(*) from storage.objects) || ' rules=' || (select count(*) from pg_policies where schemaname in ('public','storage'))"
echo "Done. Scheduled jobs, Edge Functions and their secrets are not part of a backup; see docs/RUNBOOK.md."
