#!/usr/bin/env bash
# AZ3 agent-b-loop.sh — Agent B: runs on MBAM2, watches for capture requests and screenshots MSM3U
# This script is SCP'd to MBAM2 and launched via SSH by launch-az3.sh.
# It watches $AZ3_LOG_DIR/capture-request.txt and responds with screencaptures.
# Stops when $AZ3_LOG_DIR/az3-stop.txt appears.
set -uo pipefail

# Config (these values are injected by launch-az3.sh before SCP, or read from local config.env)
# If launched standalone, source the local config.env if it exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/config.env" ]]; then
    # shellcheck disable=SC1090
    source "$SCRIPT_DIR/config.env"
fi

# Defaults if not set by config.env
AZ3_LOG_DIR="${AZ3_LOG_DIR:-/tmp/az3-logs}"
MSM3U_TB_IP="${MSM3U_TB_IP:-}"

CAPTURE_REQUEST_FILE="$AZ3_LOG_DIR/capture-request.txt"
CAPTURE_RESULT_FILE="$AZ3_LOG_DIR/capture-result.txt"
STOP_FILE="$AZ3_LOG_DIR/az3-stop.txt"
LOG_FILE="$AZ3_LOG_DIR/agent-b.log"
FRAMES_LOCAL_DIR="/tmp/az3-frames-local"
FRAMES_REMOTE_DIR="/tmp/az3-frames"

mkdir -p "$AZ3_LOG_DIR" "$FRAMES_LOCAL_DIR"

log() { echo "[$(date '+%H:%M:%S')] [AgentB] $*" | tee -a "$LOG_FILE"; }

log "=== AZ3 Agent B Starting on MBAM2 ==="
log "Watching: $CAPTURE_REQUEST_FILE"
log "Stop signal: $STOP_FILE"
log "MSM3U Thunderbolt IP: ${MSM3U_TB_IP:-<not set>}"

CAPTURE_COUNT=0

# Main watch loop — poll every 1s (fswatch not guaranteed on both Macs)
while true; do
    # Check stop signal first
    if [[ -f "$STOP_FILE" ]]; then
        log "Stop signal received. Agent B exiting cleanly."
        break
    fi

    # Check for a capture request
    if [[ -f "$CAPTURE_REQUEST_FILE" ]]; then
        REQUEST=$(cat "$CAPTURE_REQUEST_FILE" 2>/dev/null || echo "UNKNOWN")
        STEP_NAME=$(echo "$REQUEST" | cut -d':' -f2 | xargs)
        TIMESTAMP=$(date +%s)
        PNG_PATH="$FRAMES_LOCAL_DIR/az3_frame_${TIMESTAMP}_${STEP_NAME// /_}.png"

        log "Capture request received: $REQUEST"

        # Remove request file immediately to prevent double-processing
        rm -f "$CAPTURE_REQUEST_FILE"

        # Take a screenshot of whatever is on MBAM2's screen
        # (Should be the Screen Sharing window showing MSM3U's display)
        CAPTURE_OK=false
        if screencapture -x "$PNG_PATH" 2>>"$LOG_FILE"; then
            FILE_SIZE=$(stat -f%z "$PNG_PATH" 2>/dev/null || stat -c%s "$PNG_PATH" 2>/dev/null || echo "0")
            if [[ "$FILE_SIZE" -gt 1024 ]]; then
                log "Captured: $PNG_PATH (${FILE_SIZE} bytes)"
                CAPTURE_OK=true
                CAPTURE_COUNT=$((CAPTURE_COUNT + 1))
            else
                log "WARNING: Captured PNG is too small (${FILE_SIZE} bytes) — may be empty."
            fi
        else
            log "ERROR: screencapture failed."
        fi

        # SCP frame back to MSM3U (if TB IP is known)
        if $CAPTURE_OK && [[ -n "$MSM3U_TB_IP" ]]; then
            log "Sending frame to MSM3U ($MSM3U_TB_IP)..."
            if scp -q -o ConnectTimeout=10 -o BatchMode=yes \
                "$PNG_PATH" "alexis@$MSM3U_TB_IP:$FRAMES_REMOTE_DIR/" 2>>"$LOG_FILE"; then
                log "Frame delivered to MSM3U."
            else
                log "WARNING: scp to MSM3U failed — frame kept locally at $PNG_PATH"
            fi
        elif $CAPTURE_OK; then
            log "MSM3U_TB_IP not set — frame kept locally only: $PNG_PATH"
        fi

        # Write result back for Agent A
        if $CAPTURE_OK; then
            echo "PASS: frame_${TIMESTAMP}_${STEP_NAME// /_}.png captured (${FILE_SIZE:-?} bytes)" > "$CAPTURE_RESULT_FILE"
        else
            echo "FAIL: screencapture did not produce a valid PNG" > "$CAPTURE_RESULT_FILE"
        fi

        log "Result written. Total captures: $CAPTURE_COUNT"
    fi

    sleep 1
done

log "=== Agent B Stopped. Total frames captured: $CAPTURE_COUNT ==="
log "Local frames directory: $FRAMES_LOCAL_DIR"
