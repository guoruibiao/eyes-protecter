#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Eyes Protecter"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"

if [[ "$APP" != "$ROOT"/dist/*.app ]]; then
    echo "Refusing to build outside $DIST" >&2
    exit 1
fi

cd "$ROOT"
mkdir -p .build/tmp .build/modulecache .build/cache

# Keep every cache inside the project. This also makes the build work in
# sandboxed terminals where ~/Library/Caches is not writable.
export TMPDIR="$ROOT/.build/tmp"
export CLANG_MODULE_CACHE_PATH="$ROOT/.build/modulecache"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT/.build/modulecache"

COMMON_FLAGS=(
    -c release
    --disable-sandbox
    --cache-path "$ROOT/.build/cache"
    --manifest-cache local
)

echo "==> Compiling arm64"
swift build "${COMMON_FLAGS[@]}" \
    --triple arm64-apple-macosx13.0 \
    --scratch-path "$ROOT/.build/arm64"

echo "==> Compiling x86_64"
swift build "${COMMON_FLAGS[@]}" \
    --triple x86_64-apple-macosx13.0 \
    --scratch-path "$ROOT/.build/x86_64"

ARM_BIN="$ROOT/.build/arm64/arm64-apple-macosx/release/EyesProtecter"
X86_BIN="$ROOT/.build/x86_64/x86_64-apple-macosx/release/EyesProtecter"

if [[ ! -x "$ARM_BIN" || ! -x "$X86_BIN" ]]; then
    echo "Build succeeded but expected binaries are missing:" >&2
    echo "  $ARM_BIN" >&2
    echo "  $X86_BIN" >&2
    exit 1
fi

echo "==> Packaging Universal 2 $APP_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

lipo -create "$ARM_BIN" "$X86_BIN" -output "$APP/Contents/MacOS/EyesProtecter"
ARCHS="$(lipo -archs "$APP/Contents/MacOS/EyesProtecter")"
if [[ "$ARCHS" != *arm64* || "$ARCHS" != *x86_64* ]]; then
    echo "Universal binary check failed: $ARCHS" >&2
    exit 1
fi
echo "    architectures: $ARCHS"

cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp "$ROOT/Resources/MenuBarIcon.png" "$APP/Contents/Resources/MenuBarIcon.png"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Ad-hoc signature is enough for a locally built, non-sandboxed menu bar app.
codesign --force --sign - --timestamp=none "$APP"
codesign --verify --strict "$APP"

echo "==> Built: $APP"

if [[ "${1:-}" == "--open" ]]; then
    open "$APP"
fi
