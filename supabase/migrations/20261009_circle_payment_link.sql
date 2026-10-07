-- One payment link per Circle (for example a Tikkie), and the moment each
-- member tapped Pay.
--
-- Tikkie gives private users no API: the organiser sees who paid, by name,
-- in the Tikkie app. With one link per Circle and the time each member opened
-- it, matching a payment means picking among five or six names, then
-- confirming it in the organiser panel as before. Nothing here marks a payment
-- as received; only the organiser does that.
begin;

alter table public.circles
  add column if not exists payment_link text
    check (payment_link is null or (payment_link ~ '^https://[^\s]+$' and length(payment_link) <= 500));

alter table public.circle_payments
  add column if not exists payment_opened_at timestamptz;

-- The member tapped "Pay €19": record when, for the organiser.
create or replace function public.circle_payment_opened()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'Sign in first.'; end if;
  update public.circle_payments p
     set payment_opened_at = now()
   where p.profile_id = uid
     and p.status = 'awaiting_payment'
     and exists (select 1 from public.circle_memberships m
                  where m.profile_id = uid and m.circle_id = p.circle_id
                    and m.status <> 'left');
end;
$$;
revoke all on function public.circle_payment_opened() from public, anon;
grant execute on function public.circle_payment_opened() to authenticated;

-- Organisers set or clear a Circle's payment link.
create or replace function public.circle_set_payment_link(target uuid, link text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare clean text := nullif(trim(coalesce(link, '')), '');
begin
  if not public.circle_is_admin() then raise exception 'Organiser access required.'; end if;
  if clean is not null and (clean !~ '^https://[^\s]+$' or length(clean) > 500) then
    raise exception 'Paste the full payment link, starting with https://.';
  end if;
  update public.circles set payment_link = clean where id = target;
  if not found then raise exception 'Circle not found.'; end if;
  insert into public.circle_audit(actor, action, target_id) values (auth.uid(), 'set_payment_link', target);
end;
$$;
revoke all on function public.circle_set_payment_link(uuid, text) from public, anon;
grant execute on function public.circle_set_payment_link(uuid, text) to authenticated;

commit;
