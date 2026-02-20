#!/usr/bin/env bash
# AZ3 capture-msm3u.sh — Trigger a screencapture on MBAM2 and retrieve the PNG to MSM3U
# MBAM2 must be running Screen Sharing connected to MSM3U's display for this to capture
# the MSM3U screen content as rendered on MBAM2.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/config.env"

TIMESTAMP=$(date +%s)
REMOTE_PNG="/tmp/az3_capture_${TIMESTAMP}.png"
LOCAL_PNG="$MBAM2_SCREENCAPTURE_PATH"
LOG_FILE="$AZ3_LOG_DIR/capture-msm3u.log"

mkdir -p "$AZ3_LOG_DIR"
mkdir -p /tmp/az3-frames

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

log "Requesting screencapture on MBAM2 ($MBAM2_SSH_HOST)..."

# Step 1: Execute screencapture on MBAM2 (captures whatever is on MBAM2's screen,
# which should be the Screen Sharing window showing MSM3U)
if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "alexis@$MBAM2_SSH_HOST" \
    "screencapture -x '$REMOTE_PNG'" 2>>"$LOG_FILE"; then
    log "ERROR: screencapture on MBAM2 failed."
    exit 1
fi

# Step 2: SCP the PNG from MBAM2 back to MSM3U
if ! scp -q "alexis@$MBAM2_SSH_HOST:$REMOTE_PNG" "$LOCAL_PNG" 2>>"$LOG_FILE"; then
    log "ERROR: scp of $REMOTE_PNG from MBAM2 failed."
    exit 1
fi

# Step 3: Also save a timestamped copy in the frames directory
cp "$LOCAL_PNG" "/tmp/az3-frames/frame_${TIMESTAMP}.png"

# Step 4: Validate PNG (must exist and be > 1 KB)
if [[ ! -f "$LOCAL_PNG" ]]; then
    log "ERROR: PNG not found at $LOCAL_PNG after scp."
    exit 1
fi

FILE_SIZE=$(stat -f%z "$LOCAL_PNG" 2>/dev/null || stat -c%s "$LOCAL_PNG" 2>/dev/null)
if [[ "$FILE_SIZE" -lt 1024 ]]; then
    log "ERROR: PNG at $LOCAL_PNG is only ${FILE_SIZE} bytes — likely empty or corrupt."
    exit 1
fi

log "Capture OK: $LOCAL_PNG (${FILE_SIZE} bytes) — also saved as frame_${TIMESTAMP}.png"

# Clean up remote temp file
ssh -o ConnectTimeout=5 -o BatchMode=yes "alexis@$MBAM2_SSH_HOST" \
    "rm -f '$REMOTE_PNG'" 2>/dev/null || true

exit 0
