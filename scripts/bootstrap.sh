#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

log "Bootstrapping DavLauncher"

if [[ "$(uname -s)" != "Darwin" ]]; then
  log "ERROR: Xcode project generation/build requires macOS."
  exit 2
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    log "Installing XcodeGen with Homebrew"
    brew install xcodegen 2>&1 | tee "${LOG_DIR}/brew-xcodegen.log"
  else
    log "ERROR: xcodegen is missing and Homebrew is unavailable."
    exit 3
  fi
fi

log "XcodeGen: $(xcodegen --version)"
cd "${ROOT_DIR}"
run_logged xcodegen xcodegen generate

if [[ ! -d "${PROJECT_FILE}" ]]; then
  log "ERROR: ${PROJECT_FILE} was not generated."
  exit 4
fi

log "Generated ${PROJECT_FILE}"
