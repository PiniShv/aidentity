# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- A 31-second film, at the top of the README and in the first section of the
  site. It shows the problem first: to switch accounts, you sign out and sign in
  again, and you lose your open chats. Then it shows every account open at
  once. On the site it plays muted while it is on screen. **Watch with sound**
  starts it again from the beginning, with the narration, and a button turns
  its captions on.
  `assets/film/` holds its source, and `assets/film/build.sh` makes it again
  in a container with pinned versions and no network.

### Changed

- The site's front page is new, in the style of a product page: one idea per
  section, the film full width at the top, and the uses told as "One Mac, many
  uses". Every fact and command from the old page is still there. The
  card shown when a link to the site is shared has the new lead, and
  `assets/film/build.sh` now makes that card too.
- Both terminal demos are recorded again on 1.6.1. `assets/record-demo.sh`
  builds its sandbox at the fixed path `/tmp/aidentity-demo`, so the
  recordings always show the same short path. The command-line tape waits for
  each command to finish, and the menu tape waits for each screen, before they
  type the next step.

### Fixed

- `rename` moves the old launcher aside before it deletes it, as `rm` does.
  When a file inside the old launcher was locked, it was left without its
  Info.plist. aidentity no longer recognised it, so `rm` refused to remove it.
  Now a locked file is left out of the way in a hidden folder, and the message
  names that folder. A launcher that cannot be moved at all is left whole.
- The uninstaller counts a launcher wherever Spotlight finds it, as `prune`
  and `rm --purge` do. It left out a launcher kept outside your home folder
  and the app folders, listed that launcher's profile data as data no
  launcher uses, and moved it to the Trash. The launcher then opened signed
  out. Such a launcher is now listed with the others and removed with them.
- `add` refuses `--` like any other option it does not know. It used to read
  `--` as the end of its options and ignore every word after it without
  saying so.

## [1.6.1] - 2026-10-27

### Fixed

- The uninstaller missed a launcher inside a folder in the launcher folder
  that it could not read. It then moved that launcher's profile data to the
  Trash, and the launcher was left signed out. Now, when it cannot search the
  whole launcher folder, it stops before it asks and removes nothing. If the
  search fails after you answer, it still removes the launchers, but it keeps
  all profile data. `prune` and `rm --purge` already worked this way.
- `add`, `rebuild` and `doctor --fix` no longer build a launcher in place of
  a symlink. When a launcher was moved into a folder and a symlink was left
  at its old place, they replaced only the symlink. The moved launcher stayed,
  so two launchers used one profile folder. They now refuse and say why.

## [1.6.0] - 2026-10-26

### Added

- `aidentity quit NAME` quits the copy of the app that runs on one profile and
  leaves every other copy running. The Dock shows those copies as identical
  icons, so it was hard to tell which one to quit. It asks the app to quit the
  way its Quit menu item does, so the app can still ask about unsaved work. It
  acts only on a copy that macOS knows as an app, and it never stops a
  command-line tool, even one that runs the app's own program. For a Main
  launcher, it quits the copy on your original account. It looks only at your
  own processes, and never at an app's helper processes. It waits up to 10
  seconds. If the app is still running then, it says so and exits 1; there is
  no option to force it. A profile that is not running gives a message and
  exits 0. Tab completion offers your profile names after `quit`.
- In `aidentity ui`, the `s` key (stop) runs `quit` for the selected profile.
  The footer says `Quitting NAME…` while it waits, and the row shows the new
  status afterwards.
- `aidentity export` prints every launcher as JSON: its app (by bundle ID),
  profile name, badge, colour and launch settings. Save it with
  `aidentity export > profiles.json`. The file holds no account data and no
  folder paths, so no account goes with it. It does hold the values of launch
  variables, and a proxy setting can carry a password. So `export` warns on
  standard error, to keep the file private, when the file holds variable
  values or a switch with `@` in it, as in `user:password@`. It warns too
  when a launcher's app is gone and no bundle ID is recorded for it: `import`
  will skip that launcher.
