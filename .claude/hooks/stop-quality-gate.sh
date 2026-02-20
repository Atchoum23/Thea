#!/bin/bash
# stop-quality-gate.sh — Claude Code Stop hook
# Fires when Claude finishes a response. Blocks session from stopping if
# quality gates are not met. Uses exit code 2 + stderr injection.
#
# Gates:
#   1. Uncompleted checklist items in any claude-progress.txt
#   2. Uncommitted tracked Swift/markdown file changes
#   3. Uncompleted [ ] items in the v3 plan (for autonomous stream sessions)

PROJ="${CLAUDE_PROJECT_DIR:-/Users/alexis/Documents/IT & Tech/MyApps/Thea}"
cd "$PROJ" 2>/dev/null || exit 0

BLOCKED=0
REASONS=""

# ── Gate 1: claude-progress.txt uncompleted items ──────────────────────────
PROGRESS_FILE="$PROJ/claude-progress.txt"
if [ -f "$PROGRESS_FILE" ]; then
  UNCOMPLETED=$(grep -c "^- \[ \]" "$PROGRESS_FILE" 2>/dev/null || echo 0)
  if [ "$UNCOMPLETED" -gt 0 ]; then
    BLOCKED=1
    REASONS="${REASONS}• claude-progress.txt has ${UNCOMPLETED} uncompleted [ ] item(s). Mark them ✓ or document why blocked.\n"
  fi
fi

# ── Gate 2: Uncommitted tracked Swift file changes ─────────────────────────
DIRTY_SWIFT=$(git diff --name-only HEAD 2>/dev/null | grep -cE "\.swift$" || echo 0)
if [ "$DIRTY_SWIFT" -gt 0 ]; then
  FILES=$(git diff --name-only HEAD 2>/dev/null | grep -E "\.swift$" | head -5 | tr '\n' ' ')
  BLOCKED=1
  REASONS="${REASONS}• ${DIRTY_SWIFT} uncommitted Swift file(s): ${FILES}— Run: git add <files> && git commit -m 'Auto-save: [description]'\n"
fi

# ── Gate 3: PersonalParameters consultation report (reminder, not block) ───
# After every autonomous session, note which parameter values were used.
# This seeds SelfTuningEngine when PersonalParameters.swift is built.
CONSULT_LOG="$PROJ/.claude/parameter-consultation-log.txt"
if [ ! -f "$CONSULT_LOG" ] && [ -n "$CLAUDECODE" ]; then
  # Only remind once per project (file created on first session)
  touch "$CONSULT_LOG"
fi

# ── Output ─────────────────────────────────────────────────────────────────
if [ "$BLOCKED" -eq 1 ]; then
  printf "QUALITY GATE FAILED — do not stop yet:\n%b\nResolve all issues above, then you may finish.\n" "$REASONS" >&2
  exit 2
fi

exit 0
