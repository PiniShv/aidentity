# aidentity

macOS runs one copy of an app, so you get one account — sign out of work Claude to check personal Claude, then sign back in. `aidentity` builds a small launcher per account so you can run them side by side, each signed in, at the same time.

![macOS only](https://img.shields.io/badge/macOS-only-111?logo=apple&logoColor=white)
![No dependencies](https://img.shields.io/badge/dependencies-none-2FB344)
![License MIT](https://img.shields.io/badge/license-MIT-2E7DF6)

---

## 30 seconds

```bash
curl -fsSL https://raw.githubusercontent.com/PiniShv/aidentity/main/install.sh | bash
```

That is the whole thing — the installer ends by offering to run the walkthrough, so one command covers it. The walkthrough asks whether to badge the icons, shows a numbered list of the apps on your Mac that qualify, and asks what to call each account. Open the launcher it builds, sign in with the second account, and both windows stay signed in from then on. Nothing else to configure.

Said no, or want to add another account later:

```bash
aidentity setup
```

`aidentity add` is the same thing in direct, scriptable form — one profile, all of it on the command line.

<details>
<summary>Other ways to install</summary>

**Homebrew**

```bash
brew install pinishv/tap/aidentity
```

**From source**

```bash
git clone https://github.com/PiniShv/aidentity.git
cd aidentity && make install
```

All three put one file — a shell script — on your `PATH`. There is no daemon, no login item, and nothing that runs in the background. Only the `curl` installer offers the walkthrough at the end; after the other two, run `aidentity setup` when you are ready.

</details>

---

## The problem

You have a work account and a personal account in the same app. Maybe a client's account too. macOS lets exactly one copy of that app run, and the app remembers exactly one signed-in session, so using the other account means signing out and signing back in — losing your open conversations, your window layout, and thirty seconds to an SSO round trip. Then you do it again in the other direction an hour later.

Some apps offer built-in account switching, which is fine when you want *one at a time*. This is for when you want both at once: two windows, two accounts, side by side, neither one logging the other out.

---

## How it works

Chromium and Electron apps guard against a second copy of themselves with a lock file — `SingletonLock`, `SingletonCookie`, `SingletonSocket` — and that lock lives **inside the app's user data directory**, not in a system-wide location. Start a second instance with `--user-data-dir` pointing somewhere else and it creates its own lock in its own directory, never sees the first instance's lock, and simply runs. Since cookies and session tokens also live in that directory, the second instance starts logged out and stays signed into whatever account you give it. `aidentity` writes a small `.app` bundle whose entire job is to run `open -na /Applications/Whatever.app --args --user-data-dir=<that profile's directory>`.

```text
  ~/Applications/                /Applications/        ~/Library/Application Support/
  (launchers aidentity built)    (your real app)       aidentity/profiles/

  [Claude Work.app]   --+                            +--> claude-work/
                        |                            |      SingletonLock   <- lock A
  [Claude Home.app]   --+-->  [ Claude.app ]  -------+      Cookies, session, settings
                        |     one install,           |
  [Claude Client.app] --+     never modified         +--> claude-home/
                                                     |      SingletonLock   <- lock B
                        each launcher passes         |      Cookies, session, settings
                        its own --user-data-dir      |
                                                     +--> claude-client/
                                                            SingletonLock   <- lock C
                                                            Cookies, session, settings

  Three locks, three directories, no instance can see another's.
  Result: three windows, three accounts, all signed in at once.
```

The real app is never copied, patched or re-signed. It keeps its Apple signature, its keychain access groups (so SSO and passkeys keep working) and its auto-updater. The launcher holds a path, not a copy.

---

## Which apps work

The rule is simple: if the app is built on Chromium or Electron, it takes `--user-data-dir` and it works. `aidentity apps` scans your Mac and lists what qualifies.

| App | Works | Notes |
|---|---|---|
| Claude Desktop | Verified | `com.anthropic.claudefordesktop`. Use `--seed` to copy your MCP server config into the new profile. |
| ChatGPT | Verified | `com.openai.codex`. Chromium under the hood, despite looking native. |
| Slack | Detected | Slack's own workspace switcher covers most cases; separate profiles are for separate *accounts*. |
| Visual Studio Code | Detected | Separate profiles mean separate extensions and settings too. |
| Cursor | Detected | Same as VS Code — it is a fork. |
| Notion | Detected | |
| Notion Calendar | Detected | |
| Postman | Detected | |
| Microsoft Teams (classic) | Detected | The classic Electron build only. |
| Google Chrome | Detected | Chrome already has first-class profiles; use those first. |
| Microsoft Edge | Detected | Same — built-in profiles are the better tool. |
| Brave / Arc / Vivaldi / Comet | Detected | Browsers; built-in profiles usually beat this. |
| Antigravity | Detected | |
| Kiro | Detected | |
| Podman Desktop | Detected | |
| ChatGPT Classic | **No** | `com.openai.chat` — a native Swift app. See below. |

**Verified** means it was launched with two accounts simultaneously on a real Mac. **Detected** means the app has the Chromium/Electron structure `aidentity` looks for, so the mechanism applies, but it has not been signed into twice by hand. If one of them misbehaves, [open an issue](https://github.com/PiniShv/aidentity/issues) and the table gets fixed.

### Genuinely native apps do not work

Apps written in Swift/AppKit have no `--user-data-dir`, because they have no Chromium in them to accept it. There is no flag to pass, so there is nothing for `aidentity` to do. **ChatGPT Classic** (`com.openai.chat`) is the example you are most likely to hit: the newer ChatGPT desktop app is Chromium and works, the Classic one is native and does not.

`aidentity add` checks for this before it builds anything and refuses with an explanation rather than creating a launcher that silently opens a second window on the same account. Supporting native apps is not planned for v1.

---

## Commands

### `aidentity setup`

The guided walkthrough, and the recommended place to start. Aliases: `aidentity init`, `aidentity wizard`.

```bash
aidentity setup
```

It asks whether to badge the icons (yes by default), lists the compatible apps on this Mac by number, asks what to call the account, offers to copy your Claude MCP config when the app is Claude Desktop, then loops so you can set up several accounts in one pass. At the end it offers to open `~/Applications` so you can drag the new icons to your Dock.

It needs a terminal — in a script or a CI job, use `add` with flags instead.

### `aidentity add`

Create one profile directly. With no arguments it runs a short wizard: pick an app from a numbered list, type a name for the account.

```bash
aidentity add
```

Fully specified, no prompts:

```bash
aidentity add Claude --profile Work --color blue --seed
```

| Option | What it does |
|---|---|
| `--profile NAME` | The account name, e.g. `Work`. Letters, numbers, spaces, hyphens, underscores; 40 characters max. |
| `--badge X` | One character for the icon badge. Defaults to the first letter of the profile name. |
| `--color NAME` | `blue` `green` `orange` `purple` `teal` `pink` `red` `yellow` `gray` `graphite`, or a hex value like `2E7DF6`. Defaults to a colour derived from the name, so a given profile always looks the same. |
| `--no-badge` | Skip the badge entirely. The launcher gets the app's own icon, byte for byte unchanged, under the profile's name. The walkthrough asks this as a question and defaults to badges on. |
| `--seed` | Claude Desktop only: copy your existing `claude_desktop_config.json` (your MCP servers) into the new profile. They diverge from that point on. |

The launcher is named `<App> <Profile>` — `aidentity add Claude --profile Work` produces `~/Applications/Claude Work.app`. That full string is the name you use with `open` and `rm`.

The app argument accepts a name or a path, and matching is case-insensitive:

```bash
aidentity add ChatGPT --profile Personal
aidentity add "/Applications/Visual Studio Code.app" --profile Client
```

### `aidentity list`

Every profile, its target app, where its data lives, and whether it is running right now.

```bash
aidentity list
```

```text
Claude Work
   app      Claude
   profile  Work
   status   running
   data     ~/Library/Application Support/aidentity/profiles/claude-work
```

Status is `running`, `in use` (has data, not currently open), or `signed out / new`.

### `aidentity open`

Launch a profile from the terminal, instead of double-clicking it in Finder.

```bash
aidentity open "Claude Work"
```

### `aidentity rm`

Remove a launcher. Data is kept by default, so you can rebuild the launcher later and still be signed in.

```bash
aidentity rm "Claude Work"
```

Remove the launcher *and* delete the account's local data — cookies, session, settings. This cannot be undone:

```bash
aidentity rm "Claude Work" --purge
```

Add `-y` / `--yes` to skip the confirmation prompt (for scripts). `rm` refuses to run while that profile is open — quit it first.

### `aidentity apps`

Everything installed on this Mac that can take extra accounts, with bundle identifiers.

```bash
aidentity apps
```

### `aidentity doctor`

Checks the macOS version, the aidentity version, the bash version, whether `~/Applications` is writable, whether `codesign` is available, how many compatible apps it can see, and how many profiles exist. Run it first when something looks wrong.

```bash
aidentity doctor
```

### `aidentity version` / `aidentity help`

```bash
aidentity version
aidentity help
```

### Environment variables

| Variable | Default |
|---|---|
| `AIDENTITY_APPS_DIR` | `~/Applications` — where launchers are written |
| `AIDENTITY_DATA_ROOT` | `~/Library/Application Support/aidentity/profiles` — where profile data lives |

The test suite sets both, which is how it runs without touching a real machine's apps.

---

## The rough edge: Dock tiles show the original app

This is the one real cost, and it is worth knowing before you install.

The **launcher** icon carries your profile's name and its coloured letter badge — that is what you see in Finder and what you drag to the Dock. But once the app is running, the Dock tile is the *app's* tile, and its name and icon come from inside the app bundle, which `aidentity` deliberately does not modify. So two running profiles of Claude both show a tile labelled "Claude", with Claude's icon.

Telling them apart in practice:

- **The window itself.** Most of these apps show the signed-in account in the sidebar, title bar or avatar. That is usually enough.
- **Give each profile a different badge colour.** The launcher icons in Finder — and pinned in your Dock — stay distinct, so you always launch the right one.
- **Mission Control / App Exposé** (swipe up, or `Ctrl`+`Up`) shows all windows at once with their content visible.
- **`aidentity list`** tells you which profiles are running right now.

Fixing this properly would mean copying and re-signing the app bundle. That was tried: an ad-hoc signature cannot claim the vendor's team ID, so the copy breaks keychain access and often will not launch at all. Keeping your app untouched is worth an ambiguous Dock label.

---

## Is this safe?

**Your existing account and data are not touched.** `aidentity` never reads, moves or modifies your current profile. New profiles start empty in their own directory. Your original app keeps launching exactly as before, into exactly the account it was already in.

**The app is never copied, patched or re-signed.** The launcher is a five-line shell script in a hand-written `.app` bundle that calls `open -na` on the app already installed. Because the real bundle is untouched, its Apple signature stays valid, its keychain access groups keep working (SSO, passkeys) and its auto-updater keeps updating it.

**Every launcher is marked, and nothing unmarked is ever touched.** Each bundle `aidentity` builds carries a custom `Info.plist` key, `AIdentityProfile`. Any command that modifies or deletes a bundle checks for that key first and refuses without it. That is what makes a profile named after a real app harmless: if `~/Applications/Claude Work.app` existed and `aidentity` did not create it, `add` refuses to overwrite it and `rm` refuses to delete it.

**`--purge` only deletes inside its own data root.** It checks the recorded data path against `AIDENTITY_DATA_ROOT` before removing anything. A path outside that root is reported and left alone.

**Where things live:**

```text
~/Applications/<App> <Profile>.app                          the launcher
~/Library/Application Support/aidentity/profiles/<slug>/    that account's data
```

**No special permissions.** No `sudo` for anything except optionally installing the script into `/usr/local/bin`. No Accessibility or Full Disk Access prompts, no TCC grants, no background process, no network access — `aidentity` never phones home, because there is nothing to phone home to. It is a single readable shell script; [read it](bin/aidentity) before you run it.

**To uninstall completely**, see the last question below.

---

## Frequently asked

**Does it break auto-update?**
No. Your app updates itself the way it always has, because it is still the same untouched install in `/Applications`. Only the app can update itself, and `aidentity` is not in that path.

**What happens when the app updates?**
Nothing you need to do. The launcher stores the *path* to the app, not a copy of it, so the next launch picks up the new version automatically. There is no rebuild step after an update.

**Can I use more than two accounts?**
Yes. There is no limit in the tool — run `add` once per account. Each gets its own directory, its own lock, its own badge. The practical ceiling is RAM: every profile is a full instance of the app.

**Does it work with Claude Code or other CLIs?**
No, and it does not need to. `aidentity` works on desktop app bundles that accept `--user-data-dir`; CLI tools store their credentials differently and generally already support multiple accounts or config paths of their own. One connection worth noting: Claude Desktop keeps its MCP server list inside the profile, so a new profile starts with none — `aidentity add --seed` copies your existing config across as a starting point, after which the two configs are independent.

**Why do both running Dock tiles show the same app name and icon?**
Because that name and icon live inside the app bundle, which is deliberately left alone. Only the launcher carries your profile's name and badge. See [The rough edge](#the-rough-edge-dock-tiles-show-the-original-app) for how to tell windows apart.

**Is this against the terms of service?**
`aidentity` creates separate local data directories and passes a documented command-line flag. It does not circumvent authentication, share credentials, bypass licensing, or modify the application — you still sign into each account normally, with that account's own credentials. That said, terms differ by product and by plan, some of which limit how many devices or sessions one seat may use. Check the terms of the plans you are signed into. This is not legal advice, and nothing here is a guarantee about your situation.

**Both accounts are on the same plan — do I need two subscriptions?**
That is between you and the vendor, and it depends on whether the two accounts are separate accounts (usually yes, each pays its own way) or one account used twice. `aidentity` does not change what you are entitled to; it changes how many windows you can have open.

**Something went wrong. Where do I start?**
`aidentity doctor`. It reports the writability of the launcher directory, whether `codesign` is present, and how many compatible apps it can see. If a launcher opens the app on your *original* account, the app is probably native rather than Chromium — check `aidentity apps` for whether it is listed at all.

**How do I remove everything?**

```bash
aidentity list                              # see what exists
aidentity rm "Claude Work" --purge -y       # repeat for each profile
```

Then remove the tool itself:

```bash
brew uninstall aidentity          # if installed via Homebrew
rm -f /usr/local/bin/aidentity    # if installed via curl or make
rm -rf ~/Library/Application\ Support/aidentity
```

That is everything. Nothing else was installed, and your real apps are exactly as they were.

---

## Requirements

macOS, and the `bash` that already ships with it (3.2 — no newer shell required). Everything else is a system tool: `PlistBuddy`, `plutil`, `iconutil`, `osascript`, `open`. Xcode Command Line Tools are optional; without them launchers are unsigned, which does not stop them from running.

---

## Contributing

Issues and pull requests are welcome: <https://github.com/PiniShv/aidentity>.

The most useful contribution is a report on a specific app — which one, macOS version, and what happened. That is how the compatibility table gets more "Verified" rows and fewer "Detected" ones.

If you are changing code: the script targets bash 3.2, so no associative arrays, no `${var^^}`, no `mapfile`. Keep it dependency-free — everything it calls ships with macOS. Tests set `AIDENTITY_APPS_DIR` and `AIDENTITY_DATA_ROOT` so they never touch a real install; please do the same.

## Licence

MIT. See [LICENSE](LICENSE).

Built by [Pini Shvartsman](https://pinishv.com) — <contact@pinishv.com>.
