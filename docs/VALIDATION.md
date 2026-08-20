# Validation and build expectations

This repository was assembled on 2026-08-20 for the iOS/iPadOS 27 SDK.

## Validation performed before packaging

The source bundle was checked with the validation script included in the repository:

- every Bash script is parsed with `bash -n`;
- the simulator-selection Python helper is byte-compiled;
- all plist and entitlement files are parsed;
- all asset-catalog JSON files are parsed;
- all Swift files are passed through a Swift 6 parser;
- the GitHub Actions workflow YAML and `project.yml` are parsed separately before the ZIP is produced.

## What is deliberately not claimed

The packaging environment used to create this ZIP is Linux, not macOS, so it cannot run Xcode 27, WidgetKit, App Intents, the iOS 27 simulator, or the Apple code-signing toolchain. Static Swift parsing checks syntax but cannot type-check Apple SDK APIs.

For that reason, the authoritative compile/test is the included GitHub Actions workflow on `runs-on: xcode-27`. It generates the Xcode project with XcodeGen, builds both the app and WidgetKit extension, runs tests, boots an iPad simulator, installs and launches the app, captures a screenshot and logs, then creates an unsigned device IPA.

`SystemShortcut` and `RunSystemShortcutIntent` are beta APIs. If Apple changes a signature in a later Xcode 27 image, the CI artifact preserves the compiler/build logs needed to pinpoint the exact call site.

## Signing note

The generated `DavLauncher-unsigned.ipa` is intentionally unsigned. Installation on real hardware requires signing or re-signing. For shared launcher state to work between the app and WidgetKit extension, the signing/provisioning setup must preserve the same App Group entitlement for both targets.
