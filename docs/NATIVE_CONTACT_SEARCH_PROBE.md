# Native IntentPerson runtime search probe (iPadOS 27)

## Why this exists
On-device screenshot from LAB: Searchable Rich Objects showed a system
runtime AppEntity list with image/title/subtitle but no search field.
The user correctly pointed out that Apple's Mail action can display
a searchable Contacts/recipient selection dialog *during execution*.
This experiment asks whether the same native experience is available to
third-party App Intents — and particularly app-supplied synthetic entries.

Apple APIs:
- `IntentPerson.ParameterMode.contact` (system Contacts picker)
- `IntentPerson.ParameterMode.email` (Mail-like recipient picker)
- `@Parameter(..., optionsProvider: LabDemoPersonOptionsProvider())`
- `DynamicOptionsProvider.results()` yields five *fictional* `IntentPerson`
  entries with `.applicationDefined` IDs, visible “(דוגמה)” labels and
  `example.com` addresses.

## Three independent actions

1. **LAB: Native Contact Search** — required `IntentPerson` parameter
   with `mode: .contact`, **no** options provider. Control to test whether
   native Contacts search appears during execution.
2. **LAB: Contact Options Search** — `mode: .contact` plus
   `LabDemoPersonOptionsProvider`. The crucial test: does the same
   searchable UI appear and does it search five synthetic entries?
3. **LAB: Email Options Search** — `mode: .email` plus the same provider.
   Compares the email-recipient picker with the user's Mail observation.

The second action has an App Shortcut tile **LAB Contact Search**.
All three should be discoverable by name in the DavLauncher action
catalog in Shortcuts. Existing LAB: Searchable Rich Objects is preserved.

## On-device test protocol

1. Install the new IPA, open the app once, then open Shortcuts.
2. Create a Shortcut with only **LAB: Native Contact Search** and run it
   without filling the person parameter in advance. Observe whether it
   shows a search field, Contacts results and an option to choose an item.
3. Create another Shortcut with **LAB: Contact Options Search** and run
   without pre-selecting a demo person. Look for a search field; try
   searching “מרים” (among the five demo persons). Note whether the
   result comes from the supplied options, the device's actual Contacts,
   or both.
4. Repeat with **LAB: Email Options Search** and try “sarah-lab”.
5. Compare all three with Apple's **Send Email** action's recipient prompt
   and the AppEntity experiment. Record screenshots.

**Interpretation:** A search bar in the native Contacts baseline does not
prove search works for app-defined objects. If Contact Options Search also
supports searching the supplied demo entries, it establishes a reusable
native person-shaped picker for **contact-like** data. It does not prove
arbitrary PDF/photo/file AppEntities receive the same UI.

No contacts are added, deleted or changed. No email is sent. Provider
data uses reserved example.com addresses, with no remote service.
