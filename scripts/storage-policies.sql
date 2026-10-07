-- Prints the storage access rules (photo policies) as SQL that recreates
-- them. `supabase db dump` leaves the storage schema out, so the backup
-- saves these separately. Used by scripts/backup.sh.
select string_agg(
  format('drop policy if exists %I on %I.%I;', policyname, schemaname, tablename) || E'\n' ||
  format('create policy %I on %I.%I as %s for %s to %s%s%s;',
    policyname, schemaname, tablename, permissive, cmd,
    array_to_string(array(select quote_ident(r) from unnest(roles) r), ', '),
    coalesce(' using (' || qual || ')', ''),
    coalesce(' with check (' || with_check || ')', '')),
  E'\n' order by tablename, policyname) as sql
from pg_policies
where schemaname = 'storage';
