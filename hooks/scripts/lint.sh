#!/bin/bash
set -uo pipefail

# Read the hook payload from stdin
input=$(cat)

# Check jq availability
if ! command -v jq &>/dev/null; then
  echo "lint hook: jq not found, skipping" >&2
  exit 0
fi

# Extract file path from the tool input
file_path=$(jq -r '.tool_input.file_path // empty' <<< "$input")

# Skip if no file path or not a TS/TSX/JS/JSX file
case "$file_path" in
  *.ts|*.tsx|*.js|*.jsx) ;;
  *) exit 0 ;;
esac

# Skip gracefully if the project has no ESLint config or eslint isn't installed
if ! command -v npx &>/dev/null; then
  exit 0
fi
if [ ! -f "package.json" ] || ! npx --no-install eslint --version &>/dev/null; then
  exit 0
fi

output=$(npx --no-install eslint --fix "$file_path" 2>&1) || {
  echo "$output" >&2
  exit 2
}
