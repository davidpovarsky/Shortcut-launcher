# LAB: Unified JSON Picker (iPadOS 27)

## Overview

One Shortcuts action accepts JSON containing **three formats** from the existing experiments:
rich objects, contact-shaped people, and menu entries. It presents **one native
Shortcuts runtime selection sheet** and returns the selected item's JSON.

This is not three native picker engines merged together. All entries use one
temporary `MixedMenuChoiceEntity` UI representation. A contact in this menu
is NOT a real Contacts record or `IntentPerson`. Only the visual title,
subtitle and thumbnail are shared; the original format and fields are preserved
in the return value. Native Contacts search and runtime AppEntity text search
are **not guaranteed** by this API.

Source files:
- `Sources/App/Intents/UnifiedJSONPickerIntent.swift`
- `Sources/Shared/Intents/UnifiedPickerParser.swift`
- Existing `MixedMenuChoiceStore` and `MixedMenuIconRenderer` reused without changes.

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
4. Check the system picker shows all rich/contact/menu items together, with
   title, subtitle, and images where supported. Choose a contact and
   a rich item in separate runs.
5. Append **Show Result** to verify the returned JSON `format` and `item`
   match the selection. Verify all custom fields survived.
6. Cancel the picker: the action should cancel and not emit a default item.
7. Observe whether a text search control appears **at runtime**; it is
   controlled by iPadOS, not guaranteed.
8. Test invalid JSON, invalid color, oversize input, and 81 items.
9. Verify all three existing actions still work unchanged.

Xcode / device runtime acceptance is required; local Swift parsing and unit
tests alone do not prove the picker presentation.
