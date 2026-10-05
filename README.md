# VriendTime · Friendship Circles

A web app (Flutter) for six-week Friendship Circles in Alkmaar: five or six
people meet once a week for six weeks. Members apply, the organiser forms the
groups, members accept and pay €19 by a manual WhatsApp payment link, and the
Circle gets a group chat, the six meetup dates and extra plans.

- Live site: https://vriendtime.com (Netlify, built from `main`)
- Backend: Supabase project `sageyiqyvzgoayehahyq` (Postgres, Auth, Storage,
  Edge Functions, scheduled jobs)
- How to run, deploy, back up and handle problems: **[docs/RUNBOOK.md](docs/RUNBOOK.md)**

## Run it locally

```bash
flutter pub get
flutter run -d chrome          # talks to the production backend by default
```

To use another Supabase project (recommended for testing anything that
writes data):

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_your_key
```

A preview with example people and no backend writes:
`flutter run -d chrome --dart-define=CIRCLES_ENABLE_PREVIEW=true`, then open
the app with `?preview=1`. Real builds ignore this.

## Checks

```bash
./scripts/check-release.sh                      # analyse, format check, app tests, web build
cd scripts/backend-tests && npm ci && node run.mjs production_hardening_test.sql   # database tests
```

GitHub runs the app checks, every database test suite and the server-function
tests on each push. See `.github/workflows/flutter.yml`.

## Layout

| Path | What it is |
|---|---|
| `lib/src/circles/` | The Circles app: landing, application, home, profile, chat, organiser panel |
| `lib/src/screens/` | Sign-in, account & support, legal documents, password reset |
| `lib/src/core/` | Translations (EN/NL), theme, Supabase config, photo handling, diagnostics |
| `supabase/migrations/` | Database changes, applied in date order |
| `supabase/functions/` | Edge Functions: account deletion and the notification email worker |
| `supabase/tests/` | Database test suites (run in an isolated database) |
| `scripts/` | Release check, Netlify build, backup |

Older documents in `docs/` (July–September 2026) describe earlier versions
and are kept for history only.
