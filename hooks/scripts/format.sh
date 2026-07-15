#!/bin/bash
set -uo pipefail

# Read the hook payload from stdin
input=$(cat)

# Check jq availability
if ! command -v jq &>/dev/null; then
  echo "format hook: jq not found, skipping" >&2
  exit 0
fi

# Extract file path from the tool input
file_path=$(jq -r '.tool_input.file_path // empty' <<< "$input")

# Skip if no file path or not a TS/TSX/JS/JSX/JSON file
case "$file_path" in
  *.ts|*.tsx|*.js|*.jsx|*.json) ;;
  *) exit 0 ;;
esac

if ! command -v npx &>/dev/null; then
  exit 0
fi

# Run prettier on the single file (auto-fix, always exit 0 — non-blocking)
npx --no-install prettier --write "$file_path" &>/dev/null || true
