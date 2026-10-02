# VriendTime production-readiness audit — 2 October 2026

Scope: current working tree, including unpublished changes. Reviewed the active Circles app, authentication/account screens it opens, repository actions, SQL migrations, notification/deletion functions, and release checks. Older standalone-meetup screens are not the primary user journey.

This is a code and automated-test audit, not a complete authenticated browser/device walkthrough or verification of the deployed database. SQL findings describe the checked-in definitions; deployment state needs separate verification. No production data was modified and no product behaviour was changed during this audit.

Validation: Flutter analysis passed. Full suite: 207 passed, 1 failed. The failure is the existing untracked `zzzz_poll_probe_test.dart`: its waiting applicant has no Messages tab, so its tap cannot run. This is a diagnostic-test defect, not evidence of a broken Messages tab. A temporary corrected probe independently reproduced paused polling after moving from an edit form to Profile; it was removed after the run. Logs: `/tmp/vriend-audit-analyze.log`, `/tmp/vriend-audit-tests.log`, `/tmp/vriend-audit-probe.log`.

## Fix before a wider launch

### 1. Leaving and cancelling can produce conflicting payment outcomes

**High — backend state transition problem.** Profile exposes both actions during eligible active memberships. `circle_leave` immediately marks membership left; snapshot/payment lookup follows the current non-left membership. `cancel_agreement` also uses that membership to find the payment. A paid member who chooses Leave first can lose the self-service cancellation route while the payment remains paid. Conversely, paid cancellation only queues a refund; it does not immediately end the joined membership.

Separate participation state from refund state. Show the cancellation option where eligible within the leave flow, keep payment history accessible after leaving, and make a cancellation's access/headcount effects explicit. Test both action orders, refunds, and interrupted confirmations. This is a product/data-flow finding, not a legal assessment.

Evidence: [Profile actions](../lib/src/circles/circle_profile.dart:63), [leave operation](../supabase/migrations/20260924_circle_care.sql:83), [payment cancellation](../supabase/migrations/20260919_circle_release.sql:73).

### 2. New extra meetups can appear to disappear

**High — confirmed rendering logic.** Home lists only meetups with a programme week. An extra meetup is visible only if it happens to win the single next-meetup slot. Suggesting coffee after next week's scheduled event therefore saves it without providing a normal list entry. Members also have no edit/cancel path for their extra plans; the member update query only accepts weeks 4–6.

Add an Upcoming plans list containing every extra meetup, with organiser/creator information, optional RSVPs, and permission-checked edit/cancel actions.

Evidence: [Home list](../lib/src/circles/circle_home.dart:385), [member scheduling](../supabase/migrations/20261002_fixed_programme_schedule.sql:107).

### 3. Group-made venues are hidden from the group

**High — conflicting existing rules.** The server hides the venue of every numbered week until 24 hours before it starts, including member-planned weeks 4–6. The edit form then receives no venue and opens an empty Where field. A member cannot review the group's saved venue in advance and may replace it while attempting another edit.

Limit any organiser venue-reveal rule to the intended weeks. Group-planned venues should be visible as soon as saved; incomplete edits must not erase existing values.

Evidence: [snapshot redaction](../supabase/migrations/20260923_circle_waiting_progress.sql), [venue presentation](../lib/src/circles/circle_repository.dart:104), [plan editor](../lib/src/circles/circle_home.dart:814).

### 4. Background refresh stops after leaving an edit form for another tab

**High — reproduced.** Open Profile → Edit availability → switch back to Profile without Save/Cancel. The global `editing` flag stays true, so the 25-second refresh remains disabled. The corrected probe observed zero additional loads over 80 seconds after the tab change. This can hide invitations and other state updates. The form is also removed from the widget tree when switching tabs, risking loss of unsaved field values.

Preserve drafts explicitly, define what happens when navigating away, and pause only the updates that would interfere with the visible editor.

Evidence: [polling gate](../lib/src/circles/circle_shell.dart:65), [navigation](../lib/src/circles/circle_shell.dart:414), [body routing](../lib/src/circles/circle_shell.dart:485).

### 5. Refreshes can race and silently replace newer data

**High — code-level race.** `load()` accepts whichever response finishes last, without a request generation/version guard. A slow background snapshot started before a save can arrive after its fresh post-save snapshot and overwrite it. Silent polling errors are swallowed; users receive no stale/offline indication. A successful write followed by a failed refresh can still produce a success toast over stale data.

