#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

APP_PATH="${1:-}"
if [[ -z "${APP_PATH}" || ! -d "${APP_PATH}" ]]; then
  echo "Usage: $0 /path/to/DavLauncher.app" >&2
  exit 2
fi

read_plist_id() {
  python3 - "$1" <<'PY'
import plistlib, sys
with open(sys.argv[1], 'rb') as f:
    print(plistlib.load(f)['CFBundleIdentifier'])
PY
}

PARENT_ID="$(read_plist_id "${APP_PATH}/Info.plist")"
log "Parent bundle ID: ${PARENT_ID}"

STATUS=0
while IFS= read -r -d '' appex; do
  EXT_ID="$(read_plist_id "${appex}/Info.plist")"
  log "Extension bundle ID: ${EXT_ID}"
  if [[ "${EXT_ID}" != "${PARENT_ID}."* ]]; then
    log "ERROR: extension ID does not have required parent prefix"
    STATUS=1
  fi
done < <(find "${APP_PATH}/PlugIns" -maxdepth 1 -name '*.appex' -print0 2>/dev/null || true)

exit "${STATUS}"
