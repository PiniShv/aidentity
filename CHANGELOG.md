# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Help for one command: `aidentity COMMAND --help`, `aidentity COMMAND -h` and
  `aidentity help COMMAND` print that command's usage, its options with a short
  meaning each, and examples. Every command and alias has one. `--help` or
  `-h` anywhere after a command shows the help and does nothing else, so
  `aidentity rm Work --purge --help` removes nothing. `aidentity help` with an
  unknown name exits 1. `aidentity help`, `aidentity -h`, `aidentity --help` and
  `aidentity` on their own print the overview as before, which now lists
  `completion` and the per-command help.
- `aidentity completion bash|zsh|fish` prints a tab-completion script. It
  completes command names and aliases, each command's options, the names of
  profiles for `open`, `rename`, `set`, `rebuild`, `restore` and `rm`, app names
  for `add`, colour names after `--color`, and the shells for `completion`.
  A name with a space or another special character is escaped for you, also
  after an opening quote, where it is escaped for that quote. In bash, a name
  with `!` is not offered after an opening double quote. The names come from a
  hidden `aidentity __complete` command, which prints nothing on error. The
  Homebrew formula installs the three scripts.
- `aidentity update` installs the latest release from GitHub in place of the
  copy you run. It downloads that release's `bin/aidentity` and `SHA256SUMS`
  over HTTPS and installs nothing unless the checksum matches, the file is a
  complete shell script, and it says it is the version of the release tag.
  The new file is written beside the old one and moved into place in one step,
  so a failed update leaves the old file exactly as it was. It never downgrades
  and never runs `sudo`: when you cannot write to the folder, it prints the
  command to run yourself. A Homebrew copy is left to `brew upgrade aidentity`,
  and a copy in a git checkout to `git pull`. `aidentity update --check` only
  says whether a newer release is out and installs nothing.
- `aidentity help` lists the `AIDENTITY_*` environment variables the script
  reads.

### Security

- `aidentity update` is the only command that uses the network, and only when
  you run it. It contacts `api.github.com` for the latest release tag and
  `raw.githubusercontent.com` for the files. The tag must be a plain version
  number before it is used in a URL or shown. `SECURITY.md` now says this
  instead of "no network calls".
- `aidentity update` does not read your `~/.curlrc`. A setting there could
  otherwise turn off certificate checks or change where a download is saved.
  A proxy set with `https_proxy` still works.

## [1.3.0] - 2026-10-23

### Added

