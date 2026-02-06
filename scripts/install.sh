#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# Build the .app bundle
./scripts/build-app.sh

# Install to /Applications
echo "Installing Ttak.app to /Applications..."
rm -rf /Applications/Ttak.app
cp -R .build/Ttak.app /Applications/

echo ""
echo "Ttak installed successfully."
echo "Run: open /Applications/Ttak.app"
echo ""
echo "IMPORTANT: Grant Accessibility permission in System Settings."
