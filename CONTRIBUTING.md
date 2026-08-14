# Contributing to aidentity

The whole tool is one shell script: `bin/aidentity`. Read it before changing it —
it is about 650 lines and commented, and most questions are answered faster by
reading it than by asking.

## Running the tests

```sh
make test
```

225 assertions, run against the real script — not a mock of it. The suite points `AIDENTITY_APPS_DIR` and `AIDENTITY_DATA_ROOT` at throwaway
directories, so it builds and deletes launchers without touching `~/Applications`
or your real profile data. If a test ever writes outside those two variables,
that is a bug in the test, and a serious one — say so in the PR.

Run the suite before you open a PR and again after review changes. It is fast.

You can drive the script the same way by hand:

```sh
AIDENTITY_APPS_DIR=/tmp/ai-apps \
AIDENTITY_DATA_ROOT=/tmp/ai-data \
  ./bin/aidentity add Claude --profile Scratch
```

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
/bin/bash -n bin/aidentity   # syntax check under the real thing
shellcheck bin/aidentity     # optional, but fix what it finds
```

`shellcheck` is not a dependency of the tool and never will be — it is a
development convenience only.

## Safety rules a PR must preserve

These are not style preferences. A change that weakens any of them will be sent
back regardless of what else it does.

1. **Never touch a bundle that lacks the marker key.** Every launcher aidentity
   builds carries `AIdentityProfile` in its `Info.plist`. `assert_ours()` is the
   only gate between this tool and someone's real applications. Any new code
   path that deletes, overwrites or rewrites an `.app` must call it first. Do
   not add a "force" flag that skips it.

2. **Never delete outside the data root.** `rm --purge` deletes only paths under
   `$DATA_ROOT`, checked with a `case` match against the live value of the
   variable. The path recorded in a bundle's plist is untrusted input — a bundle
   can be edited by hand. Keep the check on the destination, not on the source
   of the string.

3. **Never widen profile-name validation without an escaping review.** A profile
   name becomes a directory name, a bundle name, a slug and a string embedded in
   the generated launcher script. The current rule — letters, numbers, spaces,
   hyphens, underscores; 40 chars; no leading or trailing space; no leading dot
   — is what lets the rest of the code stay simple. If you want to allow another
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

7. **`bin/aidentity` must keep ending on the line `main "$@"`.** That exact line
   is `install.sh`'s truncated-download guard: after the shebang, version and
   `bash -n` checks, it compares the last non-blank line of the download against
   `END_MARKER='main "$@"'` and refuses to install anything that does not match.
   A script cut in half is very often still valid shell, so this is the only
   check that proves the transfer finished. Nothing with content may follow it —
   not another call, not even a trailing comment (blank lines are ignored). If
   the entry point is ever renamed, `END_MARKER` in `install.sh` has to change
   in the same commit.

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
