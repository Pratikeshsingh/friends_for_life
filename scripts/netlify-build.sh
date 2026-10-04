#!/usr/bin/env bash
# Netlify build: install Flutter and build the app.
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
# Stamp the build with its commit, so the version in Profile and in error
# reports tells releases apart. Netlify provides COMMIT_REF.
APP_BUILD="1.0.0+$(printf '%s' "${COMMIT_REF:-local}" | cut -c1-7)"
flutter build web --release --pwa-strategy=none --dart-define=APP_BUILD="$APP_BUILD"

test -f build/web/index.html
test -f build/web/_redirects
echo "Netlify build $APP_BUILD ready in build/web"
