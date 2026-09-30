# Friendship Circles — trying this build

The app now opens with the Circle proposition, using the existing illustrations,
Newsreader/Manrope fonts, navy/teal/coral palette, section cards, and floating navigation.

## Try locally

```sh
flutter pub get
flutter build web --release
python3 -m http.server 8765 --bind 127.0.0.1 --directory build/web
```

Open http://127.0.0.1:8765 for the public app: an explanatory landing page,
live public activities, sign-in, and account creation. The normal build contains
no preview entry points. Even an old `?preview=1` link opens the public app.

For internal testing only, opt into the isolated demo with:
`flutter build web --release --dart-define=CIRCLES_ENABLE_PREVIEW=true`
then open http://127.0.0.1:8765/?preview=1. Never use that build for the public site.

Preview progress is saved on this browser/device. It does not read or write real
Supabase accounts, applications, messages, or payments. All member profiles are examples.
The preview initially opens an active Circle so the main experience is immediately visible.
Use **Explore** in the top bar to try:

1. **Application:** four steps, optional context/photo, availability, interests, social energy,
   and commitment. Save a draft, return, or submit to the waiting screen.
2. **Waiting:** matching status, preferences, edit answers, or withdraw.
3. **Invitation:** member profiles and schedule; join through explicitly labelled demo checkout.
4. **Six-week experience:** confirm/change RSVP, view profiles, send messages, and make plans.
   “Preview: finish this meetup” exposes its private check-in and advances the journey.
5. **Graduation:** outcome questions, continued messaging, and plan the next meetup.
6. **Organiser:** top-bar sliders icon; inspect example applications, select 5–6 people,
   create a Circle, edit weekly plans, record attendance, and try a demo refund.

Switching stages loads an example of that stage. **Reset preview** clears local preview
progress. The invitation's 8 October date is illustrative, not a promised pilot launch date.

## Implemented backend

`supabase/migrations/20260918_friendship_circles.sql` adds applications, stable membership,
Circles, links to existing events/chat threads, private check-ins, outcome responses,
refund requests, operator roles, and an audit trail. The Flutter Supabase repository calls
three narrowly scoped authenticated RPCs. Client code cannot assign members, set payment
state, or grant operator access.

Circle events are excluded from the public catalog. An attendance trigger also protects
older reservation RPCs. All Circle tables use RLS with direct app access revoked; the
RPCs authenticate and enforce membership or operator access. Member projections expose
only basic names/interests, not questionnaire context, age, or contact details.

Six weekly events are generated in Europe/Amsterdam local time, preserving the chosen
meeting hour across DST. Actual attendance is distinct from RSVP. The refund window is
measured from the recorded first meetup end time, not when the organiser presses Complete.
The operator must record actual meetup completion; six calendar weeks alone do not graduate
a Circle. Group messages and member-created plans stay available after completion.

## Deployment still required

The live Supabase project has **not** been changed. Before using real applications:

1. Back up the database and apply the migration in staging, **after** the existing
   `schema.sql` and `release_hardening.sql`. Do not subsequently reapply the old catalog
   view definition, which lacks the Circle visibility filter.
2. Assign named operators from a trusted SQL/admin context:
   `insert into public.circle_admins(profile_id) values ('AUTH_USER_UUID');`
   Never place service credentials in the Flutter client.
3. Schedule `select public.queue_circle_notifications();` hourly using a trusted
   Supabase scheduler. It deduplicates upcoming-meetup reminders, private check-in prompts,
   graduation updates, and 90-day follow-ups. These are **in-app notifications**; email/push
   delivery has not been configured.
4. Verify signup/email confirmation, profile photo upload, real cross-account messaging,
   operator formation, and account deletion against staging.
5. Connect a payment provider before accepting paid members. Live `join` deliberately
   returns “Payments are not open yet”; a browser return URL cannot fake payment success.

## Payment boundary

No payment provider has been selected or connected. Demo checkout and demo refunds move
no money. Before charging users, implement server-created checkout, verified/idempotent
provider callbacks, payment references and reconciliation, refund execution/confirmation,
and group cancellation handling. Successful trusted payment processing must update
membership and chat participation atomically. Do not manually mark real users paid as a
substitute for verified payment processing.

The current migration supplies the invitation/payment-status boundary and refund-request
workflow, **not a working payment gateway**. Operational decisions on invitation expiry,
withdrawal/replacement after launch, and cancellation refunds still need to be agreed for
the real pilot. Terms/privacy wording also needs to cover the Circle programme before launch.

## Outcome measurement

Organiser counts include applications, paid membership, completed Circles, actual meetup 1
and week 3 attendance, self-reported friends, outcome response count, and day-90 eligibility,
responses, and positive reports. The live 90-day question is only accepted after day 90.
Show response coverage when interpreting outcomes; missing responses are unknown.

## Validation

- `flutter analyze --no-pub`
- `flutter test --no-pub` (existing regression suite plus Circle tests)
- `flutter build web --release --no-pub`
- Actual phone/desktop browser screenshot review.
- Isolated PostgreSQL tests using `supabase/tests/local_bootstrap.sql`, then the existing
  schema/hardening and new migration, followed by `supabase/tests/circle_access_test.sql`.
  **The bootstrap is for a disposable local database only**, never live Supabase.

The database tests exercise real RPCs with simulated authenticated identities, public
catalog isolation, legacy-booking bypass rejection, shared-language/schedule formation,
local time across DST, RSVP idempotency, message persistence, private feedback, actual
attendance, refund deadlines, and notification deduplication. Provider tests must be added
when the payment provider is connected.
