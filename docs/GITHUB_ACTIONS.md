# GitHub Actions

## iOS 27 CI

`.github/workflows/ci.yml` runs on GitHub's `xcode-27` preview runner.

The job stages are deliberately separate so failures are easy to diagnose:

1. Bootstrap XcodeGen project.
2. Print environment diagnostics.
3. Build for an available iPad simulator.
4. Run unit tests.
5. Boot, install and launch in the iPad simulator.
6. Capture a screenshot and unified-log output.
7. Build a generic unsigned iOS device app.
8. Verify parent/extension bundle identifier prefixes.
9. Package the unsigned `.app` as an `.ipa`.
10. Upload all logs and artifacts even after a failure.

## Artifacts

Expected workflow artifact contents:

```text
Artifacts/
├── DavLauncher-Simulator.app/
├── DavLauncher-Simulator.zip
├── DavLauncher-Device-unsigned.app/
├── DavLauncher-unsigned.ipa
├── simulator-screenshot.png
└── Logs/
    ├── diagnostics.log
    ├── xcodebuild-simulator.log
    ├── xcodebuild-tests.log
    ├── simulator-boot.log
    ├── simulator-install.log
    ├── simulator-launch.log
    ├── simulator-app.log
    ├── xcodebuild-device-unsigned.log
    ├── bundle-id-verification.log
    └── artifact-summary.log
```

## Bundle ID overrides

All build scripts accept:

```bash
APP_BUNDLE_ID=com.example.Launcher \
APP_GROUP_ID=group.com.example.Launcher \
./scripts/build_unsigned_ipa.sh
```

The widget bundle ID automatically becomes:

```text
com.example.Launcher.Widgets
```
