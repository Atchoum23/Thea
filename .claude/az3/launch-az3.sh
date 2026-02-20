#!/usr/bin/env bash
# AZ3 launch-az3.sh — Orchestrates the full cross-Mac visual regression test run
# - Verifies SSH to MBAM2
# - Creates log directories on both machines
# - SCPs agent-b-loop.sh to MBAM2 and launches it in the background
# - Runs agent-a-loop.sh locally on MSM3U
# - On completion, stops Agent B and collects all frames
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/config.env"

LOG_FILE="$AZ3_LOG_DIR/launch.log"
FRAMES_DIR="/tmp/az3-frames"
STOP_FILE="$AZ3_LOG_DIR/az3-stop.txt"

mkdir -p "$AZ3_LOG_DIR" "$FRAMES_DIR"

log() { echo "[$(date '+%H:%M:%S')] [Launch] $*" | tee -a "$LOG_FILE"; }

log "=== AZ3 Cross-Mac Visual Test Launch ==="
log "MSM3U_TB_IP : ${MSM3U_TB_IP:-<not set>}"
log "MBAM2_TB_IP : ${MBAM2_TB_IP:-<not set>}"
log "MBAM2 SSH   : alexis@$MBAM2_SSH_HOST"

# --- Step 1: Verify SSH connectivity to MBAM2 ---
log "[1/6] Verifying SSH connectivity to MBAM2..."
if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "alexis@$MBAM2_SSH_HOST" "echo OK" 2>>"$LOG_FILE" | grep -q "OK"; then
    log "ERROR: Cannot reach MBAM2 via SSH ($MBAM2_SSH_HOST). Aborting."
    log "Ensure Remote Login is enabled on MBAM2 and SSH keys are configured."
    exit 1
fi
log "SSH to MBAM2: OK"

# --- Step 2: Create log directories on both machines ---
log "[2/6] Creating log directories on MSM3U and MBAM2..."
mkdir -p "$AZ3_LOG_DIR" "$FRAMES_DIR"
ssh -o ConnectTimeout=10 -o BatchMode=yes "alexis@$MBAM2_SSH_HOST" \
    "mkdir -p '$AZ3_LOG_DIR' /tmp/az3-frames-local" 2>>"$LOG_FILE"
log "Directories created."

# --- Step 3: Remove any stale stop signal from a previous run ---
rm -f "$STOP_FILE"
ssh -o ConnectTimeout=10 -o BatchMode=yes "alexis@$MBAM2_SSH_HOST" \
    "rm -f '$STOP_FILE'" 2>>"$LOG_FILE" || true

# --- Step 4: SCP agent-b-loop.sh and config.env to MBAM2 ---
log "[3/6] Deploying agent-b-loop.sh and config.env to MBAM2..."
scp -q "$SCRIPT_DIR/agent-b-loop.sh" "alexis@$MBAM2_SSH_HOST:/tmp/agent-b-loop.sh" 2>>"$LOG_FILE"
scp -q "$SCRIPT_DIR/config.env" "alexis@$MBAM2_SSH_HOST:/tmp/az3-config.env" 2>>"$LOG_FILE"
ssh -o ConnectTimeout=10 -o BatchMode=yes "alexis@$MBAM2_SSH_HOST" \
    "chmod +x /tmp/agent-b-loop.sh && cp /tmp/az3-config.env \$(dirname /tmp/agent-b-loop.sh)/config.env 2>/dev/null || true" 2>>"$LOG_FILE"
log "Deployment complete."

# --- Step 5: Launch Agent B on MBAM2 in background ---
log "[4/6] Launching Agent B on MBAM2..."
# Source the config so Agent B picks up AZ3_LOG_DIR and MSM3U_TB_IP
ssh -o ConnectTimeout=10 -o BatchMode=yes "alexis@$MBAM2_SSH_HOST" \
    "nohup bash -c 'source /tmp/az3-config.env && bash /tmp/agent-b-loop.sh' > /tmp/az3-agent-b.log 2>&1 &" 2>>"$LOG_FILE"
sleep 2
# Verify Agent B started
AGENT_B_PID=$(ssh -o ConnectTimeout=10 -o BatchMode=yes "alexis@$MBAM2_SSH_HOST" \
    "pgrep -f 'agent-b-loop.sh' | head -1" 2>/dev/null || echo "")
if [[ -n "$AGENT_B_PID" ]]; then
    log "Agent B running on MBAM2 (PID: $AGENT_B_PID)."
else
    log "WARNING: Could not confirm Agent B PID — it may have started and immediately exited."
    log "Check MBAM2: cat /tmp/az3-agent-b.log"
fi

# --- Step 6: Run Agent A locally on MSM3U ---
log "[5/6] Starting Agent A on MSM3U..."
log "Running: $SCRIPT_DIR/agent-a-loop.sh"
echo ""
AGENT_A_EXIT=0
bash "$SCRIPT_DIR/agent-a-loop.sh" || AGENT_A_EXIT=$?

# --- Cleanup: Stop Agent B ---
log "[6/6] Stopping Agent B on MBAM2..."
# Write stop signal to shared log dir; Agent B polls for this file
touch "$STOP_FILE"
# Also write it on MBAM2 directly in case log dir is local-only
ssh -o ConnectTimeout=10 -o BatchMode=yes "alexis@$MBAM2_SSH_HOST" \
    "touch '$STOP_FILE'" 2>>"$LOG_FILE" || true
sleep 2

# --- Collect frames from MBAM2 ---
log "Collecting captured frames from MBAM2..."
REMOTE_FRAMES=$(ssh -o ConnectTimeout=10 -o BatchMode=yes "alexis@$MBAM2_SSH_HOST" \
    "ls /tmp/az3-frames-local/*.png 2>/dev/null | wc -l | xargs" 2>/dev/null || echo "0")
if [[ "$REMOTE_FRAMES" -gt 0 ]]; then
    scp -q "alexis@$MBAM2_SSH_HOST:/tmp/az3-frames-local/*.png" "$FRAMES_DIR/" 2>>"$LOG_FILE" || true
    log "Collected $REMOTE_FRAMES frame(s) from MBAM2 into $FRAMES_DIR."
else
    log "No frames found on MBAM2 (frames sent via Thunderbolt Bridge are already in $FRAMES_DIR)."
fi

LOCAL_FRAMES=$(ls "$FRAMES_DIR"/*.png 2>/dev/null | wc -l | xargs)
echo ""
log "=== AZ3 Run Complete ==="
log "Total frames in $FRAMES_DIR : $LOCAL_FRAMES"
log "Results: $AZ3_LOG_DIR/agent-a-results.txt"
log "Agent A exit code: $AGENT_A_EXIT"

echo ""
echo "Frames are in: $FRAMES_DIR"
echo "Open them for manual visual review:"
echo "  open $FRAMES_DIR"

exit $AGENT_A_EXIT
