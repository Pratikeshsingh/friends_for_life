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

For local overrides, run Flutter with `--dart-define` values:

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_your_key
```

## Database bootstrap

Run the SQL in [supabase/schema.sql](supabase/schema.sql) inside the Supabase SQL editor before testing sign-up fully. It creates:

- `profiles`
- `events`
- `event_attendees`
- `chat_threads`
- `chat_participants`
- `messages`

It also enables Row Level Security and adds a trigger that creates a profile row automatically when a user signs up.
