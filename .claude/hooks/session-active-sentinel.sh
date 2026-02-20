#!/bin/bash
# session-active-sentinel.sh — PreToolUse hook (no matcher = runs on every tool)
# Touches /tmp/claude-code-thea-active so that thea-sync and claude-session-sync
# know a Claude Code session is live and skip their destructive operations.
# TTL: 2 hours — if Claude crashes without Stop hook firing, sentinel expires naturally.
touch /tmp/claude-code-thea-active
exit 0
