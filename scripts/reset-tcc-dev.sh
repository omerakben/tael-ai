#!/usr/bin/env bash
#
# reset-tcc-dev.sh
#
# Reset TCC entries for the TAEL macOS agent so we can re-test the
# permission flows from a clean state during development.
#
# Use this when:
#  - You changed signing identity and the app suddenly looks "new" to TCC.
#  - You want to re-trigger the Screen Recording prompt from scratch.
#  - A grant feels stuck (granted in System Settings, but the API still
#    reports denied).
#
# This script ONLY touches our bundle id (ai.tael.macagent). It does not
# reset other apps' permissions. Quit the app before running.
#
# Usage:
#   ./scripts/reset-tcc-dev.sh             # actually reset
#   ./scripts/reset-tcc-dev.sh --dry-run   # print what it would do
#
# Reference: `man tccutil` — `tccutil reset <SERVICE> [bundle-id]`.

set -euo pipefail

BUNDLE_ID="ai.tael.macagent"

# Services that map to TCC categories we care about. PR 1 only touches
# ScreenCapture, but resetting the others is harmless and saves a trip
# back to this file later.
SERVICES=(
  "ScreenCapture"
  "Accessibility"
  "Microphone"
  "AppleEvents"
  "ListenEvent"        # Input Monitoring
)

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
fi

if [[ "$(uname)" != "Darwin" ]]; then
  echo "error: this script must be run on macOS" >&2
  exit 2
fi

echo "TAEL TCC dev reset"
echo "  bundle id: ${BUNDLE_ID}"
echo "  services : ${SERVICES[*]}"
echo

if pgrep -x "TAELMacAgent" >/dev/null 2>&1; then
  echo "warning: TAELMacAgent appears to be running."
  echo "         Quit it before running this script for a clean reset."
  echo
fi

for svc in "${SERVICES[@]}"; do
  cmd=(tccutil reset "$svc" "$BUNDLE_ID")
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "would run: ${cmd[*]}"
  else
    echo "running:   ${cmd[*]}"
    # tccutil exits non-zero if there is no entry to reset for that
    # service. That is fine — treat it as a no-op.
    "${cmd[@]}" || echo "  (no existing entry for ${svc}, skipping)"
  fi
done

echo
echo "Done. Quit and relaunch TAELMacAgent before re-testing permissions."
