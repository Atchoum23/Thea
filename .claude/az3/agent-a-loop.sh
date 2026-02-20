#!/usr/bin/env bash
# AZ3 agent-a-loop.sh — Agent A: runs on MSM3U, executes test steps and collects results
# Reads test steps from $AZ3_LOG_DIR/test-steps.txt (one step per line)
# Coordinates with Agent B on MBAM2 via shared log directory files
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/config.env"

STEPS_FILE="$AZ3_LOG_DIR/test-steps.txt"
CURRENT_STEP_FILE="$AZ3_LOG_DIR/current-step.txt"
CAPTURE_REQUEST_FILE="$AZ3_LOG_DIR/capture-request.txt"
CAPTURE_RESULT_FILE="$AZ3_LOG_DIR/capture-result.txt"
RESULTS_FILE="$AZ3_LOG_DIR/agent-a-results.txt"
LOG_FILE="$AZ3_LOG_DIR/agent-a.log"
FRAMES_DIR="/tmp/az3-frames"

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

mkdir -p "$AZ3_LOG_DIR" "$FRAMES_DIR"

log() { echo "[$(date '+%H:%M:%S')] [AgentA] $*" | tee -a "$LOG_FILE"; }

# Initialize results file
echo "=== AZ3 Agent A Results — $(date) ===" > "$RESULTS_FILE"

# Verify test steps file exists
if [[ ! -f "$STEPS_FILE" ]]; then
    log "WARNING: $STEPS_FILE not found. Creating a sample test-steps.txt."
    cat > "$STEPS_FILE" << 'STEPS'
# AZ3 Test Steps — one step per line
# Format: STEP_NAME | COMMAND (optional — if blank, just captures current state)
# Lines starting with # are comments and are skipped.
# Example steps:
launch-thea | open -a Thea
wait-for-main-window |
click-new-conversation |
type-hello-message |
verify-ai-response |
STEPS
    log "Sample test-steps.txt written. Edit $STEPS_FILE and re-run."
    exit 0
fi

log "=== AZ3 Agent A Starting ==="
log "Steps file: $STEPS_FILE"
log "Results: $RESULTS_FILE"

STEP_NUM=0
TOTAL_STEPS=$(grep -c '^[^#]' "$STEPS_FILE" 2>/dev/null || echo "0")
log "Total steps to execute: $TOTAL_STEPS"

# Clean up any stale signal files from a previous run
rm -f "$CAPTURE_REQUEST_FILE" "$CAPTURE_RESULT_FILE"

while IFS= read -r LINE; do
    # Skip blank lines and comments
    [[ -z "$LINE" || "$LINE" =~ ^[[:space:]]*# ]] && continue

    STEP_NUM=$((STEP_NUM + 1))
    STEP_NAME=$(echo "$LINE" | cut -d'|' -f1 | xargs)
    STEP_CMD=$(echo "$LINE" | cut -d'|' -f2- | xargs)

    log "--- Step $STEP_NUM/$TOTAL_STEPS: $STEP_NAME ---"

    # Write current step for Agent B context
    echo "$STEP_NAME" > "$CURRENT_STEP_FILE"

    # Execute the step command if one is provided
    if [[ -n "$STEP_CMD" ]]; then
        log "Executing: $STEP_CMD"
        if eval "$STEP_CMD" >> "$LOG_FILE" 2>&1; then
            log "Command succeeded."
        else
            EXIT_CODE=$?
            log "WARNING: Command exited with code $EXIT_CODE — continuing to capture."
        fi
    else
        log "(No command — capturing current state)"
    fi

    # Wait for UI to settle
    log "Waiting 2s for UI to settle..."
    sleep 2

    # Signal Agent B to capture a frame
    log "Notifying Agent B to capture frame..."
    echo "CAPTURE:$STEP_NAME:$(date +%s)" > "$CAPTURE_REQUEST_FILE"

    # Wait up to 30s for Agent B to respond with a result
    WAITED=0
    RESULT=""
    while [[ $WAITED -lt 30 ]]; do
        if [[ -f "$CAPTURE_RESULT_FILE" ]]; then
            RESULT=$(cat "$CAPTURE_RESULT_FILE")
            break
        fi
        sleep 1
        WAITED=$((WAITED + 1))
    done

    if [[ -z "$RESULT" ]]; then
        log "TIMEOUT: Agent B did not respond within 30s for step '$STEP_NAME'."
        RESULT="TIMEOUT: Agent B did not respond"
        SKIP_COUNT=$((SKIP_COUNT + 1))
        echo "SKIP | $STEP_NUM | $STEP_NAME | $RESULT" >> "$RESULTS_FILE"
    elif echo "$RESULT" | grep -qi "^PASS"; then
        log "PASS: $STEP_NAME — $RESULT"
        PASS_COUNT=$((PASS_COUNT + 1))
        echo "PASS | $STEP_NUM | $STEP_NAME | $RESULT" >> "$RESULTS_FILE"
    else
        log "FAIL: $STEP_NAME — $RESULT"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo "FAIL | $STEP_NUM | $STEP_NAME | $RESULT" >> "$RESULTS_FILE"
    fi

    # Clean up signal files for the next iteration
    rm -f "$CAPTURE_REQUEST_FILE" "$CAPTURE_RESULT_FILE"

done < "$STEPS_FILE"

# --- Summary ---
TOTAL_RAN=$((PASS_COUNT + FAIL_COUNT + SKIP_COUNT))
echo "" >> "$RESULTS_FILE"
echo "=== Summary ===" >> "$RESULTS_FILE"
echo "PASS:    $PASS_COUNT" >> "$RESULTS_FILE"
echo "FAIL:    $FAIL_COUNT" >> "$RESULTS_FILE"
echo "TIMEOUT: $SKIP_COUNT" >> "$RESULTS_FILE"
echo "TOTAL:   $TOTAL_RAN" >> "$RESULTS_FILE"

log "=== Agent A Complete ==="
log "PASS: $PASS_COUNT | FAIL: $FAIL_COUNT | TIMEOUT: $SKIP_COUNT | TOTAL: $TOTAL_RAN"
log "Full results: $RESULTS_FILE"
log "Captured frames: $FRAMES_DIR"

echo ""
cat "$RESULTS_FILE"

exit $FAIL_COUNT
