# Architecture

Short map of the Windows app and the browser-extension bridge. The end-to-end diagram lives in [README.md](../README.md#architecture).

## Data flow

```
Browser extension (MV3)
        │  WebSocket + API token
        ▼
HttpServer.bind(loopbackIPv4)     default port 6969
  LocalServerService              127.0.0.1 only
        │
        ▼
Riverpod DownloaderRepository
        │
        ├─► yt-dlp / gallery-dl (extract)
        │         │
        │         ▼
        │       aria2c (fetch)
        │         │
        │         ▼
        │       FFmpeg (mux / convert)
        │
        └─► optional gobird (X Feed only, experimental)
```

The extension never talks to yt-dlp. It sends the current tab URL (and optional X Feed requests) to the running desktop app. The app authenticates a `HELLO` message with the settings API token (`LocalServerAuth`), then queues downloads.

## Local server

- Bind address is **IPv4 loopback** (`127.0.0.1`), never a public interface.
- Default port **6969** (`AppSettings.serverPort`); restart required after a change.
- WebSocket upgrade on the same port. Clients must send `HELLO` with a token within two seconds or the socket is closed.
- Progress is broadcast back to connected extensions (`PROGRESS` payloads, throttled).
- Optional **X Feed**: `X_FEED_REQUEST` / `X_FEED_RESULT` (`lib/features/x_feed/`). Cookies are not allowed on that channel; gobird reads `auth_token` / `ct0` from a local Netscape heartbeat. Off by default — see `third_party/gobird/RISK_NOTICE.md`.

## App layers

State is **Riverpod**. Routing is **GoRouter** (`lib/core/router/app_router.dart`): `/`, `/stats`, `/settings` (+ general, output, advanced, performance, system, appearance, plugins, smart_organizer).

| Area | Location | Role |
|------|----------|------|
| Shell / settings / dock | `lib/core/ui/` | Window chrome, sidebar, floating dock, settings tiles |
| Local WS + binaries | `lib/core/services/` | Loopback server, notifications, yt-dlp updater, binary locator |
| Download pipeline helpers | `lib/core/download/` | Paths, cleanup, progress throttle, X URL helpers |
| Downloader feature | `lib/features/downloader/` | `domain` / `data` / `presentation` |
| X Feed feature | `lib/features/x_feed/` | gobird process + WS contract |
| l10n | `lib/l10n/` | ARB → `AppLocalizations` (en, fr, ar) |

`yt-dlp` and `gallery-dl` sources live under `lib/features/downloader/data/sources/`. The repository (`DownloaderRepositoryImpl`) owns the queue, persistence, and engine selection.

## Extensions

`extension/shared/` is the source of truth. `dart run tool/build_extension.dart` copies it into `extension/chrome/` and `extension/firefox/` and writes manifests. Firefox unlisted signing is CI-only (`AMO_JWT_*` GitHub secrets).

## Plugins

`lib/core/plugins/` — optional hooks on download start/complete/fail (Smart Organizer and similar). Not on the hot path for a normal yt-dlp download.
