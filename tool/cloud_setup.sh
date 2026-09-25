#!/usr/bin/env bash
# One-shot setup for a Claude cloud (Linux) session — see docs/CLOUD-SESSION.md.
# Installs the same Flutter version as the owner's PC, fetches packages and
# writes env/cloud.json from environment variables when they are set.
# Safe to re-run.
set -euo pipefail

FLUTTER_VERSION="3.47.5"
FLUTTER_DIR="${FLUTTER_DIR:-$HOME/flutter}"
cd "$(dirname "$0")/.."

if ! command -v flutter >/dev/null 2>&1; then
  if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
    git clone --depth 1 --branch "$FLUTTER_VERSION" \
      https://github.com/flutter/flutter.git "$FLUTTER_DIR"
  fi
  export PATH="$FLUTTER_DIR/bin:$PATH"
  echo "export PATH=\"$FLUTTER_DIR/bin:\$PATH\"" >> "$HOME/.bashrc"
fi

flutter config --no-analytics >/dev/null
flutter --version
flutter pub get

# Cloud config (git-ignored). Values are public (URL + publishable key),
# but the owner keeps them out of git — pass them as environment variables.
if [ -n "${SUPABASE_URL:-}" ] && [ -n "${SUPABASE_PUBLISHABLE_KEY:-}" ]; then
  cat > env/cloud.json <<EOF
{
  "SUPABASE_URL": "$SUPABASE_URL",
  "SUPABASE_PUBLISHABLE_KEY": "$SUPABASE_PUBLISHABLE_KEY",
  "GOOGLE_WEB_CLIENT_ID": "${GOOGLE_WEB_CLIENT_ID:-}",
  "GOOGLE_ANDROID_CLIENT_ID": "${GOOGLE_ANDROID_CLIENT_ID:-}"
}
EOF
  echo "Wrote env/cloud.json"
else
  echo "No SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY: offline-only build."
fi

echo "Setup done. Next: dart format lib test && flutter analyze && flutter test --timeout 45s -r expanded > test-output.txt"
