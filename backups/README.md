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
