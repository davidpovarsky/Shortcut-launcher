#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

OUT="${LOG_DIR}/static-validation.log"

{
  echo "=== Static validation ==="
  date
  echo

  echo "--- Shell scripts ---"
  for file in "${ROOT_DIR}"/scripts/*.sh; do
    bash -n "${file}"
    echo "OK ${file#${ROOT_DIR}/}"
  done

  echo
  echo "--- Python scripts ---"
  python3 -m py_compile "${ROOT_DIR}/scripts/select_simulator.py"
  echo "OK scripts/select_simulator.py"

  echo
  echo "--- Property lists ---"
  python3 - "${ROOT_DIR}" <<'PY'
import glob
import os
import plistlib
import sys
root = sys.argv[1]
files = sorted(glob.glob(os.path.join(root, "Config", "*.plist")) + glob.glob(os.path.join(root, "Config", "*.entitlements")))
for path in files:
    with open(path, "rb") as handle:
        plistlib.load(handle)
    print("OK", os.path.relpath(path, root))
PY

  echo
  echo "--- JSON assets ---"
  python3 - "${ROOT_DIR}" <<'PY'
import glob
import json
import os
import sys
root = sys.argv[1]
for path in sorted(glob.glob(os.path.join(root, "**", "*.json"), recursive=True)):
    if "/Build/" in path or "/Artifacts/" in path:
        continue
    with open(path, encoding="utf-8") as handle:
        json.load(handle)
    print("OK", os.path.relpath(path, root))
PY

  echo
  echo "--- Swift parser ---"
  if command -v xcrun >/dev/null 2>&1; then
    find "${ROOT_DIR}/Sources" "${ROOT_DIR}/Tests" -name '*.swift' -print0 | xargs -0 xcrun swiftc -parse
    echo "OK all Swift sources parse"
  elif command -v swiftc >/dev/null 2>&1; then
    find "${ROOT_DIR}/Sources" "${ROOT_DIR}/Tests" -name '*.swift' -print0 | xargs -0 swiftc -parse
    echo "OK all Swift sources parse"
  else
    echo "SKIP Swift parser unavailable"
  fi
} 2>&1 | tee "${OUT}"
