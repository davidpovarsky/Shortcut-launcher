# SiriKit Dynamic Search — Editor vs Runtime Search Experiment

## Why this experiment exists

iPadOS 27 testing of `AppEntity + EntityStringQuery` showed searchable
suggestions in the **Shortcuts editor**, but the **runtime resolution picker**
showed only static suggestions, with no search field. A separate
`IntentPerson(mode: .contact)` probe opened the native searchable Contacts
picker at runtime, but that picker does not filter solely to app-owned records.

The user specifically wants a **single system-native runtime picker with live
search and suggestions over app-owned objects**, not a two-step filter/menu
or a custom app-hosted SwiftUI screen.

Legacy SiriKit has a different API:
`INIntentParameterSupportsDynamicEnumeration` +
`INIntentParameterSupportsSearch`, with handler callback
`provideEntryOptionsCollection(for:searchTerm:with:)`.
Open-source Telegram iOS uses this pattern to return dynamically filtered
chats. Whether the same search UI appears at **runtime on iPadOS 27** is
**unverified**; testing that is the purpose of this experiment.

## Implementation

- Intent definition: `Config/DavShowPanel.intentdefinition`
  - Existing DavShowPanel remains untouched.
  - New custom SiriKit intent: `DavSearchCatalog` / `DavSearchCatalogIntent`
  - New SiriKit custom object type: `DavCatalogEntry`
  - Single object parameter: `entry` (label: Demo Item)
  - `INIntentParameterSupportsSearch = true`
  - `INIntentParameterSupportsDynamicEnumeration = true`
  - `INIntentParameterSupportsResolution = true`
  - Required parameter-combination summary: `Search for ${entry}`
- Handler: `Sources/SiriPanelHandler/SiriCatalogSearchHandler.swift`
  - 16 **fictional** items with stable identifiers, short subtitles, SF Symbol
    images, and searchable Hebrew/English tags
  - Empty `searchTerm`: six initial suggestions
  - Nonempty `searchTerm`: query the **entire 16-item catalog**; split
    whitespace-separated terms and match every term
  - The handler logs each query to the extension's NSLog output
  - `resolveEntry` validates the selected item's stable identifier
  - `handle` returns .success plus a NSUserActivity containing the selected
    identifier and title
- Extension dispatch: `Sources/SiriPanelHandler/SiriPanelIntentHandler.swift`
- Supported intent registration: `Config/SiriPanelHandler-Info.plist`
- Shortcuts donation on app launch: `Sources/App/SiriPanelDonation.swift`

**No real contacts, email messages, files, or Photos are read or modified.**
The samples are only simulated catalog entries.

## Build verification

- Workflow: `Package unsigned IPA`
- Successful run: https://github.com/davidpovarsky/Shortcut-launcher/actions/runs/40841051033
- Build source commit: `24c7ba0977bf0225e71b6c895e163fd8ad0938fb`
- GitHub artifact: `DavLauncher-IPA-40`
- ZIP integrity verified, and `Payload/DavLauncher.app/DavShowPanel.intentdefinition`
  inspected from the produced IPA:
  - Both DavShowPanel and DavSearchCatalog are present
  - `entry` has dynamic enumeration and search enabled
  - The embedded SiriPanelHandler extension declares support for both intents

This verifies packaging and code compilation, **not picker UI behavior**.

## iPadOS 27 acceptance protocol

1. Provision/sign and install `DavLauncher-SideStore.ipa`, launch Dav Launcher
   once to trigger intent donation.
2. In the Shortcuts app, search for **LAB: SiriKit Live Search** under
   Dav Launcher, add it to a new Shortcut. If absent, note that separately:
   we may need to adjust SiriKit action discoverability, not the picker code.
3. **Editor test:** Tap the `Demo Item` parameter, search for
   `invoice`, `MP4`, `מתכון` and `דניאל`. These items are not among
   the six default suggestions; obtaining a matching record shows that
   `provideEntryOptionsCollection` receives and filters the search term.
4. **Runtime test:** Clear the configured parameter or set it to
   `Ask Each Time` if the Shortcuts UI provides that option, then run the
   Shortcut. Observe whether Shortcuts asks for an entry. Tap the value
   selection control as needed (the Contacts experiment required a tap).
   Record whether this opens:
   - A list without search
   - A live search field with app-only suggestions
   - Free-text entry or another Siri dialog
   - No parameter prompt / action failure
5. Search `invoice` and select `חשבונית אוקטובר`. Then search `מתכון`
   and select `כרטיס מתכון משפחתי` in a fresh run.
6. Compare the on-device UI with both `LAB: Native Contact Search`
   and `LAB: Searchable Rich Objects`. Take screenshots and note
   whether tapping the parameter is required.

## Success criterion

**Success** requires the runtime picker to expose a live search field
within the Shortcuts-hosted picker and to list only the app's synthetic
`DavCatalogEntry` results supplied by `searchTerm` callbacks.

A searchable editor-time picker alone is **partial success**, not the
requested functionality. Shortcuts owns the picker presentation.

## Future investigation

If Shortcuts does not surface the search box at runtime, investigate
SiriKit's `INObjectResolutionResult.disambiguation(with:)` and
`INObjectCollection` sections as separate controlled experiments. Avoid
assuming that rich disambiguation supports live input: Apple's WWDC20
documentation presents it separately from search in dynamic options.
