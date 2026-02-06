#!/bin/bash
set -euo pipefail

echo "Quitting Ttak..."
osascript -e 'quit app "Ttak"' 2>/dev/null || true
sleep 1

echo "Removing Ttak.app..."
rm -rf /Applications/Ttak.app

echo "Removing config..."
rm -rf ~/.config/ttak

echo "Ttak uninstalled."
