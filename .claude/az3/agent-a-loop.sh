#!/usr/bin/env bash
# AZ3 agent-a-loop.sh — Self-contained: executes test steps on MSM3U, fetches frames from MBAM2 agent
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.env"

STEPS_FILE="$AZ3_LOG_DIR/test-steps.txt"
RESULTS_FILE="$AZ3_LOG_DIR/az3-results.txt"
LOG_FILE="$AZ3_LOG_DIR/agent-a.log"
FRAMES_DIR="/tmp/az3-frames"
AGENT_URL="http://${MBAM2_TB_IP}:18791"

PASS_COUNT=0; FAIL_COUNT=0; SKIP_COUNT=0
mkdir -p "$AZ3_LOG_DIR" "$FRAMES_DIR"

log() { echo "[$(date '+%H:%M:%S')] [AZ3] $*" | tee -a "$LOG_FILE"; }

echo "=== AZ3 Results — $(date) ===" > "$RESULTS_FILE"

# Verify MBAM2 capture agent is reachable
if ! curl -sf --max-time 5 "$AGENT_URL/ping" >/dev/null 2>&1; then
    log "ERROR: MBAM2 capture agent not reachable at $AGENT_URL"
    log "On MBAM2, run: python3 /tmp/az3_capture_agent.py &"
    exit 1
fi
log "MBAM2 capture agent: OK ($AGENT_URL)"

if [[ ! -f "$STEPS_FILE" ]]; then
    log "ERROR: $STEPS_FILE not found"; exit 1
fi

TOTAL_STEPS=$(grep -c '^[^#]' "$STEPS_FILE" 2>/dev/null || echo 0)
log "=== AZ3 Starting — $TOTAL_STEPS steps ==="
STEP_NUM=0

while IFS= read -r LINE; do
    [[ -z "$LINE" || "$LINE" =~ ^[[:space:]]*# ]] && continue
    STEP_NUM=$((STEP_NUM + 1))
    STEP_NAME=$(echo "$LINE" | cut -d'|' -f1 | xargs)
    STEP_CMD=$(echo "$LINE" | cut -d'|' -f2- | xargs)
    TIMESTAMP=$(date +%s)
    FRAME="$FRAMES_DIR/${STEP_NUM}_${STEP_NAME// /_}_${TIMESTAMP}.png"

    log "--- Step $STEP_NUM/$TOTAL_STEPS: $STEP_NAME ---"

    # Execute step command
    CMD_STATUS="OK"
    if [[ -n "$STEP_CMD" ]]; then
        log "CMD: $STEP_CMD"
        if ! eval "$STEP_CMD" >> "$LOG_FILE" 2>&1; then
            CMD_STATUS="CMD_FAILED"
            log "WARNING: command exited non-zero"
        fi
    fi

    # Wait for UI to settle
    WAIT_SECS=$(echo "$LINE" | grep -o 'wait=[0-9]*' | cut -d= -f2 || echo 2)
    sleep "${WAIT_SECS:-2}"

    # Fetch screenshot from MBAM2 agent
    if curl -sf --max-time 15 "$AGENT_URL/capture" -o "$FRAME" 2>>"$LOG_FILE"; then
        FILE_SIZE=$(stat -f%z "$FRAME" 2>/dev/null || echo 0)
        if [[ "$FILE_SIZE" -gt 1024 ]]; then
            log "CAPTURED: ${FILE_SIZE} bytes → $(basename "$FRAME")"
            PASS_COUNT=$((PASS_COUNT + 1))
            echo "PASS | $STEP_NUM | $STEP_NAME | ${FILE_SIZE}B captured | cmd=$CMD_STATUS" >> "$RESULTS_FILE"
        else
            log "FAIL: frame too small (${FILE_SIZE}B)"; FAIL_COUNT=$((FAIL_COUNT + 1))
            echo "FAIL | $STEP_NUM | $STEP_NAME | frame too small (${FILE_SIZE}B)" >> "$RESULTS_FILE"
        fi
    else
        log "FAIL: could not fetch frame from MBAM2"; FAIL_COUNT=$((FAIL_COUNT + 1))
        echo "FAIL | $STEP_NUM | $STEP_NAME | MBAM2 capture failed" >> "$RESULTS_FILE"
    fi

done < "$STEPS_FILE"

echo "" >> "$RESULTS_FILE"
echo "=== Summary ===" >> "$RESULTS_FILE"
echo "PASS: $PASS_COUNT" >> "$RESULTS_FILE"
echo "FAIL: $FAIL_COUNT" >> "$RESULTS_FILE"
echo "TOTAL: $((PASS_COUNT + FAIL_COUNT))" >> "$RESULTS_FILE"

log "=== AZ3 Complete: PASS=$PASS_COUNT FAIL=$FAIL_COUNT ==="
log "Frames: $FRAMES_DIR"; log "Results: $RESULTS_FILE"
cat "$RESULTS_FILE"
exit $FAIL_COUNT
