# Chrome Web Store Checklist

## Before packaging

- Confirm the extension version matches `pubspec.yaml`.
- Run `node --test extension/chrome/tests/common.test.js`.
- Run `node --check extension/chrome/background.js`.
- Run `node --check extension/chrome/content.js`.
- Run `node --check extension/chrome/popup.js`.
- Run `flutter analyze`.
- Run `flutter test`.

## Package output

- Run `powershell -ExecutionPolicy Bypass -File tools/build_chrome_extension.ps1`.
- Verify the unpacked output in `build/extension/chrome`.
- Verify the release zip in `build/extension/modern_downloader_chrome_v<version>.zip`.

## Review before upload

- Confirm the extension only targets supported video sites.
- Confirm there is no `Audio Only` flow in the injected UI or context menu.
- Confirm photo and gallery URLs are rejected before they are sent.
- Confirm the popup shows connection diagnostics and the last error.
- Confirm the popup can open the desktop app and test the connection.
- Confirm the extension requests only the permissions listed in `manifest.json`.
- Confirm localhost auth works against the desktop app.
- Confirm the site blocklist and allowlist work on at least one site each.
- Confirm recent jobs render without using HTML injection.

## Store submission

- Load the unpacked extension in Chrome and smoke test on supported sites.
- Capture updated screenshots of the popup and injected button state.
- Update the Chrome Web Store description to mention video-only scope.
- Upload the new zip package.
- Record the published version and release date.
