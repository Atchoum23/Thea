#!/bin/bash
# =============================================================================
# THEA ULTIMATE AUTONOMOUS QA RUNNER v2.0
# MSM3U (Mac Studio M3 Ultra)
# Covers: iOS, macOS, watchOS, tvOS, Tizen, Web, CI/CD, Security, Compliance
# =============================================================================

set -euo pipefail

THEA_DIR="/Users/alexis/Documents/IT & Tech/MyApps/Thea"
LOG_DIR="$HOME/.claude/thea-qa"
MISSIONS_DIR="/tmp/thea-qa-missions"
SESSION="thea-qa"
MODEL="claude-opus-4-6"
MAX_TURNS=200

mkdir -p "$LOG_DIR"

echo "========================================"
echo "  THEA ULTIMATE QA RUNNER v2.0"
echo "  Machine: $(hostname -s)"
echo "  Started: $(date)"
echo "========================================"
echo ""

# Verify prerequisites
if ! command -v claude &>/dev/null; then
  echo "ERROR: claude CLI not found"
  exit 1
fi
if ! command -v tmux &>/dev/null; then
  echo "ERROR: tmux not found — brew install tmux"
  exit 1
fi
if [ ! -d "$MISSIONS_DIR" ]; then
  echo "ERROR: Missions not found at $MISSIONS_DIR"
  echo "Expected: mission-main.txt, mission-web.txt, mission-tizen.txt"
  exit 1
fi

echo "✓ Prerequisites verified"
echo ""

# Kill any existing session
tmux kill-session -t "$SESSION" 2>/dev/null && echo "✓ Cleared previous session" || true
sleep 1

# Create fresh tmux session with 5 windows
tmux new-session -d -s "$SESSION" -n "monitor" -x 250 -y 60
tmux new-window -t "$SESSION" -n "main"
tmux new-window -t "$SESSION" -n "web"
tmux new-window -t "$SESSION" -n "tizen"
tmux new-window -t "$SESSION" -n "ci-watch"
echo "✓ tmux session created: $SESSION (5 windows)"
echo ""

# ─────────────────────────────────────────────────────────────
# Window 0: Live Monitor
# ─────────────────────────────────────────────────────────────
tmux send-keys -t "$SESSION:monitor" \
  "echo '=== THEA QA LIVE MONITOR ===' && echo 'Logs: $LOG_DIR' && echo '' && sleep 3 && tail -f '$LOG_DIR'/*.log 2>/dev/null || echo 'Waiting for logs...'" Enter

# ─────────────────────────────────────────────────────────────
# Window 1: MAIN QA Agent (Apple platforms: iOS/macOS/watchOS/tvOS)
# Sequential: lint → Debug builds → Release builds → tests → security → CI
# ─────────────────────────────────────────────────────────────
echo "→ Launching MAIN QA agent (Apple platforms)..."
tmux send-keys -t "$SESSION:main" \
  "cd '$THEA_DIR' && echo '=== MAIN QA AGENT START ===' && claude --dangerously-skip-permissions --verbose --model $MODEL --max-turns $MAX_TURNS -p \"\$(cat '$MISSIONS_DIR/mission-main.txt')\" 2>&1 | tee '$LOG_DIR/main.log'; echo '=== MAIN AGENT EXIT: '\$?' ===' | tee -a '$LOG_DIR/main.log'" Enter

sleep 2

# ─────────────────────────────────────────────────────────────
# Window 2: Web App Agent (TheaWeb Swift server) — PARALLEL
# ─────────────────────────────────────────────────────────────
echo "→ Launching WEB APP agent (TheaWeb)..."
tmux send-keys -t "$SESSION:web" \
  "cd '$THEA_DIR' && echo '=== WEB AGENT START ===' && claude --dangerously-skip-permissions --verbose --model $MODEL --max-turns 80 -p \"\$(cat '$MISSIONS_DIR/mission-web.txt')\" 2>&1 | tee '$LOG_DIR/web.log'; echo '=== WEB AGENT EXIT: '\$?' ===' | tee -a '$LOG_DIR/web.log'" Enter

sleep 2

# ─────────────────────────────────────────────────────────────
# Window 3: Tizen App Agent — PARALLEL
# ─────────────────────────────────────────────────────────────
echo "→ Launching TIZEN agent..."
tmux send-keys -t "$SESSION:tizen" \
  "cd '$THEA_DIR' && echo '=== TIZEN AGENT START ===' && claude --dangerously-skip-permissions --verbose --model $MODEL --max-turns 80 -p \"\$(cat '$MISSIONS_DIR/mission-tizen.txt')\" 2>&1 | tee '$LOG_DIR/tizen.log'; echo '=== TIZEN AGENT EXIT: '\$?' ===' | tee -a '$LOG_DIR/tizen.log'" Enter

sleep 2

# ─────────────────────────────────────────────────────────────
# Window 4: CI Monitor (starts watching after 5 min)
# ─────────────────────────────────────────────────────────────
echo "→ Setting up CI monitor (activates in 5 min)..."
tmux send-keys -t "$SESSION:ci-watch" "bash -c '
echo \"=== CI MONITOR: waiting 5 min for builds to start ===\" &&
sleep 300 &&
cd \"$THEA_DIR\" &&
echo \"=== CI MONITOR ACTIVE ==\" &&
while true; do
  echo \"\" &&
  echo \"=== CI Status: \$(date) ===\"
  gh run list --limit 6 --json name,status,conclusion 2>/dev/null | \\
    python3 -c \"import sys,json; runs=json.load(sys.stdin); [print(f\x27  {r[\\\"name\\\"]}: {r[\\\"conclusion\\\"] or r[\\\"status\\\"]}\x27) for r in runs]\" 2>/dev/null || echo \"  (gh not available)\"
  echo \"---\"
  sleep 120
done
'" Enter

echo ""
echo "========================================"
echo "  ALL AGENTS LAUNCHED SUCCESSFULLY"
echo "========================================"
echo ""
echo "Session:   $SESSION"
echo "Logs:      $LOG_DIR/"
echo ""
echo "How to monitor:"
echo "  tmux attach -t $SESSION"
echo "  (then Ctrl+B, 0..4 to switch windows)"
echo ""
echo "Tail all logs:"
echo "  tail -f $LOG_DIR/*.log"
echo ""
echo "Check completion:"
echo "  ls /tmp/thea-qa/*.done 2>/dev/null"
echo ""
echo "Expected completion: 60-120 minutes"
echo "Time started: $(date)"
echo ""
