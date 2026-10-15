#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
BUILD_ROOT=$(mktemp -d "${TMPDIR:-/private/tmp}/notchwork-build.XXXXXX")
export CLANG_MODULE_CACHE_PATH="$BUILD_ROOT/module-cache"
export SWIFT_MODULE_CACHE_PATH="$BUILD_ROOT/module-cache"
trap 'rm -rf "$BUILD_ROOT"' EXIT
DIST="$PWD/dist"
mkdir -p "$BUILD_ROOT/project" "$DIST"
cp Package.swift "$BUILD_ROOT/project/"
ditto --norsrc Sources "$BUILD_ROOT/project/Sources"
ditto --norsrc Tests "$BUILD_ROOT/project/Tests"
swift build -c release --package-path "$BUILD_ROOT/project" --scratch-path "$BUILD_ROOT/build"
BIN_DIR=$(swift build -c release --package-path "$BUILD_ROOT/project" --scratch-path "$BUILD_ROOT/build" --show-bin-path)
APP="$BUILD_ROOT/Notchwork.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Notchwork" "$APP/Contents/MacOS/Notchwork"
cp "$BIN_DIR/notchworkctl" "$DIST/notchworkctl"
cp Info.plist "$APP/Contents/Info.plist"
cp LICENSE NOTICE "$APP/Contents/Resources/"
cp LICENSE NOTICE "$DIST/"
SIGN_IDENTITY="${NOTCHWORK_SIGNING_IDENTITY:--}"
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  codesign --force --sign - --entitlements Notchwork.entitlements "$APP"
  codesign --force --sign - "$DIST/notchworkctl"
else
  codesign --force --options runtime --timestamp --entitlements Notchwork.entitlements --sign "$SIGN_IDENTITY" "$APP"
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$DIST/notchworkctl"
fi
codesign --verify --deep --strict "$APP"
codesign --verify --strict "$DIST/notchworkctl"
rm -f "$DIST/Notchwork.zip"
(cd "$BUILD_ROOT" && zip -qr -X "$DIST/Notchwork.zip" Notchwork.app)
rm -rf "$DIST/Notchwork.app"
ditto --norsrc "$APP" "$DIST/Notchwork.app"
(cd "$DIST" && shasum -a 256 Notchwork.zip notchworkctl > SHA256SUMS)
print "Built $DIST/Notchwork.zip ($(uname -m)); signing identity: $SIGN_IDENTITY"
