# VriendTime 2.0 — Friendship Circles implementation plan

Status: proposed implementation plan; no application or database changes made.
Date: 18 September 2026.
Source: supplied VriendTime 2.0 product specification, checked against the local Flutter/Supabase repository.

## 1. Pilot scope and product rules

Deliver the complete journey for 30–60 adults around Alkmaar, organised manually into approximately 5–10 Circles:

Discover → apply → wait → receive Circle invitation → pay → meet weekly for six weeks → continue independently.

- Approximately six compatible people remain together throughout the programme.
- One payment of €19 covers the programme; food, drinks, and paid activities are separate.
- Collect payment after a Circle is offered, before participation begins. “Upfront” means before the programme, not before a match exists.
- Offer a refund request within 48 hours after the first meetup. Define the precise deadline before implementing it.
- Adults of any age may apply; prioritise ages 25–45 for initial matching without presenting this as an eligibility limit.
- Photos are optional. Availability and shared language are essential matching inputs.
- No subscription, free first week, automated matching, public feed, marketplace, or premium tier.
- Graduation preserves coordination access without another payment.
- The primary long-term measure is voluntary contact with at least one Circle member 90 days after starting.

## 2. What the repository actually provides

| Area | Current evidence | Implementation implication |
| --- | --- | --- |
| Authentication and routing | `lib/src/app.dart`, `screens/prototype_shell.dart`, `screens/auth_flow_screen.dart` | Keep sign-in, recovery, and session handling; separate account completion from meetup selection. |
| Public discovery | `screens/onboarding_screen.dart`, `screens/web_marketing_landing.dart` | Replace event-led acquisition with the Circle promise and application CTA on mobile and web. |
| Profiles | `screens/profile_screen.dart`, `profiles` table, photo service | Reuse personal details; introduce structured matching data instead of overloading existing text fields. |
| Meetups and reservations | `core/event_service.dart`, `core/event_catalog.dart`, `events`, `event_attendees`, hardened RPCs | Keep meetup mechanics; add Circle ownership, membership checks, and attendance outcomes. |
| Notifications | `core/notification_service.dart`, notification tables and SQL functions | Extend existing delivery/storage patterns for Circle milestones; verify scheduled execution in deployment. |
| Messaging | Chat tables and participant policies exist; hardening includes a participant helper | Reuse after policy review; add a Circle thread and actual messaging UI. |
| Admin | No dedicated Circle/admin UI found in the inspected app | Build a small protected operator surface for applications, group formation, and programme operations. |
| Payments | No payment implementation found | Add server-side checkout, verified payment events, reconciliation, and refund operations. |
| Tests | Authentication, home, profile, event, landing, responsive, and core tests | Adapt changed expectations and extend coverage for Circle transitions and access boundaries. |

The repository contains locally modified `README.md` and `lib/src/core/supabase_config.dart`. Preserve those changes during implementation.

## 3. Proposed architecture and data model

Keep Flutter and Supabase. Add focused Circle models/services and screens; avoid putting the entire new lifecycle into `PrototypeShell`.

Use additive, versioned database migrations following the existing schema and hardening scripts. Existing profiles, reservations, and historical events remain intact.

