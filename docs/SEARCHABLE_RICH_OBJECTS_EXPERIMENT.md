# Searchable Rich Objects — Shortcuts AppEntity Experiment

## Goal

Validate the **native parameter picker in the Shortcuts editor**, including a
search field, stable AppEntity selection, thumbnail images, subtitles and
selectable rich metadata. This is NOT an in-app SwiftUI picker and does NOT
intercept the system's Contacts or Files providers.

## Action

- Name: **LAB: Searchable Rich Objects**
- Shortcuts App Shortcut tile: **LAB Search Objects**
- Parameter: **Rich Object** (required `SearchableRichSampleEntity`)
- Output: **the selected AppEntity**, with inspectable `Name`, `Category`,
  `Source (demo)`, `Description` and `Tags` properties
- Location: `Sources/App/Intents/SearchableRichObjectIntent.swift`

The app includes 16 entirely **fictional records** (documents, photos,
contacts, a book, a message, etc.) with stable IDs, descriptive subtitles,
metadata and locally rendered colored SF Symbol images. The first seven
are suggested by `suggestedEntities()`; all 16 can be found through
`entities(matching:)` by matching title, subtitle, source, category,
description or tags. Saved selections are re-resolved through
`entities(for:)` even after relaunching the application.

No Contacts/Photos/Files/Calendar/Mail data is accessed, modified or
registered, and no network service is needed.

## Acceptance test on iPadOS 27

1. Install the **new** IPA and launch DavLauncher at least once.
2. Open Shortcuts, add an action, search for **LAB: Searchable Rich Objects**
   under DavLauncher (or launch it from the LAB Search Objects tile).
3. Tap **Rich Object** in the action **editor, before running it**.
4. Inspect the native picker: it should show multiple suggestions with
   title/subtitle/colored thumbnails; look for its text search field.
5. Search for `invoice`, `דניאל`, `MP4`, or `email`.
   Those records are deliberately *not* in the first seven suggestions:
   seeing them proves that `entities(matching:)` was called.
6. Select an item, run the Shortcut, and use **Get Details of App Entities**
   or the magic-variable property picker to inspect the entity properties.
7. Close and reopen Shortcuts, then rerun the saved Shortcut; the stable
   ID must resolve to the same record.

**Important:** Shortcuts owns the picker presentation. The app can supply
search, content and metadata but cannot guarantee that iPadOS exposes a
visible search bar in every OS context. Observe the actual iPad UI.
If the search field is absent, record whether the entity's suggestions,
selection and output still work; do not mistake editor-time picker behavior
for the `requestDisambiguation` picker shown when an App Intent runs.

The older `LAB: Rich Entity Picker` remains an App Intent in the app for
comparison; only its dedicated App Shortcut tile was reassigned to avoid
exceeding the provider's ten App Shortcuts.
