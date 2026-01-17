#!/bin/bash
# Script to display your SSH public key for copying to GitHub

echo "=== Your SSH Public Key ==="
echo ""
if [ -f ~/.ssh/id_ed25519.pub ]; then
    cat ~/.ssh/id_ed25519.pub
    echo ""
    echo "=== Copy the line above and paste it into GitHub ==="
elif [ -f ~/.ssh/id_rsa.pub ]; then
    cat ~/.ssh/id_rsa.pub
    echo ""
    echo "=== Copy the line above and paste it into GitHub ==="
else
    echo "No SSH key found. Generating a new one..."
    ssh-keygen -t ed25519 -C "github-thea" -f ~/.ssh/id_ed25519 -N ""
    echo ""
    echo "=== Your new SSH Public Key ==="
    cat ~/.ssh/id_ed25519.pub
    echo ""
    echo "=== Copy the line above and paste it into GitHub ==="
fi
