# VriendTime runbook

The one place for how VriendTime is run. Keep it current when something
changes. No passwords or keys belong here.

## What runs where

| Part | Where | Notes |
|---|---|---|
| Web app | Netlify, site vriendtime.com | Built from `main` by `scripts/netlify-build.sh`. Each build is stamped `1.0.0+<commit>`; the stamp shows in Profile and in error reports. |
| Database, sign-in, photos | Supabase project `sageyiqyvzgoayehahyq` (EU, Free plan) | Photos in the private `profile-photos` bucket. |
| Account deletion | Edge Function `delete-account` | Deployed. |
| Notification emails | Edge Function `send-notifications`, called every 10 minutes by the database job `vriendtime-send-emails` | Sends app notifications through Resend from hello@vriendtime.com, replies to support@. Set up once as in "Turning on app emails" below. The email switch in Profile shows only in builds with `EMAIL_DELIVERY=true` (a Netlify environment variable). |
| Calendar links | Edge Function `calendar` | Serves a meetup or a one-to-one coffee as an `.ics` file for Apple Calendar. Public on purpose (calendar apps can't sign in); links carry random IDs. Deploy: `supabase functions deploy calendar --no-verify-jwt`. |
| Booking emails to places | Sent by `send-notifications` from the `circle_venue_emails` queue | The organiser's "Send booking email" button queues one; it goes out within 10 minutes. After three failed tries the organiser gets "A booking email failed". |
| Code and checks | GitHub `Pratikeshsingh/friends_for_life` | Checks: app, database suites, server functions. |

Deploying the server functions (from the project folder, signed in with
`supabase login`): `supabase functions deploy send-notifications --no-verify-jwt`,
`supabase functions deploy calendar --no-verify-jwt`, and
`supabase functions deploy delete-account`.

Scheduled jobs inside the database (times in UTC):

| Job | Schedule | Does |
|---|---|---|
| `vriendtime-send-emails` | every 10 minutes | Calls `send-notifications`, only when an email or a booking email is waiting |
| `vriendtime-circle-notifications` | hourly at :15 | Meetup-tomorrow reminders, check-in prompts and later programme messages |
| `vriendtime-coffees` | hourly at :15 | Suggests the one-to-one coffees |
| `vriendtime-coffee-reminders` | hourly at :00 | "Coffee with Anna today" at 08:00 Netherlands time on the day of a coffee |
| `vriendtime-meetup-housekeeping` | hourly at :05 | Marks meetups done; organiser alerts for a week without a place (3 days ahead) or not booked (2 weeks ahead); the week 5 email, chat message and alert |
| `vriendtime-pay-by-reminders` | hourly at :30 | The day-before pay-by reminder; open seats after 7 days; "ready to start" and 14-day alerts; moving placeholder start dates |
| `vriendtime-circle-prompts` | hourly at :50 | After week 2: the WhatsApp group question; waiting applicants: "Still free at your times?" every four weeks |
| `vriendtime-circle-alerts` | hourly at :45 | Tells the organiser when a Circle can be formed or someone missed two meetups (at most daily) |
| `vriendtime-organiser-digest` | hourly at :00 | One "Things to do" email to the organiser at 09:00, 13:00 and 18:00 Netherlands time, when something new came in |
| `vriendtime-chat-digest` | daily 17:00 | The daily email about unread group messages |
| `vriendtime-purge-action-requests` | daily 03:30 | Deletes retry copies older than 7 days |
| `vriendtime-purge-error-events` | daily 03:40 | Deletes error records older than 30 days |
| `vriendtime-purge-old-records` | daily 03:50 | Deletes notifications older than a year, and reports resolved over a year ago |

## Turning on app emails

One-time set-up. Account emails (sign-up, password reset) already go through
Resend via Supabase's SMTP settings; this is for the app's own notifications.

1. Make a long random secret in Terminal: `openssl rand -hex 32`. Keep it
   for steps 2 and 4 only; don't save it anywhere else.
2. Supabase → Edge Functions → Secrets, add:
   - `RESEND_API_KEY`: a Resend API key with "Sending access" (a separate key
     from the SMTP one is fine)
   - `NOTIFICATION_FROM`: `VriendTime <hello@vriendtime.com>`
   - `NOTIFICATION_CRON_SECRET`: the secret from step 1
   - `APP_URL`: `https://vriendtime.com`
3. Deploy the worker from the project folder:
   `supabase functions deploy send-notifications --no-verify-jwt`
   (the secret, not a login, protects it).
4. In the SQL editor, store the same secret for the schedule:
   `select vault.create_secret('PASTE-THE-SECRET', 'notification_cron_secret');`
5. Run `supabase/migrations/20261012_email_delivery.sql`. It starts the
   schedule, and older notifications are not emailed.
6. Netlify → Site configuration → Environment variables: `EMAIL_DELIVERY` =
   `true`. It takes effect with the next deploy.
7. Test with your own account, in the SQL editor:
   `insert into notifications(recipient_profile_id, kind, title, body) select id, 'update', 'Test email', 'If you can read this, app emails work.' from profiles where email = 'YOUR-EMAIL';`
   The email arrives within 10 minutes; Resend → Emails shows each send.

If emails stop: Supabase → Edge Functions → send-notifications → Logs, and
`select title, email_attempts, email_error from notifications where emailed_at is null order by created_at desc limit 20;`.
An error of "Email provider limit reached" means Resend's daily cap; those
emails go out by themselves an hour later.

## Releasing a change

1. Run `./scripts/check-release.sh` and the database tests locally.
2. If the change needs a database migration, decide the order:
   - **App first, then migration** when the migration removes something the
     live app still uses (columns, functions).
   - **Migration first, then app** when the new app needs something the
     migration adds.
3. Push to `main`. Wait for the three GitHub checks to pass and Netlify to
   deploy. The new build stamp appears in Profile.
4. Run the migration in the Supabase SQL editor, then verify it.
5. Sign in on vriendtime.com and open home, Profile and the organiser panel.

Migrations are applied by hand in the SQL editor; the project has no
migration ledger. `supabase/migrations/` lists every change in order. Never
re-run old migrations or `supabase/schema.sql` against production; several
later migrations depend on what earlier ones renamed or removed.

Rolling back the web app: redeploy an earlier build in Netlify. Only do that
if the database has not since removed something that build needs.

## Payments, refunds and moves

Circles made from 16 October 2026 pay first (migration 20261040); older
Circles keep the old flow (meet the group, then pay).

- Form a Circle as before (5–6 people for one time). Members get "We’ve found
  people for your times": they see six seats and how many are confirmed, the
  six weeks and their costs, but no names, photos, dates, places or chat.
  The start date you choose when forming is only a placeholder; it moves on a
  week at a time so it never comes within 3 days.
- Accepting records an agreement to pay €39; it does not take money. The
  member pays through the payment link. Check the bank and confirm receipt
  (To do → Payments to confirm). That confirms their place.
- Seven days without paying: they get "Your seat is open again", go back on
  the waiting list, and you get "A seat is open". Invite someone from the
  waiting list into that seat. The late person can still pay until the start:
  with a free seat they join; if not, confirming their payment turns it into
  a €39 credit for their next group (shown as "Moving · already paid").
- With 5 paid you get "A group is ready to start" (To do → Groups ready to
  start). Press Start this Circle and choose the first date: the group's own
  weekday, at least 3 days ahead (usually the week after). The six weeks move
  to it, paid members hear the date, and the group, places and chat open.
  Then book the weeks as usual.
- After 14 days with paid members still waiting, they get "Your group needs a
  little longer" (no refund mentioned) and you get "A group is waiting".
- Refund: before the start the member can cancel in Profile; it appears under
  Refunds to send. Return the money, then press Confirm refund completed.
  After the start there is no refund, only the free switch.
- Never mention refunds in messages or emails; they are in the FAQ and terms.
- Move/switch: one free switch until the second meetup. The member appears as
  "Moving · already paid" in Applicants. Place them in a new Circle (their
  acceptance is free), or press Refund instead if no group fits in reasonable
  time.
- If you cancel a Circle, everyone who paid appears under Refunds to send.

## WhatsApp groups (opt-in)

After week 2 each member is asked once whether they'd like a WhatsApp group
for their Circle: "Yes, add me" (a number is then required), "No thanks", or
"We already have a group". When two people say yes you get "A WhatsApp group
can be made". On the Circles tab, the Circle shows who said yes with their
numbers and a Copy numbers button: create the group in WhatsApp by hand with
only those people. Never add anyone who didn't say yes.

## Safety reports

A new report notifies the organiser in the app (A member reported a concern).
Check the organiser panel at least daily while Circles are running.

1. Read the report in To do → Open reports. Contact the reporter on WhatsApp
   if needed.
2. If someone is at risk: tell the reporter to contact emergency services
   (112) and to leave; you can remove a message (Hide) from the chat.
3. To stop someone attending, cancel their place with them, and use Future
   Circles exclusions so they are not matched with the reporter again.
4. Resolve the report when handled. Keep only what you need.

## Backups and restore

Run `./scripts/backup.sh` at least weekly while the pilot runs, and before
every migration. It needs Docker Desktop running. It writes a dated folder in
`~/VriendTime-backups` with `schema.sql`, `roles.sql`, `data.sql`,
`storage-policies.sql` (the photo access rules, which the database dump
leaves out), the photos and a manifest. Keep it private and encrypted; it
contains personal data.

To restore (tested 7 Oct 2026 with a full copy of the live data):

1. Create an empty Supabase project in the VriendTime organisation, region
   West EU. If Supabase refuses because of the free-project limit, pause
   another free project first.
2. Connect → Direct → Session pooler: copy the address, fill in the database
   password, and save it as a one-line file, for example
   `~/VriendTime-backups/restore-url.txt` (open it in TextEdit and paste).
3. `./scripts/restore.sh ~/VriendTime-backups/<folder> <new-project-ref> ~/VriendTime-backups/restore-url.txt`
   It refuses the live project and refuses a project that is not empty.
4. Not in a backup, set up again by hand for a real recovery: Auth settings
   (SMTP, templates, URLs, rate limits), the Edge Functions and their
   secrets, the vault secret, and the scheduled jobs (re-run the migrations
   that schedule them).
5. For a drill: point a local build at the copy (`--dart-define=SUPABASE_URL`
   and `SUPABASE_PUBLISHABLE_KEY`), sign in with a test account and check
   the profile, photo, Circle and messages. Do not deploy or schedule
   anything there. Delete the project and the connection file afterwards.

## Photos and deleting accounts

Each member has one photo; replacing it deletes the old file. Delete
accounts only through the app (Profile → Account details → Delete account):
deleting a user in the Supabase dashboard leaves their photo behind, and the
privacy policy promises it is removed.

Once a week, after the backup, run `./scripts/clean-photos.sh`. It lists photo
files that are nobody's current photo; run it again with `--apply` to delete
them. It never touches current photos or anything uploaded in the last day.

Free-plan projects pause after a week without activity. If the project is
paused, restore it from the Supabase dashboard before the next meetup.

## When something breaks

1. Check https://vriendtime.com loads and you can sign in.
2. Supabase dashboard: project status, API errors, Auth logs.
3. Netlify: latest deploy status.
4. Database: recent error records (area, kind such as `storage:403`, build).
5. Tell the affected Circle on WhatsApp how the next meetup will go ahead.
6. Fix, or redeploy the previous Netlify build if the database allows it.
7. Write down what happened and what prevents it next time. If personal data
   may have been exposed, assess whether it must be reported to the
   Autoriteit Persoonsgegevens within 72 hours.

## Contacts and access

- Owner and organiser: you. Support: WhatsApp +31 6 85660139.
- Keep sign-in recovery and two-factor authentication on for GitHub, Netlify,
  Supabase and the domain registrar. Note where recovery codes are kept.
- Before a wider launch, add a second person who can reach these accounts.
