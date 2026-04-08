#!/bin/bash
# Builds TKRMCPServer and wraps it in a minimal .app bundle for macOS TCC permissions.
# Usage: ./scripts/bundle.sh
# Output: .build/bundle/TKRMCPServer.app

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="TKRMCPServer"
BUNDLE_DIR="$PROJECT_DIR/.build/bundle"
APP_DIR="$BUNDLE_DIR/$APP_NAME.app"

# Build release binary
echo "Building release binary..."
swift build -c release --package-path "$PROJECT_DIR"

# Create .app bundle structure
echo "Creating .app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"

# Copy binary and Info.plist
cp "$PROJECT_DIR/.build/release/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$PROJECT_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"

# Ad-hoc code sign so macOS recognizes the bundle identity
echo "Code signing..."
codesign --force --sign - "$APP_DIR"

echo ""
echo "Bundle created: $APP_DIR"
echo ""
echo "MCP binary path (for claude mcp add):"
echo "  $APP_DIR/Contents/MacOS/$APP_NAME"
echo ""
echo "To reset TCC permissions after rebuilding:"
echo "  tccutil reset All com.tkr.mcp-server"
