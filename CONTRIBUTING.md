# Contributing

Windows-first Flutter desktop app plus Manifest V3 browser extensions. Product target is **Windows 10/11**; other platform folders are not a support goal.

## Setup

1. Fork [itsnazzym/Downloader](https://github.com/itsnazzym/Downloader) and clone your fork.
2. Install [Flutter stable](https://docs.flutter.dev/get-started/install/windows) (SDK `^3.10` per `pubspec.yaml`).
3. From the repo root:

```bash
flutter pub get
flutter analyze
flutter test
dart run tool/build_extension.dart
```

Optional: `flutter run -d windows` for the desktop UI.

After changing `extension/shared/`, always re-run `dart run tool/build_extension.dart` so `extension/chrome/` and `extension/firefox/` stay in sync.

## Pull requests

- Branch from `main` / `master` (`feature/…` or `fix/…`).
- Keep PRs focused. Do not commit secrets, `.env`, AMO JWT keys, or local binaries (`bin/gobird.exe`, signed `.xpi`).
- Use `.env.example` as the template for local Firefox signing; never copy real keys into git.
- Before opening a PR, run:

```bash
dart format --output=none --set-exit-if-changed lib/ test/ tool/
flutter analyze
flutter test
```

CI (`.github/workflows/ci.yml`) runs the same format check, `flutter analyze --no-fatal-infos`, `flutter test --coverage`, then a **20% line-coverage floor** (`dart run tool/check_coverage.dart`).

### Analyzer

`analysis_options.yaml` includes `package:flutter_lints/flutter.yaml`. CI keeps `--no-fatal-infos` because `flutter analyze` is **not** clean of infos/warnings yet (including `duplicate_ignore` on `LoggerService`). Do not drop `--no-fatal-infos` until a full `flutter analyze` (no extra flags) exits 0. Do not tighten lints in `analysis_options.yaml` in drive-by PRs.

## Dart style

Match the file you edit. The repo is formatted with `dart format`; quote style is mixed (`prefer_single_quotes` is not enabled). Conventions:

- Follow existing imports (`package:modern_downloader/…` or relative) in that file.
- Prefer explicit types; avoid unused `dynamic` except JSON/`Map<String, dynamic>` boundaries.
- User-visible strings go in ARB (`lib/l10n/app_en.arb`, `app_fr.arb`, `app_ar.arb`) — do not hardcode UI copy.
- Do not add empty `catch` blocks; log with `LoggerService`.
- Feature code lives under `lib/features/<name>/{domain,data,presentation}/`. Shared UI, settings, and the local server live under `lib/core/`.

## Tests

```bash
flutter test
flutter test --coverage
dart run tool/check_coverage.dart
```

Widget tests that touch plugins should mock native channels (see existing `test/` helpers). Coverage is line-based from `coverage/lcov.info`; the CI floor is conservative (20%) so refactors can land without going red.

## Architecture

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and the mermaid diagram in [README.md](README.md).
