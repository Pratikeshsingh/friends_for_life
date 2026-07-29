# VriendTime prototype

A Flutter prototype for small, planned meetups in Alkmaar.

## Prototype scope

- Onboarding for account setup, meetup selection, and profile photo upload
- Home flow for browsing small coffee, lunch, and dinner meetups
- Meetup detail screen with area shown upfront and exact address timing
- Profile and preference management UI

## Notes

This repository includes Supabase authentication and a starter backend schema.

## Supabase setup

The app is currently wired to this Supabase project URL by default:

- `https://sageyiqyvzgoayehahyq.supabase.co`

For local debug builds, the app can use the bundled defaults. Profile and
release builds require explicit `--dart-define` values so staging/test builds
cannot accidentally point at the wrong backend.

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_your_key
```

Example release build:

```bash
flutter build web --release \
  --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_your_key
```

## Database bootstrap

Run the SQL in [supabase/schema.sql](supabase/schema.sql) inside the Supabase
SQL editor before testing sign-up fully. It creates:

- `profiles`
- `events`
- `event_attendees`
- `chat_threads`
- `chat_participants`
- `messages`

It also enables Row Level Security and adds a trigger that creates a profile row automatically when a user signs up.

Then run [supabase/release_hardening.sql](supabase/release_hardening.sql). It
adds the release-safe catalog view/RPCs/policies used by the app for
reservation safety, address privacy, attendance writes, and storage limits.

## Account deletion function

Profile → Account → Delete account calls the authenticated Supabase Edge
Function in
[supabase/functions/delete-account/index.ts](supabase/functions/delete-account/index.ts).
Deploy it to each Supabase project used by the app:

```bash
supabase functions deploy delete-account --project-ref your-project-ref
```

The function verifies the signed-in user, removes their profile photos, and
then hard-deletes their Auth user. Foreign-key cascades in the schema remove
their profile-linked reservations, notifications, chat participation, and
messages. Never put the Supabase service-role key in the Flutter app; the Edge
Function receives it from Supabase's server environment.

## Auth redirects

Configure these URLs in Supabase Auth before tester launch:

- Site URL: `https://vriendtime.com`
- Password recovery redirect: `https://vriendtime.com/#/reset-password`
- Mobile email callback/deep link: `vriendtime://auth/callback`

For web hosting, keep [web/_redirects.txt](web/_redirects.txt) or an equivalent
SPA fallback so routes resolve to `index.html`.

## Tester launch checklist

- Run `flutter analyze`.
- Run `flutter test`.
- Run both SQL files in Supabase in order.
- Confirm the `profile-photos` bucket accepts only JPG, PNG, and WebP under the configured size limit.
- Deploy and smoke test the `delete-account` Edge Function with a disposable account.
- Build profile/release targets with explicit Supabase `--dart-define` values.
- Smoke test sign-up, email confirmation, password reset, reservation, cancellation, notification address reveal, profile edit, photo upload, logout, and app resume.
