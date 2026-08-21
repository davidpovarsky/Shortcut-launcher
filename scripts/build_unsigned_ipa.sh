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
WIDGET_PATH="${APP_PATH}/PlugIns/DavLauncherWidgets.appex"
if [[ ! -d "${APP_PATH}" ]]; then
  log "ERROR: Device app not found at ${APP_PATH}"
  exit 5
fi

"${ROOT_DIR}/scripts/verify_bundle_ids.sh" "${APP_PATH}" 2>&1 | tee "${LOG_DIR}/bundle-id-verification.log"

log "Verifying embedded extension, assets, and localizations"
required_paths=(
  "${WIDGET_PATH}"
  "${APP_PATH}/Assets.car"
  "${APP_PATH}/en.lproj/Localizable.strings"
  "${APP_PATH}/he.lproj/Localizable.strings"
  "${WIDGET_PATH}/en.lproj/Localizable.strings"
  "${WIDGET_PATH}/he.lproj/Localizable.strings"
)
for required_path in "${required_paths[@]}"; do
  if [[ ! -e "${required_path}" ]]; then
    log "ERROR: Required bundle resource missing: ${required_path}"
    exit 6
  fi
  log "OK bundle resource: ${required_path}"
done

# SideStore discovers requested capabilities by reading the entitlements embedded
# in the incoming app/extension Mach-O binaries. A completely unsigned Xcode
# build has no LC_CODE_SIGNATURE and therefore looks like it requests no App
# Groups. Ad-hoc signing preserves the requested entitlements without requiring
# an Apple certificate; SideStore will still provision and re-sign the app.
ADHOC_DIR="${BUILD_DIR}/AdHocEntitlements"
rm -rf "${ADHOC_DIR}"
mkdir -p "${ADHOC_DIR}"

resolve_entitlements() {
  local source_plist="$1"
  local destination_plist="$2"
  python3 - "${source_plist}" "${destination_plist}" "${APP_GROUP_ID}" <<'PY'
import plistlib
import sys

source, destination, app_group = sys.argv[1:]
with open(source, "rb") as handle:
    value = plistlib.load(handle)

def resolve(item):
    if isinstance(item, dict):
        return {key: resolve(val) for key, val in item.items()}
    if isinstance(item, list):
        return [resolve(val) for val in item]
    if isinstance(item, str):
        return item.replace("$(APP_GROUP_ID)", app_group).replace("${APP_GROUP_ID}", app_group)
    return item

with open(destination, "wb") as handle:
    plistlib.dump(resolve(value), handle, fmt=plistlib.FMT_XML, sort_keys=False)
PY
}

APP_ENTITLEMENTS="${ADHOC_DIR}/DavLauncher.entitlements"
WIDGET_ENTITLEMENTS="${ADHOC_DIR}/DavLauncherWidgets.entitlements"
resolve_entitlements "${ROOT_DIR}/Config/DavLauncher.entitlements" "${APP_ENTITLEMENTS}"
resolve_entitlements "${ROOT_DIR}/Config/DavLauncherWidgets.entitlements" "${WIDGET_ENTITLEMENTS}"

log "Ad-hoc signing WidgetKit extension with requested entitlements"
/usr/bin/codesign --force --sign - --timestamp=none --entitlements "${WIDGET_ENTITLEMENTS}" "${WIDGET_PATH}"

log "Ad-hoc signing containing app with requested entitlements"
/usr/bin/codesign --force --sign - --timestamp=none --entitlements "${APP_ENTITLEMENTS}" "${APP_PATH}"

MAIN_DUMP="${ARTIFACTS_DIR}/DavLauncher-adhoc-entitlements.plist"
WIDGET_DUMP="${ARTIFACTS_DIR}/DavLauncherWidgets-adhoc-entitlements.plist"
/usr/bin/codesign -d --entitlements :- "${APP_PATH}" > "${MAIN_DUMP}" 2>> "${LOG_DIR}/codesign-adhoc.log"
/usr/bin/codesign -d --entitlements :- "${WIDGET_PATH}" > "${WIDGET_DUMP}" 2>> "${LOG_DIR}/codesign-adhoc.log"

python3 - "${MAIN_DUMP}" "${WIDGET_DUMP}" "${APP_GROUP_ID}" <<'PY'
import plistlib
import sys

expected = sys.argv[3]
for path in sys.argv[1:3]:
    with open(path, "rb") as handle:
        plist = plistlib.load(handle)
    groups = plist.get("com.apple.security.application-groups", [])
    if expected not in groups:
        raise SystemExit(f"ERROR: {path} does not contain expected App Group {expected!r}; got {groups!r}")
    print(f"OK embedded App Group entitlement in {path}: {groups}")
PY

if ! /usr/bin/otool -l "${APP_PATH}/DavLauncher" | grep -q 'LC_CODE_SIGNATURE'; then
  log "ERROR: Main app still has no LC_CODE_SIGNATURE after ad-hoc signing"
  exit 7
fi
if ! /usr/bin/otool -l "${WIDGET_PATH}/DavLauncherWidgets" | grep -q 'LC_CODE_SIGNATURE'; then
  log "ERROR: Widget extension still has no LC_CODE_SIGNATURE after ad-hoc signing"
  exit 8
fi

PACKAGE_DIR="${BUILD_DIR}/SideStorePackage"
rm -rf "${PACKAGE_DIR}"
mkdir -p "${PACKAGE_DIR}/Payload"
cp -R "${APP_PATH}" "${PACKAGE_DIR}/Payload/"

IPA_PATH="${ARTIFACTS_DIR}/DavLauncher-SideStore.ipa"
rm -f "${IPA_PATH}"
(cd "${PACKAGE_DIR}" && zip -qry "${IPA_PATH}" Payload)

cp -R "${APP_PATH}" "${ARTIFACTS_DIR}/DavLauncher-Device-adhoc.app"
log "Created SideStore-ready IPA at ${IPA_PATH}"
log "The IPA is only ad-hoc signed so SideStore can read its requested entitlements. SideStore must still provision and re-sign it before installation."
