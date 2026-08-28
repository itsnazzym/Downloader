# Browser extensions

Shared sources live in `extension/shared/`. Packaged outputs:

- `extension/chrome/` — Chrome / Chromium MV3 (service worker + offscreen WebSocket)
- `extension/firefox/` — Firefox MV3 (background scripts)

## Build

```bash
dart run tool/build_extension.dart
```

## Install (developer)

See the root [README.md](../README.md) section **Browser extensions**.

## X feed panel

On `x.com`, open the extension popup and choose **X Feed** (or open the browser sidebar).
The panel keeps every unique video post it observes during the current tab
session (up to a high safety limit of 10,000 items). Scrolling X remains
user-controlled; the panel does not scroll the page for you.

**Default source:** local DOM extraction of posts already loaded in the active tab
(“For You — local”).

**Optional experimental source:** when the desktop app has *Use gobird (experimental)*
enabled (Advanced settings, consent required), the panel first asks the app for a
bounded read-only home feed via authenticated WebSocket (`X_FEED_REQUEST`).
Live DOM collection stays on and merges with that snapshot.
Cookies are **not** sent on that channel. On Windows, the extension refreshes a
local Netscape cookie heartbeat and the desktop app supplies only `auth_token` and `ct0` to gobird
through its child-process environment (never command-line arguments). If gobird
is disabled, missing, offline, or errors, the panel shows the reason and may
fall back to the local DOM feed. No unofficial X API logic runs inside the
extension itself.

Select the videos you want and send them to the local desktop app one at a time.

## Privacy

See [privacy.md](privacy.md).
