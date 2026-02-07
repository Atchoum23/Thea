#!/bin/bash
# setup-mac-sync.sh — One-time setup for Thea auto-sync on a Mac
# Run this on each Mac to set up: git pushsync alias, sync script, launchd agent, git hooks.
# After running, set up SSH key auth between your Macs:
#   ssh-copy-id alexis@OTHER_MAC.local
set -euo pipefail

THIS_MAC=$(hostname -s)
echo "Setting up Thea auto-sync on: $THIS_MAC"

# 1. Create ~/bin if needed
mkdir -p ~/bin

# 2. Copy sync script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cat > ~/bin/thea-sync.sh << 'SYNCEOF'
#!/bin/bash
# thea-sync.sh — Auto-pull, build Release, install to /Applications
set -euo pipefail

PROJECT_DIR="/Users/alexis/Documents/IT & Tech/MyApps/Thea"
LOG_FILE="/Users/alexis/Library/Logs/thea-sync.log"
LOCK_FILE="/tmp/thea-sync.lock"
SCHEME="Thea-macOS"
CONFIG="Release"

if [ -f "$LOCK_FILE" ]; then
    pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then exit 0; fi
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }

cd "$PROJECT_DIR"
git fetch origin main --quiet 2>> "$LOG_FILE"
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)
[ "$LOCAL" = "$REMOTE" ] && exit 0

log "New commits: ${LOCAL:0:8} → ${REMOTE:0:8}"

if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
    log "Stashing local changes"
    git stash push -m "thea-sync auto-stash $(date '+%Y%m%d-%H%M%S')" --quiet
fi

if ! git pull --ff-only origin main >> "$LOG_FILE" 2>&1; then
    log "ERROR: git pull failed"
    osascript -e 'display notification "Thea: git pull failed" with title "Thea Sync" sound name "Basso"' 2>/dev/null || true
    exit 1
fi

log "Pull OK → $(git rev-parse --short HEAD)"

command -v xcodegen &>/dev/null && { log "xcodegen..."; xcodegen generate --use-cache >> "$LOG_FILE" 2>&1 || true; }

log "Building $SCHEME ($CONFIG)..."
BUILD_LOG=$(mktemp)
if xcodebuild -project Thea.xcodeproj -scheme "$SCHEME" -destination "platform=macOS" \
    -configuration "$CONFIG" -derivedDataPath "$PROJECT_DIR/.build/DerivedData" \
    CODE_SIGNING_ALLOWED=NO build 2>&1 | tee "$BUILD_LOG" | tail -5 >> "$LOG_FILE" 2>&1; then

    log "Build OK"
    APP_PATH="$PROJECT_DIR/.build/DerivedData/Build/Products/$CONFIG"
    if [ -d "$APP_PATH/Thea.app" ]; then
        killall Thea 2>/dev/null || true; sleep 1
        rm -rf /Applications/Thea.app
        cp -R "$APP_PATH/Thea.app" /Applications/Thea.app
        log "Installed → /Applications/Thea.app"
        osascript -e 'display notification "Thea synced & installed" with title "Thea Sync" sound name "Glass"' 2>/dev/null || true
    else
        log "WARNING: .app not found at $APP_PATH"
    fi
else
    log "ERROR: Build failed"
    osascript -e 'display notification "Thea build failed" with title "Thea Sync" sound name "Basso"' 2>/dev/null || true
fi
rm -f "$BUILD_LOG"
SYNCEOF
chmod +x ~/bin/thea-sync.sh
echo "  ✓ Created ~/bin/thea-sync.sh"

# 3. Set up git pushsync alias (auto-detects which Mac to trigger)
git config --global alias.pushsync '!f() { git push "$@" && OTHER_MAC=""; THIS_MAC=$(hostname -s); if [ "$THIS_MAC" = "mbam2" ] || [ "$THIS_MAC" = "MBAM2" ]; then OTHER_MAC="MSM3U.local"; elif [ "$THIS_MAC" = "msm3u" ] || [ "$THIS_MAC" = "MSM3U" ]; then OTHER_MAC="MBAM2.local"; fi; if [ -n "$OTHER_MAC" ]; then echo "Triggering sync on $OTHER_MAC..."; ssh -o ConnectTimeout=5 -o BatchMode=yes "alexis@$OTHER_MAC" "/Users/alexis/bin/thea-sync.sh" </dev/null >/dev/null 2>&1 & echo "Build triggered (background)."; fi; }; f'
echo "  ✓ Configured git pushsync alias"

# 4. Create launchd polling agent (5-minute fallback)
cat > ~/Library/LaunchAgents/com.alexis.thea-sync.plist << 'PLISTEOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>com.alexis.thea-sync</string>
    <key>ProgramArguments</key>
    <array><string>/Users/alexis/bin/thea-sync.sh</string></array>
    <key>StartInterval</key><integer>300</integer>
    <key>RunAtLoad</key><true/>
    <key>StandardOutPath</key><string>/Users/alexis/Library/Logs/thea-sync-stdout.log</string>
    <key>StandardErrorPath</key><string>/Users/alexis/Library/Logs/thea-sync-stderr.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key><string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
        <key>HOME</key><string>/Users/alexis</string>
    </dict>
    <key>LowPriorityIO</key><true/>
    <key>ProcessType</key><string>Background</string>
</dict>
</plist>
PLISTEOF
launchctl unload ~/Library/LaunchAgents/com.alexis.thea-sync.plist 2>/dev/null || true
launchctl load ~/Library/LaunchAgents/com.alexis.thea-sync.plist
echo "  ✓ Installed launchd agent (polling every 5 min)"

# 5. Create post-merge git hook for XcodeGen
HOOK_FILE="$PROJECT_DIR/.git/hooks/post-merge"
cat > "$HOOK_FILE" << 'HOOKEOF'
#!/bin/bash
if command -v xcodegen &>/dev/null; then
    echo "Running xcodegen generate --use-cache..."
    xcodegen generate --use-cache 2>/dev/null || echo "WARNING: xcodegen failed"
fi
HOOKEOF
chmod +x "$HOOK_FILE"
echo "  ✓ Created post-merge git hook (xcodegen)"

# 6. Copy global claude.md from the project's reference copy
if [ -f "$PROJECT_DIR/.claude/claude-global-reference.md" ]; then
    cp "$PROJECT_DIR/.claude/claude-global-reference.md" ~/.claude/claude.md
    echo "  ✓ Updated ~/.claude/claude.md"
fi

echo ""
echo "Done! Remaining manual step:"
echo "  Set up SSH key auth to the other Mac:"
echo "    ssh-copy-id alexis@OTHER_MAC.local"
echo ""
echo "  To verify: ssh alexis@OTHER_MAC.local echo OK"
