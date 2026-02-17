#!/bin/bash
# =============================================================================
# THEA ULTIMATE AUTONOMOUS QA RUNNER v6.0
# MSM3U (Mac Studio M3 Ultra, 256GB RAM)
#
# Coverage:
#   Apple platforms: macOS, iOS, watchOS, tvOS (Debug + Release, CLI + GUI-eq.)
#   Web: TheaWeb (Vapor 4)
#   Tizen: thea-tizen (TypeScript/React) + TV/TheaTizen (legacy)
#   G1: Live Screen Monitoring + Interactive Voice Guidance
#   G2: Automatic Foreground App Pairing
#   H Phase: Comprehensive Deep Audit
#   Implementation: Zero stubs/TODOs in production code
#   UX/UI: Liquid Glass, accessibility, Cmd+K, artifacts panel
#   CI/CD: All 6 GitHub Actions workflows → green
#   Research: Latest 2026 APIs, Swift 6, SwiftUI 6, HealthKit, MLX
#   Sanitizers: ASan, TSan, Clang analyzer
#   Privacy/Compliance: April 2026, Privacy Manifest, AssistantSchema
#   AI Innovation: Extended thinking, RAG, ReAct, multimodal, MLX updates
#   Architecture: SOLID, file splitting, concurrency audit, docs
#   Gap Analysis: Systematic gap discovery, all addenda phases, opportunities
#   Dynamic Intelligence: Replace hardcoded values with system-aware decisions
#   Pre-G Phases: All priorities 1-4, QA phases 0-11.5 verified
#   Performance: Launch time, memory, energy, offline resilience, localization
#   GUI Builds: Xcode GUI builds triggered after CLI builds clean
#
# INVIOLABLE: Never remove. Only add, fix, and improve.
# NOTIFICATIONS: ntfy topic "thea-runner" — progress on every agent start/stop
# =============================================================================

set -euo pipefail

THEA_DIR="/Users/alexis/Documents/IT & Tech/MyApps/Thea"
LOG_DIR="$HOME/.claude/thea-qa"
SESSION="thea-qa"
MODEL="claude-opus-4-6"
C="$THEA_DIR/.claude"
NTFY_TOPIC="thea-runner"

mkdir -p "$LOG_DIR"

# ntfy notification helper
notify() {
  local title="$1"
  local body="${2:-}"
  ntfy pub --title "$title" "$NTFY_TOPIC" "$body" 2>/dev/null || true
}

echo "════════════════════════════════════════════════════════"
echo "  THEA ULTIMATE QA RUNNER v6.0"
echo "  Machine: $(hostname -s) | RAM: 256GB M3 Ultra"
echo "  Started: $(date)"
echo "════════════════════════════════════════════════════════"

notify "🚀 Thea QA Runner v6.0 starting on $(hostname -s)" "$(date)"

# Verify prerequisites
command -v claude &>/dev/null || { echo "ERROR: claude CLI not found"; exit 1; }
command -v tmux &>/dev/null  || { echo "ERROR: tmux not found"; exit 1; }
command -v ntfy &>/dev/null  || echo "⚠  ntfy not found — install with: brew install ntfy"
[ -f "$C/mission-main.txt" ] || { echo "ERROR: mission files not found in $C"; exit 1; }

echo "✓ Prerequisites verified"

# Kill any existing session
tmux kill-session -t "$SESSION" 2>/dev/null && echo "✓ Cleared previous session" || true
sleep 1

