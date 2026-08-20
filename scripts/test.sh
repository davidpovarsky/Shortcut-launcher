#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

if [[ ! -d "${PROJECT_FILE}" ]]; then
  "${ROOT_DIR}/scripts/bootstrap.sh"
fi

if [[ -f "${BUILD_DIR}/simulator_udid.txt" ]]; then
  UDID="$(cat "${BUILD_DIR}/simulator_udid.txt")"
else
  UDID="$(python3 "${ROOT_DIR}/scripts/select_simulator.py")"
fi

log "Booting test simulator ${UDID}"
xcrun simctl boot "${UDID}" 2>/dev/null || true
xcrun simctl bootstatus "${UDID}" -b 2>&1 | tee "${LOG_DIR}/test-simulator-boot.log"

log "Testing on simulator ${UDID}"
set -o pipefail
xcodebuild \
  -project "${PROJECT_FILE}" \
  -scheme "${SCHEME}" \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=${UDID}" \
  -derivedDataPath "${BUILD_DIR}/DerivedData-Tests" \
  -parallel-testing-enabled NO \
  APP_BUNDLE_ID="${APP_BUNDLE_ID}" \
  APP_GROUP_ID="${APP_GROUP_ID}" \
  CODE_SIGNING_ALLOWED=NO \
  test \
  2>&1 | tee "${LOG_DIR}/xcodebuild-tests.log"
