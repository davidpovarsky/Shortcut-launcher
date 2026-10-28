# Confirmation Back / Next — experimental iPadOS 27 test

## Purpose

Determine whether the Shortcuts system confirmation interface supports custom labels and whether choosing "חזור" (the system's **deny/cancel** button) can be caught as an error and turned into a normal output string without stopping the entire Shortcut.

This deliberately tests behavior Apple discourages: Apple's WWDC/App Intents guidance says confirmation cancellation normally **terminates the intent**, and developers should not suppress it. The experiment is not a supported navigation pattern.

## Actions

- **LAB: Confirmation Back or Next** — presents a native confirmation interface with custom `ConfirmationActionName.custom` labels:
  - **המשך** — accepted: returns the string `next` to the Shortcut.
  - **חזור** — denies: attempts to catch the thrown error and return `back`.
- **LAB: Read Confirmation Trace** — independently retrieves the last recorded phase, returned value, error type, and error domain/code. This is useful even if iPadOS aborts the first action without reaching a catch block.

The first action uses `requestConfirmation(actionName:dialog:showDialogAsPrompt:content:)` with a small static SwiftUI view. It does **not** depend on WebKit and does **not** change the existing Snippet clock or other actions.

## Reproducible Shortcuts test

Create a Shortcut containing:
1. **DavLauncher → LAB: Confirmation Back or Next**
2. **Text:** `ACTION FINISHED -> [magic variable: output of the previous action]`
3. **Show Result:** show that text.

Run twice, separately:

**A — Tap המשך.** Expected: action returns `next` and Show Result displays `ACTION FINISHED -> next`.

**B — Tap חזור.** This is the actual unsupported-behavior experiment. Possible results:
- Show Result appears with `back`: the particular iPadOS version allowed the thrown cancellation to be caught and converted into a normal result. Do not assume it works on all versions.
- Shortcut stops with no Show Result: iPadOS may terminate on cancellation regardless of the catch.
- Error appears: record its exact text.

Then run **LAB: Read Confirmation Trace** as a separate Shortcut followed by **Show Result**.
- `phase=caught_confirmation_error_returned_back` proves the catch was reached and a result was *attempted*, not necessarily that Shortcuts accepted it.
- `phase=before_prompt` implies the catch/result wasn't recorded (termination or lost process).
- `phase=returned_next` verifies the affirmative case.

No automatically "return to previous Shortcut action" behavior is implemented; it is not an iPadOS feature. A returned `back` would need explicit If/Repeat branching logic in the Shortcut.

## Safety / interpretation

Only the confirmation's own result is experimentally converted; unrelated failures could be caught too and will be visible in the trace's error type/domain. This is intentionally a diagnostic proof of concept, not recommended app behavior. Do not use it for destructive operations.

References:
- https://developer.apple.com/documentation/appintents/confirmationactionname/custom(acceptlabel:acceptalternatives:denylabel:denyalternatives:destructive:)
- https://developer.apple.com/documentation/appintents/appintent/requestconfirmation(conditions:actionname:dialog:showdialogasprompt:content:)
