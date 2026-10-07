-- Clean slate after the pilot test accounts were deleted (7 Oct 2026), and
-- admin@vriendtime.com as the organiser.
--
-- Removes what the deleted test accounts left behind: the test Circle with
-- its meetups, chat and messages; payment records and audit lines whose
-- account no longer exists; and the error log from testing. Real accounts
-- are not touched. Photos are removed separately with scripts/clean-photos.sh.
begin;

-- Organiser: run again now that the admin@ account exists (it was signed
-- up after 20261013 ran).
insert into public.circle_admins(profile_id)
select id from public.profiles where lower(email) = 'admin@vriendtime.com'
on conflict do nothing;

-- The test Circle (cascades to its meetups, memberships, chat and messages).
delete from public.circles c
 where not exists (select 1 from public.circle_memberships m
                    join auth.users u on u.id = m.profile_id
                   where m.circle_id = c.id);

delete from public.circle_payments where profile_id is null;
delete from public.circle_audit where actor is null;
delete from public.app_error_events;

commit;
