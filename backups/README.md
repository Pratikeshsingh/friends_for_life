# VriendTime recovery snapshots

## Before the July 2026 UI polish

- Archive: `vriendtime-before-ui-polish-2026-07-11.tar.gz`
- SHA-256: `7ba2bec773dd600efe882ba7645c9fe7088d276d10e41e34c12c28d5daa85109`
- Source state: the complete working tree immediately before the UI/UX polish pass, including the user's tracked and untracked work.
- Excluded: `.git`, `.dart_tool`, `build`, platform ephemeral folders, and this `backups` directory.

To verify the archive:

```sh
shasum -a 256 backups/vriendtime-before-ui-polish-2026-07-11.tar.gz
```

Restore into a separate empty directory first so the current working tree is not overwritten accidentally.

## Before the immersive edge-to-edge pass

- Archive: `vriendtime-before-immersive-pass-2026-07-11.tar.gz`
- SHA-256: `7e3b53b6bc50205dcc20c4479524c20ebd9f387053195a19b5d2c1136f5bba7a`
- Source state: the completed first UI-polish pass, immediately before the immersive landing, public preview, availability, navigation, and 10:00 address-release work.
- Excluded: `.git`, `.dart_tool`, `build`, platform ephemeral folders, and this `backups` directory.

## Before compact immersive headers across internal pages

- Archive: `vriendtime-before-compact-immersive-pages-2026-07-11.tar.gz`
- SHA-256: `9d8488c0ba8bc4954cb3ba5b6e8e3cc565ad65c9ba3a6b17de36a9ed59d545e3`
- Source state: the immersive landing, public meetup exploration, 10:00 venue release, and new table-based logo, immediately before extending compact edge-to-edge artwork to Home, Meetups, Profile, and onboarding.
- Excluded: `.git`, `.dart_tool`, `build`, platform ephemeral folders, and this `backups` directory.
# Compact immersive pages before single-scene redesign (2026-07-12)

- Archive: `vriendtime-before-single-scene-pages-2026-07-12.tar.gz`
- SHA-256: `94bbed3e7c130814d1cdd8f030cf9b673d371610a9ba233a1af6b2729fb65e20`
- Purpose: Restores the working compact-header implementation before Home,
  Meetups, and Profile were recomposed around one continuous illustration.

## Before the editorial invitation-card pass (2026-07-12)

- Archive: `vriendtime-before-editorial-invitations-2026-07-12.tar.gz`
- SHA-256: `6fe37b68cf082df47d22f21c83f342ebed33f30e81a26eabed2fcd6e8577ef21`
- Purpose: Restores the working single-scene pages before their Home,
  Meetups, and Profile foreground components received the editorial identity.

## Before the unified immersive meetup pass (2026-07-12)

- Archive: `vriendtime-before-unified-immersive-meetups-2026-07-12.tar.gz`
- SHA-256: `d5e460c44dcdb8e0b4d711e258392368526886f14a7b919dc562ec9a57e676b6`
- Purpose: Restores the editorial invitation version before meetup cards,
  onboarding, availability labels, profile sign-out, and mobile navigation were
  unified.

## Before the mobile UX follow-up (2026-07-12)

- Archive: `vriendtime-before-mobile-ux-follow-up-2026-07-12.tar.gz`
- SHA-256: `85f8d90705f4277bc06881b0f3cc949bd51dab21d13a04e4158628ccb4109705`
- Purpose: Restores the unified immersive version before landing actions,
  mobile navigation, privacy help, and iPhone photo handling were refined.

## Before the contextual Home and web landing pass (2026-07-14)

- Archive: `vriendtime-before-contextual-home-web-landing-2026-07-14.tar.gz`
- SHA-256: `32f497ae6b5b564f084607cb2088cfdade577be816f4807999602b0e2ed42e88`
- Purpose: Restores the working immersive app before the contextual Home,
  web-specific marketing page, and exact address-release copy were added.

## Landing hero asset rollback (2026-07-14)

- Current mobile asset: `assets/generated/landing-open-seat-mobile-v1.webp`
- Current desktop asset: `assets/generated/landing-open-seat-desktop-v1.webp`
- Previous mobile asset, preserved unchanged:
  `assets/generated/landing-immersive-mobile-v2.webp`
- Previous desktop asset, preserved unchanged:
  `assets/generated/landing-immersive-desktop-v2.webp`
- To restore the previous hero, point the two `landingImmersive` constants in
  `lib/src/widgets/meetup_media.dart` back to the previous assets and swap the
  corresponding asset entries in `pubspec.yaml`.

## Before the onboarding and meetup polish pass (2026-07-14)

- Archive: `vriendtime-before-onboarding-meetup-polish-2026-07-14.tar.gz`
- SHA-256: `579ff6583c718e30e40921bd1a84d0fa165a6881626fd7ff5183a0086388061a`
- Purpose: Restores the working open-seat landing version before the public
  reservation actions, authentication backgrounds, onboarding disclosures,
  meetup metadata, and photo-upload feedback were refined.

## Before the pinned explorer and visible details pass (2026-07-15)

- Archive: `vriendtime-before-pinned-sheet-visible-details-2026-07-15.tar.gz`
- SHA-256: `51a283ec65a3a97c601538f741c7ad8093f32925bfa1678b4a0a44d2f24d1f43`
- Purpose: Restores the working compact landing and onboarding version before
  the public meetup explorer received a pinned, clipped header and all profile
  detail fields were made directly visible.
