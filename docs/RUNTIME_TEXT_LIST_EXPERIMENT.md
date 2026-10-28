# Runtime text-list editor — iPadOS Shortcuts A/B experiment

## Goal

Test whether \`@Parameter(size: .init(min:max:))\` changes the **runtime** input UI shown by \`requestValue()\` for \`[String]\` into the native list editor the user photographed (add, remove, reorder, Done/Cancel).

This tests a precise hypothesis; App Intents documentation promises bounded collection *configuration*, but **does not guarantee this widget will appear during Shortcuts execution**.

## Discovery and actions

Two separate discoverable actions are included, without adding AppShortcut provider tiles (already at ten):

- **LAB: Runtime Text List (Sized)** — optional \`[String]\` parameter with \`size: .init(min: 1, max: 8)\`; \`perform()\` invokes \`try await $items.requestValue(...)\`, then returns a numbered string with a diagnostic label, preserving ordering and duplicates.
- **LAB: Runtime Text List (Plain)** — identical optional \`[String]\` and call to \`requestValue\`, **without** \`size:\`, giving a control group on the same device and OS.

The parameter is intentionally optional to avoid mandatory resolution **before** \`perform()\`. In the actual test, \`requestValue\` is always invoked from inside \`perform()\`, so the user can observe the UI precisely at runtime, rather than the editor's parameter configuration UI.

### Test on iPad

1. Install the latest IPA from \`Package unsigned IPA\`.
2. Build shortcut A: **LAB: Runtime Text List (Sized)** followed by **Show Result** with its magic output.
3. Launch the Shortcut, **not merely edit its parameters**. Check if a modal with **add/delete/reorder** appears. Enter two values and reorder them if supported.
4. Check if **Show Result** lists the values in the same order.
5. Build shortcut B: **LAB: Runtime Text List (Plain)** followed by **Show Result**.
6. Compare the **runtime** UI between A and B. Note whether the native editor appears, or an unsupported-list error, or another generic value picker.
7. If a list editor is shown only while configuring an action (before execution), log that separately: it does not solve an AI composer invoked at runtime.

### Expected observations

| Observation | Meaning |
| --- | --- |
| Sized shows add/remove/reorder but Plain does not | Evidence that size affects runtime control |
| Both show same add/remove/reorder UI | Lists work at runtime; size not the decisive factor |
| Both show different generic prompts | Sized array alone does not unlock editor |
| Compiler rejects sized primitive String array | Framework's sized-array overload does not support this primitive type; test cannot be shipped exactly as proposed |

This experiment does **not** contain file import or mixed String/IntentFile types; those are later tests only if runtime collection editing works.

References:
- https://developer.apple.com/documentation/appintents/intentcollectionsize/init(min:max:)
- https://developer.apple.com/documentation/appintents/intentparameter/requestvalue(_:)
- https://developer.apple.com/documentation/appintents/adding-parameters-to-an-app-intent
