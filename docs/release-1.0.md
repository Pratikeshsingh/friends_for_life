> **Historical (September 2026).** This describes the first Circles release. For how VriendTime runs today, see [RUNBOOK.md](RUNBOOK.md).

# VriendTime 1.0 release

## What is implemented

Public introduction and real Alkmaar activities; account creation and sign-in; saved matching applications; organiser matching and six weekly invitations; explicit €19 manual payment agreement; organiser receipt confirmation; paid Circle membership, chat and RSVP; private check-ins and reports; scheduling and attendance tools; cancellations and manual refunds; graduation and 90-day follow-up; notifications and own-data export. The original brand, artwork, fonts and colours are retained.

No automatic checkout or payment provider is used. An accepted invitation stays unpaid until an authorised organiser records receipt. Refund confirmation likewise records a transfer already made outside the app. The app does not collect bank or card details.

## September 21 experience update

Shorter public introduction with illustrated story cards and an interactive six-week journey; four-step onboarding with private date of birth and automatically calculated age; English/Dutch matching; separate day/time selection including per-day schedules; social-style cards, matching goals and optional context; required primary profile photo for recognition (not identity verification); redesigned profile and waiting state with availability reconfirmation. Shared Circle profiles exclude private birthday, matching goals and context. Storage access restricts photos to their owner, authorised organisers and assigned Circle members.

## Backend deployment

The four migrations dated 20260918–20260921 were applied to project `sageyiqyvzgoayehahyq` using the authenticated Supabase Management API. They preserve the existing 31 profiles and 55 events. Private Circle events are excluded from the public activity catalog. The `vriendtime-circle-notifications` cron job queues in-app reminders hourly at minute 15. This is in-app delivery, not email or push delivery.

The production project currently has no Circle organisers. Assign only the account explicitly designated by the owner:

```sql
insert into public.circle_admins(profile_id)
select id from public.profiles where email = 'DESIGNATED_ACCOUNT_EMAIL'
on conflict do nothing;
```

The organiser button then appears in that account’s app header. It supports matching, scheduling, actual attendance, payment receipt confirmation, cancellation, refund confirmation, and reviewing reports.

Migrations were applied directly; do not blindly rerun them or the original `schema.sql`. In particular, recreating the original public catalog without the Circle filter would expose private events. Before adopting CLI migration tracking, reconcile the existing deployment history.

## Verification

- Flutter analysis: no issues.
- Flutter tests: 115 passed, including manual consent, unpaid access, cancellation display and responsive views.
- All three SQL integration suites passed in isolated PostgreSQL 17: `circle_access_test.sql`, `circle_release_test.sql`, and `circle_experience_test.sql`.
- SQL checks cover authorisation, consent vs receipt, duplicate confirmations, refunds after account deletion, private exports/reports, RSVP, check-ins, attendance, DST and notification deduplication.
- Offline navigation and recovery verified with both page and service-worker networking disabled.
- Release web build produced successfully. Public mobile and desktop browser checks use an isolated local Chrome because the in-app browser execution tool is unavailable.
- Read-only production checks confirm the migrations and reminder job exist, original record counts are unchanged, no test payments exist, and internal RPCs are not callable by members.
- A proposed privileged production-account smoke test was rejected by automatic approval review. No production test accounts were created; a complete authenticated production journey has not been verified.

## Publishing

Run `scripts/check-release.sh`. Upload the **contents** of `build/web` (or the packaged zip) to the existing Netlify site for `vriendtime.com`. `_redirects` and `_headers` are included. The offline service worker caches only the public offline page and icon, never private API responses. Deploy over HTTPS for installation support.

This workspace has no Netlify deployment credentials. The existing website has not been replaced. Before public launch, supply the operator’s public name/contact email for the terms and privacy policy, designate the organiser account, and verify signup confirmation and password reset on the production origin. Supabase Auth’s redirect allow-list must include `https://vriendtime.com/`, `https://vriendtime.com/#/reset-password`, and the mobile callback `vriendtime://auth/callback`. Local email-link testing requires explicitly allowing the local origin.

Flutter shares application code across platforms. App-store releases still need signing, distribution accounts, platform review, and device testing; this build has only been validated for web.

## Operational notes

Contact accepted members using the email shown beside their payment agreement. Confirm receipt only after checking the actual €19 transfer. Check the report/refund queues regularly. Cancelling a Circle queues refund requests for recorded payments, but does not transfer money. Deleted accounts leave payment records and outstanding refund obligations available for follow-up; do not retain this contact information beyond your applicable accounting/dispute requirements.

The app offers cancellation within 14 days of acceptance as well as the original 48-hour post-meetup satisfaction refund. Mandatory consumer rights remain unaffected. Operator identity and the precise legal/business arrangement must be confirmed by the owner before launch. Relevant official guidance: [online sales](https://business.gov.nl/regulations/long-distance-sales-and-purchases/), [cancellation](https://business.gov.nl/regulations/cancellation-period-sale/), and [online cancellation controls](https://business.gov.nl/amendments/online-shops-must-have-cancellation-button/).
