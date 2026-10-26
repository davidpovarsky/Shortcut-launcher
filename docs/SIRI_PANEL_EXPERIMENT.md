# SiriKit UI experiment — wiring not complete

A separate Intents UI target displays requested and actual dimensions. This is NOT yet a callable SiriKit action.

Remaining: define DavShowPanelIntent in an .intentdefinition file; generate the intent classes; add an Intents handler extension; register the intent in both extensions. Validate compilation and Siri / Shortcuts execution on device.

Do not interpret a successful UI-extension build as evidence that Shortcuts automation can show it. Existing Action and Share extensions remain untouched.
