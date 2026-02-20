#!/usr/bin/env bash
# AZ3 capture-msm3u.sh — Fetch screenshot from MBAM2 HTTP capture agent
# Agent runs on MBAM2 port 18791 (started from Terminal session for screen recording permission)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.env"

TIMESTAMP=$(date +%s)
LOCAL_PNG="$MBAM2_SCREENCAPTURE_PATH"
LOG_FILE="$AZ3_LOG_DIR/capture-msm3u.log"
AGENT_URL="http://${MBAM2_TB_IP}:18791"

mkdir -p "$AZ3_LOG_DIR" /tmp/az3-frames

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

# Verify agent is reachable
if ! curl -sf --max-time 5 "$AGENT_URL/ping" >/dev/null 2>&1; then
    log "ERROR: MBAM2 capture agent not reachable at $AGENT_URL"
    log "Start it on MBAM2: python3 /tmp/az3_capture_agent.py &"
    exit 1
fi

log "Fetching screenshot from MBAM2 agent ($AGENT_URL)..."
if ! curl -sf --max-time 15 "$AGENT_URL/capture" -o "$LOCAL_PNG" 2>>"$LOG_FILE"; then
    log "ERROR: capture request to MBAM2 agent failed"
    exit 1
fi

FILE_SIZE=$(stat -f%z "$LOCAL_PNG" 2>/dev/null || stat -c%s "$LOCAL_PNG" 2>/dev/null)
if [[ "$FILE_SIZE" -lt 1024 ]]; then
    log "ERROR: PNG only ${FILE_SIZE} bytes — likely empty"
    exit 1
fi

cp "$LOCAL_PNG" "/tmp/az3-frames/frame_${TIMESTAMP}.png"
log "Capture OK: $LOCAL_PNG (${FILE_SIZE} bytes) — frame_${TIMESTAMP}.png saved"
exit 0
