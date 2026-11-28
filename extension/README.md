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

## Pairing with the desktop app

The extension no longer needs a pasted token. On first use it connects to the app on `127.0.0.1`, and the
app asks the user whether to allow this browser:

1. The extension shows `?` on its toolbar icon. Its popup shows a 4-digit code and "Waiting for approval in the app".
2. TapLoad shows the same code in an invitation. The user compares the two codes, then chooses **Allow**, **Deny** or **Always deny**.
3. On Allow the app sends a token over that same socket; the extension keeps it in `storage.local` and connects.
   Nothing is typed by the user again, and the token survives app restarts.

**Revocation.** Settings, Extension (and the other settings views) list the paired browsers. Revoking one closes
its socket at once, deletes its token, and pauses invitations from that browser for 10 minutes. After a revocation
the extension falls back to pairing: it never loops.

**Pauses.** Deny pauses the browser for 10 minutes, Always deny for 24 hours, and a fourth request within an hour is paused by the app.
If nobody answers within 2 minutes the request expires; the app sets no pause, and the extension waits 30 minutes before asking again by itself
(after a busy answer it waits 30 seconds). After a refusal or a revocation the popup only shows the remaining time
(the app's pause would refuse an earlier retry) and the extension asks again once the pause is over. Only after an expiry or a busy answer does the
popup offer a **Try again** button, which asks the background script to start over immediately.
The hourly limit is not a refusal: the popup says "Too many requests" with the time left and no button. Without a
token the extension schedules no reconnect before a pause ends (not every 10 seconds); only a restart of its
background script still makes one attempt.
Saving a setting or **Test connection** while a request waits keeps its socket, so the code does not change.

**Security.**

- Only a socket whose `Origin` is `chrome-extension://…` or `moz-extension://…` can ask to pair. A web page
  always sends its own `https://…` Origin, which a page cannot forge, and the app refuses the connection (403).
- Approval happens only in the desktop app. No WebSocket message approves a request, the comparison code is never
  logged, and it is shown for comparison only (it grants nothing by itself).
- One request is pending at a time per browser origin; a second browser origin waits (`PAIR_BUSY`).
- Each browser gets its own random token; the app keeps only its SHA-256, and tokens are revocable one by one.
- **Always deny** applies to the origin id shown in the invitation. A code that your popup does not show means
  the request does not come from your TapLoad extension (a local program can claim any origin, including yours).

**Manual token.** The token field remains in the popup under **Advanced** (collapsed). A token pasted from TapLoad,
Settings, Extension still works exactly as before and never triggers pairing.

**Older app.** If the app answers the pairing request with a bare `AUTH_FAILED`, the popup says "Update the app".

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
