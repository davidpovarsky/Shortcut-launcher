#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

"${ROOT_DIR}/scripts/bootstrap.sh"

set -o pipefail
xcodebuild \
  -project "${PROJECT_FILE}" \
  -scheme "${SCHEME}" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "${BUILD_DIR}/DerivedData-Device" \
  APP_BUNDLE_ID="${APP_BUNDLE_ID}" \
  APP_GROUP_ID="${APP_GROUP_ID}" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build \
  2>&1 | tee "${LOG_DIR}/xcodebuild-device-unsigned.log"

APP_PATH="${BUILD_DIR}/DerivedData-Device/Build/Products/Release-iphoneos/DavLauncher.app"
if [[ ! -d "${APP_PATH}" ]]; then
  log "ERROR: Device app not found at ${APP_PATH}"
  exit 5
fi

"${ROOT_DIR}/scripts/verify_bundle_ids.sh" "${APP_PATH}" 2>&1 | tee "${LOG_DIR}/bundle-id-verification.log"

PACKAGE_DIR="${BUILD_DIR}/UnsignedPackage"
rm -rf "${PACKAGE_DIR}"
mkdir -p "${PACKAGE_DIR}/Payload"
cp -R "${APP_PATH}" "${PACKAGE_DIR}/Payload/"

IPA_PATH="${ARTIFACTS_DIR}/DavLauncher-unsigned.ipa"
rm -f "${IPA_PATH}"
(cd "${PACKAGE_DIR}" && zip -qry "${IPA_PATH}" Payload)

cp -R "${APP_PATH}" "${ARTIFACTS_DIR}/DavLauncher-Device-unsigned.app"
log "Created unsigned IPA at ${IPA_PATH}"
log "This IPA must be signed/re-signed before installation on a physical device."
