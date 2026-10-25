# Contributing to aidentity

The tool ships as one shell script, `bin/aidentity`. It is written in `src/`:
the same code, split by subject into files of a few hundred lines each.
`make build` joins them back into `bin/aidentity` and updates `SHA256SUMS`.
Read the code before changing it — it is commented throughout, and most
questions are answered faster by reading it than by asking.

## Where the code lives

Edit `src/`, never `bin/aidentity`. Commit both: installs and updates fetch
`bin/aidentity` alone. `make test`, `make lint` and CI stop when the two
disagree, and say so.

```sh
make build    # after every change in src/
```

| File in `src/` | What it holds |
|---|---|
| `00-header.sh` | the version, the directories, the environment |
| `10-output.sh` | messages, prompts, the macOS check |
| `20-validation.sh` | profile names, quoting, JSON strings |
| `30-apps.sh` | finding Chromium and Electron apps |
| `40-colours-icons.sh` | badge colours and icons |
| `50-launcher.sh` | what counts as our launcher, the running check, safe deletes, clean-up on exit, building a launcher, restore records |
| `51-launch-settings.sh` | per-profile launch settings |
| `52-launcher-assembly.sh` | putting a launcher together and moving it into place |
| `53-trash.sh` | `trash_path`, which moves profile data into the Trash |
| `60-cmd-list.sh` | `apps`, `list`, `open`, `version` |
| `61-cmd-rm-doctor.sh` | `rm`, `doctor` |
| `62-cmd-add.sh` | `add`, `setup` |
| `63-cmd-manage.sh` | `rename`, `set`, `restore`, `prune`, `rebuild` |
| `64-cmd-quit.sh` | `quit` |
| `65-cmd-transfer.sh` | `export`, `import` |
| `70-update.sh` | `update`, and the download checks `install.sh` shares |
| `80-ui.sh` | the menu: drawing and the terminal |
| `81-ui-keys.sh` | the menu: keys and actions |
| `90-command-table.sh` | the table every command is listed in |
| `91-command-help.sh` | help text |
| `92-completion.sh` | shell completion |
| `99-dispatch.sh` | `main`, and the last line |

The number sets the order in `bin/aidentity`; a new file needs a free one.
Bash errors and shellcheck name lines of `bin/aidentity`. To find the line to
edit:

```sh
bash scripts/build.sh --where 2345
```

## Running the tests

```sh
make test
```

Every assertion runs against the real script — not a mock of it. `make test` runs
it under `/bin/bash`, the 3.2 that ships with macOS, and detaches it from your
terminal, so a prompt can never sit waiting for you. The suite points `AIDENTITY_APPS_DIR` and `AIDENTITY_DATA_ROOT` at throwaway
directories, so it builds and deletes launchers without touching `~/Applications`
or your real profile data. It also points `HOME` at the sandbox, so `rm --purge`,
`prune` and `uninstall.sh` move data to a sandbox Trash and never to your real
one. If a test ever writes outside the sandbox, that is a bug in the test, and a
serious one — say so in the PR.

The suite is split by area. `test/run_tests.sh` is the entry point. `test/lib.sh`
holds what every area shares: the sandbox, the assertions, the runners (`ai`,
`libcall` and the others) and the fake apps. Each `test/t_<area>.sh` holds the
groups for one part of the tool. To run only some areas:

```sh
bash test/run_tests.sh --list         # print the area names
bash test/run_tests.sh ui completion  # run only those areas
make test AREA=ui                     # the same, through make
```

| Area | What it tests |
|---|---|
| `basics` | help, version, exit codes, `apps`, name rules, quoting, colours |
| `lifecycle` | app detection, the marker key, `add`, `list`, `rm`, `--purge`, `--seed`, icons, refusals, `rename`, `set` |
| `running` | the check for a profile that is running |
| `quit` | `quit`, against real processes: finding one profile's copy of an app, the quit request, `SIGTERM`, and the other copies left running |
| `accounts` | the account-name prompt, `setup`, `--main`, a failed build, status and permissions |
| `maintenance` | `rm` hints, `prune`, rename and rebuild edge cases, finding launchers, interrupts, symlinks |
| `restore` | restore records, `doctor --fix`, adding a profile again |
| `settings` | per-profile launch settings, the VS Code socket limit |
| `json` | `list --json` |
| `transfer` | `export` and `import`: the file's contents, a round trip, and every refusal of a file or an entry |
| `ui` | the menu |
| `launcher` | the generated launcher's sign-in guard |
| `install` | `install.sh`, `make formula` and `make release` input checks |
| `release` | release notes, the release check, the build from `src/` |
| `uninstall` | `uninstall.sh` |
| `help` | help for each command, and `--help` never running one |
| `completion` | shell completion |
| `update` | `aidentity update` |

