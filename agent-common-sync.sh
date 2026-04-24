#!/usr/bin/env sh
set -eu

# Cross-platform shell wrapper.
# Requires PowerShell 7+ (`pwsh`) on macOS/Linux, or `powershell` on Windows environments that expose it.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SCRIPT="$SCRIPT_DIR/agent-common-sync.ps1"

if command -v pwsh >/dev/null 2>&1; then
  exec pwsh -NoProfile -ExecutionPolicy Bypass -File "$SCRIPT" "$@"
elif command -v powershell >/dev/null 2>&1; then
  exec powershell -NoProfile -ExecutionPolicy Bypass -File "$SCRIPT" "$@"
else
  echo "Error: PowerShell is required. Install PowerShell 7+: https://github.com/PowerShell/PowerShell" >&2
  exit 127
fi
