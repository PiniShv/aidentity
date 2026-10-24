# Security Policy

## Reporting a vulnerability

Email **contact@pinishv.com**. Put "aidentity" in the subject line.

Do not open a public issue for anything that lets one user's code or data reach
another user's applications, profile data or credentials.

Include:

- what you did, in commands anyone can re-run
- what happened, and what you expected instead
- the output of `aidentity doctor`
- your macOS version and the aidentity version

Expect an acknowledgement within a few days. This is a one-person project with
no bug bounty and no formal SLA; I will tell you honestly when I can look at it.
Please give me a reasonable window to ship a fix before publishing. Credit in
the changelog if you want it.

## Trust model

Read this before deciding whether a finding is a bug.

- **aidentity runs as you, with your permissions.** It is a shell script. No
  daemon, no root, no `sudo`, no privileged helper, no launch agent. Anything it
  can do, you could do from a terminal.
- **It builds a local app bundle that Apple has not signed.** The launcher in
  `~/Applications` is ad-hoc signed at most (`codesign --sign -`). It is not
  notarised and never will be, because it is generated on your Mac. macOS treats
  it as a locally-built app.
- **It makes no network calls except when you run `aidentity update`.** No
  telemetry, no analytics, no automatic update check, no crash reporting.
  `aidentity update` (and `update --check`) is the only code in the script that
  connects anywhere. It uses `curl` over HTTPS only (TLS 1.2 or later, also on
  redirects). It does not read your `~/.curlrc`, so settings there cannot turn
  off certificate checks. It contacts:
  - `api.github.com`, to read the tag of the latest release;
  - `raw.githubusercontent.com`, to download that release's `bin/aidentity`
    and `SHA256SUMS` (not with `--check`).

  The test-only setting `AIDENTITY_UPDATE_URL` can point `update` at another
  `https://` address. It prints a warning on every run.

  It sends nothing about your profiles or apps — only what any HTTPS download
  sends, such as your IP address and curl's user agent.

  Before it replaces anything, it checks that the tag is a plain version
  number (`v1.2.3`), that the script matches the published checksum (no
  checksum, no update), that it is a complete shell script, and that it says
  it is the version of the tag. It never downgrades and never runs `sudo`. A
  copy managed by Homebrew, or run from a git checkout, is left to
  `brew upgrade` or `git pull`. A failed check leaves the old file untouched.

  The checksum is published in the same repository as the script. It catches
  a damaged, cut-off or swapped download, but not a compromise of the
  repository itself. The Homebrew formula pins a checksum reviewed at release
  time, so it is the stronger channel.
- **It never copies, patches or re-signs the app you already have.** The
  launcher points at the installed app in place. Your app keeps its Apple
  signature, its keychain access groups and its auto-update.
- **Profile data is not encrypted by aidentity.** Each profile directory under
  `~/Library/Application Support/aidentity/profiles/` holds session cookies and
  tokens for the account signed into it, exactly as the app's normal data
  directory does. It is protected by your account's file permissions and by
  FileVault if you have it on — nothing more. A second profile is a second live
  session on your disk. Treat it accordingly.
- **A launcher runs an app you already trust.** aidentity adds a
  `--user-data-dir` argument to an app that is already installed, plus any
  per-profile settings you chose from a short allowlist. It does not inject
  code into it. Before opening the app, the launcher removes variables such as
  `NODE_OPTIONS` from the environment it was started with, and the first time
  a new profile opens while the app already runs, it may show one dialog.
- **Each profile folder holds a small restore record** (`.aidentity-profile.plist`)
  that `aidentity restore` reads. Its contents are checked as if typed on the
  command line.

## In scope

- **The installer and the CLI** (`bin/aidentity`, `install.sh`, the Homebrew
  formula): command injection through a profile name, app name or path;
  anything that gets arbitrary code into the generated launcher script;
  unsafe handling of `AIDENTITY_APPS_DIR` or `AIDENTITY_DATA_ROOT`; a TOCTOU
  window in bundle creation.
- **The generated launcher**: anything that makes it execute a binary other
  than the app recorded in its `Info.plist`, or point at a data directory other
  than the one recorded; an escaping failure in the embedded paths or settings;
  a switch or variable outside the allowlist reaching the app.
- **The restore record**: anything in it that `restore` acts on without the
  checks a command-line value gets.
- **`aidentity update`**: anything that makes it install a file other than the
  release's published script, replace a file other than the copy you ran,
  downgrade, connect over plain HTTP, or leave a broken file in place.
- **The deletion logic** (`rm`, `--purge`, and the overwrite path in `add`):
  anything that removes or overwrites a bundle without the `AIdentityProfile`
  marker key, or deletes a path outside `$AIDENTITY_DATA_ROOT`. Symlink and
  path-traversal tricks in a profile name are exactly the kind of thing I want
  to hear about.
- **Profile-name validation**: any input accepted by `validate_profile_name`
  that then misbehaves as a directory name, a bundle name, a slug, or a string
  embedded in the launcher.

## Out of scope

- Vulnerabilities in the apps aidentity launches (Claude, ChatGPT, Slack,
  Chrome, and so on). Report those to their vendors.
- "The launcher is not notarised by Apple." That is the design, stated above.
- "Profile data can be read by someone with my unlocked Mac and my user
  account." So can the app's own data directory, your keychain-backed sessions
  and your browser cookies. aidentity does not change that boundary.
- Anything that requires root, or an attacker who already has code execution as
  your user.
- Someone hand-editing a launcher's `Info.plist` to point at their own paths.
  If a person can write to `~/Applications`, they are already you.

## Verifying a release

Each release on the [releases page](https://github.com/PiniShv/aidentity/releases)
has four files: `aidentity`, `install.sh`, `uninstall.sh` and `SHA256SUMS`. Each
has signed build provenance. It is made by the release workflow
(`.github/workflows/release.yml`) when a release tag is pushed. Releases made
before that workflow have none.

GitHub also adds two archives to every release page, "Source code (zip)" and
"Source code (tar.gz)". These are not signed and have no provenance. The
Homebrew formula installs from the tar.gz.

To check a file you downloaded, use the GitHub CLI. Install it with
`brew install gh` and sign in once with `gh auth login`, because the check
reads the provenance from GitHub:

```sh
gh attestation verify aidentity --repo PiniShv/aidentity
```

To also name the workflow and the tag, add them:

```sh
gh attestation verify aidentity --repo PiniShv/aidentity \
  --signer-workflow PiniShv/aidentity/.github/workflows/release.yml \
  --source-ref refs/tags/v1.4.0
```

What a pass proves:

- The file is byte for byte the one that a GitHub Actions run in this
  repository signed. With the second command, that run was `release.yml`,
  started by that tag.
- The signature comes from GitHub's identity for that run, not from a key
  stored in the repository, and the record is public.

What it does not prove:

- That the code is safe or has been reviewed. It says where a file came from,
  not what is in it. Whoever can push a release tag to this repository can make
  a signed release, so read the source if you need more than that.
- Anything about a file you did not check. This includes the "Source code"
  archives, which are not signed. The installer and the Homebrew formula do not
  run this check. The installer compares `bin/aidentity` with
  `SHA256SUMS` from the same tag, which catches a damaged download but not a
  bad release, because both files come from the same place. To verify, download
  `aidentity` from the release page and run the command above.
- Anything about releases made before provenance was added.

## Supported versions

The latest tagged release. There are no backported fixes to older versions —
upgrade with `brew upgrade aidentity`, `aidentity update`, or re-run the
installer.
