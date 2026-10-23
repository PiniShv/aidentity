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
- **It never transmits anything anywhere.** No network calls, no telemetry, no
  analytics, no update check, no crash reporting. The script makes zero outbound
  connections; `grep` it if you want to confirm.
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

## Supported versions

The latest tagged release. There are no backported fixes to older versions —
upgrade with `brew upgrade aidentity`, or re-run the installer.
