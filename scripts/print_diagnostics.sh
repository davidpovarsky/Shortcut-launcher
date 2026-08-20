#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

{
  echo "=== DavLauncher build diagnostics ==="
  date
  echo
  echo "--- OS ---"
  sw_vers || true
  uname -a || true
  echo
  echo "--- Xcode ---"
  xcodebuild -version || true
  xcode-select -p || true
  xcrun --sdk iphoneos --show-sdk-version || true
  xcrun --sdk iphonesimulator --show-sdk-version || true
  echo
  echo "--- Swift ---"
  xcrun swift --version || true
  echo
  echo "--- XcodeGen ---"
  xcodegen --version || true
  echo
  echo "--- Simulators ---"
  xcrun simctl list devices available || true
  echo
  echo "--- Runtimes ---"
  xcrun simctl list runtimes || true
  echo
  echo "--- Git ---"
  git status --short || true
  git rev-parse HEAD || true
  echo
  echo "--- Non-secret build variables ---"
  echo "APP_BUNDLE_ID=${APP_BUNDLE_ID}"
  echo "APP_GROUP_ID=${APP_GROUP_ID}"
  echo "SCHEME=${SCHEME}"
} 2>&1 | tee "${LOG_DIR}/diagnostics.log"
