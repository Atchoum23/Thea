#!/bin/bash
# Finish Setup Script for Thea
# This script completes the GitHub push and builds the app

set -e

echo "🚀 Thea Finish Setup Script"
echo "==========================="

THEA_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$THEA_DIR"

# Step 1: Start SSH agent and add key
echo ""
echo "📝 Step 1: Setting up SSH authentication..."
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Step 2: Test SSH connection to GitHub
echo ""
echo "🔐 Step 2: Testing GitHub SSH connection..."
ssh -T git@github.com 2>&1 || true

# Step 3: Push changes
echo ""
echo "📤 Step 3: Pushing changes to GitHub..."
git push origin main

if [ $? -eq 0 ]; then
    echo "✅ Changes pushed successfully!"
else
    echo "❌ Push failed. Please check your SSH key configuration."
    exit 1
fi

# Step 4: Check CI status
echo ""
echo "🔄 Step 4: CI Status"
echo "Please monitor GitHub Actions at:"
echo "https://github.com/Atchoum23/Thea/actions"

# Step 5: Build the app
echo ""
echo "🔨 Step 5: Building Thea.app..."
xcodebuild -project Thea.xcodeproj \
    -scheme Thea-macOS \
    -configuration Release \
    -destination 'platform=macOS' \
    -derivedDataPath build/DerivedData \
    build 2>&1 | tail -20

# Step 6: Install to /Applications
echo ""
echo "📦 Step 6: Installing to /Applications..."
APP_PATH="build/DerivedData/Build/Products/Release/Thea.app"
if [ -d "$APP_PATH" ]; then
    cp -R "$APP_PATH" /Applications/
    echo "✅ Thea.app installed to /Applications"
else
    echo "❌ Build failed - Thea.app not found"
    exit 1
fi

echo ""
echo "🎉 Setup Complete!"
echo "=================="
echo "✅ SSH key configured"
echo "✅ Changes pushed to GitHub"
echo "✅ Thea.app installed to /Applications"
echo ""
echo "Run 'open -a Thea' to launch the app!"
