#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/Build"
ARTIFACTS_DIR="${ROOT_DIR}/Artifacts"
LOG_DIR="${ARTIFACTS_DIR}/Logs"
PROJECT_FILE="${ROOT_DIR}/DavLauncher.xcodeproj"
SCHEME="DavLauncher"
APP_BUNDLE_ID="${APP_BUNDLE_ID:-com.dav.DavLauncher}"
APP_GROUP_ID="${APP_GROUP_ID:-group.com.dav.DavLauncher}"

mkdir -p "${BUILD_DIR}" "${ARTIFACTS_DIR}" "${LOG_DIR}"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

run_logged() {
  local name="$1"
  shift
  log "RUN ${name}: $*"
  "$@" 2>&1 | tee "${LOG_DIR}/${name}.log"
}
