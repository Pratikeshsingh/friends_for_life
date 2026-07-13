# VriendTime logo system — July 2026

## Idea

The mark shows two people facing each other across a small real table. It
replaces the former interlocking-loop symbol, which could read as an engagement
ring or infinity mark at small sizes.

The silhouette is intentionally simple:

- navy person: familiarity and trust;
- teal person: openness and new connection;
- coral table: the real-world meeting point;
- warm cream app-icon background: calm, welcoming, and consistent with the UI.

## Source of truth

- Transparent vector: `assets/brand/vriendtime-mark.svg`
- App-icon vector: `assets/brand/vriendtime-app-icon.svg`
- Flutter UI implementation: `lib/src/widgets/brand_logo.dart`

The Flutter interface paints the vector directly with `CustomPainter`, so the
mark stays crisp at every size and does not require an image decode. Raster
exports are retained for platform surfaces that require PNG or WebP.

## Colors

- Navy: `#062B55`
- Teal: `#29B8AA`
- Coral: `#FF7759`
- App-icon cream: `#FFF9F1`

## Platform exports

The updated mark is exported to Android launcher icons, iOS and macOS app-icon
sets, the web app manifest icons, maskable icons, favicons, and the legacy brand
raster files. Android and iOS launch surfaces use the new mark as well. The
previous logo remains recoverable from the July UI snapshots in `backups/`.
