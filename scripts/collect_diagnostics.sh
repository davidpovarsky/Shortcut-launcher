#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

mkdir -p "${LOG_DIR}"
{
  echo "=== Artifact listing ==="
  find "${ARTIFACTS_DIR}" -maxdepth 3 -type f -print | sort
  echo
  echo "=== Build directory sizes ==="
  du -sh "${BUILD_DIR}"/* 2>/dev/null || true
  echo
  echo "=== Project tree ==="
  find "${ROOT_DIR}" -maxdepth 4 -type f \
    -not -path '*/Build/*' \
    -not -path '*/Artifacts/*' \
    -print | sort
} > "${LOG_DIR}/artifact-summary.log" 2>&1

if [[ -d "${ROOT_DIR}/DavLauncher.xcodeproj" ]]; then
  xcodebuild -project "${ROOT_DIR}/DavLauncher.xcodeproj" -scheme "${SCHEME}" -showBuildSettings \
    APP_BUNDLE_ID="${APP_BUNDLE_ID}" APP_GROUP_ID="${APP_GROUP_ID}" \
    > "${LOG_DIR}/build-settings.log" 2>&1 || true
fi