- `aidentity import FILE` builds the launchers in a file that `export` made,
  on this Mac or another. It finds each app by its bundle ID among the apps
  installed here, and checks every value as `add` checks it. A launcher that
  exists already is skipped, never changed. Anything it cannot use is skipped
  with a reason, and the rest go on. It shows what it will create and what it
  skips, with each new launcher's switches, its variables by name, and the
  server of each proxy variable (never a user name or password), and asks you to type `yes` first. `-y` skips the
  question; with no terminal and no `-y`, it refuses. A new profile starts
  signed out, unless its profile folder is still here: then it uses that
  folder, as `add` does, and the plan says so. The file is treated as
  untrusted: it may come from someone else. A file over 4 MB, or one that
  lists more than 200 launchers, is refused, and so is one that is not valid
  JSON, holds a `null`, or has another format number. `import` exits 1 if a
  launcher could not be built.

### Changed

- `rm --purge`, `aidentity prune` and `uninstall.sh` move profile data to the
  Trash instead of deleting it, so a wrong name or a hasty `yes` can be
  undone. Each command says where the data went and how to undo it. The move
  is a plain rename, not a request to Finder, so macOS shows no permission
  prompt, and the folder moves whole or not at all. It goes to `~/.Trash`. On
  a volume that is not the home folder's, it goes to that volume's
  `.Trashes/<your user ID>` folder, which Finder makes the first time you put
  something in the Trash from that volume. If the volume has none, or the
  Trash cannot be written, nothing is moved: the data stays where it was and
  the message says why. `rm --purge` and `prune` then exit 1. The prompts and
  help texts say Trash, as does the `p` key of the menu's remove question. The
  uninstaller still deletes the launchers and still asks you to type
  `delete`. Emptying the Trash is what deletes the data for good, and what
  removes the sign-in from the Mac: a folder in the Trash still holds it.
- To undo a move to the Trash, move the folder back into the profiles folder.
  Then run `aidentity restore`, if the folder holds a restore record.
  `rm --purge` now writes the restore record first when the profile has none,
  so that works for profiles made before 1.2.0 too. `prune` and the
  uninstaller write none, so for such a profile run `aidentity add` with the
  same app and profile name: it uses the folder. The uninstaller also removes
  the profiles folder when it is empty, so make it again before you move
  folders back.
- The code is written in `src/`, split by subject, and built into
  `bin/aidentity`, which still ships as one file. Installs and updates fetch
  it as before. On its own, the split changed no behaviour: the built file
  differed from 1.5.0 only in comments, and in where one function sits.

### Fixed

- In `aidentity ui`, a key whose command failed was shown in the style of a
  success. For example, Enter on a profile that could not be opened looked
  like it worked. A failure now shows in red. A failure that printed nothing,
  such as Ctrl-C while `s` waits for an app, shows a line of its own, for
  example `Did not finish quitting NAME.`
- `rm --purge` kept a profile's data when another launcher in the launcher
  folder used it, but it missed one filed into a folder inside it, or kept in
  an app folder. It now looks wherever `prune` looks, and so do `add` and
  `import` before they make a profile. If that search fails, the data is kept
  and no profile is made.
- `prune` and the uninstaller check each folder again just before they move
  it, so a launcher made while they waited for your answer keeps its folder.
  A profile folder that is a symbolic link is not moved, and the message says
  why.
- The messages that say a profile is running now name the command that quits
  it: `aidentity quit "NAME"`.
- Ctrl-C in `aidentity ui` could leave the terminal with echo off, when it
  came while the menu read its profiles or as a wait for a key ran out, and
  in bash 3.2 it could be lost. The terminal now always comes back.
- The uninstaller kept going after a launcher it could not remove (a locked
  one, say) and moved that launcher's data, so the launcher that was left
  opened signed out. It now keeps that data, and the data of any launcher
  that still uses a folder.

### Changed (for maintainers and contributors)

- The test suite is split into areas: `test/lib.sh` holds what they share, and
  each `test/t_<area>.sh` holds the groups for one part of the tool. Run some
  of them with `make test AREA=ui` or `bash test/run_tests.sh ui completion`.
  Each area starts from an empty work space, and gives the same results alone
  as in the full run.
- The suite sets `HOME` to a folder in its sandbox, so every command that
  moves data to the Trash uses a sandbox Trash, and the final check proves
  that none of the suite's profile folders reached the real Trash. A small
  disk image stands in for a second volume when `hdiutil` works, and those
  tests are skipped, with a note, when it does not.
- `trash_path` is in `src/53-trash.sh`. `uninstall.sh` carries a copy, and
  `scripts/guards.sh` fails when the two differ.
