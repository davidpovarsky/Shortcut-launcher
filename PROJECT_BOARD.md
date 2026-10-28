# Project Board

This is a living working-memory document for this repository.
It is intentionally lightweight. Humans and coding agents should update it when useful discoveries, ideas, plans, optimizations, problems, or follow-up work arise during normal development.
Do not turn this into a duplicate issue tracker or a dump of temporary thoughts.

## Inbox

Quick captures that still need classification.

## Ideas & Opportunities

Potential improvements, features, optimizations, or architectural ideas.

## Discoveries & Tips

Useful technical discoveries, undocumented behavior, shortcuts, implementation tricks, platform behavior, or reusable knowledge discovered while working.

- Runtime system menus: IntentChoiceOption only exposes title and semantic style; for title/subtitle/image rows during an App Intent, requestDisambiguation(among:) with transient AppEntity values is a better fit. Use per-invocation IDs and App Group-backed EntityQuery resolution. Picker appearance remains system-controlled and is not identical to native vCard Contacts or Actions MenuItem.

## Experiments / Investigations

Things worth testing or researching before deciding whether to implement them.

- [ ] Investigate iPadOS snippet-host restrictions: user observed yellow/red prohibited-content placeholder instead of WebKit.WebView while native SwiftUI text rendered. Test four isolated actions: Native Snippet Controls; Snippet ShareLink; Compact SwiftUI WebView(url:) (180 pt); and Compact UIKit WKWebView (UIViewRepresentable, 180 pt). Compare on iPad to separate unsupported web views from sizing issues. See docs/WEBVIEW_SNIPPET_EXPERIMENT.md.
- [ ] Test one-second real-network Snippet reloads: LAB: Internet Clock (Live) fetches https://utctime.app/api/now every ~1s and calls InternetTimeSnippetIntent.reload() after each response, with counters and a manual Fetch-now control. Verify on iPad whether automatic visible updates occur (not just the manual AppIntent redraw). See docs/INTERNET_TIME_SNIPPET_EXPERIMENT.md.

## Open Questions

Important unresolved questions or uncertainties.

- [ ] Can iPadOS 27 Shortcuts continue when a native `requestConfirmation` is denied and the App Intent deliberately catches the thrown cancellation? Check `LAB: Confirmation Back or Next`, then `LAB: Read Confirmation Trace`; compare accepted `next` versus denied `back`. Apple's guidance discourages catching cancellation. Test steps: docs/CONFIRMATION_BACK_NEXT_EXPERIMENT.md.

## Planned / Todo

Concrete work that is worth doing but is not part of the current task.

- [ ] iPad acceptance: LAB: Wikipedia Discovery should show an image/title/summary inside a native confirmation snippet; tapping חפש שוב should fetch a *different* random MediaWiki article while the same Shortcut remains suspended; tapping פתח should return the article's URL to the next Shortcut action. See docs/WIKIPEDIA_DISCOVERY_EXPERIMENT.md. The catch-on-denial pattern is experimentally known to work on this iPadOS version, not Apple-guaranteed.

Use Markdown checkboxes where useful:

- [ ] Example item

## Done

Completed items that are still useful to retain because they document an important decision, discovery, or implementation.

- [x] Streamline Package unsigned IPA GitHub Actions path to device Release build + ad-hoc entitlement signing + IPA artifact, removing redundant XcodeGen, repeated notifications, simulator/tests and unnecessary diagnostics. Preserve full iOS 27 CI separately for comprehensive checks. See docs/WIKIPEDIA_DISCOVERY_EXPERIMENT.md.

Example:

- [x] Example improvement
  - Implemented: YYYY-MM-DD
  - Commit/PR: ...
  - Notes: ...

## Archive

Older completed/superseded items that still have historical value.
