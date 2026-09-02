# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- MIT `LICENSE` at the repository root.
- Contributor docs: `CONTRIBUTING.md`, `docs/ARCHITECTURE.md`, GitHub issue templates.
- CI line-coverage floor (20%) after `flutter test --coverage`.
- Storage Usage: on-disk folder size scan, donut slice, details, and l10n keys.
- i18n for system notifications, tray menu, clipboard errors, settings dropdowns, sidebar sources, and extension appearance / quality UI.

### Changed

- GitHub URLs and release/extension homepage links now use **itsnazzym/Downloader**.
- Download list size sort compares byte sizes instead of formatted strings.
- Floating dock includes Stats; sidebar exposes Smart Organizer.

### Removed

- Unused theme facade and dead typography; merged stray `tools/` scripts into `tool/`.

### Fixed

- CI Windows release compile on MSVC 14.51 (VS 18): silence STL1011/C2338 from plugin C++/WinRT experimental coroutine headers.
- CI now builds Windows installer/portable zip and an Android release APK as downloadable artifacts on `pull_request` and `workflow_dispatch` (version bump + GitHub Release stay limited to `push` to main).
- Hardened download pipeline, X library titles, and the extension feed panel.
- Extension / X feed: skip Discord invite pages, map quoted videos to the tweet that actually has the video, and fail immediately on suspended or video-less tweets instead of retrying.

## [1.0.6] - 2026-08-27

### Added

- Optional experimental gobird X Feed (bundled Windows binary, opt-in in Advanced settings).
- Release packaging for gobird alongside the Windows artifacts.

### Fixed

- Firefox add-on version bump so AMO unlisted signing can succeed.
- Release workflow skips git tags that already exist when bumping the version.
- Await Futures returned inside `try` blocks.
- Theme tests no longer require a network font download.

## [1.0.5] - 2026-03-19

### Added

- Release `v1.0.5` (Windows app + browser extensions).

## [1.0.4] - 2026-02-15

### Added

- Windows installer (`.exe`) in the release workflow.
- Core app structure: downloader features, services, glass UI, FR/EN/AR l10n.

### Changed

- Dart 3 wildcard captures instead of unused `_` identifiers.

### Fixed

- Installer `.exe` path in the release workflow.
- `MediaPlayerNotifier` testable via `testMode`.

## [1.0.3] - 2026-02-01

### Added

- Link grabbing: URL scan, video selection, and download queue integration.

### Changed

- Direct `crypto` dependency in `pubspec.lock`.

### Fixed

- Logging for new download errors.

## [1.0.1] - 2026-01-31

### Fixed

- Widget tests mock native desktop plugins; AppShell coverage.

## [1.0.0] - 2026-01-31

### Added

- Initial Windows downloader (Flutter), local WebSocket bridge, Chrome/Firefox MV3 extensions.
- GitHub Actions CI and automated releases.

[Unreleased]: https://github.com/itsnazzym/Downloader/compare/v1.0.6...HEAD
[1.0.6]: https://github.com/itsnazzym/Downloader/compare/v1.0.5...v1.0.6
[1.0.5]: https://github.com/itsnazzym/Downloader/compare/v1.0.4...v1.0.5
[1.0.4]: https://github.com/itsnazzym/Downloader/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/itsnazzym/Downloader/compare/v1.0.1...v1.0.3
[1.0.1]: https://github.com/itsnazzym/Downloader/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/itsnazzym/Downloader/releases/tag/v1.0.0