An area gives the same results alone as in the full suite, and CI runs each
one alone to show it. Before each area, the runner empties the work space
(the launcher folder, the data root and the fake apps' folder) and builds the
fake apps again. Files kept directly in the sandbox are not reset, so an area
must make what it reads and must not rely on what another area left. After
each area, the runner checks it left no launcher or profile data behind. If two
areas need the same helper or stub, put it in `test/lib.sh`.

To add a test, find the group it belongs to in the area file for that part of
the tool, or start a new `group "…"` there. To add an area, create
`test/t_<name>.sh` and add the name to `TEST_AREAS` in `test/run_tests.sh`, in
the place where it should run. The suite stops with a message when a file is
missing from that list. `make lint`, the source guards and CI find a new file
by themselves.

Run the suite before you open a PR and again after review changes. It is fast.
`make check` runs the lint, the suite and the source guards in
`scripts/guards.sh` — the checks CI blocks on. CI also repeats the suite under a
second bash and smoke-tests the CLI. Without shellcheck installed, `make lint`
only checks syntax and says so. The completion tests that need zsh or fish run
when that shell is installed and are skipped, with a note, when it is not. CI
installs fish; zsh comes with macOS.

You can drive the script the same way by hand:

```sh
AIDENTITY_APPS_DIR=/tmp/ai-apps \
AIDENTITY_DATA_ROOT=/tmp/ai-data \
  ./bin/aidentity add Claude --profile Scratch
```

Set `HOME` to a throwaway folder as well if you try `rm --purge` or `prune`:
they move data to your real Trash.

## bash 3.2 — not optional

macOS ships bash 3.2 (2007) and that is the interpreter the script must run
under. Anything newer is not installed on a stock Mac, and `#!/usr/bin/env bash`
finds 3.2 first for most people.

Do not use:

- associative arrays (`declare -A`)
- `${var^^}` / `${var,,}` case conversion — use `tr '[:upper:]' '[:lower:]'`
- `mapfile` / `readarray` — use a `while IFS= read -r` loop
- `&>>`, `|&`, `;;&` in `case`
- negative array indices (`${arr[-1]}`)
- `${var@Q}` and the other `@` transformations

Check yourself before pushing:

```sh
/bin/bash --version          # must say 3.2.x
make build                   # bin/aidentity from src/
/bin/bash -n bin/aidentity   # syntax check under the real thing
shellcheck bin/aidentity     # optional, but fix what it finds
```

`shellcheck` is not a dependency of the tool and never will be — it is a
development convenience only.

## Safety rules a PR must preserve

These are not style preferences. A change that weakens any of them will be sent
back regardless of what else it does.

1. **Never touch a bundle that lacks the marker key.** Every launcher aidentity
   builds carries `AIdentityProfile` in its `Info.plist`. `is_our_launcher()` is
   the only gate between this tool and someone's real applications. Any new code
   path that deletes, overwrites or rewrites an `.app` must check it first:
   through `assert_ours()` where failing means exit, or inline (as
   `build_launcher` does) where the caller has a recovery path. Do not add a
   "force" flag that skips it.

2. **Never remove profile data outside the data root, or while a profile
   runs.** `rm --purge`, `prune` and `uninstall.sh` never delete profile data:
   they move it to the Trash with `trash_path()`, which renames it on its own
   volume and leaves it where it was when it cannot. They move only paths that
   `data_is_ours()` accepts: absolute, no dot segments, resolved with `cd -P`,
   strictly below the root. The path recorded in a bundle's plist is untrusted
   input — a bundle can be edited by hand. Keep the check on the destination,
   not on the source of the string. Every move is also gated on
   `running_on_profile()`, which must fail closed: if it cannot tell, it says
   "running". Never pipe its process list into `grep -q` — under `pipefail` an
   early exit reads as "no match". `running_on_profile()` takes a fresh look
   every time. Views that ask about many profiles hold one `proc_snapshot()`
   in their own `local` variables and ask `running_in_snapshot()`; a move to
   the Trash never does. Both helpers, the other
   three functions of the running check and `trash_path()` are copied into
   `uninstall.sh`, and CI fails if the copies differ.

3. **Never widen profile-name validation without an escaping review.** A profile
   name becomes a directory name, a bundle name, a slug and a string embedded in
   the generated launcher script. The current rule — letters, numbers, spaces,
   hyphens, underscores; 40 chars; no leading or trailing space; no leading dot
   or hyphen — is what lets the rest of the code stay simple. If you want to allow another
   character, the PR must show what happens to it in all four of those places,
   and must keep `shquote()` in the path that writes the launcher. Adding a
   character is a security change, not a UX change.

4. **Never copy, patch or re-sign the target app.** The launcher points at the
   app where it already lives. That is what keeps the vendor's signature, the
   keychain access groups (SSO, passkeys) and auto-update working. Copying and
   re-signing has been tried; an ad-hoc signature cannot claim the vendor's team
   ID and the copy dies at launch.

5. **No third-party dependencies.** Icon badging uses `iconutil` and
   `osascript -l JavaScript`; plists use `PlistBuddy` and `plutil`. Everything
   ships with macOS. A PR that reaches for ImageMagick, Python packages, Node or
   `jq` will not be merged.

6. **Icon failures are never fatal.** `build_icon` falling back to the app's
   plain icon is correct behaviour. Keep new cosmetic code on the same footing.

7. **Keep the shape installed copies check.** `install.sh` and
   `aidentity update` check a download by its checksum, and a release by its
   version line. Copies of 1.4.0 already installed also check, with their own
   fixed code, that the script starts with `#!`, passes `bash -n` and ends on
   the line `main "$@"`. So `bin/aidentity` must keep all of these: one
   `AIDENTITY_VERSION="x.y.z"` line, `#!` first, valid shell, and `main "$@"`
   as the last line with content (blank lines are ignored, a trailing comment
   is not). The first two are in `src/00-header.sh`, the last line in
   `src/99-dispatch.sh`. `scripts/guards.sh` checks each of them before every
   release.

   The download checks (`https_fetch`, `verify_release_file`, `install_atomic`
   and the helpers between the `download block` markers) are pasted into
   `install.sh`, which cannot source the file it checks. Change both copies in
   the same commit; `scripts/guards.sh` fails when they differ. The block uses
   each script's own `warn` and `die`, each script's EXIT trap removes
   `INSTALL_STAGED`, and every command substitution in it that can fail has a
   fallback, because `install.sh` runs under `set -e`.

8. **Regenerate `SHA256SUMS` in the same commit that changes `bin/aidentity`.**
   `install.sh` fetches that file and refuses to install a script whose hash
   does not match, or that has no checksum, so a stale checksum breaks every
   `curl` install. CI fails the build when the two disagree. `make build`
   regenerates it.

## Adding support for a new app

There is no per-app list to edit — that is the design. Detection is structural,
in `is_chromium_app()`: an `Electron Framework.framework`, or any
`*.framework` containing `Versions/*/Helpers/*.app`. If an app matches, it
already works.

So "add support for X" usually means one of:

- **X is Chromium/Electron but is not detected.** Its bundle layout is unusual.
  Send the output of `ls "/Applications/X.app/Contents/Frameworks"` (see the
  app-request issue template) and, if you are patching, extend
  `is_chromium_app()` with another *structural* probe. Do not add a hard-coded
  bundle ID. Keep it a directory test: this function runs across every installed
  app, and binary scanning turned `aidentity apps` into a 30-second wait. The
  slow path (`strings` for `--user-data-dir`) belongs in
  `is_chromium_app_deep()`, which only runs when the user names one app.

- **X is genuinely native (Swift/AppKit).** Then it has no `--user-data-dir` and
  this approach cannot work. ChatGPT Classic (`com.openai.chat`) is the
  reference example. This is a documented limitation, not a bug to fix.

- **X stores something outside the profile directory** and so needs a seeding
  step, like Claude Desktop's MCP server config under `--seed`. Keep any such
  code opt-in behind a flag, and keep it copying — never moving — the original.

Test on a real installation of the app and say in the PR which app, which
version, and that two accounts stayed signed in at once.

## Reporting a bug

Open an issue with the bug report template and **include the full output of**:

```sh
aidentity doctor
```

That one command reports the macOS version, the aidentity version, the bash
version, whether the launcher directory is writable, whether `codesign` is
available, and how many compatible apps and profiles exist. Most reports are
diagnosable from it alone, and without it the first reply is going to be a
request for it.

Also say which app and which profile name, and paste the exact command you ran.
Redact the profile name if it contains anything you would rather not publish —
just say so, so nobody chases a name mismatch.

## Pull requests

- One change per PR. A refactor and a fix in the same diff take three times as
  long to review.
- Match the surrounding style: two-space indent, `local` on every function
  variable, `die` for fatal errors, `warn` for recoverable ones.
- Update `--help` and `docs/` when you change behaviour. Undocumented flags do
  not exist.
- Bump `AIDENTITY_VERSION` only when asked. Releases are cut deliberately.

## Prose in docs and help text

Direct and concrete. Explain the mechanism, not how great it is. No
"seamless", "effortless", "supercharge", "game-changer". Short sentences.
Assume a competent reader who has never seen the tool.
