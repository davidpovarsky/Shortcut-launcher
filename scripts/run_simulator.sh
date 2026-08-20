#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

if [[ ! -f "${BUILD_DIR}/simulator_udid.txt" ]]; then
  log "No prior simulator build found; building first."
  "${ROOT_DIR}/scripts/build_simulator.sh"
fi

UDID="$(cat "${BUILD_DIR}/simulator_udid.txt")"
APP_PATH="${BUILD_DIR}/DerivedData-Simulator/Build/Products/Debug-iphonesimulator/DavLauncher.app"

log "Booting simulator ${UDID}"
xcrun simctl boot "${UDID}" 2>/dev/null || true
xcrun simctl bootstatus "${UDID}" -b 2>&1 | tee "${LOG_DIR}/simulator-boot.log"

log "Installing ${APP_PATH}"
xcrun simctl uninstall "${UDID}" "${APP_BUNDLE_ID}" 2>/dev/null || true
xcrun simctl install "${UDID}" "${APP_PATH}" 2>&1 | tee "${LOG_DIR}/simulator-install.log"

log "Launching ${APP_BUNDLE_ID}"
xcrun simctl launch "${UDID}" "${APP_BUNDLE_ID}" 2>&1 | tee "${LOG_DIR}/simulator-launch.log"
sleep 5

xcrun simctl io "${UDID}" screenshot "${ARTIFACTS_DIR}/simulator-screenshot.png" 2>&1 | tee "${LOG_DIR}/simulator-screenshot.log"
xcrun simctl spawn "${UDID}" log show \
  --style compact \
  --last 5m \
  --predicate "process == 'DavLauncher'" \
  > "${LOG_DIR}/simulator-app.log" 2>&1 || true

log "Simulator smoke run completed"