| Entity | Main fields and purpose |
| --- | --- |
| `circle_applications` | Applicant, city/area, languages, interests, preferred activities, social energy, hopes, life-stage context, matching status, submission timestamps. Reference profile age information rather than duplicating date of birth unnecessarily. |
| `circle_application_availability` | Application, weekday, local time window, timezone; allows actual overlapping availability checks. |
| `circles` | Name, city, timezone, proposed start, schedule, capacity, lifecycle status, price in minor units/currency, completion timestamp. |
| `circle_memberships` | Circle, profile, invitation/acceptance status, invitation expiry, joined/left timestamps. Payment is tracked separately. |
| Existing `events` | Nullable `circle_id`, programme week 1–6, explicit visibility, organiser responsibility, completion timestamp. Optional later meetups have no programme week. |
| Existing `event_attendees` | RSVP remains separate from actual attendance; add attended/absent/unknown outcome and recorded timestamp. A reservation alone is not proof of attendance. |
| Existing chat tables | Add a Circle association to a thread; membership controls participation. Keep the thread after graduation. |
| `circle_payments` | Membership, expected amount/currency, provider references, payment/refund status, timestamps. Server controlled. |
| `payment_webhook_events` | Unique provider event ID and processing status for deduplication and retries. |
| `circle_refund_requests` | Membership/payment, request timestamp, eligibility deadline snapshot, optional reason, operator decision, provider refund reference. |
| `circle_check_ins` | Member, meetup, feeling, optional positive connection preferences. Private to the submitter and authorised operators. |
| `circle_outcome_responses` | Week 6, week 7+, and day 90 follow-ups: plans to meet, actual meetings, friendship/contact outcomes, outside-programme contact. |
| `admin_roles` / audit log | Server-managed operator permissions and records of matching, membership, scheduling, and refund actions. |

Constraints: unique membership per Circle/profile; at most one active application and one active programme membership per person for the pilot; unique programme week per Circle; one check-in per member/meetup; unique provider payment/event identifiers. Enforce group capacity and lifecycle transitions transactionally.

Keep application status, membership status, Circle status, and payment status distinct. Proposed Circle states: draft → offered → confirmed → active → completed, with cancellation paths. An invited member can be awaiting payment while other members have paid; the whole group should not inherit one person's payment state.

## 4. User experience

Primary navigation: My Circle, Messages, Profile. The My Circle destination renders the appropriate application, waiting, invitation, programme, or graduation state. Notifications remain accessible through the existing shell.

1. **Discover:** “Meet 5 people. See them for 6 weeks. See what happens.” Show the six-week commitment, Alkmaar pilot, €19 one-off price, separate activity costs, and guarantee. CTA: “Find my Circle.”
2. **Apply:** Short, resumable questionnaire for the ten specified topics. Prefill existing profile values, allow multiple languages and availability slots, validate adulthood, and make photo upload optional. Account creation/sign-in secures the submission.
3. **Wait:** “We're building your Circle.” Show city, preferred schedule, matching status, and an operator-supplied start estimate when available. Let users edit or withdraw their application. Do not invent a launch date.
4. **Invitation:** Show Circle schedule, actual start date, basic member profiles, full price/cost explanation, and “Join Founding Circle — €19.” Support declined/expired invitations and payment retry.
5. **Programme:** Show current week, same group, next activity/location, confirmed count, RSVP, messages, and all six weeks. Cancelled or postponed meetups must not automatically count as completed.
6. **Check-in:** After each completed meetup, offer the four feelings and optional positive connection choices. Never expose another member's feedback or omissions.
7. **Graduation:** “Your Circle is now yours. ❤️” Ask whether the group plans to meet again; preserve messaging and simple member-created meetup coordination without payment.

Use the existing visual system, typography, and reusable widgets. Update reservation reminders, profile help/FAQ, notification copy, and public metadata so they no longer describe the old one-off product as the main experience.

## 5. Delivery phases and acceptance criteria

### Phase 0 — Confirm operating rules and map the transition

Resolve the decisions in section 9, record a state-transition matrix, and identify any existing users/events that must stay accessible. Establish a staging environment and feature-controlled rollout. Select the payment provider and verify its current integration requirements during implementation.

**Done when:** product states, payment timing, group launch rules, refund timing, operator access, and pilot ownership are explicit; the team can implement without inventing product rules.

### Phase 1 — Circle foundation and access controls

Add migrations, data models, Circle service, operator authorisation, and transactional lifecycle operations. Link meetups and chat threads to Circles. Apply access checks to tables, views, RPCs, notifications, and photo sharing.

Circle events must be excluded from the public event catalog and old public reservation paths. Existing reservation RPCs and client fallback writes must not let unrelated users join Circle events. Return only approved basic member fields; do not make full profiles public to solve member display.

**Done when:** staged fixtures cover all lifecycle states; outsiders cannot read private Circle data or reserve its meetups; users cannot assign themselves to a Circle, change payment state, or grant themselves operator access.

