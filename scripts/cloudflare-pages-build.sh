#!/usr/bin/env bash
# Cloudflare Pages build for the OpenRecall Flutter web target (spec-web-mvp §7).
#
# Cloudflare Pages settings that pair with this script:
#   Build command:          bash scripts/cloudflare-pages-build.sh
#   Build output directory: build/web
#   Root directory:         /
#   Environment variables:  SUPABASE_URL, SUPABASE_ANON_KEY
set -euo pipefail

FLUTTER_VERSION=3.47.2
FLUTTER_HOME="$HOME/flutter"

# The Pages build image has no Flutter toolchain; install it, pinned to the
# version in .metadata. --branch <tag> --depth 1 keeps a tagged commit so
# Flutter's own `git describe` version check still works on the shallow clone.
if [ ! -x "$FLUTTER_HOME/bin/flutter" ]; then
  git clone --depth 1 --branch "$FLUTTER_VERSION" \
    https://github.com/flutter/flutter.git "$FLUTTER_HOME"
fi
export PATH="$FLUTTER_HOME/bin:$PATH"
git config --global --add safe.directory "$FLUTTER_HOME"

flutter --version

# .env is a bundled Flutter asset (pubspec.yaml: flutter: assets: - .env) read
# by flutter_dotenv at startup. It is git-ignored, so recreate it here from the
# Pages environment. Both values ship in the Android APK too and are safe under
# RLS (spec-web-mvp §5.1) — do not put anything else in .env.
: "${SUPABASE_URL:?SUPABASE_URL is not set in the Cloudflare Pages environment}"
: "${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY is not set in the Cloudflare Pages environment}"
printf 'SUPABASE_URL=%s\nSUPABASE_ANON_KEY=%s\n' \
  "$SUPABASE_URL" "$SUPABASE_ANON_KEY" > .env

flutter pub get
flutter build web --release
