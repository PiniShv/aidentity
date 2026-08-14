# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.0] - 2026-08-14

Four commands that close gaps found in review, a recorded demo, and a live
Homebrew tap. No change to how launchers work, so existing profiles keep
running untouched.

### Added

- `aidentity rename OLD NEW` (alias `mv`) — renames a profile and moves its
  data directory with it, so the account stays signed in. The data is moved
  first and the launcher rebuilt second; if the rebuild fails the move is rolled
  back, because a recoverable half-rename beats a lost session. Refuses while
  the profile is running, since moving the directory out from under a live
  instance would break it, and refuses a name that collides with an existing
  launcher or data directory.
- `aidentity set NAME` (aliases `modify`, `edit`) — changes `--badge`,
  `--color` or `--no-badge` in place. Only the launcher bundle is rewritten and
  the profile directory is never opened, so it is safe with the app running.
- `aidentity prune` — finds profile data that no launcher points at, which is
  what a launcher deleted in Finder leaves behind, and offers to remove it.
  Lists each orphan with its disk size, asks for a typed `yes` unless `-y` is
  given, and skips anything running or recorded outside the data root. That data
  was previously unreachable forever.
- `aidentity rebuild NAME` / `--all` (alias `repair`) — regenerates launchers
  after the target app moves or is reinstalled. If the recorded path is gone it
  looks the app up again by name, which covers a move between `/Applications`
  and `~/Applications`. Profile data is never touched.
- The badge character and colour are now recorded in the launcher's
  `Info.plist`, so `set` and `rebuild` can regenerate an icon without asking you
  to remember what you picked.
- `AIDENTITY_APP_DIRS` — colon-separated list of directories to search for apps,
  default `/Applications:$HOME/Applications`. `list_compatible_apps` and
  `resolve_app` previously hardcoded `/Applications`, so the test suite scanned
  the developer's own machine and any recording would have published their app
  list. The case-insensitive fallback walks the same path instead of a second
  hardcoded list.
- `assets/demo.gif` in the README — a terminal recording made entirely inside a
  sandbox: `HOME`, the app search path, the launcher directory and the data root
  all point at `/tmp` fixtures, so no real app list, username, hostname or path
  can appear. `assets/record-demo.sh` regenerates it from `assets/demo.tape`.
- A published `SHA256SUMS`, with a CI gate so it cannot go stale, and
  `make checksums` to regenerate it.
- The Homebrew tap is live: `brew install pinishv/tap/aidentity`, or
  `brew tap pinishv/tap && brew install aidentity`. Homebrew does not run the
  walkthrough — run `aidentity setup` after installing.

### Changed

- The badge loop makes one `osascript` call for every icon size instead of one
  per size. Icon generation went from roughly 690ms to 330ms: starting the Cocoa
  runtime costs far more than the drawing does.
- The logo and app icon were redrawn as vector art. The previous mark had a dark
  background baked in, so it appeared as a dark rectangle on GitHub's light
  theme and could not be used as an app icon. `assets/logo.svg`,
  `assets/icon.svg`, `assets/aidentity.icns` and raster fallbacks.

### Fixed

- `add` reported success after a failed build. `build_launcher` ran inside
  `$(…)`, so its `die()` exited only the subshell and `add` went on to print
  "✓ Created" and exit 0 with no launcher on disk.
- `uninstall.sh` could delete a running profile's data. Its running check used
  `pgrep -af`, and on macOS `-a` means "include ancestors", not "print argv", so
  the guard never fired. It now matches `bin/aidentity` exactly.
- `rm --purge` could escape its own data root two ways: `"$DATA_ROOT//"` passed
  the prefix test yet *is* the root, and a symlink inside the root was followed
  out of it. The guard resolves paths now instead of comparing strings.
- Distinct profile names could collapse onto one data directory, because
  slugifying folds spaces, underscores and hyphens together — three launchers
  silently shared one account. Collisions are refused with an explanation.
- App bundle names went unescaped into the generated `Info.plist`, so a name
  like "Barnes & Noble" produced a plist aidentity could no longer read, leaving
  a bundle it could neither remove nor overwrite.
- The running check matched unanchored, so a profile at `…/claude-work` matched
  a running `…/claude-work-2` and froze an unrelated profile.
- The data-root check looped forever on a relative path: `"${head%/*}"` reaches a
  fixed point that never equals its input. Because `rm --purge` deletes the
  launcher before that call, the user was left with a wedged process eating
  memory and a half-removed profile. Paths must now be absolute and free of dot
  segments, which also makes the walk-up provably terminate, and both the
  launcher directory and data root are anchored at startup so a relative
  override cannot reach it.
- The running check treated "`pgrep` failed" the same as "nothing is running",
  so a data-loss guard failed open. Anything but exit 0 or 1 now reports the
  profile as running and the caller refuses to delete.
- Backticks inside the unquoted help heredoc were command-substituted, so
  `aidentity help` actually executed `mv` and printed its usage.
- A `local want="$1" app="…$want…"` built the path from a stale value, because
  the second assignment on that line cannot see the first.
- The walkthrough ran the profile-name check in a subshell and discarded its
  message, then printed a generic rule that often did not match why the name was
  refused. It now reports the actual reason and re-prompts instead of ending the
  session — the continue-on-failure branch was previously unreachable.
- Menu choices parse as base 10 (`010` used to select the eighth app), relative
  app paths are made absolute (a launcher built from a relative path could never
  start), `--seed` no longer copies Claude's config into other apps, and a
  launcher with no icon drops the key rather than declaring a missing file.
- CI: the multi-byte-character guard used `grep -P`, which BSD grep rejects, so
  the step passed unconditionally on macOS. It moved to a Linux job that can
  actually fail, alongside checks for the `install.sh` end-marker contract and
  for drift between the safety helpers duplicated across scripts.

### Security

- **Path traversal in `install.sh`.** `AIDENTITY_REF` was interpolated raw into
  the `raw.githubusercontent.com` path, and curl collapses dot-segments before
  sending the request. A ref of `../../../owner/repo/branch` therefore made the
  installer fetch and install `bin/aidentity` from an entirely different GitHub
  account — confirmed live against a real URL. Refs are now validated: no `..`,
  no leading or trailing `/`, and only `[A-Za-z0-9._/-]`. Branch names
  containing slashes still work.
- **The installer verifies a checksum.** Its previous `verify()` was a marker
  match, not an integrity check: a hand-written 2KB file that satisfied the size,
  shebang, version-marker, syntax and end-marker checks installed `0755` and was
  then offered for execution. `SHA256SUMS` is now fetched and compared before
  anything is staged. What that buys, stated plainly: it catches truncation,
  corruption and a proxy swapping the body, but not a compromise of the
  repository, because the checksum is served from the same origin as the file.
  The Homebrew formula pins a sha256 committed at release time, which remains
  the stronger channel.

### Tests

225 assertions at 1.0.0, 279 now.

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

[Unreleased]: https://github.com/PiniShv/aidentity/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/PiniShv/aidentity/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/PiniShv/aidentity/releases/tag/v1.0.0