### Phase 2 — Acquisition, questionnaire, and waiting state

Update both landing experiences. Refactor auth onboarding so `selected_event_ids` is no longer required for Circle applicants. Add saved questionnaire drafts, submission, editing/withdrawal, and the waiting view. Profile data should have a clear canonical source rather than conflicting copies in auth metadata and database rows.

**Done when:** a new or returning user can apply without choosing an event, recover a draft, return after sign-in, and see truthful matching information. Network failures do not falsely report submission success.

### Phase 3 — Manual matching and invitations

Build a protected operator screen showing applicants, availability overlap, shared language, and compatibility inputs. Operators create a draft group, select its schedule and start date, review conflicts, and send invitations. Log membership changes and prevent double assignment/capacity races.

Generate six editable weekly meetups once, using Europe/Amsterdam local scheduling so daylight-saving changes do not shift the intended meeting hour. Start with a full six-week outline and allow activity/venue details to be filled manually. Week 4–6 organiser responsibility shifts toward members.

**Done when:** an operator can assemble and invite a complete group, retry generation without duplicate meetups, and track declined/expired invitations. Members see their actual offered group and schedule.

### Phase 4 — Payments and refund operations

Create checkout on the server for an authenticated, eligible invitation using the stored €19/EUR price. Confirm payment only from verified provider state; returning from checkout alone cannot grant paid membership. Process duplicate/out-of-order events safely, reconcile missed events, and expose pending/failed/succeeded states clearly.

Provide refund requests with a server-calculated deadline. Operators review requests and execute provider refunds; show “refunded” only after provider confirmation. Handle a paid group that cannot launch and the race between invitation expiry and payment completion.

**Done when:** sandbox payment, cancellation, retry, delayed confirmation, duplicate webhook, failed refund, and successful refund paths work. Client-supplied prices and payment statuses cannot change entitlements.

### Phase 5 — Six-week participant experience

Build the Circle home, member previews, timeline, upcoming meetup, RSVP, private group messages, and post-meetup check-ins. Extend reminders using the existing notifications infrastructure and verify the scheduler runs. Add operator actual-attendance recording and rescheduling/cancellation support.

Distinguish programme week, completed meetup count, and member attendance. A postponed meetup must not move the Circle to graduation merely because six calendar weeks elapsed.

**Done when:** six test users can participate across a simulated programme; RSVP changes and messages survive refresh; failures are recoverable; check-ins stay private; week 4–6 member coordination works.

### Phase 6 — Graduation and outcome measurement

Complete the programme explicitly, retain Circle coordination, and collect graduation, week 7+, and day 90 responses. Add a small operator report for the funnel, attendance, completion, refunds, referrals, and friendship outcomes.

Define each metric's numerator and denominator. Report response rate and unknown outcomes alongside survey results. For day 90, include only participants whose 90-day observation point has arrived; show confirmed-positive/all-eligible and positive/respondents separately. Do not treat missing responses as known success or known failure.

**Done when:** completed groups can still message and arrange another meetup without payment; operators can distinguish intentions from actual continued meetings and inspect a reproducible outcome report.

### Phase 7 — Release validation and pilot launch

Run analyser, relevant Flutter tests, production web build, database access tests, payment sandbox integration checks, and an operator-to-participant end-to-end rehearsal. Visually inspect phone and desktop layouts, long/empty content, keyboard interaction, and loading/error states.

Deploy additive database changes and server functions before enabling the Circle UI. Validate staging migrations and recovery first. Configure secrets, payment callbacks, notification scheduling, and operator accounts in deployment. Roll out to internal users, then the founding pilot.

**Done when:** a real staging journey works from application to payment and first RSVP; privacy boundaries hold; refund and cancellation procedures are rehearsed; deployment configuration is documented.

## 6. Suggested code boundaries

