#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Eyes Protecter"
APP="$ROOT/dist/$APP_NAME.app"

if [[ ! -d "$APP" ]]; then
    echo "==> $APP_NAME.app not found, building first"
    "$ROOT/scripts/build-app.sh"
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
ZIP="$ROOT/dist/Eyes-Protecter-$VERSION.zip"
DMG="$ROOT/dist/Eyes-Protecter-$VERSION.dmg"
CHECKSUM="$ROOT/dist/Eyes-Protecter-$VERSION-SHA256.txt"
STAGE="$ROOT/.build/dmg-stage"

echo "==> Verifying signature"
codesign --verify --strict "$APP"

echo "==> Creating zip"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

echo "==> Creating dmg"
rm -rf "$STAGE"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/$APP_NAME.app"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
DMG_OK=0
if hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGE" \
    -ov -format UDZO \
    "$DMG" >/dev/null; then
    DMG_OK=1
else
    echo "warning: hdiutil could not create a DMG (it may be blocked in a sandbox)." >&2
    echo "         The zip is still valid; run this script from Terminal for a DMG." >&2
    rm -f "$DMG"
fi
rm -rf "$STAGE"

echo "==> Writing checksums"
CHECK_FILES=("$(basename "$ZIP")")
if [[ "$DMG_OK" -eq 1 ]]; then
    CHECK_FILES+=("$(basename "$DMG")")
fi
(cd "$ROOT/dist" && shasum -a 256 "${CHECK_FILES[@]}" > "$(basename "$CHECKSUM")")

echo ""
echo "Release artifacts:"
echo "  $ZIP"
if [[ "$DMG_OK" -eq 1 ]]; then
    echo "  $DMG"
fi
echo "  $CHECKSUM"
echo ""
echo "Publish on GitHub:"
echo "  https://github.com/guoruibiao/eyes-protecter/releases/new"
echo "  Tag:    v$VERSION"
echo "  Title:  Eyes Protecter $VERSION"
if [[ "$DMG_OK" -eq 1 ]]; then
    echo "  Assets: upload the .zip and .dmg above"
else
    echo "  Assets: upload the .zip above"
fi
echo ""
echo "With GitHub CLI (if installed and authenticated):"
echo "  gh release create v$VERSION \"$ZIP\" --title \"Eyes Protecter $VERSION\" --notes \"Eyes Protecter $VERSION\""
