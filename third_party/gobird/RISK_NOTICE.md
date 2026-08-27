# gobird — experimental risk notice

Modern Downloader may optionally bundle [gobird](https://github.com/mudrii/gobird)
(MIT License) as an **experimental**, **opt-in**, **read-only** engine for the
X feed panel on Windows.

## Important

- gobird uses **unofficial / private X (Twitter) APIs**. This can violate the
  X Terms of Service and may expose your account to **suspension or permanent ban**.
- Upstream behaviour can break **without notice**.
- The feature is **OFF by default**. Enabling it in Advanced settings requires
  explicit consent.
- Modern Downloader only allows the read-only `home` command with
  `--json --quiet --count 1..100`. When no local heartbeat credentials are
  available, the configured `--browser chrome|firefox` fallback is used.
- No write commands, free-form arguments, account rotation, or proxy settings
  are passed to gobird.
- Cookies stay on your machine. The extension writes a local Netscape heartbeat,
  and only `auth_token` and `ct0` are supplied to the gobird child process via
  environment variables; they are never placed in command-line arguments.
- The local DOM feed remains the default and automatic fallback.

Pinned Windows release: `26.05.13`
Archive: `gobird_26.05.13_windows_amd64.zip`
