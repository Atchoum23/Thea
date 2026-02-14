#!/bin/bash
# Script to generate GPG key for GitHub commit signing

set -e

echo "🔐 GPG Key Setup for GitHub"
echo "==========================="

# Check if GPG is installed
if ! command -v gpg &> /dev/null; then
    echo "GPG not found. Installing via Homebrew..."
    brew install gnupg
fi

# Check for existing keys
EXISTING_KEY=$(gpg --list-secret-keys --keyid-format LONG 2>/dev/null | grep -E "^sec" | head -1 || true)

if [ -n "$EXISTING_KEY" ]; then
    echo "Found existing GPG key:"
    gpg --list-secret-keys --keyid-format LONG
    echo ""
    KEY_ID=$(gpg --list-secret-keys --keyid-format LONG | grep -E "^sec" | head -1 | awk '{print $2}' | cut -d'/' -f2)
else
    echo "Generating new GPG key..."
    echo ""

    # Generate key non-interactively
    cat > /tmp/gpg-gen-key.conf << EOF
%no-protection
Key-Type: eddsa
Key-Curve: ed25519
Key-Usage: sign
Subkey-Type: ecdh
Subkey-Curve: cv25519
Subkey-Usage: encrypt
Name-Real: Alexis
Name-Email: ft8dmqpkhs@privaterelay.appleid.com
Expire-Date: 0
%commit
EOF

    gpg --batch --gen-key /tmp/gpg-gen-key.conf
    rm /tmp/gpg-gen-key.conf

    KEY_ID=$(gpg --list-secret-keys --keyid-format LONG | grep -E "^sec" | head -1 | awk '{print $2}' | cut -d'/' -f2)
    echo "✅ GPG key generated with ID: $KEY_ID"
fi

echo ""
echo "=== GPG Public Key (copy this to GitHub) ==="
echo ""
gpg --armor --export "$KEY_ID"
echo ""
echo "=============================================="

# Configure git to use this key
echo ""
echo "Configuring git to use GPG key..."
git config --global user.signingkey "$KEY_ID"
git config --global commit.gpgsign true
git config --global gpg.program $(which gpg)

echo ""
echo "✅ Git configured to sign commits with GPG key: $KEY_ID"
echo ""
echo "Copy the public key above (including -----BEGIN PGP PUBLIC KEY BLOCK-----"
echo "and -----END PGP PUBLIC KEY BLOCK-----) and paste it into GitHub."
