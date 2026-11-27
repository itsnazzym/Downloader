# Privacy Policy — TapLoad Browser Extension

**Last updated:** 2026-11-27

## What this extension does

TapLoad helps you send public video page URLs from supported sites (YouTube, Instagram, X/Twitter, TikTok, Twitch, Facebook) to the **TapLoad desktop application** running on your computer (`127.0.0.1`). On X.com, an optional local feed panel can analyze video posts already loaded in the active page after the user explicitly requests it.

## Data collected and where it goes

| Data | Purpose | Destination |
|------|---------|-------------|
| Page / media URLs you choose to download | Start a download in the desktop app | Local WebSocket to `127.0.0.1` only |
| X post text, author, thumbnail, and video metadata from the loaded page | Show selectable local feed results | Extension panel memory only |
| Optional experimental gobird feed results (normalized metadata only) | When enabled in the desktop app, show selectable home-feed videos | Local WebSocket `X_FEED_RESULT` only |
| Cookies for the active supported site (optional, user-controlled) | Authenticated downloads via yt-dlp and, when gobird is enabled, local X feed authentication | Local WebSocket to `127.0.0.1` only; gobird receives only `auth_token` and `ct0` through a local child-process environment |
| User-Agent / referrer | Improve download compatibility | Local WebSocket to `127.0.0.1` only |
| Extension settings (port, token, UI prefs) | Configuration | Browser `storage.local` on your device |
| Like / bookmark requests on X (the id of the post you act on) | Like or bookmark a post with your own account when you press the button | `x.com` only, sent from your `x.com` tab with your own signed-in session |
| X web app scripts (`abs.twimg.com`) | Read X's current API identifiers so the request is valid | Downloaded into the tab and read there; nothing is sent in return |

**We do not** send your browsing data, cookies, or download history to any remote server operated by us. There is no analytics or advertising network.

## Permissions

- **activeTab / host permissions (listed video sites):** read the current page URL, inject the optional download button, and—only after a user action—read video posts already rendered in the active X.com page.
- **cookies:** read cookies for supported sites when Auto-Cookies is enabled, so the desktop app can access age-gated or login-required media. For experimental gobird, the active X session is written to a local heartbeat and only the two required X session values are supplied to the local gobird process.
- **storage:** save settings and a short sanitized recent-download list (no cookies).
- **contextMenus / alarms / offscreen (Chrome):** context-menu downloads and a durable local WebSocket to the desktop app.

Adult-site host access is **optional** and not granted by default.

## Like and bookmark on X

When you press Like or Bookmark on a post, the extension's content script, running in your `x.com` tab, sends the request to X's web API (`x.com/i/api/graphql`) with your own session, as if you clicked on the site. It reads the CSRF value (`ct0`) from the page and fetches X's own web bundle from `abs.twimg.com` (without credentials) to find the current API identifiers. The session cookie, the CSRF value and the bearer stay in that tab: they are not stored, not sent to the TapLoad desktop app for these actions, and not sent to any third party. If that API call cannot be used (X's identifiers could not be read or are outdated, or the call fails for an unexpected reason), the content script instead clicks X's own Like or Bookmark button on that post, once, when the post is loaded in the page; it clicks nothing when the post is already liked or bookmarked as requested. X's web app then sends its usual request. A rate-limit (429) or authentication answer is reported to you without this fallback. A one-time warning is shown before the first use; its acknowledgement is kept in `storage.local`. This feature is unofficial and X may rate-limit or restrict accounts that use it heavily.

The extension does not bundle any private X API client library; the like/bookmark requests above are the only direct calls to X, and they are made only on your action. Experimental gobird access (if enabled) runs only inside the local desktop app.

## Local authentication

The desktop app requires an API token. The extension sends the token only inside the WebSocket `HELLO` message (never in the connection URL query string).

## Contact

Project: https://github.com/itsnazzym/Downloader
