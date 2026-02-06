#!/bin/bash
set -euo pipefail

VERSION="${1:-1.0.0}"
APP_NAME="Ttak"
BUNDLE_DIR=".build/${APP_NAME}.app"

# ── Code Signing / Notarization Variables ──────────────────────────
# Set these environment variables before running, or pass them inline.
#
# Required for signing:
#   DEVELOPER_ID    – "Developer ID Application: Your Name (TEAMID)"
#
# For notarization, use ONE of these two methods:
#
#   Method A – Keychain profile (recommended for CI/CD):
#     NOTARY_PROFILE  – profile name stored via:
#       xcrun notarytool store-credentials "ttak-notary" \
#         --apple-id "you@example.com" --team-id "ABCDE12345"
#
#   Method B – Inline credentials:
#     APPLE_ID        – Apple ID email
#     TEAM_ID         – 10-character Apple Developer Team ID
#     APP_PASSWORD    – app-specific password
#
# To skip signing entirely (local dev), leave DEVELOPER_ID unset.
# ───────────────────────────────────────────────────────────────────
DEVELOPER_ID="${DEVELOPER_ID:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
APPLE_ID="${APPLE_ID:-}"
TEAM_ID="${TEAM_ID:-}"
APP_PASSWORD="${APP_PASSWORD:-}"

echo "Building ttak v${VERSION} (release)..."
swift build -c release --disable-sandbox

echo "Assembling ${APP_NAME}.app..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS"
mkdir -p "$BUNDLE_DIR/Contents/Resources"

# Copy binary
cp .build/release/ttak "$BUNDLE_DIR/Contents/MacOS/ttak"

# Copy Info.plist with version substitution
sed "s/1.0.0/$VERSION/g" resources/Info.plist > "$BUNDLE_DIR/Contents/Info.plist"

# Create PkgInfo
echo -n "APPL????" > "$BUNDLE_DIR/Contents/PkgInfo"

echo "Built: $BUNDLE_DIR"

# ── Code Signing ───────────────────────────────────────────────────
if [ -n "$DEVELOPER_ID" ]; then
    echo "Signing with: $DEVELOPER_ID"
    codesign --force --options runtime --deep \
        --sign "$DEVELOPER_ID" \
        "$BUNDLE_DIR"
    echo "Verifying signature..."
    codesign --verify --verbose "$BUNDLE_DIR"
else
    echo "Skipping code signing (DEVELOPER_ID not set)"
fi

# ── Notarization ───────────────────────────────────────────────────
if [ -n "$DEVELOPER_ID" ] && { [ -n "$NOTARY_PROFILE" ] || { [ -n "$APPLE_ID" ] && [ -n "$TEAM_ID" ] && [ -n "$APP_PASSWORD" ]; }; }; then
    ZIP_PATH=".build/${APP_NAME}.app.zip"
    echo "Creating zip for notarization..."
    ditto -c -k --keepParent "$BUNDLE_DIR" "$ZIP_PATH"

    echo "Submitting for notarization..."
    if [ -n "$NOTARY_PROFILE" ]; then
        # Method A: Keychain profile (recommended)
        xcrun notarytool submit "$ZIP_PATH" \
            --keychain-profile "$NOTARY_PROFILE" \
            --wait
    else
        # Method B: Inline credentials
        xcrun notarytool submit "$ZIP_PATH" \
            --apple-id "$APPLE_ID" \
            --team-id "$TEAM_ID" \
            --password "$APP_PASSWORD" \
            --wait
    fi

    echo "Stapling notarization ticket..."
    xcrun stapler staple "$BUNDLE_DIR"

    echo "Notarization complete."
    rm -f "$ZIP_PATH"
else
    echo "Skipping notarization (credentials not set)"
fi

echo "Done. To run: open $BUNDLE_DIR"
