#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

"${ROOT_DIR}/scripts/bootstrap.sh"

UDID="$(python3 "${ROOT_DIR}/scripts/select_simulator.py")"
echo "${UDID}" > "${BUILD_DIR}/simulator_udid.txt"
log "Using iPad simulator ${UDID}"

set -o pipefail
xcodebuild \
  -project "${PROJECT_FILE}" \
  -scheme "${SCHEME}" \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=${UDID}" \
  -derivedDataPath "${BUILD_DIR}/DerivedData-Simulator" \
  APP_BUNDLE_ID="${APP_BUNDLE_ID}" \
  APP_GROUP_ID="${APP_GROUP_ID}" \
  CODE_SIGNING_ALLOWED=NO \
  build \
  2>&1 | tee "${LOG_DIR}/xcodebuild-simulator.log"

APP_PATH="${BUILD_DIR}/DerivedData-Simulator/Build/Products/Debug-iphonesimulator/DavLauncher.app"
if [[ ! -d "${APP_PATH}" ]]; then
  log "ERROR: Simulator app not found at ${APP_PATH}"
  exit 5
fi

rm -rf "${ARTIFACTS_DIR}/DavLauncher-Simulator.app"
cp -R "${APP_PATH}" "${ARTIFACTS_DIR}/DavLauncher-Simulator.app"
(cd "${ARTIFACTS_DIR}" && ditto -c -k --sequesterRsrc --keepParent DavLauncher-Simulator.app DavLauncher-Simulator.zip)
log "Simulator build artifact created"
