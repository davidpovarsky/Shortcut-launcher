#!/usr/bin/env python3
import json
import subprocess
import sys

raw = subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"])
data = json.loads(raw)

runtime_keys = sorted(
    [k for k in data.get("devices", {}) if "SimRuntime.iOS" in k],
    reverse=True,
)

preferred_words = ("iPad Pro", "iPad Air", "iPad")
for runtime in runtime_keys:
    devices = data["devices"].get(runtime, [])
    for word in preferred_words:
        for device in devices:
            if word in device.get("name", "") and device.get("isAvailable", True):
                print(device["udid"])
                sys.exit(0)

print("No available iPad simulator found", file=sys.stderr)
sys.exit(1)