- `scripts/build.sh` refuses an empty file in `src/`. It had put a blank line
  before it, which made `--where` name the wrong line for every line after it.

## [1.5.0] - 2026-10-25

### Changed

- The overview that `aidentity help`, `aidentity -h`, `aidentity --help` and
  `aidentity` on its own print is shorter. It lists each command with one line
  on what it does, and points to `aidentity help COMMAND` for the options. The
  options were written in two places before, and the two had started to
  differ. The help of every command now lists `-h, --help` under OPTIONS.
  `aidentity help rm --help` shows the help of `help`; it was an error.
- Tab completion asks `aidentity` what fits on every Tab, for commands and
  options as well as names, so the scripts that `aidentity completion` prints
  are a few lines long. bash, zsh and fish offer the same words, decided in one
  place. In fish, that means options come without a description, and short
  spellings such as `-p` are no longer offered. A script saved from 1.4.0
  keeps working. A script saved from this release on never needs to be made
  again after an upgrade.
- `aidentity update` checks a download in three ways: `SHA256SUMS` has a
  valid line for `bin/aidentity`, the file matches that checksum, and the file
  says it is the version of the release tag. It no longer also checks that the
  file starts with `#!`, passes `bash -n` and ends on its last line. The
  checksum already proves the file is the published one, and those checks now
  run on every release before it is published.

- `aidentity list` and `aidentity list --json` look at the running processes
  once for all profiles, not once per profile, so they are much faster with
  many profiles. If that look fails, the warning is printed once. The
  commands that change or delete a profile still look afresh every time they
  check.
- `aidentity list` shows each control character in a name, a path or a launch
  setting as `?`, as the menu does, so a launcher's name cannot send escape
  sequences to the terminal. In a UTF-8 locale this also covers some invisible
  characters, such as the joiner inside some emoji. `list --json` still prints
  every name exactly.

### Removed

- `install.sh` no longer checks the size, first line, syntax and last line of
  the download on its own. The checksum covers all of that, and each release
  is checked before it is published.
- The test-only setting `AIDENTITY_UPDATE_URL`. `aidentity update` now always
  reads the release from GitHub, and no setting can point it at another
  address. `aidentity help`, `SECURITY.md` and the guide no longer list it.

### Fixed

- `aidentity ui` gives the terminal back when it is ended by SIGTERM or SIGHUP
  while it waits for a key. Before, the terminal was left with echo off. It
  now leaves through its normal path, within two seconds, with the same exit
  status (143 or 129).
- Profile names, `--arg` and `--env` values and the bundle identifier in a
  restore record accept only ASCII letters, in every locale. In a UTF-8
  locale, the default in Terminal, the checks also accepted letters such as
  `é`, `ß` and fullwidth letters, which the docs say are refused. An `--arg`
  or `--env` value with any character outside ASCII is refused, and the
  message does not print it back. A path that `aidentity` prints for you to
  type is now quoted when it has such a letter.
- `--color` takes only ASCII hex digits, in every locale. In a UTF-8 locale it
  also accepted fullwidth digits such as `ｆ`, and the menu could then quit
  with an error when it showed that profile.

### Security

- The installer refuses to install without a matching checksum. Before, when
  `SHA256SUMS` was missing or could not be downloaded (a network failure took
  the same path), it warned and installed anyway. Now it changes nothing and
  names the ref it tried (`AIDENTITY_REF`). For a release tag, the script must
  also say it is that version.
- The installer's own downloads do not read your `~/.curlrc`, as
  `aidentity update` already did, and stop an answer far bigger than the
  file. The `curl` that you pipe into `bash` still reads `~/.curlrc`. If your
  proxy or CA certificate is set there, set `https_proxy` or `CURL_CA_BUNDLE`
  instead; the installer says so when it cannot download the script. Each
  download now stops after 60 seconds, as in `aidentity update`, not 120.

### Changed (for maintainers and contributors)

- `install.sh` and `aidentity update` share one block of download code:
  fetch, verify, read the version and install in one step. `install.sh`
  carries a pasted copy, because it cannot source the file it checks, and
  `scripts/guards.sh` fails when the two copies differ, when a shared
  function is defined again outside the block, or when `install.sh` runs
  `curl` anywhere but in `https_fetch`. The guard that
  compared the last line with `install.sh`'s `END_MARKER` is gone; the guard
  for installed copies pins the same line.