# Create 21-window tmux session (0-20)
tmux new-session   -d -s "$SESSION" -n "monitor"          -x 250 -y 60
tmux new-window    -t "$SESSION" -n "main"
tmux new-window    -t "$SESSION" -n "web"
tmux new-window    -t "$SESSION" -n "tizen"
tmux new-window    -t "$SESSION" -n "ci-watch"
tmux new-window    -t "$SESSION" -n "release-parallel"
tmux new-window    -t "$SESSION" -n "implementation"
tmux new-window    -t "$SESSION" -n "uxui"
tmux new-window    -t "$SESSION" -n "ci-fix"
tmux new-window    -t "$SESSION" -n "tizen2"
tmux new-window    -t "$SESSION" -n "compliance"
tmux new-window    -t "$SESSION" -n "g1-g2-h"
tmux new-window    -t "$SESSION" -n "gui-sanitize"
tmux new-window    -t "$SESSION" -n "research"
tmux new-window    -t "$SESSION" -n "ai-innovation"
tmux new-window    -t "$SESSION" -n "architecture"
tmux new-window    -t "$SESSION" -n "gap-analysis"
tmux new-window    -t "$SESSION" -n "dynamic-intel"
tmux new-window    -t "$SESSION" -n "pregphases"
tmux new-window    -t "$SESSION" -n "performance"
tmux new-window    -t "$SESSION" -n "gui-builds"

echo "✓ 21-window tmux session: $SESSION"

# Helper: launch agent in window with ntfy notifications
launch() {
  local win="$1" name="$2" turns="$3" mission="$4" brief="$5"
  echo "→ Launching $name (window $win)..."
  notify "▶ $name started" "Window $win | Mission: $mission"
  tmux send-keys -t "${SESSION}:${win}" \
    "unset CLAUDECODE && cd '$THEA_DIR' && echo '=== $name START ===' && echo '$brief Read .claude/${mission} carefully and execute it step by step, autonomously and completely. NEVER remove existing functionality. Do not stop until all success criteria are met. Commit after every fix.' | claude --dangerously-skip-permissions -p - --model $MODEL --max-turns $turns --verbose --output-format stream-json 2>&1 | tee '$LOG_DIR/${mission%.txt}.log'; EXIT_CODE=\$?; echo '=== $name EXIT: '\$EXIT_CODE' ===' | tee -a '$LOG_DIR/${mission%.txt}.log'; ntfy pub --title \"$([ \$EXIT_CODE -eq 0 ] && echo '✅' || echo '⚠️') $name done\" $NTFY_TOPIC \"Exit \$EXIT_CODE — check window $win\" 2>/dev/null || true" Enter
  sleep 1
}

# ── Window 0: Monitor ────────────────────────────────────────
tmux send-keys -t "${SESSION}:0" \
  "echo '=== THEA QA LIVE MONITOR ===' && tail -f '$LOG_DIR'/*.log 2>/dev/null || echo 'Waiting for logs...'" Enter

# ── Window 1: Main Apple Platforms (16 builds) ───────────────
launch 1 "MAIN-QA" 200 "mission-main.txt" \
  "Execute all phases: SwiftLint, all 16 builds (4 platforms × Debug+Release × CLI), swift tests, security audit, April 2026 compliance."

# ── Window 2: Web App ────────────────────────────────────────
launch 2 "WEB" 80 "mission-web.txt" \
  "Fix and verify TheaWeb Vapor server: 0 errors, 0 warnings, all routes, swift test passes, SwiftLint clean."

# ── Window 3: Tizen (initial) ────────────────────────────────
launch 3 "TIZEN" 80 "mission-tizen.txt" \
  "Fix thea-tizen (TypeScript/React/Vite) and TV/TheaTizen: 0 TS errors, 0 ESLint errors, build passes."

# ── Window 4: CI Watch ───────────────────────────────────────
tmux send-keys -t "${SESSION}:4" "bash -c '
sleep 300 && cd \"$THEA_DIR\" &&
echo \"=== CI MONITOR ACTIVE ==\" &&
while true; do
  echo \"=== CI: \$(date) ===\"
  gh run list --limit 6 --json name,status,conclusion 2>/dev/null | \
    python3 -c \"import sys,json; runs=json.load(sys.stdin); [print(f'\''  {r[\\\"name\\\"]}: {r[\\\"conclusion\\\"] or r[\\\"status\\\"]}'\'' ) for r in runs]\" 2>/dev/null || echo \"  (gh unavailable)\"
  sleep 120
done
'" Enter
echo "→ CI monitor active in window 4"

