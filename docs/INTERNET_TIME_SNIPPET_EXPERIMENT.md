# Internet Clock in Shortcuts Snippet — real online-data test

## Purpose

This test distinguishes a **network-fed live display** from a local clock animation.

The new Shortcuts action is **LAB: Internet Clock (Live)** (discoverable directly in DavLauncher). It uses the external [UTCTime API](https://utctime.app/api), which was checked from the connected Windows host and returned HTTP 200 and fields utc_iso/unix_ms. UTCTime publishes a fair-use limit of 10 requests/sec/IP, so this experiment targets roughly 1 request/sec. No key or personal data is sent, though the service naturally sees the requester's IP address.

## Exact mechanics

1. On first launch of the snippet, the intent awaits **one real HTTPS fetch** from the external API before returning the view. The rendered UTC and Israeli timestamps are derived solely from that server's response.
2. An actor-isolated shared monitor starts a polling task. Approximately once per second it makes a new HTTPS request with a fresh UUID query param and no-cache headers, decodes the actual unix_ms / utc_iso response, saves counts/latency, and calls InternetTimeSnippetIntent.reload().
3. **No local timer advances the visible clock.** The digits and success count only update after fresh network responses and successful snippet rerendering.
4. Each automatic experiment is capped at 120 seconds to avoid continuing public-API requests forever after the snippet is dismissed. **Restart** begins a fresh 120-second experiment.
5. The **Fetch now** AppIntent button is the positive control. It fetches the server and triggers a snippet refresh even if automated snippet reloads are throttled or the polling task has stopped.
6. **Stop automatic requests** cancels the monitor's polling task. The monitor is an in-process experiment; a fresh app process can start a new experiment.

## What to observe on iPad

Run **DavLauncher → LAB: Internet Clock (Live)** in the Shortcuts app. Keep the floating snippet visible for at least 15 seconds.

- Does the UTC time on-screen change **without taps**? Count changes in HTTPS successes and network attempts. If all grow by roughly 1 per second, the app can poll and iPadOS is accepting the snippet reloads.
- If the screen freezes, tap **Fetch now**. If it refreshes to a newer UTC server timestamp with an incremented success count, the fetch and manual reload work but continuous background refresh is restricted/throttled.
- If the initial fetch fails, verify network access and HTTP errors shown. The time must remain unchanged; an offline clock animation would conceal failure.
- Also compare **Restart** and **Stop automatic requests**.
- The timestamps are independent from the iPad system clock. UTC is taken from utc_iso, Israeli time is formatted from unix_ms using Asia/Jerusalem, not Date() or the current device time.

## Limits / caveats

Apple publicly documents SnippetIntent.reload() and notes that the app is kept active while a snippet is visible. It **does not guarantee** a one-second system-hosted render cadence; iOS may coalesce/throttle refreshes and may affect the app process/task lifetime. This is a measured experiment, not a claim of guaranteed live-second updates.

Docs:
- https://developer.apple.com/documentation/appintents/snippetintent
- https://developer.apple.com/documentation/appintents/displaying-static-and-interactive-snippets
- https://utctime.app/api
