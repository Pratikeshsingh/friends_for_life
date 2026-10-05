# VriendTime runbook

The one place for how VriendTime is run. Keep it current when something
changes. No passwords or keys belong here.

## What runs where

| Part | Where | Notes |
|---|---|---|
| Web app | Netlify, site vriendtime.com | Built from `main` by `scripts/netlify-build.sh`. Each build is stamped `1.0.0+<commit>`; the stamp shows in Profile and in error reports. |
| Database, sign-in, photos | Supabase project `sageyiqyvzgoayehahyq` (EU, Free plan) | Photos in the private `profile-photos` bucket. |
| Account deletion | Edge Function `delete-account` | Deployed. |
| Notification emails | Edge Function `send-notifications` | Written and tested, **not deployed**. Until it is, every notification is in-app only, and the email switch in Profile is hidden. When email is live, set the Netlify environment variable `EMAIL_DELIVERY=true` and redeploy. |
| Code and checks | GitHub `Pratikeshsingh/friends_for_life` | Checks: app, database suites, server functions. |

Scheduled jobs inside the database (times in UTC):

| Job | Schedule | Does |
|---|---|---|
| `vriendtime-circle-notifications` | hourly at :15 | Meetup-tomorrow reminders, check-in prompts and later programme messages |
| `vriendtime-circle-alerts` | hourly at :45 | Tells the organiser when a Circle can be formed or someone missed two meetups (at most daily) |
| `vriendtime-purge-action-requests` | daily 03:30 | Deletes retry copies older than 7 days |
| `vriendtime-purge-error-events` | daily 03:40 | Deletes error records older than 30 days |

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

- Accepting an invitation records an agreement to pay €19; it does not take
  money. The member pays through the WhatsApp payment link. The organiser
  checks the bank account and confirms receipt in the organiser panel
  (To do → Payments to confirm). Only then do the place and chat open.
- Keep your own list of payments received (date, name, reference shown in the
  app) so you can reconcile them with the app.
- Refund: possible until 48 hours before the first meetup. The member cancels
  in Profile; it appears under Refunds to send. Return the money, then press
  Confirm refund completed.
- Move: one free move between the start of the first and the second meetup.
  The member appears as "Moving · already paid" in Applicants. Place them in a
  new Circle (their acceptance is free), or press Refund instead if no group
  fits in reasonable time.
- If you cancel a Circle, everyone who paid appears under Refunds to send.

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
every migration. It writes a dated folder outside the project with
`schema.sql`, `roles.sql`, `data.sql`, the photos and a manifest. Keep it
private and encrypted; it contains personal data.

Prove a backup works at least once:

1. Create a separate, empty Supabase project (free).
2. In it, run `roles.sql`, then `schema.sql`, then `data.sql`
   (`psql "<connection string>" -f file.sql`).
3. Upload the photos folder to a `profile-photos` bucket in that project
   (`supabase storage cp -r <folder> ss:///profile-photos --experimental`
   while linked to the test project).
4. Point a local build at it (see README) and sign in with a test account.
   Check the profile, photo, Circle, payments and notifications.
5. Do not deploy or schedule anything in that project; it must not send
   messages. Delete it afterwards.

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
