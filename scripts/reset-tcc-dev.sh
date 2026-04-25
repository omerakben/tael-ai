#!/usr/bin/env bash
set -euo pipefail

BUNDLE_ID="ai.tael.macagent"

echo "Resetting Screen Recording TCC state for ${BUNDLE_ID}"
tccutil reset ScreenCapture "${BUNDLE_ID}"
