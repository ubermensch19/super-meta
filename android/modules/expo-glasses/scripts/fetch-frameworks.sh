#!/usr/bin/env bash
# Fetch the Meta Wearables DAT xcframeworks that this module vendors.
# They're large binaries (~74MB) so they're gitignored; run this once after clone.
set -euo pipefail

MODULE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$MODULE_DIR/ios/Frameworks"
VERSION="0.5.0"
mkdir -p "$DEST"

# 1) Reuse a locally-resolved SwiftPM checkout if present (fastest).
LOCAL="$(find "$HOME/Library/Developer/Xcode/DerivedData" \
  -ipath '*SourcePackages/checkouts/meta-wearables-dat-ios' -maxdepth 6 -type d 2>/dev/null | head -1)"

if [ -n "${LOCAL:-}" ] && [ -d "$LOCAL/MWDATCore.xcframework" ]; then
  echo "Copying xcframeworks from local SwiftPM checkout: $LOCAL"
  cp -R "$LOCAL/MWDATCore.xcframework" "$LOCAL/MWDATCamera.xcframework" "$DEST/"
else
  # 2) Otherwise clone the public SDK repo (binaryTargets live at its root).
  echo "Cloning meta-wearables-dat-ios@$VERSION"
  TMP="$(mktemp -d)"
  git clone --depth 1 --branch "$VERSION" https://github.com/facebook/meta-wearables-dat-ios "$TMP"
  cp -R "$TMP/MWDATCore.xcframework" "$TMP/MWDATCamera.xcframework" "$DEST/"
  rm -rf "$TMP"
fi

echo "Done. Vendored:"
ls -1 "$DEST"
