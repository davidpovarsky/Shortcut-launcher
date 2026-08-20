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