- `scripts/guards.sh` checks that `bin/aidentity` passes `bash -n` under
  `/bin/bash` and starts with `#!`. Installed copies of 1.4.0 still check
  both, as well as the last line and the version line, which the guards
  already pinned.
- The menu tests put SIGINT and SIGHUP back to their defaults before they
  start the menu, as the update tests already did. A suite started with
  either signal ignored no longer waits out a 90-second timeout in each
  Ctrl-C test.

- One body for the running check, `running_in_snapshot`, answers the delete
  guards and the views that ask about many profiles. The delete guards ask
  `running_on_profile`, which always takes a fresh `proc_snapshot`; the views
  take one snapshot for all their rows. The menu's own copy of the check is
  gone. `uninstall.sh` carries the same four functions, and
  `scripts/guards.sh` compares all four. One reader, `launcher_rows`, gives
  `list`, `list --json`, the menu and completion the same launchers, with the
  same rule for a main launcher's data folder, and `shown` is the one rule
  for showing text from the disk.

## [1.4.0] - 2026-10-24

### Added

- `aidentity ui` opens a full-screen menu over your profiles. Each row shows
  the launcher, its badge in its own colour (or `original` for a main
  launcher) and whether it is running. One key does the rest: Enter opens the
  profile, `a` adds one, `r` renames it, `c` picks a colour, `b` sets the
  badge, `d` removes it (`k` keeps its data; `p` deletes the data too and asks
  you to type yes) and `x` shows the doctor's report (`f` then repairs).
  `?` lists the keys and `q` quits. Every key runs the same command as the
  command line, so every check stays as it is: a running profile is refused,
  and a main launcher never deletes the app's data. The list refreshes every
  two seconds and when the window is resized. The menu needs a terminal,
  follows `NO_COLOR`, fits a narrow window and scrolls a long list. It puts
  the terminal back as it found it when it ends, including after Ctrl-C and
  when the terminal is closed. `aidentity` with no arguments still prints the
  help.
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
- Releases carry signed build provenance. Pushing a `v*` tag runs a release
  workflow. It checks the tag against the script's version, `SHA256SUMS` and
  the installer's default version, and signs `aidentity`, `install.sh`,
  `uninstall.sh` and `SHA256SUMS`. It then checks the signatures and that the
  tag still points at the signed commit, and creates the GitHub release with
  those files and the version's changelog section as notes. The release page
  says that GitHub's "Source code" archives are not signed.
  `gh attestation verify aidentity --repo PiniShv/aidentity` checks a
  downloaded file; it needs `gh auth login` first. `SECURITY.md` says what that
  proves and what it does not.

### Security

- `aidentity update` is the only command that uses the network, and only when
  you run it. It contacts `api.github.com` for the latest release tag and
  `raw.githubusercontent.com` for the files. The tag must be a plain version
  number before it is used in a URL or shown. `SECURITY.md` now says this
  instead of "no network calls".
- `aidentity update` does not read your `~/.curlrc`. A setting there could
  otherwise turn off certificate checks or change where a download is saved.
  A proxy set with `https_proxy` still works.

### Changed (for maintainers and contributors)

- `scripts/release-notes.sh x.y.z` prints a release's notes, the install
  header and the changelog section, and fails when the version has no notes.
  `scripts/release-check.sh vX.Y.Z` is the release workflow's first check. It
  also refuses an installer whose default is not the tag, which the source
  guards allow. Both scripts are linted and tested, and CI runs them with Linux
  tools. `docs/homebrew-tap.md` and the hint `make release` prints describe the
  new release step.
- The test suite drives the menu on a pseudo-terminal: keys, the screen it
  writes, signals, a resize, and the terminal's settings before and after.
- The menu looks at the running processes once per refresh, not once per
  profile, so a long list refreshes quickly. `list`, `rm`, `rename` and the
  other commands still read a fresh process list each time they ask.

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

[Unreleased]: https://github.com/PiniShv/aidentity/compare/v1.6.1...HEAD
[1.6.1]: https://github.com/PiniShv/aidentity/compare/v1.6.0...v1.6.1
[1.6.0]: https://github.com/PiniShv/aidentity/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/PiniShv/aidentity/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/PiniShv/aidentity/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/PiniShv/aidentity/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/PiniShv/aidentity/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/PiniShv/aidentity/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/PiniShv/aidentity/releases/tag/v1.0.0
