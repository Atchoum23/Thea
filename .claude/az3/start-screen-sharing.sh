#!/usr/bin/env bash
# AZ3 start-screen-sharing.sh — Open Screen Sharing on MBAM2 pointed at MSM3U's Thunderbolt IP
# This instructs MBAM2 (via SSH + AppleScript) to open a Screen Sharing connection to MSM3U.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/config.env"

LOG_FILE="$AZ3_LOG_DIR/screen-sharing.log"
mkdir -p "$AZ3_LOG_DIR"

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

if [[ -z "$MSM3U_TB_IP" ]]; then
    log "ERROR: MSM3U_TB_IP is not set in config.env. Run setup.sh first."
    exit 1
fi

log "=== AZ3 Screen Sharing Setup ==="
log "Opening Screen Sharing on MBAM2 pointing at MSM3U ($MSM3U_TB_IP)..."

# Tell MBAM2 via SSH to open Screen Sharing to MSM3U's Thunderbolt IP
# The AppleScript uses the 'open location' command with vnc:// scheme
SSH_RESULT=$(ssh -o ConnectTimeout=10 -o BatchMode=yes "alexis@$MBAM2_SSH_HOST" \
    "osascript -e 'tell application \"Screen Sharing\" to open location \"vnc://$MSM3U_TB_IP\"'" 2>&1 || true)

log "AppleScript result: ${SSH_RESULT:-<no output>}"

# Wait for Screen Sharing to open
log "Waiting 5s for Screen Sharing to establish connection..."
sleep 5

# Verify Screen Sharing process is running on MBAM2
SS_PID=$(ssh -o ConnectTimeout=10 -o BatchMode=yes "alexis@$MBAM2_SSH_HOST" \
    "pgrep -x 'Screen Sharing' 2>/dev/null || echo ''" 2>/dev/null || echo "")

if [[ -n "$SS_PID" ]]; then
    log "Screen Sharing is running on MBAM2 (PID: $SS_PID). Connection to MSM3U established."
    log "MBAM2 is now displaying MSM3U's screen — captures via capture-msm3u.sh will show MSM3U UI."
else
    log "WARNING: Screen Sharing process not detected on MBAM2 after 5s."
    log "You may need to manually open Screen Sharing on MBAM2:"
    log "  open vnc://$MSM3U_TB_IP  (run this on MBAM2)"
    log "  OR: Finder → Go → Connect to Server → vnc://$MSM3U_TB_IP"
fi

log "=== Done ==="
