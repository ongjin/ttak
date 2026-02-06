#!/bin/bash
set -euo pipefail

INSTALL_DIR="/usr/local/bin"
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST_NAME="com.ttak.agent.plist"

echo "Building ttak..."
swift build -c release

echo "Installing binary to $INSTALL_DIR..."
sudo cp .build/release/ttak "$INSTALL_DIR/ttak"
sudo chmod +x "$INSTALL_DIR/ttak"

echo "Installing LaunchAgent..."
mkdir -p "$PLIST_DIR"
sed "s|HOMEBREW_PREFIX|/usr/local|g" resources/com.ttak.agent.plist > "$PLIST_DIR/$PLIST_NAME"

echo "Loading LaunchAgent..."
launchctl load "$PLIST_DIR/$PLIST_NAME"

echo ""
echo "ttak installed successfully."
echo "IMPORTANT: Grant Accessibility permission in System Settings."
