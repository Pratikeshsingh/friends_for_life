# VriendTime UI polish — July 2026

This pass keeps the product warm and human while removing repeated prompts, decorative weight, ambiguous copy, and avoidable startup work.

## Recovery

The complete working tree from immediately before this pass is preserved at:

`backups/vriendtime-before-ui-polish-2026-07-11.tar.gz`

SHA-256:

`7ba2bec773dd600efe882ba7645c9fe7088d276d10e41e34c12c28d5daa85109`

Restore the archive into a separate empty directory first. Do not extract it over the active working tree unless intentionally replacing the current version.

## Product changes

- Simplified the launch screen around one promise, one human hero image, one primary action, and three short trust signals.
- Removed hard-coded preview dates and reduced repetitive empty-state prompts.
- Reduced onboarding to three actionable steps; completion is no longer presented as a fourth task.
- Reworked onboarding copy, privacy explanations, autofill, keyboard actions, validation feedback, and cancellation wording.
- Made gender optional and kept phone optional.
- Removed nonessential onboarding illustrations and unified in-app event artwork.
- Tightened headline line-height and reduced excessive heavy font weights.
- Reduced the floating bottom navigation footprint.
- Replaced the hard-coded Alkmaar heading with city-aware copy that never labels other-city events as local.
- Moved available meetup content above decorative content on the Meetups tab.
- Separated nested meetup and calendar actions for keyboard and screen-reader users.
- Improved profile, support, safety, reservation, cancellation, empty, error, and calendar copy.
- Added semantics, tooltips, image fallbacks, private-field labels, and large-text coverage.
- Added explicit retry states so network failures are not presented as genuine lack of availability.
- Removed prototype meetup history as a fallback for failed network requests.
- Shows email-confirmation guidance throughout the authenticated app, not only on Profile.

## Performance changes

- The original PNG source artwork remains available in the repository and in the recovery archive, but it is no longer declared as a shipped Flutter asset directory.
- Declared UI artwork and local fonts now total approximately **1.5 MB**, down from approximately **57 MB** of PNG artwork previously included by broad directory declarations.
- Runtime-downloaded Google Fonts were replaced with bundled Manrope and Newsreader variable fonts.
- Signed-out launch no longer fetches events, past events, reservations, attendance state, notifications, or profile warm-up data.
- Removed an attendance-status request that existed only to control a redundant reminder.
- Added branded cream/navy launch surfaces for web, Android, and iOS.
- Added a lightweight, accessible web loading shell and removed the portrait-only PWA lock.

## Verification scope

- Static analysis and the full Flutter test suite.
- Responsive checks at 320, 375, 768, 1024, and 1440 pixels.
- 200% onboarding text scaling.
- Source-level XML/JSON validation.
- Rendered mobile review captures for launch, Home, and Meetups during implementation.
- Release web build validation. Android resource XML was validated structurally; an Android debug build could not start in this environment because no compatible Java/Gradle runtime was available.

The in-app browser surface was unavailable during this pass, so a final signed-in click-through with real backend data remains a sensible release smoke test.
