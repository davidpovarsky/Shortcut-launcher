# LAB: Unified JSON Picker + Native Items (iPadOS 27)

## Purpose

Two App Intents take the SAME mixed JSON input and instantiate genuinely typed
App Intents values. The JSON is an input transport, not the display type.

1. **LAB: Unified JSON Picker** asks the user to pick ONE item at runtime and
   returns a typed **UnifiedNativePickerValue**, not a String/JSON envelope.
2. **LAB: Create Unified Native Items** does **NOT** display a picker. It returns
   an array **[UnifiedNativePickerValue]** containing ALL the created items in
   input order. Use Shortcuts' own **Choose from List**, **Repeat with Each**,
   or other actions to process these values.

Both use exactly the same builder and cases:
- Rich: the ORIGINAL SearchableRichSampleEntity from the separately working
  "LAB: Searchable Rich Objects" action (not a menu surrogate).
- Contact: native IntentPerson with application-defined ID and optional handle.
  This does NOT read, create, or modify device Contacts.
- Menu: existing MixedMenuChoiceEntity from Show Mixed Menu.

The original Searchable Rich Objects action has a fixed, internal sample catalog
and deliberately needs NO JSON input. The two new actions create their own
additional session-scoped native entities from caller-provided JSON. The
runtime objects are retained in the existing shared App Group-backed stores
for one hour so Shortcuts can resolve their identifiers AFTER the intent ends;
the fixed original catalog is unchanged.

## Important Shortcuts UI limitation

A single requestDisambiguation prompt containing a heterogeneous union may
present uniformly styled choice rows on iPadOS. The host (Shortcuts/iPadOS)
controls this presentation; sharing original entity types and thumbnails does
NOT force its runtime chooser to match the original EDITOR-TIME searchable
AppEntity picker. In particular, an ordinary menu-like selection sheet is not
evidence that the rich value was converted to MixedMenuChoiceEntity.

The new no-picker action avoids the app's disambiguation sheet entirely and
lets you try Shortcuts' native "Choose from List" against the typed results.
Neither route guarantees visually different row templates for each union case;
acceptance requires inspecting a real iPadOS 27 shortcut run.

## Mixed JSON input

All items in one interleaved array (preserves order):

```json
[
  {"format":"richObject","id":"report","name":"דוח פעילות 2026","subtitle":"PDF · דוגמה","icon":"doc.richtext","color":"#2563EB","source":"Files","tags":["report"]},
  {"format":"contact","id":"sarah","name":"שרה לוי","email":"sarah@example.com","icon":"person.crop.circle.fill"},
  {"format":"menu","id":"do-it","type":"rich","title":"הפעל פעולה","subtitle":"פעולת תפריט","icon":"bolt.fill","color":"#FFB020"}
]
```

Also accepts grouped arrays:

```json
{
  "richObjects": [{"name":"Document","source":"Files"}],
  "contacts": [{"name":"Demo Person","email":"demo@example.com"}],
  "menuItems": [{"title":"Open","type":"rich","icon":"arrow.up.forward"}]
}
```

Also accepts {"items":[...]} and legacy named menu dictionaries.

Fields:
- richObject: title/name, optional subtitle, source, category, details, tags,
  id, icon, color, backgroundColor, imageBase64
- contact: title/name/displayName, optional email/emailAddress, phone, id.
  The email or phone contributes a native IntentPerson.Handle.
- menu: title, optional subtitle, icon, color, backgroundColor, imageBase64,
  type=rich|vcard|menu. This case always creates MixedMenuChoiceEntity;
  "vcard" here does NOT create an IntentFile.
- 80 items maximum, 1 MB input maximum, 250 KB decoded imageBase64 maximum.

## Return values

| Action | Runtime choice | Native Shortcuts output |
| --- | --- | --- |
| LAB: Unified JSON Picker | Yes, one item | UnifiedNativePickerValue (one of rich, contact, menu) |
| LAB: Create Unified Native Items | No | [UnifiedNativePickerValue] (all items, ordered) |

These values are not dictionaries or JSON text. The source's arbitrary extra
JSON fields are not magically exposed as fields on the native types. To retain
an arbitrary untyped JSON payload, pass the original input alongside the typed
output in the surrounding Shortcut.

**Migration note:** Prior LAB: Unified JSON Picker versions returned a String
with format/id/item. Reconnect any downstream shortcut steps that previously
expected JSON text: the new action now deliberately returns the actual native
value.

## Verification

1. Build, install and launch on iPadOS 27, then refresh Shortcuts' app actions
   if needed.
2. Add LAB: Unified JSON Picker with the sample array. Choose each of the
   three kinds and inspect the output's *type*, not merely its appearance.
3. Add LAB: Create Unified Native Items with the same sample JSON and run it.
   No picker should appear. Use Count to verify 3 values.
4. Feed that result to Shortcuts' Choose from List. Verify order, preview,
   selected value, and downstream type (rich entity, IntentPerson, menu entity).
5. Add Get Details / Quick Look as appropriate; check both typed outputs and
   runtime identifier resolution after the originating action completes.
6. Cancel a picker; confirm no default value is returned.
7. Run on device to determine whether the host chooses identical row styling
   for mixed types. CI builds and unit tests **cannot prove visual parity**.
8. Confirm original Searchable Rich Objects, Show Mixed Menu, and the existing
   Create Mixed Menu Items actions are unchanged.

Key sources:
- Sources/App/Intents/UnifiedNativePickerValue.swift
- Sources/App/Intents/UnifiedNativeItemBuilder.swift
- Sources/App/Intents/UnifiedJSONPickerIntent.swift
- Sources/App/Intents/CreateUnifiedNativeItemsIntent.swift
- Sources/App/Intents/SearchableRichObjectIntent.swift
- Sources/Shared/Intents/UnifiedPickerParser.swift

Apple AppUnionValue documentation:
https://developer.apple.com/documentation/appintents/appunionvalue
