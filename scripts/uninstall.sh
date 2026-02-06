#!/bin/bash
set -euo pipefail

PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST_NAME="com.ttak.agent.plist"

echo "Stopping ttak..."
launchctl unload "$PLIST_DIR/$PLIST_NAME" 2>/dev/null || true

echo "Removing LaunchAgent..."
rm -f "$PLIST_DIR/$PLIST_NAME"

echo "Removing binary..."
sudo rm -f /usr/local/bin/ttak

echo "Removing config..."
rm -rf ~/.config/ttak

echo "ttak uninstalled."
