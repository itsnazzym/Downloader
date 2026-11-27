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

### Panel

- **Stable order.** Items keep the order in which X (or TikTok) showed them;
  new posts that arrive while you scroll do not reshuffle the list. A
  "new videos" chip tells you how many arrived, and a toggle switches between
  feed order and most recent first.
- **Selection.** Click a card to select it, Shift+click for a range, or drag
  across cards with the mouse (long-press then drag on touch screens). Send the
  selected videos to the local desktop app.
- **Creator profile.** The profile button on a card opens the creator's page on
  the right platform. It is only shown for X and TikTok, and the handle is
  derived from the video's own URL.
- **Download queue.** The panel follows the desktop queue: progress, speed and
  an estimated time left for each download, plus cancel (running), remove
  (queued), retry (failed) and cancel all. The **Downloads** tab lists them.
- **X like / bookmark.** Each X card has Like and Bookmark buttons (see below).
- **Theme.** Colours, radii and shadows follow the design chosen in the desktop
  app and update live when it changes. The stylesheets only add fallback values
  on `:root` (used until the app sends its theme), translucent `rgba()`
  shadows and overlays, and white on video thumbnails; a test rejects any other
  hard-coded colour. The extension icons are the desktop app logo.
- **Offline.** When the desktop app is not running the panel says so and
  reconnects by itself when the app comes back.
- **Languages.** English, French and Arabic (right-to-left layout included).

### Like and bookmark on X

The buttons call X's own web endpoints from the `x.com` tab, with the session
you are already signed in with, as if you clicked on the site:

- The content script reads the `ct0` CSRF value from the page cookie and fetches
  X's own web bundle (`abs.twimg.com`, without credentials) to discover the
  current GraphQL query identifiers and the web-app bearer. Nothing is sent to
  the desktop app or to any third party.
- A one-time warning explains that this is unofficial, goes through your
  account and may be limited by X; you confirm once (stored locally).
- Requests are throttled in the extension (about 1.5 s apart, 30 per minute).
  If X still answers with a limit, the panel shows a rate message and pauses
  the buttons for a few seconds.
- If the API route fails, the extension falls back to clicking the real button
  on the page when the post is rendered.

### Known limits

- Like/bookmark need an open, signed-in `x.com` tab and may break when X changes
  its web app (the panel then asks you to reload the tab).
- The panel keeps up to 10,000 items per tab session; scrolling stays yours.
- Profile buttons exist for X and TikTok only.

## Privacy

See [privacy.md](privacy.md).
