# LAB: Unified JSON Picker (iPadOS 27)

## Overview

The first version flattened all the choices into a single menu entity, which
caused the same visual format for rich objects, contacts and menu rows. That
was incorrect for this experiment.

Version 2 uses a real native typed union with three distinct cases:

- Rich: UnifiedRichObjectEntity, an AppEntity with its own image and subtitle.
- Contact: IntentPerson with an application-defined identifier and optional handle.
- Menu: MixedMenuChoiceEntity, keeping the prior menu type.

The selection still returns the original JSON unchanged within the output envelope.
It does NOT create or fetch Contacts records from the device.

The native Shortcuts host owns the actual presentation. A mixed UnionValue
parameter can retain the underlying types but cannot GUARANTEE that the runtime
disambiguation sheet will show three different visual row styles. This must
be inspected on iPadOS 27. It may group by case or normalize the rows.

Sources:
- Sources/Shared/Intents/UnifiedNativePickerValue.swift
- Sources/App/Intents/UnifiedJSONPickerIntent.swift
- Sources/Shared/Intents/UnifiedPickerParser.swift

Apple's WWDC26 App Intents session (UnionValue chapter):
https://developer.apple.com/videos/play/wwdc2026/345/

## Action

- Name: **LAB: Unified JSON Picker** (discoverable as an App Intent).
- Input: **Mixed JSON** (string; may come from Text, Dictionary serialized as
  JSON, or a Magic Variable holding the JSON).
- Output: **String** containing `format`, `id`, `item`.
- Single selection, not a multiple-selection list.
- User cancellation exits the action without returning a fabricated choice.

## Input

Recommended: one interleaved array where each item sets its `format`.

```json
[
  {"format":"richObject","id":"report","name":"דוח פעילות 2026","subtitle":"PDF · דוגמה","icon":"doc.richtext","color":"#2563EB","source":"Files","tags":["report"]},
  {"format":"contact","id":"sarah","name":"שרה לוי","email":"sarah@example.com","phone":"+15551234567","icon":"person.crop.circle.fill"},
  {"format":"menu","id":"do-it","type":"rich","title":"הפעל פעולה","subtitle":"פעולת תפריט","icon":"bolt.fill","color":"#FFB020"},
  {"format":"menu","id":"card","type":"vcard","title":"כרטיס לדוגמה","subtitle":"תצוגת כרטיס"}
]
```

Alternative grouped object:

```json
{
  "richObjects": [{"name":"Document","source":"Files"}],
  "contacts": [{"name":"Demo Person","email":"demo@example.com"}],
  "menuItems": [{"title":"Open","type":"rich","icon":"arrow.up.forward"}]
}
```

Or `{"items": [ ... ]}`. The plain array supports interleaving all formats
in the user's chosen order; grouped objects use richObjects, then contacts,
then menuItems. Legacy root named-object menus also work.

Supported kinds:
- `richObject`: `title` or `name`; subtitle may fall back to
  `source`/`category`/`details`.
- `contact`: `title`/`name`/`displayName`; subtitle may fall back to
  `email`/`emailAddress`/`phone`/`handle`.
- `menu`: `title`; `type` may be `rich` or `vcard`, for visuals only.
- Optional `id`, `subtitle`, SF Symbol `icon`, `color` (#RRGGBB),
  `backgroundColor`, `imageBase64` (PNG/JPEG, max 250KB decoded).
- All supplied fields are left intact in `item`; internal generated menu
  session IDs never escape to output.
- Up to 80 items and 1MB input JSON.

## Output example

Choosing the second entry returns:

```json
{
  "format": "contact",
  "id": "sarah",
  "item": {
    "format": "contact",
    "id": "sarah",
    "name": "שרה לוי",
    "email": "sarah@example.com",
    "phone": "+15551234567",
    "icon": "person.crop.circle.fill"
  }
}
```

The original item is nested unchanged (key order may be normalized by JSON
encoding). This is an app-defined JSON record, not an actual `IntentPerson`.

## Verification

1. Build the branch with Xcode 27, sign, install on iPadOS 27.
2. Open the app once, then Shortcuts. Add **LAB: Unified JSON Picker**.
3. Paste the mixed array into **Mixed JSON**. Run it.
4. Inspect whether iPadOS uses truly different visual rows or normalizes
   all three native types. Choose rich, contact, and menu separately to check
   that the output maps to the correct original JSON item. If the host still
   uses one layout for all rows, this experimental approach is NOT a visual fix.
5. Append **Show Result** to verify the returned JSON `format` and `item`
   match the selection. Verify all custom fields survived.
6. Cancel the picker: the action should cancel and not emit a default item.
7. Observe whether a text search control appears **at runtime**; it is
   controlled by iPadOS, not guaranteed.
8. Test invalid JSON, invalid color, oversize input, and 81 items.
9. Verify all three existing actions still work unchanged.

Xcode / device runtime acceptance is required; local Swift parsing and unit
tests alone do not prove the picker presentation.