# ── Window 5: Parallel Release (iOS + watchOS + tvOS) ────────
launch 5 "RELEASE-PARALLEL" 120 "mission-parallel-release.txt" \
  "Build iOS, watchOS, tvOS Release (arm64-only, ENABLE_DEBUG_DYLIB=NO). Fix every error. 0 warnings."

# ── Window 6: Implementation Completeness ────────────────────
launch 6 "IMPLEMENTATION" 200 "mission-implementation.txt" \
  "Find every stub, TODO, placeholder in production (included) Swift files and FULLY implement them. Wire everything in. Never remove."

# ── Window 7: UX/UI Design ───────────────────────────────────
launch 7 "UXUI" 200 "mission-uxui.txt" \
  "Apply Liquid Glass design, semantic color tokens, accessibility labels, animations across all 4 Apple platforms. Implement UI_UX_IMPLEMENTATION_PLAN enhancements."

# ── Window 8: CI/CD Fix ──────────────────────────────────────
launch 8 "CI-FIX" 150 "mission-ci-fix.txt" \
  "Fix ALL 6 GitHub Actions workflows until every one shows success. Push with git pushsync. Monitor until green."

# ── Window 9: Tizen Continuation ─────────────────────────────
launch 9 "TIZEN2" 120 "mission-tizen2.txt" \
  "Continue Tizen work: real API integration, TV remote navigation, all screens implemented, 0 TypeScript errors, 0 ESLint errors."

# ── Window 10: Privacy & April 2026 Compliance ───────────────
launch 10 "COMPLIANCE" 100 "mission-privacy-compliance.txt" \
  "Privacy Manifest for all 4 targets, AssistantSchema App Intents, SwiftData assessment. All April 2026 deadlines met."

# ── Window 11: G1 + G2 + H Phase ─────────────────────────────
launch 11 "G1-G2-H" 200 "mission-g1-g2.txt" \
  "Verify G1 (Live Screen Monitoring + Voice Guidance): all 7 success criteria. Verify G2 (App Pairing): all 15 criteria. Execute H Phase Comprehensive Deep Audit."

# ── Window 12: GUI Builds + Sanitizers ───────────────────────
launch 12 "GUI-SANITIZE" 150 "mission-gui-builds.txt" \
  "GUI-equivalent builds with CLANG_ANALYZER enabled. ASan and TSan builds. Leak checks. swift test --enable-code-coverage. SwiftLint --strict."

# ── Window 13: Research + Modernize ──────────────────────────
launch 13 "RESEARCH" 150 "mission-research-modernize.txt" \
  "Web-research latest 2026 Swift/SwiftUI/HealthKit/MLX/Tizen APIs. Apply modernizations. Implement UI_UX_IMPLEMENTATION_PLAN high-priority items. Verify all inter-component pipelines."

echo ""
echo "════════════════════════════════════════════════════════"
echo "  ALL 13 AGENTS LAUNCHED (14 windows)"
echo "════════════════════════════════════════════════════════"
echo ""
echo " 0: monitor           — live log tail"
echo " 1: main              — 16 builds (4 platforms × Debug+Release)"
echo " 2: web               — TheaWeb Vapor"
echo " 3: tizen             — Tizen TV initial"
echo " 4: ci-watch          — CI status monitor"
echo " 5: release-parallel  — iOS/watchOS/tvOS Release"
echo " 6: implementation    — zero stubs/TODOs in production"
echo " 7: uxui              — Liquid Glass, accessibility, UX plan"
echo " 8: ci-fix            — all 6 workflows → green"
echo " 9: tizen2            — Tizen API integration + remote nav"
echo "10: compliance        — Privacy Manifest, App Intents"
echo "11: g1-g2-h           — G1 screen guidance, G2 app pairing, H audit"
echo "12: gui-sanitize      — Clang analyzer, ASan, TSan, coverage"
echo "13: research          — 2026 APIs, modernization, UX plan impl."
echo ""
echo "Session:  $SESSION"
echo "Logs:     $LOG_DIR/"
echo "Monitor:  tmux attach -t $SESSION  (Ctrl+B, 0-13)"
echo "Started:  $(date)"
echo ""
