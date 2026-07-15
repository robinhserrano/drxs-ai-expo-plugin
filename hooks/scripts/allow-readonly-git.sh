#!/bin/bash
# PreToolUse hook (rn-reviewer agent): restrict Bash to read-only git inspection.
# Allows only `git diff` and `git status`. Denies everything else (file writes,
# git checkout/apply, redirections, compound-command bypass).

if ! command -v jq &>/dev/null; then
  exit 0
fi

DENY_REASON="rn-reviewer is read-only: only 'git diff' and 'git status' are allowed."

deny() {
  local reason="$1"
  jq -n --arg reason "$reason" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Reject shell operators outright. A compound command (`;`, `&&`, `||`, `|`,
# redirections, command substitution) could smuggle a mutating command past a
# first-token check, so anything not a single bare git command is denied.
case "$COMMAND" in
  *";"* | *"&"* | *"|"* | *">"* | *"<"* | *'`'* | *'$('*)
    deny "$DENY_REASON"
    ;;
esac

# Allow only `git diff …` and `git status …` (with optional leading whitespace).
if echo "$COMMAND" | grep -Eq '^[[:space:]]*git[[:space:]]+(diff|status)([[:space:]]|$)'; then
  exit 0
fi

deny "$DENY_REASON"