Serialize/coalesce loads or ignore superseded responses, distinguish saved-but-refresh-failed from save failure, and expose last-sync/retry status. Add bounded waits for stalled requests and tests with deliberately reordered responses.

Evidence: [load/action handling](../lib/src/circles/circle_shell.dart:120).

### 6. Email delivery can duplicate sends

**High — backend reliability risk.** `notifications_pending_email` selects pending rows but does not claim/lease them. Concurrent workers can select the same batch. The sender has no provider idempotency key and records results only after sending the batch; a crash midway repeats earlier successful sends. Returned errors from the acknowledgement RPC are not checked. Network calls have no explicit timeout.

Use atomic claims with recovery leases, a stable notification-based idempotency key, per-message acknowledgements, checked RPC errors, and bounded retry/backoff. Verify the sender schedule and actual delivery separately; the repository alone does not prove deployment.

Evidence: [queue query](../supabase/migrations/20260924_circle_care.sql:45), [sender](../supabase/functions/send-notifications/index.ts).

### 7. Past events can stay labelled “Your next meetup”

**High — confirmed selection logic.** Home selects the first event not marked completed, without checking its start/end time. An organiser forgetting to complete last week's event pins it above future plans. Sorting only by date also ignores order between same-day events. The 48-hour refund/check-in experience additionally depends on manual completion state.

Derive upcoming/ongoing/past from the event timestamps in the Circle timezone. Keep attendance recording separate from whether an event is in the past. Make refund/check-in timing explicit and test late organiser completion.

Evidence: [next-meetup selection](../lib/src/circles/circle_home.dart:40), [completion/refund](../supabase/migrations/20261002_fixed_programme_schedule.sql:73).

### 8. Release failures are effectively invisible to the developer

**High — observability gap.** The global error handler returns immediately in release mode. No remote crash/error reporting is configured in the inspected app. A blank screen or failed asynchronous callback can therefore be difficult to diagnose from a user's report.

Add privacy-conscious error reporting, build identifiers, correlation IDs, and a recoverable error screen. Report important backend failures without uploading chat messages, photos, or sensitive application answers.

Evidence: [error handler](../lib/main.dart:65), [dependencies](../pubspec.yaml).

## Improve the core journeys next

### 9. Payment confirmation is still a manual pilot workflow

One shared external payment request is matched by name and manually confirmed. Duplicate names, somebody paying for a friend, a delayed organiser, and clicking Pay again are ambiguous. There is no distinct member-facing “payment sent, verification pending” state with an expected response time.

For the pilot: unique payment reference, explicit verification status, support route, and a reconciled payment history. For automation: payment-provider events with idempotent processing and reconciliation. Payment consent must remain separate from receipt.

Evidence: [configuration](../lib/src/core/payment_config.dart), [invitation/payment UI](../lib/src/circles/circle_home.dart:289), [receipt confirmation](../supabase/migrations/20260919_circle_release.sql:94).

### 10. Group plan changes are immediate edits, not shared decisions

Any paid member can overwrite a week 4–6 activity/venue. The member schedule operation saves and audits, but does not notify the group as the organiser schedule path does. There is no version check to protect simultaneous edits. “Suggest an extra meetup” also directly creates an event, without distinguishing proposed from agreed.

Decide explicitly whether these are suggestions or confirmed plans. At minimum display who changed a plan, notify the group, and detect stale edits. Keep weekly dates fixed.

Evidence: [schedule actions](../supabase/migrations/20261002_fixed_programme_schedule.sql:55), [member editor](../lib/src/circles/circle_home.dart:829).

### 11. Chat history stops at 100 messages

The snapshot returns the latest 100 messages; the UI has no older-message pagination. Earlier agreements become inaccessible in an active six-week group. Sending also lacks a client-generated request ID: an accepted request with a lost response can be duplicated on retry.

Paginate chat separately from the full snapshot, preserve scroll position, add unread/new-message affordances, and make sends idempotent.

Evidence: [snapshot](../supabase/migrations/20260918_friendship_circles.sql:127), [message rendering/sending](../lib/src/circles/circle_shell.dart:435).

### 12. Failed dialog saves discard useful input

Plan and report dialogs close before the network write. A failed action produces an error, but the activity/venue or detailed report is no longer in an open editor for retry. Reports are particularly costly to retype.

Keep editors open while saving, disable duplicate submission, and retain input on failure. Close only after a confirmed save.

Evidence: [plan save](../lib/src/circles/circle_home.dart:896), [private report](../lib/src/circles/circle_shell.dart:859).

