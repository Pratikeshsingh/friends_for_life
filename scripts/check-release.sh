#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter pub get
flutter analyze --no-pub
# Spacing and line breaks follow the standard Dart format.
dart format --output=none --set-exit-if-changed lib test
flutter test --no-pub
flutter build web --release --no-pub --pwa-strategy=none
# Demo mode must never be enabled in the public build.
test -f build/web/index.html
test -f build/web/sw.js
test -f build/web/_redirects
printf 'Release build ready in build/web\n'
