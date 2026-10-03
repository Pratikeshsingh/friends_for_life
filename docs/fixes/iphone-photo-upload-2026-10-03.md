# Phone photo upload

The reported production toast is generic and does not identify the exact failure. The original image and device logs were unavailable; its specific encoding/size has not been confirmed.

Confirmed code gaps:
- Circle picker restricted extensions to JPEG/PNG/WebP, excluding HEIC/HEIF originals.
- Input validation rejected originals over 8 MiB before resizing.
- The web path used Flutter's image descriptor rather than the browser's native image decoder.
- Unknown decoding errors misleadingly advised changing format/size.

Implemented locally:
- Image-library picker instead of a restricted extension list.
- Shared preparation for Circle onboarding/profile and account-profile uploads.
- Web uses HTML image decoding and canvas JPEG export (quality 0.85), supporting HEIC where the browser supports it. Safari added HEIC/HEIF image support in version 17: https://webkit.org/blog/14445/webkit-features-in-safari-17-0/
- Native path retains Flutter decoding with consistent resize and resource cleanup.
- Original guard: 40 MiB, at most 64 million pixels and 12,000 pixels per dimension. Supports normal 48 MP dimensions without storing the full original. RAW/unusually large originals are not promised support.
- Prepared image: longest edge 1,024 pixels, aspect preserved, no upscaling. Browser output is JPEG; native output is PNG. Re-encoding discards source metadata. The storage allowlist/8 MiB cap remain as safety checks on the prepared image.
- Preparation errors separated from storage errors, with English/Dutch guidance. HEIC on a browser lacking native support gets actionable feedback rather than a false size warning.

Validation:
- Six new preparation tests passed on Flutter's native test runner and in Chrome.
- Cases include >8 MiB input, output size/signature/dimensions, portrait shape, no upscaling, empty/oversized/corrupt input, HEIF brand detection and 48 MP sizing limits.
- Full current Flutter suite: 177 passed.
- Analysis had no compile errors; it reported six style notices in existing concurrently edited code.
- Chrome does not establish actual iPhone HEIC decoding. A real iPhone test remains necessary, including camera/library input, rotation, iCloud download, Safari and the reported embedded browser.

No production deployment, storage configuration change or real member upload was performed. Deploy the verified release through the normal pipeline, then retry the original iPhone photo. If it still fails, collect its format/dimensions and a sanitised preparation/storage error separately.