### 13. Confirmation-email recovery is incomplete

Signup without a session tells the user to confirm their email, then switches to Sign in. The current auth flow has no resend-confirmation action; the older prototype has one but it is not the active Circles flow. Password confirmation also compares trimmed passwords while signup submits the original password, allowing whitespace differences to pass confirmation.

Provide a dedicated Check your email state with resend/cooldown, correction of the address, and return handling. Compare exactly the password that will be submitted.

Evidence: [signup](../lib/src/screens/auth_flow_screen.dart:1077), [legacy resend only](../lib/src/screens/prototype_shell.dart:816).

### 14. Getting to the meetup needs a stronger practical screen

The active Circle card has a venue label and date/time, but no structured full address, directions action, or calendar export. Calendar support exists elsewhere in the older event experience. Full venue details are only shown on the featured card, making later plans hard to inspect.

Make a meetup detail screen with exact time, address/map link, meeting point, accessibility/cost notes where relevant, calendar entry, and a clear help route. Show expected price before committing to paid activities.

Evidence: [meetup card](../lib/src/circles/circle_home.dart:454), [existing calendar service](../lib/src/core/calendar_service.dart).

### 15. Time handling mixes Netherlands wall time and device time

The server emits local date/time strings; `circleMeetupStart` constructs a device-local DateTime. Comparing this with the device clock can shift client venue-release behaviour for someone travelling. The server independently masks venues, so this is primarily a consistency issue, not evidence of a venue leak.

Carry an absolute timestamp plus the named Circle timezone; sort/compare instants and format intentionally. Verify DST and non-Netherlands device timezones.

Evidence: [time helper](../lib/src/circles/circle_repository.dart:83), [venue helper](../lib/src/circles/circle_repository.dart:104).

### 16. Settings failures can look like user choices

A failed email-setting read displays enabled=true; a failed exclusion read displays an empty list. These are unknown states presented as saved preferences. Cancel on a focused application edit invokes the same callback as Save completion and shows “Saved.” even though it discards edits.

Keep the last confirmed preference or show unavailable/retry. Use separate Save and Cancel callbacks and accurate feedback.

Evidence: [preference reads](../lib/src/circles/circle_repository.dart:250), [focused Cancel](../lib/src/circles/circle_application.dart:710), [shared callback](../lib/src/circles/circle_shell.dart:505).

## Further hardening and operational checks

- **Notifications:** member notifications all lead to Home; the notification query omits event_id. Deep-link to the relevant meetup/check-in and preserve context. The email default URL is `.nl`, whereas auth uses `.com`; confirm the deployed APP_URL and canonical domain.
- **Photos:** full original uploads can be up to 8 MB, with no resize pipeline. Repeated successful replacements retain older objects. Add compressed thumbnails, dimension limits, and safe cleanup after replacement. Account deletion removes photos before deleting Auth; failure at the final step can leave an active account with broken photo references.
- **Programme attendance:** removing weekly RSVP did not create automatic event-attendee records on payment confirmation. Do not reuse the old RSVP confirmed_count as a programme headcount. Payment notification copy still asks members to RSVP. Align count semantics and backend copy with the new commitment model.
- **Matching/admin:** a group is activated on the first confirmed payment; the five/six initial invitees are not necessarily five/six paid attendees. Define minimum paid attendance, invitation expiry handling, replacement rules, and when an organiser postpones a group. Backend validates shared availability and exclusions, which is a good foundation.
- **Safety/support:** private reporting and exclusions exist, but reporting feedback is a generic sent message and future-match exclusion does not stop contact inside the current Circle. Define report follow-up, urgent support, and current-group intervention. Avoid promising the group can never infer who left when the member list changes.
- **Accessibility:** existing responsive tests are useful but do not establish keyboard navigation, screen-reader semantics, large text, colour contrast, or real mobile keyboard behaviour. These need a deliberate device/browser pass, including the new collapsed Programme settings controls.
- **Release discipline:** local migrations are not proof of applied database changes. Deployment notes warn that historical migrations were applied manually. Reconcile the migration history, verify SQL access suites on the actual candidate schema, add email-worker tests, and run a staging journey for two members and an organiser. The existing workflow runs Flutter checks/build, not these backend integration tests.

Recommended order: payment/leave state transitions → all-plan visibility and venue rules → refresh/error recovery → email delivery and monitoring → authenticated staging release check → the remaining experience improvements.
