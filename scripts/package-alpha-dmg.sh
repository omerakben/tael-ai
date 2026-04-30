#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/TAELMacAgent/TAELMacAgent.xcodeproj"
SCHEME="TAELMacAgent"
TEAM_ID="${TEAM_ID:-4X8U3NCLQ8}"
APP_NAME="TAELMacAgent"
VERSION="${VERSION:-0.1.0-alpha}"
BUILD_DIR="$ROOT_DIR/dist/alpha"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
APP_ZIP="$BUILD_DIR/$APP_NAME-$VERSION.app.zip"
DMG_PATH="$BUILD_DIR/$APP_NAME-$VERSION.dmg"
DEVELOPER_ID_APPLICATION="${DEVELOPER_ID_APPLICATION:-}"
NOTARYTOOL_PROFILE="${NOTARYTOOL_PROFILE:-}"

usage() {
    cat <<EOF
Usage:
  DEVELOPER_ID_APPLICATION="Developer ID Application: ..." \\
  NOTARYTOOL_PROFILE="tael-notary" \\
  VERSION="0.1.0-alpha.1" \\
  $0

Required:
  DEVELOPER_ID_APPLICATION  Developer ID Application signing identity.
  NOTARYTOOL_PROFILE        Keychain profile created with xcrun notarytool store-credentials.

Output:
  $DMG_PATH
EOF
}

require_value() {
    local name="$1"
    local value="$2"
    if [[ -z "$value" ]]; then
        echo "error: $name is required." >&2
        usage >&2
        exit 2
    fi
}

require_command() {
    local name="$1"
    if ! command -v "$name" >/dev/null 2>&1; then
        echo "error: required command not found: $name" >&2
        exit 2
    fi
}

require_value "DEVELOPER_ID_APPLICATION" "$DEVELOPER_ID_APPLICATION"
require_value "NOTARYTOOL_PROFILE" "$NOTARYTOOL_PROFILE"
require_command xcodebuild
require_command xcrun
require_command hdiutil
require_command codesign
require_command spctl
require_command ditto

if ! security find-identity -v -p codesigning | grep -F "$DEVELOPER_ID_APPLICATION" >/dev/null; then
    echo "error: Developer ID identity not found in keychain: $DEVELOPER_ID_APPLICATION" >&2
    echo "Install the Developer ID Application certificate before packaging alpha DMGs." >&2
    exit 2
fi

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Archiving $APP_NAME $VERSION"
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVE_PATH" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$DEVELOPER_ID_APPLICATION" \
    archive

APP_PATH="$ARCHIVE_PATH/Products/Applications/$APP_NAME.app"
if [[ ! -d "$APP_PATH" ]]; then
    echo "error: archive did not produce $APP_PATH" >&2
    exit 1
fi

echo "==> Verifying app signature"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo "==> Submitting app for notarization"
ditto -c -k --keepParent "$APP_PATH" "$APP_ZIP"
xcrun notarytool submit "$APP_ZIP" \
    --keychain-profile "$NOTARYTOOL_PROFILE" \
    --wait

echo "==> Stapling app notarization ticket"
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"

echo "==> Gatekeeper app assessment"
spctl -a -vvv "$APP_PATH"

echo "==> Creating DMG"
rm -f "$DMG_PATH"
hdiutil create \
    -volname "TAEL AI Alpha" \
    -srcfolder "$APP_PATH" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

echo "==> Submitting DMG for notarization"
xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$NOTARYTOOL_PROFILE" \
    --wait

echo "==> Stapling notarization ticket"
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

echo "==> Gatekeeper DMG assessment"
spctl -a -vvv --type open "$DMG_PATH"

echo "Alpha DMG ready: $DMG_PATH"
