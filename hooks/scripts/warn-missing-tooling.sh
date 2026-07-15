#!/bin/bash
# SessionStart hook: warn when Node tooling (or EAS CLI, if the project uses it) is missing.
# Output is injected into Claude's context (not displayed in the terminal).
# Non-blocking — always exits 0.

if ! command -v node &>/dev/null; then
  echo "⚠️ Node.js is not installed. rn-native's skills assume npm/npx are available on PATH."
  exit 0
fi

if ! command -v npx &>/dev/null; then
  echo "⚠️ npx is not available. Install a recent npm (comes bundled with Node 8.2+)."
  exit 0
fi

if [ -f "eas.json" ] && ! command -v eas &>/dev/null; then
  echo "⚠️ This project has an eas.json but the EAS CLI is not installed. Install with: npm install -g eas-cli"
fi

exit 0
