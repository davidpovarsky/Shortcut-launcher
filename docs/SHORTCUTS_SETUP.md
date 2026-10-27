# Shortcuts setup

## Notification-triggered Control Center launcher

Create a launcher profile in Dav Launcher and set a unique automation token, for example:

```text
DAV:READING
```

Add the Dav Launcher control to Control Center and edit it to select that profile.

Create a Notification Automation in Shortcuts for Dav Launcher and filter it using the token.

A typical shortcut is:

```text
Notification Automation receives DAV:READING
    -> perform your automation
    -> Set Launcher State: Reading Mode = Success
    -> Wait 1 second (optional)
    -> Reset Launcher: Reading Mode
```

For a failure branch:

```text
If operation failed
    -> Set Launcher State: Reading Mode = Error
Otherwise
    -> Set Launcher State: Reading Mode = Success
End If
```

The visual state persists until a Dav Launcher App Intent changes it. This is intentional so the control reflects the real completion state of your Shortcut.

## Direct-launch widget

Add **Dav Direct Launcher** to the Home Screen.

Edit the widget and configure:

- Appearance Profile: one of the profiles created in Dav Launcher.
- Action: the system `SystemShortcut` picker.

The Action picker can represent an installed app, App Shortcut, custom Shortcut, or supported system action.

If the selected custom Shortcut should also update the widget/control appearance, add Dav Launcher's `Set Launcher State` action inside that Shortcut.


## Show Mixed Menu — one-action JSON picker (iPadOS 27)

Add the **Show Mixed Menu** action from **DavLauncher** to a Shortcut.
Connect a **Text** action containing JSON to the **Menu JSON** input. Running
Show Mixed Menu opens the native system choice prompt *inside the same action*.
After selection it returns **Text containing the chosen object's JSON**. Add
**Get Dictionary from Input** afterward if you want fields such as id, title,
subtitle, payload, or a custom URL in separate Shortcuts actions.

Example:

```json
[
  {
    "id": "settings",
    "type": "rich",
    "title": "הגדרות",
    "subtitle": "שינוי העדפות",
    "icon": "gearshape.fill",
    "color": "#64748B",
    "payload": {"action": "open-settings"}
  },
  {
    "id": "files",
    "type": "vcard",
    "title": "קבצים",
    "subtitle": "ניהול קבצים",
    "icon": "folder.fill",
    "color": "#F59E0B",
    "payload": {"action": "show-files"}
  }
]
```

The original object-keyed JSON from the menu experiments also works:
`{"settings":{"title":"הגדרות","icon":"gearshape.fill","color":"#64748B"}}`
Its outer keys become the item IDs. A JSON array permits explicit reordering.
Each item supports id, type (rich or vcard; defaults to rich), title, subtitle,
icon (SF Symbols name), color (#RRGGBB / #RRGGBBAA), optional backgroundColor,
optional imageBase64 (PNG/JPEG up to 250 KB), and **any other custom fields**.
Maximum 80 items and 1 MB of input.

The same system picker contains both types: rich uses a circular colored
symbol background, while vcard uses a rounded-square/card-like thumbnail or
the supplied photo. The latter is a **visual style**, not a write to Contacts
or a native vCard object. The system controls the actual list presentation, so
this does not guarantee pixel-for-pixel parity with the third-party Actions
MenuItem or Shortcuts' vCard rendering.

If the user cancels, the intent stops with a system cancellation; no value
is returned. The transient picker entities are cached in App Group defaults
per invocation for system entity resolution and removed when the action ends;
stale cache entries expire after one hour.

## LAB: Generate Object Types (iPadOS 27)

Create a Shortcut with two actions:
1. **DavLauncher → LAB: Generate Object Types**. Select **Object Type** from the system dropdown.
2. **Shortcuts → Choose from List** and connect the first action's output.

No input JSON or sample data required. The action returns homogeneous arrays of
real values (wrapped in an App Intents UnionValue, one case per invocation).
Examples: rich AppEntity, IntentPerson, vCard IntentFile, PNG IntentFile,
PlaceDescriptor, .ics files with VEVENT or VTODO, PDF, WAV audio, MP4 video,
URL, LinkMetadata, AttributedString, String, numeric/date/duration/measurement
types, PersonNameComponents, and IntentCurrencyAmount/IntentPaymentMethod.

**Important differences:** AppEntity is not Actions' private MenuItem. vCard
is a FILE, not necessarily a Contact object to the Shortcuts list renderer.
PDFs, images, audio, videos, and .ics are valid standalone FILES with matching
content; they are not native Photo Library PHAsset, Calendar Event, Reminder,
or Music Library objects. The selector includes unsupported system-owned or
contextual object types and clearly labels their output as *unavailable* rather
than silently substituting fake objects.

This is an observation/testing tool: do not claim that passing values through
UnionValue retains their native visual presentation until each mode has been
tested with Choose from List on an iPad. No library or account objects are
written, and samples are synthetic.
