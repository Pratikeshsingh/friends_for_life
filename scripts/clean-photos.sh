#!/usr/bin/env bash
# Remove profile photos nobody uses any more: replaced photos whose clean-up
# failed, and photos of accounts deleted outside the app (for example in the
# Supabase dashboard). A member's current photo is never touched, nor is any
# photo uploaded in the last 24 hours.
#
#   ./scripts/clean-photos.sh           # list what would be deleted
#   ./scripts/clean-photos.sh --apply   # delete it
#
# Files must be deleted through the Storage API; deleting rows with SQL would
# leave the files behind. Needs the Supabase CLI, logged in and linked.
set -euo pipefail
cd "$(dirname "$0")/.."

project="sageyiqyvzgoayehahyq"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

supabase db query --linked -o json "
select o.name from storage.objects o
 where o.bucket_id = 'profile-photos'
   and o.created_at < now() - interval '1 day'
   and not exists (select 1 from public.profiles p where p.profile_photo_path = o.name)
 order by o.name" > "$work/rows.json"

python3 - "$work/rows.json" "$work/delete.json" <<'PY'
import json, re, sys
rows = json.load(open(sys.argv[1])).get('rows', [])
names = [r['name'] for r in rows if re.fullmatch(r'[0-9a-f-]{36}/[^/]+', r.get('name') or '')]
json.dump({'prefixes': names}, open(sys.argv[2], 'w'))
print(f"{len(names)} unused photo file(s)")
for n in names[:50]:
    print('  ' + n)
PY

if [[ "${1:-}" != "--apply" ]]; then
  echo "Nothing deleted. Run with --apply to delete these files."
  exit 0
fi

count=$(python3 -c "import json,sys; print(len(json.load(open(sys.argv[1]))['prefixes']))" "$work/delete.json")
if [[ "$count" == "0" ]]; then echo "Nothing to delete."; exit 0; fi

key=$(supabase projects api-keys --project-ref "$project" -o json \
  | python3 -c "import json,sys; print(next(k['api_key'] for k in json.load(sys.stdin) if k.get('name') == 'service_role'))")
curl -sf -X DELETE "https://$project.supabase.co/storage/v1/object/profile-photos" \
  -H "apikey: $key" -H "Authorization: Bearer $key" \
  -H "Content-Type: application/json" --data @"$work/delete.json" \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(f'Deleted {len(d)} file(s).')"
