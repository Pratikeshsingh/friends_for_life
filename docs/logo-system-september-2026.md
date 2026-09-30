# VriendTime logo — September 2026

Approved direction: three people surrounding a V-shaped opening. The supplied reference is reconstructed as clean vector paths, with forest green #145247, coral #F56853 and cream #F7EBD3. The wordmark uses the app's bundled Manrope ExtraBold, rather than approximating the reference's unknown rounded font. SVG wordmark letters are outlined for portable rendering.

- `assets/brand/vriendtime-logo.svg`: transparent stacked logo and outlined wordmark.
- `assets/brand/vriendtime-mark.svg`: transparent full symbol.
- `assets/brand/vriendtime-mark-small.svg`: symbol without cream centre for small sizes.
- `assets/brand/vriendtime-mark-mono.svg`: one-colour symbol.
- `assets/brand/vriendtime-app-icon.svg`: opaque cream background and safe icon padding.
- `assets/brand/vriendtime-brand-sheet.png`: visual comparison including small sizes.

The Flutter mark switches to the simple version below 48 logical pixels. The header uses a horizontal layout, with white lettering on dark backgrounds. Web launch, favicons, Android/iOS/macOS/Windows icon exports and iOS launch images use the same source geometry. Native packaging/device testing is separate from asset export.

Regenerate using `scripts/export-brand.py` with Python packages pillow, fonttools and cairosvg (plus system Cairo). On Homebrew macOS, set `DYLD_FALLBACK_LIBRARY_PATH=/opt/homebrew/lib` if Cairo is not found. The script generates `brand_mark_painter.dart`; run `dart format` afterward. Existing July branding documentation is historical.

## Loading motion

The three people travel inward from top, left and right with a slight stagger. Initial separation is 300 vector units above and 330 units to either side, with an expanded motion area to keep every person visible. A four-second loop assembles during the first 1.6 seconds, holds through 2.88 seconds, then separates smoothly. The centre fades in as the people meet. Web CSS and Flutter use the same timing structure. Reduced-motion settings display the complete static mark. Loading never waits for the animation to finish. Open `docs/logo-animation.html` for a standalone motion preview.
