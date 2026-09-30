#!/usr/bin/env bash
# Netlify build: install Flutter, build the current app, then add the
# previous meetup app under /oldapp from the prebuilt files in legacy/oldapp.
set -euo pipefail
cd "$(dirname "$0")/.."

FLUTTER_VERSION="${FLUTTER_VERSION:-3.44.0}"
FLUTTER_DIR="$HOME/flutter-$FLUTTER_VERSION"
if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi
export PATH="$FLUTTER_DIR/bin:$PATH"
flutter config --no-analytics >/dev/null
flutter --version

flutter pub get
flutter build web --release --pwa-strategy=none

# The old app was built with --base-href /oldapp/ and loads CanvasKit from
# Google's CDN, so only its own files are copied here.
mkdir -p build/web/oldapp
cp -R legacy/oldapp/. build/web/oldapp/

test -f build/web/index.html
test -f build/web/_redirects
test -f build/web/oldapp/index.html
echo "Netlify build ready in build/web"
