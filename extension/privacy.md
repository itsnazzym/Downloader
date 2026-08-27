# Privacy Policy — Modern Downloader Browser Extension

**Last updated:** 2026-08-26

## What this extension does

Modern Downloader helps you send public video page URLs from supported sites (YouTube, Instagram, X/Twitter, TikTok, Twitch, Facebook) to the **Modern Downloader desktop application** running on your computer (`127.0.0.1`). On X.com, an optional local feed panel can analyze video posts already loaded in the active page after the user explicitly requests it.

## Data collected and where it goes

| Data | Purpose | Destination |
|------|---------|-------------|
| Page / media URLs you choose to download | Start a download in the desktop app | Local WebSocket to `127.0.0.1` only |
| X post text, author, thumbnail, and video metadata from the loaded page | Show selectable local feed results | Extension panel memory only |
| Optional experimental gobird feed results (normalized metadata only) | When enabled in the desktop app, show selectable home-feed videos | Local WebSocket `X_FEED_RESULT` only |
| Cookies for the active supported site (optional, user-controlled) | Authenticated downloads via yt-dlp and, when gobird is enabled, local X feed authentication | Local WebSocket to `127.0.0.1` only; gobird receives only `auth_token` and `ct0` through a local child-process environment |
| User-Agent / referrer | Improve download compatibility | Local WebSocket to `127.0.0.1` only |
| Extension settings (port, token, UI prefs) | Configuration | Browser `storage.local` on your device |

**We do not** send your browsing data, cookies, or download history to any remote server operated by us. There is no analytics or advertising network.

## Permissions

- **activeTab / host permissions (listed video sites):** read the current page URL, inject the optional download button, and—only after a user action—read video posts already rendered in the active X.com page.
- **cookies:** read cookies for supported sites when Auto-Cookies is enabled, so the desktop app can access age-gated or login-required media. For experimental gobird, the active X session is written to a local heartbeat and only the two required X session values are supplied to the local gobird process.
- **storage:** save settings and a short sanitized recent-download list (no cookies).
- **contextMenus / alarms / offscreen (Chrome):** context-menu downloads and a durable local WebSocket to the desktop app.

Adult-site host access is **optional** and not granted by default.

The extension never embeds unofficial/private X API clients. Experimental gobird access (if enabled) runs only inside the local desktop app.

## Local authentication

The desktop app requires an API token. The extension sends the token only inside the WebSocket `HELLO` message (never in the connection URL query string).

## Contact

Project: https://github.com/Mizaruta/Downloader
