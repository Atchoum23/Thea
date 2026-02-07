#!/bin/bash
# enforce-pushsync.sh — Claude Code PreToolUse hook
# Blocks plain "git push" and instructs Claude to use "git pushsync" instead.
# This ensures every push also triggers a sync build on the other Mac.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Match "git push" but NOT "git pushsync"
if echo "$COMMAND" | grep -qE '\bgit\s+push\b' && ! echo "$COMMAND" | grep -qE '\bgit\s+pushsync\b'; then
  cat >&2 <<'EOF'
BLOCKED: Use "git pushsync" instead of "git push".

git pushsync pushes to origin AND triggers a sync build on the other Mac.
Replace "git push" with "git pushsync" in your command, keeping all other arguments the same.
EOF
  exit 2  # Block the action
fi

exit 0
