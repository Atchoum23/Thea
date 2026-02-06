#!/bin/bash

# Thea Native Messaging Host Installer
# Installs the native messaging host for Chrome and Brave browsers

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="Thea"
HOST_NAME="com.thea.native"
HOST_BINARY="TheaNativeMessagingHost"

# Paths
THEA_APP="/Applications/${APP_NAME}.app"
HOST_PATH="${THEA_APP}/Contents/Helpers/${HOST_BINARY}"
MANIFEST_SOURCE="${SCRIPT_DIR}/Manifests/${HOST_NAME}.json"

# Browser native messaging host directories
CHROME_USER_DIR="${HOME}/Library/Application Support/Google/Chrome/NativeMessagingHosts"
CHROME_SYSTEM_DIR="/Library/Google/Chrome/NativeMessagingHosts"
CHROMIUM_USER_DIR="${HOME}/Library/Application Support/Chromium/NativeMessagingHosts"
BRAVE_USER_DIR="${HOME}/Library/Application Support/BraveSoftware/Brave-Browser/NativeMessagingHosts"
EDGE_USER_DIR="${HOME}/Library/Application Support/Microsoft Edge/NativeMessagingHosts"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Function to get the Chrome extension ID
get_extension_id() {
    local browser="$1"
    local extensions_dir=""

    case "$browser" in
        "chrome")
            extensions_dir="${HOME}/Library/Application Support/Google/Chrome/Default/Extensions"
            ;;
        "brave")
            extensions_dir="${HOME}/Library/Application Support/BraveSoftware/Brave-Browser/Default/Extensions"
            ;;
    esac

    # Look for Thea extension (you would replace this with actual extension ID after publishing)
    # For development, return placeholder
    echo "THEA_EXTENSION_ID_PLACEHOLDER"
}

# Function to install manifest for a browser
install_manifest() {
    local browser_name="$1"
    local target_dir="$2"
    local extension_id="$3"

    if [ ! -d "$target_dir" ]; then
        mkdir -p "$target_dir"
        print_status "Created directory: $target_dir"
    fi

    local manifest_dest="${target_dir}/${HOST_NAME}.json"

    # Create manifest with correct extension ID and path
    cat > "$manifest_dest" << EOF
{
  "name": "${HOST_NAME}",
  "description": "Thea Native Messaging Host - iCloud Passwords & Hide My Email integration for ${browser_name}",
  "path": "${HOST_PATH}",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://${extension_id}/"
  ]
}
EOF

    print_status "Installed manifest for ${browser_name}: ${manifest_dest}"
}

# Function to check if browser is installed
is_browser_installed() {
    local browser="$1"

    case "$browser" in
        "chrome")
            [ -d "/Applications/Google Chrome.app" ] && return 0
            ;;
        "brave")
            [ -d "/Applications/Brave Browser.app" ] && return 0
            ;;
        "chromium")
            [ -d "/Applications/Chromium.app" ] && return 0
            ;;
        "edge")
            [ -d "/Applications/Microsoft Edge.app" ] && return 0
            ;;
    esac

    return 1
}

# Main installation
main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║     Thea Native Messaging Host Installer                   ║"
    echo "║     iCloud Passwords & Hide My Email for Chrome/Brave      ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""

    # Check if Thea is installed
    if [ ! -d "$THEA_APP" ]; then
        print_error "Thea.app not found at ${THEA_APP}"
        print_warning "Please install Thea first, then run this installer again."
        exit 1
    fi

    # Check if host binary exists
    if [ ! -f "$HOST_PATH" ]; then
        print_warning "Native host binary not found at ${HOST_PATH}"
        print_warning "Building may be required..."
    fi

    # Install for each supported browser
    echo "Installing native messaging host..."
    echo ""

    # Google Chrome
    if is_browser_installed "chrome"; then
        CHROME_EXT_ID=$(get_extension_id "chrome")
        install_manifest "Google Chrome" "$CHROME_USER_DIR" "$CHROME_EXT_ID"
    else
        print_warning "Google Chrome not installed, skipping..."
    fi

    # Brave Browser
    if is_browser_installed "brave"; then
        BRAVE_EXT_ID=$(get_extension_id "brave")
        install_manifest "Brave Browser" "$BRAVE_USER_DIR" "$BRAVE_EXT_ID"
    else
        print_warning "Brave Browser not installed, skipping..."
    fi

    # Chromium
    if is_browser_installed "chromium"; then
        CHROMIUM_EXT_ID=$(get_extension_id "chromium")
        install_manifest "Chromium" "$CHROMIUM_USER_DIR" "$CHROMIUM_EXT_ID"
    else
        print_warning "Chromium not installed, skipping..."
    fi

    # Microsoft Edge
    if is_browser_installed "edge"; then
        EDGE_EXT_ID=$(get_extension_id "edge")
        install_manifest "Microsoft Edge" "$EDGE_USER_DIR" "$EDGE_EXT_ID"
    else
        print_warning "Microsoft Edge not installed, skipping..."
    fi

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    print_status "Installation complete!"
    echo ""
    echo "Next steps:"
    echo "  1. Open your browser's extension page"
    echo "  2. Install the Thea extension"
    echo "  3. Click 'Connect to iCloud' in the extension popup"
    echo "  4. Authenticate with Face ID or Touch ID"
    echo "  5. Enjoy Safari-like iCloud integration!"
    echo ""
    echo "Note: After installing the Thea extension, re-run this script"
    echo "      to update the manifest with the correct extension ID."
    echo ""
}

# Uninstall function
uninstall() {
    echo "Uninstalling Thea Native Messaging Host..."

    rm -f "${CHROME_USER_DIR}/${HOST_NAME}.json" 2>/dev/null && print_status "Removed Chrome manifest"
    rm -f "${BRAVE_USER_DIR}/${HOST_NAME}.json" 2>/dev/null && print_status "Removed Brave manifest"
    rm -f "${CHROMIUM_USER_DIR}/${HOST_NAME}.json" 2>/dev/null && print_status "Removed Chromium manifest"
    rm -f "${EDGE_USER_DIR}/${HOST_NAME}.json" 2>/dev/null && print_status "Removed Edge manifest"

    print_status "Uninstall complete!"
}

# Parse command line arguments
case "${1:-}" in
    --uninstall|-u)
        uninstall
        ;;
    --help|-h)
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --uninstall, -u    Remove native messaging host"
        echo "  --help, -h         Show this help message"
        echo ""
        ;;
    *)
        main
        ;;
esac