- New `lib/src/core/circle_models.dart` and `circle_service.dart` for typed lifecycle data and backend operations.
- Separate application, waiting/invitation, Circle home, messages, and operator screens under `lib/src/screens/`.
- Refactor `prototype_shell.dart` to route from loaded application/membership state; keep account and notification handling reusable.
- Adapt `auth_flow_screen.dart`, `onboarding_screen.dart`, and `web_marketing_landing.dart` for the new acquisition flow.
- Extend `event_service.dart` and `event_catalog.dart` carefully so historical public events and private Circle events cannot be confused.
- Add versioned SQL migrations and narrowly scoped server functions for checkout, payment events, and privileged operations.
- Review account deletion for new foreign keys, survey data, and payment records; agree necessary payment-record retention before applying cascades.

## 7. Validation priorities

| Layer | Required evidence |
| --- | --- |
| Domain tests | Lifecycle transitions, overlapping availability, capacity, six-week generation, DST, refund deadline boundaries, completion rules. |
| Database tests | Outsider/member/operator permissions, cross-Circle access denial, private feedback, safe profile projection, RPC bypass attempts, atomic assignment. |
| Widget tests | Application validation/resume, waiting/invitation/payment states, optional photo, RSVP, check-in, graduation, responsive layout. |
| Integration tests | Auth resume, invitation → checkout → verified membership, webhook replay, refunds, messaging, notifications, account deletion. |
| Pilot rehearsal | Operator forms a Circle; six users join; weeks progress; group graduates; members arrange a subsequent meetup. |

Reuse existing tests where their behaviour still applies. Update old meetup-first expectations deliberately rather than disabling failing tests wholesale.

## 8. Rollout and operational safeguards

- Preserve historical events and reservations. Do not enrol existing users or charge them automatically.
- Retain access to existing bookings during the transition, even if the main navigation changes.
- Provide an operator checklist for cancellations, no-shows, member withdrawal, venue changes, group launch failure, and refund requests.
- Stop new invitations/checkouts if rollback is needed; keep paid participants' schedule and support access available. A frontend feature toggle does not reverse payments or deployed data.
- Instrument milestone timestamps from authoritative actions; avoid collecting private message content for analytics.
- Keep the first pilot manual. More elaborate automation follows evidence of friendship formation.

## 9. Decisions needed before dependent implementation

| Decision | Proposed starting point |
| --- | --- |
| Payment provider/account | Select a provider supporting the pilot's required payment methods and refunds; confirm business account readiness. |
| Pilot launch and invitation expiry | Use an operator-set start date and explicit deadline; the specification's 8 October date is illustrative until confirmed. |
| Minimum viable group | Aim for six; agree whether a group of five may launch, and what happens if payment or withdrawal reduces it further. |
| Refund clock | Use the actual end of Meetup 1 plus 48 hours; agree treatment of absence, cancellation, and postponement. |
| Withdrawal/replacement | Avoid routine reshuffling after launch; agree exceptions and explain the impact to remaining members. |
| Operator access | Named, server-authorised operators using a minimal admin screen. |
| Address/member visibility | Share minimal profiles with invited members; decide precise venue-release timing and who may view photos. |
| Member coordination | Let active members propose/organise later meetups, and retain simple scheduling after graduation; define edit ownership. |
| Notifications | Confirm which deployed channels exist. In-app notification records do not establish email or push delivery. |
| Follow-up and retention | Agree outreach channel, consent, retention, and ownership for week 7+ and day 90 surveys. |
| Pilot language | Confirm English-only UI or Dutch/English delivery; questionnaire captures spoken languages either way. |

## 10. Recommended first implementation milestone

Build one complete staging slice: new user applies → operator forms a Circle → user receives invitation → sandbox payment confirms membership → Circle home shows six scheduled meetups and accepts an RSVP.

This exercises the central product and its hardest dependencies early. It is an internal milestone, not a complete public pilot: messaging, refunds, private check-ins, graduation, outcome measurement, and release validation still need to be finished before launch.

Suggested implementation order is the phase order above. A delivery-date estimate should follow Phase 0, payment account readiness, and confirmation of the deployed backend/admin tooling; the local repository alone cannot establish those conditions.