- `aidentity list --json` prints every launcher as one JSON array, for scripts
  and other front ends. Every object has the same keys: `name`, `app`,
  `app_path`, `profile`, `data_dir` (null for a main launcher), `main`,
  `status` (`running`, `in use`, `signed out / new`, `app missing` or
  `not running`), `badge` (null for the app's own icon), `color`, `built_by`
  (the aidentity version that built the launcher), `args`, `env` and
  `own_extensions`. `env` holds variable names only, never values, as in the
  plain list. With no profiles it prints `[]`. The plain `list` output is
  unchanged.

### Changed

- `list` now refuses an option or argument it does not know. It used to
  ignore them, so a mistyped `--json` printed the plain list and exited 0.

### Fixed

- VS Code and its forks (Cursor, Kiro and others) quit at start, with no
  window, when the profile folder path was long. They keep a socket in that
  folder, and macOS allows a socket path of 103 bytes. The default data folder,
  a long app name and a long profile name went past it: a Visual Studio Code
  profile named `Acme Consulting` already did. `add`, `rename` and `restore`
  now refuse such a profile before they create or move anything, and say how
  many characters to cut. `doctor` reports existing profiles that are too long;
  the fix is a shorter name with `rename`.

## [1.2.0] - 2026-10-23

### Added

- `aidentity add APP --main` builds a launcher for your original account. While
  any profile runs, macOS treats it as the app itself, so clicking the app only
  switched to that profile and the original account could not be opened. The
  main launcher starts the app with no profile directory, so it always opens the
  original account. `setup` offers one per app. `rm --purge` and `rename` never
  touch the app's own data.
- `list` shows `app missing` with the fix when a launcher's app has moved.
- `aidentity restore` rebuilds the launcher of a profile whose launcher is gone
  (deleted in Finder, or removed with `rm` without `--purge`), still signed in.
  Each profile folder now keeps a small restore record for this. `rm` and
  `prune` point to it.
- Per-profile launch settings: `add` and `set` take `--arg SWITCH` and
  `--env NAME=value`, from an allowlist (proxy, language, display scale, GPU
  switches; proxy, locale and time-zone variables). Anything else is refused,
  because many switches can hand the app to another program or switch off
  its protections. Settings survive rename, rebuild and restore and are
  checked again each time; a stored one that is not allowed is dropped. A
  launcher with settings is owner-only, and `list` shows variable names,
  never values.
- `--own-extensions` gives a VS Code, Cursor or Kiro profile its own
  extensions folder.
- A sign-in guard: the first time a new profile opens while another copy of
  the app runs, its launcher warns once. macOS hands an opened link — such as
  a browser sign-in — to the copy that started first, so the sign-in could
  land in another profile.
- `doctor` checks every profile: an older build, a moved or missing app, a
  folder other users can read, a missing restore record, a shared folder, and
  folders no launcher points at. `doctor --fix` rebuilds stale launchers and
  makes profile folders owner-only.

### Changed (for maintainers and contributors)

- `make check` runs everything CI runs: lint, the test suite and the source
  guards, which moved from inline CI shell into `scripts/guards.sh`. The
  multi-byte guard now uses perl, so it also runs on macOS.
- `make release VERSION=x.y.z` prepares a release: version, the installer's
  default ref, the changelog heading and `SHA256SUMS`. `make formula` points
  the formula at the pushed tag. `docs/homebrew-tap.md` lists the whole order
  and test commands current Homebrew accepts.
- The installer and uninstaller have end-to-end tests: install.sh against a
  stub `curl`, uninstall.sh with every search path in the sandbox.
  `AIDENTITY_BIN_DIRS` tells uninstall.sh exactly where to look for the
  command, and its launcher search follows `AIDENTITY_APP_DIRS`.
- CI pins `actions/checkout` to a commit (v7.0.1, which also drops the Node 20
  deprecation warning), Dependabot keeps it current, pushes run only for
  `main` and tags, and every job has a timeout. `make lint` fails on a missing
  file and also covers `scripts/guards.sh` and `assets/record-demo.sh`.
- `assets/record-demo.sh` records in a fresh temporary folder under
  `/bin/bash`, and says which machine facts can appear (macOS and bash
  versions, in `doctor`).

### Fixed

- `add` with no `--profile` asks for the account name again. 1.1.0 lost the
  prompt, so `aidentity add` picked an app and then failed on an empty name.
- `list` said `signed out / new` for every Electron profile (Claude, Slack, VS
  Code), because it only looked for Chromium's `Default/` folder.
- A failed `rename`, `set` or `rebuild` no longer loses the launcher. Launchers
  are now built in a hidden staging folder and swapped in only when complete.
  Before, the old launcher was deleted first, and the build then exited instead
  of returning — so rename's roll-back never ran, the session was left with no
  launcher, and `prune` offered to delete it.
- One typo at the app menu ended the whole `setup` walkthrough. It now asks
  again; `q` stops.
- `rebuild` and `rename` stripped the badge (and a chosen colour) from
  launchers built by 1.0.0. They now restore 1.0.0's defaults.
- Launchers drop `NODE_OPTIONS`, `ELECTRON_*`, `VSCODE_*`, `DYLD_*` and similar
  variables before opening the app. `open` passes its environment on, so a
  profile opened from a terminal inherited them.
- `prune` deleted the data of launchers that were moved out of the launcher
  folder, and of launchers that recorded the data root with a different
  spelling (a symlink, a trailing slash). It now looks for launchers more widely
  and compares directories by identity.
- `rm` without `--purge` suggested `aidentity rm NAME --purge`, which cannot work
  once the launcher is gone. It now prints the `add` line that reattaches the
  data and points to `prune`. `rm` also no longer says "Removed" when a locked
  bundle survived, and `rm A B` is refused instead of removing only `B`.
- `--profile --seed` created a profile named "--seed". Option values starting
  with `-` are refused, and so are profile names.
- A non-ASCII `--badge` under `LC_ALL=C` wrote invalid UTF-8 and failed.
- Renaming only the capitals of a name (`work` → `Work`) is allowed. A default
  badge letter now follows the new name.
- `rebuild` exits non-zero when a launcher could not be rebuilt.
- Adding a profile that already exists keeps its badge and colour, and says
  "Updated" instead of "Created".
- A relative `AIDENTITY_DATA_ROOT` such as `../profiles` was recorded with its
  `..`, so purge, rename and prune refused the profiles it made. Both
  directories are now cleaned up on paper when the tool starts.
- `setup`, `add` and the installer test whether a terminal can really be opened.
  `/dev/tty` reads as accessible on every Mac, so "needs a terminal" never fired
  — and `make test` hung silently in a real terminal, waiting for a key.
- The installer exited 1 after a successful install when there was no terminal
  (CI, MDM). It no longer runs `setup` as root, refuses to install over a
  directory, and replaces a symlink instead of following it.
- `uninstall.sh` now also removes profile data no launcher points at, says
  "gone" only when it is, and exits 1 when there is no terminal to confirm on.

### Security

- **The "is this profile running?" check could report a running profile as
  stopped** when many app processes were running, so `rm --purge`, `rename`,
  `prune` and `uninstall.sh` could act on a live profile. The check no longer
  depends on a pipeline that stops reading early.
- New profile directories are created owner-only (0700), like the apps' own,
  and a seeded MCP config is 0600.

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

[Unreleased]: https://github.com/PiniShv/aidentity/compare/v1.3.0...HEAD
[1.3.0]: https://github.com/PiniShv/aidentity/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/PiniShv/aidentity/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/PiniShv/aidentity/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/PiniShv/aidentity/releases/tag/v1.0.0
