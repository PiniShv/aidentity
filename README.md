<div align="center">

<img src="assets/logo.svg" alt="" width="96" height="96">

# aidentity

### Stop signing out to switch accounts.

**Run your work, personal and client accounts side by side. Each one stays signed in.**

Built for AI desktop apps like Claude and ChatGPT. Also tested with Slack, VS Code, Cursor, Notion and other apps built on Chromium, the engine inside Google Chrome. [See the list](#which-apps-work).

![macOS only](https://img.shields.io/badge/macOS-only-111?logo=apple&logoColor=white)
![Latest version](https://img.shields.io/github/v/tag/PiniShv/aidentity?label=version&sort=semver)
![No dependencies](https://img.shields.io/badge/dependencies-none-2FB344)
![MIT licence](https://img.shields.io/badge/license-MIT-2E7DF6)

[Install](#30-seconds) · [How it works](#how-it-works) · [Which apps work](#which-apps-work) · [FAQ](#frequently-asked) · [Full guide](docs/guide.md)

```bash
curl -fsSL https://raw.githubusercontent.com/PiniShv/aidentity/main/install.sh | bash
```

<img src="assets/demo.gif" alt="Terminal demo: aidentity creates Claude and ChatGPT profiles, then renames, recolours, removes and restores one" width="800">

</div>

<a id="30-seconds"></a>

## Quick start

Open Terminal (press **Cmd + Space**, type `Terminal`, press **Return**) and paste:

```bash
curl -fsSL https://raw.githubusercontent.com/PiniShv/aidentity/main/install.sh | bash
```

Or use Homebrew:

```bash
brew install pinishv/tap/aidentity
```

1. **Say yes to the walkthrough** at the end of the installer. After Homebrew, run `aidentity setup`.
2. **Pick your app** from the list and name the account, for example `Work`.
3. **Open the new icon**, for example `Claude Work`, and sign in once. The walkthrough offers to open its folder. Drag the icon to your Dock.

> [!IMPORTANT]
> If the app is already open, quit it first. Sign in to the new icon, then open the app again. Some apps sign in through your browser, and macOS hands the result to the window that started first. [Why](docs/guide.md#signing-in-to-a-new-profile)

The installer checks the download, never uses `sudo` and leaves your shell files alone. To read it first or build from source, see [Install and upgrade](docs/guide.md#install-and-upgrade).

Day to day:

```bash
aidentity add Claude --profile Work --color blue   # one more account, no questions
aidentity list                                     # every profile, and which are running
aidentity rename "Claude Work" Client              # stays signed in
aidentity restore "Claude Client"                  # bring back a deleted icon
aidentity doctor --fix                             # check and repair
```

[All commands](docs/guide.md#commands)

## How it works

1. **Chromium and Electron apps lock their data folder.** The lock stops the app from starting twice.
2. **aidentity builds a small launcher for each account.** It opens your app again with `--user-data-dir`, a start-up option that points the app at a different data folder.
3. **New folder, new lock, new sign-in.** Cookies live in that folder, so each launcher opens its own account.

```text
Claude Work.app    →  Claude.app  +  profiles/claude-work    (work account)
Claude Client.app  →  Claude.app  +  profiles/claude-client  (client account)
Claude Main.app    →  Claude.app  +  Claude's own folder     (your original account)
```

There is still one `Claude.app`. [The full picture](docs/guide.md#how-it-works)

> [!NOTE]
> **The main trade-off.** While profiles run, the Dock shows the app's own tile for each one, with the same name and icon. macOS reads both from inside the app, and aidentity never changes the app. [How to tell them apart](docs/guide.md#the-rough-edge-dock-tiles-show-the-original-app)

## Why aidentity

- **Your app stays untouched.** It is never copied, changed or signed again, so it keeps its signature, its keychain access and its own updates.
- **One script you can read.** About 3,000 lines of bash. [Read it](bin/aidentity) before you run it. It needs nothing extra; the Xcode Command Line Tools are optional. After install it makes no network calls, never uses `sudo` and runs nothing in the background.
- **Easy to undo.** Deleted an icon? `aidentity restore` brings it back, still signed in. Something looks wrong? `aidentity doctor --fix`. `rm` keeps your data unless you add `--purge`. The [uninstaller](docs/guide.md#uninstall) asks before it deletes any profile.
- **Your original account stays one click away.** While a profile runs, clicking `Claude.app` takes you to that profile. `aidentity add Claude --main` builds a Main launcher that opens your original account instead. [Why](docs/guide.md#opening-your-original-account-while-a-profile-runs)

Worth knowing: aidentity does not encrypt profile data. Each data folder holds a live sign-in, just like the app's own folder. [Is this safe?](docs/guide.md#is-this-safe)

## Which apps work

Apps built on **Chromium** (the engine inside Google Chrome) or **Electron** (a toolkit for desktop apps built on that engine). Run `aidentity apps` to see which of yours qualify.

| Status | Apps |
|---|---|
| **Verified**: two accounts signed in at once, checked by hand | Claude Desktop |
| **Tested**: starts as its own copy with its own data; two sign-ins not checked yet | ChatGPT, Slack, Visual Studio Code, Cursor, Kiro, Antigravity, Notion, Notion Calendar, Obsidian, Podman Desktop, Postman |
| **Browsers**: detected, but their built-in profiles usually do the job better | Chrome, Edge, Brave, Arc, Vivaldi, Comet |
| **Does not work** | ChatGPT Classic and other native Mac apps (Swift or AppKit). Microsoft Teams (classic) and MiniMax Design, which ignore the separate folder. |

Native apps have no Chromium inside, so they have no `--user-data-dir` option to use. `aidentity add` checks this first and refuses. A few Electron apps ignore that option, and `add` cannot tell, so they are listed above. For VS Code, Cursor and Kiro, keep profile names short. Support for native apps is not planned for version 1. [Full list and notes](docs/guide.md#which-apps-work)

Tried another app? [Tell us how it went](https://github.com/PiniShv/aidentity/issues). That is how an app moves to Verified.

## Frequently asked

**Something went wrong. Where do I start?**

Run `aidentity doctor`. It checks your setup and every profile. If it says problems can be fixed, run `aidentity doctor --fix`. Still stuck? [Open an issue](https://github.com/PiniShv/aidentity/issues) with the `doctor` output. It can show your Mac user name and profile names, so remove anything private first.

**Can I use more than two accounts?**

Yes. aidentity sets no limit, so run `add` once per account. Your Mac's memory is the real limit, because each open profile is the app running again.

**Why do the running Dock tiles all look the same?**

That is [the main trade-off](#how-it-works). The icons you click carry the profile name and a coloured badge, so you can pick the right one. To tell running windows apart, look at the account shown in each window, or use Mission Control.

**Does it break auto-update?**

No. Your app is untouched and updates itself as before. A launcher stores the path to the app, not a copy, so the next launch uses the new version. aidentity itself never checks for updates. Upgrade it with `brew upgrade aidentity`, or run the install line again.

**Is this against the terms of service?**

aidentity creates separate local data folders and passes a documented command-line option. It does not get around sign-in, share credentials or change the app. Terms differ by product and plan, and some limit how many sessions one paid user can run, so check yours. This is not legal advice.

**Does it work with Claude Code or other command-line tools?**

No. It works with desktop apps. Command-line tools keep their sign-in in other ways.

[All answers](docs/guide.md#frequently-asked)

---

<div align="center">

[Full guide](docs/guide.md) · [Security policy](SECURITY.md) · [Contributing](CONTRIBUTING.md) · [Changelog](CHANGELOG.md) · [Licence](LICENSE)

Built by [Pini Shvartsman](https://pinishv.com). MIT licence.

<sub>Not affiliated with Anthropic, OpenAI or the makers of the other apps named here.</sub>

</div>
