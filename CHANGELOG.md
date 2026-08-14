# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-08-14

First release.

### Added

- `aidentity setup` (aliases `init`, `wizard`) — the guided walkthrough, and the
  recommended starting point. Asks whether to badge the icons, lists the
  compatible apps on this Mac by number, asks what to call each account, offers
  to copy Claude Desktop's MCP config, then loops so several accounts can be set
  up in one pass. Ends by offering to open `~/Applications`. Needs a terminal;
  scripts should use `add` with flags.
- `aidentity add [app]` — builds a launcher app for a second (third, fourth)
  account of an app you already have. The direct, scriptable form of `setup`.
  Run it with no arguments for a guided pick-from-a-list setup, or name the app
  directly. Options: `--profile NAME`, `--badge X`, `--color NAME`,
  `--no-badge`, `--seed`.
- `aidentity list` — every profile, the app it targets, where its data lives,
  and whether it is running right now.
- `aidentity open NAME` — launch a profile from the terminal.
- `aidentity rm NAME` — remove a launcher. Keeps the profile data unless you
  pass `--purge`. `-y` skips the confirmation prompt.
- `aidentity apps` — the Chromium- and Electron-based apps on this Mac that can
  take extra accounts.
- `aidentity doctor` — macOS version, aidentity version, bash version, launcher
  directory writability, whether `codesign` is available, and how many
  compatible apps and profiles were found. This is the output to attach to a
  bug report.
- `aidentity version` and `aidentity help`.
- Badged icons: the source app's icon with a coloured circle and a letter,
  composited using only `iconutil` and `osascript -l JavaScript`. Colour is
  chosen deterministically from the profile name unless `--color` says
  otherwise, so a profile always looks the same. The 16x16 and 32x32 sizes are
  left unbadged because a letter is illegible at those sizes. If badging fails
  for any reason, the launcher falls back to the app's plain icon — it is never
  a fatal error.
- `--no-badge` skips the badge and gives the launcher the source app's icon
  unchanged — byte-identical to the app's own `.icns` — under the profile's
  name. The walkthrough asks this as a question, defaulting to badges on.
- `--seed` copies Claude Desktop's existing MCP server configuration into a new
  profile, which otherwise starts empty. The two diverge afterwards.
- `AIDENTITY_APPS_DIR` and `AIDENTITY_DATA_ROOT` override where launchers and
  profile data go. The test suite uses them to run without touching a real
  machine.
- `install.sh` ends by offering to run `aidentity setup`, so a `curl … | bash`
  takes you from nothing to a working second account in one command. The prompt
  and the walkthrough both read from `/dev/tty`, because stdin is the installer
  script itself during a piped install; with no terminal (CI, provisioning) the
  offer is skipped.
- Homebrew formula for the `PiniShv/tap` tap.

### How it works

Chromium and Electron apps keep their single-instance lock (`SingletonLock`,
`SingletonCookie`, `SingletonSocket`) inside the user data directory. Give a
second instance a different `--user-data-dir` and the two never see each other's
lock, so both run at once, each signed into its own account.

The launcher is a hand-written `.app` bundle — a `/bin/sh` script, an
`Info.plist`, and an `icon.icns` — that runs `open -na <the app you already
have> --args --user-data-dir=<this profile>`. `LSUIElement` is set, so the
launcher itself shows no Dock tile of its own.

The real app is never copied, patched or re-signed. That is what keeps its Apple
signature, its keychain access groups (so SSO and passkeys keep working) and its
auto-update intact. Nothing needs re-running when the app updates.

### Security

- Every launcher carries a custom `Info.plist` key, `AIdentityProfile`.
  aidentity refuses to modify or delete any bundle that lacks it, so `rm` is
  safe even if a profile is named after an app you already have installed.
- `--purge` refuses to delete anything outside its own data root, regardless of
  what path a bundle's plist records.
- Profile names are restricted to letters, numbers, spaces, hyphens and
  underscores; 40 characters maximum; no leading or trailing space; no leading
  dot. Paths embedded in the generated launcher are shell-quoted.
- The generated `Info.plist` is checked with `plutil -lint` before the launcher
  is considered built.
- No network access of any kind: no telemetry, no update check, no crash
  reporting.

### Known limitations

- macOS only. Requires the bash that ships with macOS (3.2) — no bash 4+
  features anywhere in the script.
- Genuinely native apps (Swift/AppKit) are not supported, because they have no
  `--user-data-dir`. ChatGPT Classic (`com.openai.chat`) is the reference
  example. Note that the current ChatGPT app (`com.openai.codex`) is Chromium
  under the hood and does work.
- Confirmed working on Claude Desktop (`com.anthropic.claudefordesktop`) and
  ChatGPT (`com.openai.codex`). Detection also finds Slack, VS Code, Cursor,
  Notion, Notion Calendar, Postman, Microsoft Teams classic, Chrome, Edge,
  Brave, Arc, Vivaldi, Comet, Antigravity, Kiro and Podman Desktop.
- Both ChatGPT and Claude offer built-in account switching on some plans.
  aidentity is for when you want the accounts signed in at the same time, in
  separate windows.

[Unreleased]: https://github.com/PiniShv/aidentity/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/PiniShv/aidentity/releases/tag/v1.0.0
