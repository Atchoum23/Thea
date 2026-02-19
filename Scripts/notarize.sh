#!/bin/bash
# notarize.sh — Submit a .app or .dmg to Apple notarytool and staple the result.
#
# Usage:
#   ./Scripts/notarize.sh /path/to/Thea.dmg
#   ./Scripts/notarize.sh /path/to/Thea.app
#
# Prerequisites:
#   1. Store notarytool credentials once:
#      xcrun notarytool store-credentials "notarytool-profile" \
#        --apple-id alexis@calevras.com \
#        --team-id 6B66PM4JLK
#      (Uses app-specific password from appleid.apple.com → Security → App-Specific Passwords)
#
#   2. Or set env vars for CI:
#      APPLE_ID, APPLE_APP_PASSWORD, APPLE_TEAM_ID
#

set -euo pipefail

ARTIFACT="${1:-}"
if [[ -z "$ARTIFACT" ]]; then
    echo "Usage: $0 <path-to-app-or-dmg>" >&2
    exit 1
fi

if [[ ! -e "$ARTIFACT" ]]; then
    echo "Error: artifact not found: $ARTIFACT" >&2
    exit 1
fi

TEAM_ID="${APPLE_TEAM_ID:-6B66PM4JLK}"

# If env vars are set (CI mode), use them directly
if [[ -n "${APPLE_ID:-}" && -n "${APPLE_APP_PASSWORD:-}" ]]; then
    echo "→ Submitting for notarization (CI mode)..."
    xcrun notarytool submit "$ARTIFACT" \
        --apple-id "$APPLE_ID" \
        --password "$APPLE_APP_PASSWORD" \
        --team-id "$TEAM_ID" \
        --wait
else
    # Local mode: use stored Keychain profile
    echo "→ Submitting for notarization (Keychain profile)..."
    xcrun notarytool submit "$ARTIFACT" \
        --keychain-profile "notarytool-profile" \
        --wait
fi

echo "→ Stapling notarization ticket..."
xcrun stapler staple "$ARTIFACT"

echo "→ Validating..."
xcrun stapler validate "$ARTIFACT"

echo "✅ Notarization complete: $ARTIFACT"
