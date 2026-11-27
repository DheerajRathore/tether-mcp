#!/bin/bash
set -euo pipefail

VERSION="${1:?usage: build-dmg.sh <version>, e.g. 0.1.0}"
cd "$(dirname "$0")/.."

rm -rf build dist
xcodebuild -project Tether.xcodeproj -scheme Tether -configuration Release \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=YES \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  MARKETING_VERSION="$VERSION" build

APP="build/Build/Products/Release/Tether.app"
codesign --verify --deep --strict "$APP"
codesign -d --entitlements - "$APP/Contents/MacOS/tether-cli" 2>&1 | grep -q app-sandbox \
  && { echo "tether-cli is sandboxed, aborting"; exit 1; } || true

mkdir dist
cp -R "$APP" dist/
ln -s /Applications dist/Applications
hdiutil create -volname "Tether" -srcfolder dist -ov -format UDZO "Tether-$VERSION.dmg"
shasum -a 256 "Tether-$VERSION.dmg" | tee "Tether-$VERSION.dmg.sha256"
