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

had_real_failure=0
for svc in "${SERVICES[@]}"; do
  cmd=(tccutil reset "$svc" "$BUNDLE_ID")
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "would run: ${cmd[*]}"
    continue
  fi

  echo "running:   ${cmd[*]}"
  # We capture combined output and the exit code so we can distinguish
  # the typical "no existing entry" case (suppress, keep going) from
  # real failures like an unknown service name (warn loudly).
  #
  # Note: the `if !` form is REQUIRED. A bare `output=$(...); rc=$?` would
  # let `set -e` abort the whole script on the first non-zero tccutil
  # exit, making the rest of this block dead code. Bash flips `$?` after
  # `!`, so PIPESTATUS preserves the original tccutil exit code.
  if ! output=$("${cmd[@]}" 2>&1); then
    rc=${PIPESTATUS[0]}

    # tccutil's "nothing to reset" message looks like:
    #   tccutil: Failed to reset all approval status for ai.tael.macagent
    # That is benign — there was simply no entry yet. Anything else is
    # surfaced and counted as a real failure so debugging is not hidden.
    if [[ "$output" == *"Failed to reset"* ]]; then
      echo "  (no existing entry for ${svc}, skipping)"
    else
      echo "  warning: tccutil exited ${rc} for ${svc}:" >&2
      echo "  ${output}" >&2
      had_real_failure=1
    fi
  fi
done

if [[ $had_real_failure -ne 0 ]]; then
  echo
  echo "error: at least one tccutil call failed for an unexpected reason." >&2
  exit 1
fi

echo
echo "Done. Quit and relaunch TAELMacAgent before re-testing permissions."
