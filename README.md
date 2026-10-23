<p align="center">
  <img src="assets/logo.svg" alt="" width="128" height="128">
</p>

# aidentity

macOS runs one copy of an app, so you get one account — sign out of work Claude to check personal Claude, then sign back in. `aidentity` builds a small launcher per account so you can run them side by side, each signed in, at the same time.

![macOS only](https://img.shields.io/badge/macOS-only-111?logo=apple&logoColor=white)
![No dependencies](https://img.shields.io/badge/dependencies-none-2FB344)
![License MIT](https://img.shields.io/badge/license-MIT-2E7DF6)

![Terminal recording: aidentity lists the compatible apps, creates three profiles, shows them with aidentity list, renames one and recolours it, then runs doctor](assets/demo.gif)

<sub>Recorded in a sandbox against fixture apps — the home directory, app search path, launcher directory and data root all point at a throwaway temporary folder, so nothing from a real machine appears. `assets/record-demo.sh` regenerates it from `assets/demo.tape`.</sub>

---

## 30 seconds

```bash
curl -fsSL https://raw.githubusercontent.com/PiniShv/aidentity/main/install.sh | bash
```

That is the whole thing — the installer ends by offering to run the walkthrough, so one command covers it. The walkthrough asks whether to badge the icons, shows a numbered list of the apps on your Mac that qualify, and asks what to call each account. Open the launcher it builds, sign in with the second account, and both windows stay signed in from then on. Nothing else to configure.

Homebrew works too, in either spelling:

```bash
brew install pinishv/tap/aidentity
```

```bash
brew tap pinishv/tap && brew install aidentity
```

Only the `curl` installer offers the walkthrough at the end. After a Homebrew install — or if you said no, or you want to add another account later — start it yourself:

```bash
aidentity setup
```

`aidentity add` is the same thing in direct, scriptable form — one profile, all of it on the command line.

Every route puts one file — a shell script — on your `PATH`. There is no daemon, no login item, and nothing that runs in the background.

**What each channel checks.** The Homebrew formula pins the sha256 of a tagged release tarball, committed to the tap before anyone installs it. The `curl` installer verifies the script it downloads against a `SHA256SUMS` file served from the same origin: that catches a truncated transfer, a corrupted or stale cached object, and a mix of two versions, but not deliberate tampering — whoever can change the file on that origin, or intercept the connection, can change its checksum too. Homebrew is the more verifiable of the two.

<details>
<summary>Install from source</summary>

```bash
git clone https://github.com/PiniShv/aidentity.git
cd aidentity && make install
```

Same single script, same `PATH`. Run `aidentity setup` when you are ready.

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

It asks whether to badge the icons (yes by default), lists the compatible apps on this Mac by number, asks what to call the account, offers to copy your Claude MCP config when the app is Claude Desktop, offers a `Main` launcher for your original account (see [below](#opening-your-original-account-while-a-profile-runs)), then loops so you can set up several accounts in one pass. At the end it offers to open `~/Applications` so you can drag the new icons to your Dock.

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
| `--profile NAME` | The account name, e.g. `Work`. Letters, numbers, spaces, hyphens, underscores; 40 characters max. It cannot start with a space, a dot or a hyphen. |
| `--badge X` | One character for the icon badge. Defaults to the first letter of the profile name. |
| `--color NAME` | `blue` `green` `orange` `purple` `teal` `pink` `red` `yellow` `gray` `graphite`, or a hex value like `2E7DF6`. Defaults to a colour derived from the name, so a given profile always looks the same. |
| `--no-badge` | Skip the badge entirely. The launcher gets the app's own icon, byte for byte unchanged, under the profile's name. The walkthrough asks this as a question and defaults to badges on. |
| `--seed` | Claude Desktop only: copy your existing `claude_desktop_config.json` (your MCP servers) into the new profile. They diverge from that point on. |
| `--main` | Build a launcher for your **original** account instead of a new one, named `<App> Main` unless you pass `--profile`. Pin it to your Dock in place of the app — see [Opening your original account](#opening-your-original-account-while-a-profile-runs). |
| `--arg SWITCH` | Pass a switch to the app every time this profile opens. Repeatable. See [Per-profile settings](#per-profile-settings). |
| `--env NAME=value` | Set an environment variable for this profile. Repeatable. |
| `--own-extensions` | VS Code, Cursor and Kiro only: give this profile its own extensions folder instead of sharing yours. |

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

Status is `running`, `in use` (the app has written data there, not currently open), or `signed out / new`. "In use" means the profile has been opened, not that a sign-in is still valid. A `--main` launcher shows `running` or `not running`, for your original account. A launcher whose app has moved shows `app missing` with the `rebuild` command that fixes it; if the app was uninstalled, reinstall it first.

### `aidentity open`

Launch a profile from the terminal, instead of double-clicking it in Finder.

```bash
aidentity open "Claude Work"
```

### `aidentity rename`

Rename a profile. The data directory moves with the launcher, so the account stays signed in. Alias: `aidentity mv`.

```bash
aidentity rename "Claude Work" Client
```

The second argument is the new *account* name; the launcher keeps the app prefix, so this produces `~/Applications/Claude Client.app` and moves the profile directory to `…/profiles/claude-client`. The data is moved first and the launcher rebuilt second — if the rebuild fails, the move is rolled back and nothing changes. `rename` refuses to run while the profile is open, because moving the directory out from under a running instance would break it. It also refuses if the new name collides with an existing launcher or profile directory.

### `aidentity set`

Change a profile's badge or colour without touching its account. Aliases: `modify`, `edit`.

```bash
aidentity set "Claude Work" --color purple
aidentity set "Claude Work" --badge W
aidentity set "Claude Work" --no-badge
```

`--color`, `--badge`, `--no-badge`, `--arg`, `--env` and `--own-extensions` take the same values as on `add`; `--clear-args`, `--clear-env` and `--shared-extensions` undo them. At least one of them is required. A new `--env` value replaces one with the same name. Only the launcher bundle and the small restore record beside the profile are rewritten — the app's own data is never opened — so this is safe with the app running. Asking for a colour on a launcher that has no badge adds one back, using the first letter of the profile name.

### `aidentity prune`

Find profile data that no launcher points at, and offer to delete it.

```bash
aidentity prune
```

This is what gets left behind when a launcher is deleted in Finder, or removed with `aidentity rm` without `--purge`: the directory stays, holding a signed-in session. `prune` lists each orphan with its disk size and full path, then asks you to type `yes`. `-y` / `--yes` skips that prompt. Anything currently running is skipped, and so is anything recorded outside the data root.

Before calling anything an orphan, `prune` looks for launchers in the launcher directory and the folders inside it, in the app search path, and through Spotlight, and it compares directories by identity rather than by how their path is spelled. If you keep a launcher somewhere else entirely, its data shows up in the list — read it before you type `yes`.

### `aidentity restore`

Rebuild the launcher of a profile whose launcher is gone — deleted in Finder, or removed with `aidentity rm` without `--purge` — so the account opens again, still signed in.

```bash
aidentity restore                    # list what can be restored
aidentity restore "Claude Work"
aidentity restore --all
```

Every profile folder holds a small restore record, `.aidentity-profile.plist`: the profile name, the app, the badge and the colour. The app ignores it. `restore` reads it, finds the app again (by name or bundle ID if it moved), and builds the launcher with the same look. Everything in the record is checked as if you had typed it. Profiles made before this version get a record the next time their launcher is rebuilt, which `aidentity doctor --fix` does for you. `prune` names the folders that can be restored before it offers to delete them.

### `aidentity rebuild`

Regenerate launchers after the app they point at moved. Alias: `repair`.

```bash
aidentity rebuild "Claude Work"
aidentity rebuild --all
```

Each launcher stores the path of the app it opens. If that path no longer exists, `rebuild` looks the app up again by name across the search path, which covers a move between `/Applications` and `~/Applications`; if it still cannot be found, that profile is reported and skipped rather than rewritten, and `rebuild` exits non-zero. Profile data is never touched, so every account stays signed in. A launcher built by aidentity 1.0.0 gets its default badge and colour back; a colour you picked by hand back then can be set again with `aidentity set`.

### `aidentity rm`

Remove a launcher. Data is kept by default, so you can bring the launcher back later and still be signed in — `rm` prints the exact `aidentity add` line that reattaches it, and `aidentity prune` deletes the data when you are sure.

```bash
aidentity rm "Claude Work"
```

Remove the launcher *and* delete the account's local data — cookies, session, settings. This cannot be undone:

```bash
aidentity rm "Claude Work" --purge
```

Add `-y` / `--yes` to skip the confirmation prompt (for scripts). `rm` refuses to run while that profile is open — quit it first. On a `--main` launcher, `--purge` does nothing: that launcher opens the app's own account, and aidentity never deletes the app's own data.

### `aidentity apps`

Everything installed on this Mac that can take extra accounts, with bundle identifiers.

```bash
aidentity apps
```

### `aidentity doctor`

Checks the macOS version, the aidentity version, the bash version, whether `~/Applications` is writable, whether `codesign` is available and how many compatible apps it can see. Then one row per profile: a launcher built by an older version, an app that moved or is gone, a profile folder other users can read, a missing restore record, two launchers sharing a folder, and profile folders no launcher points at. Run it first when something looks wrong.

```bash
aidentity doctor
```

`--fix` repairs what it can without a person: it rebuilds stale launchers (which also writes missing restore records) and makes profile folders owner-only. It never reads or changes the data inside a profile folder, and it leaves anything that needs a decision — a deleted app, a folder outside the data root — for you.

```bash
aidentity doctor --fix
```

`doctor` always exits 0, so scripts can call it for the report. `doctor --fix` exits 1 if something it tried to fix could not be fixed.

### `aidentity version` / `aidentity help`

```bash
aidentity version
aidentity help
```

### Environment variables

| Variable | Default |
|---|---|
| `AIDENTITY_APP_DIRS` | `/Applications:$HOME/Applications` — colon-separated list of directories searched for compatible apps |
| `AIDENTITY_APPS_DIR` | `~/Applications` — where launchers are written |
| `AIDENTITY_DATA_ROOT` | `~/Library/Application Support/aidentity/profiles` — where profile data lives |

The first two are one letter apart and mean different things: the plural `APP_DIRS` is where your *apps* are looked for, `APPS_DIR` is where aidentity *writes* its launchers.

The test suite sets `AIDENTITY_APPS_DIR` and `AIDENTITY_DATA_ROOT`, which is how it runs without touching a real machine. The demo recording sets all three, so it never scans the apps actually installed.

---

## Opening your original account while a profile runs

macOS keeps one record per app, not per window. Every profile is the same `Claude.app` started a second time, so while any profile is running, macOS considers Claude to be running. Click `Claude.app` in the Dock, in Finder or in Spotlight, and macOS does what it always does for a running app: it switches to it. You land in whichever profile is open, and your original account does not start.

The fix is a launcher for the original account:

```bash
aidentity add Claude --main
```

That builds `~/Applications/Claude Main.app`. It starts Claude with no profile directory, so it opens the account Claude.app always opened, with Claude's own data. It always starts, even while other profiles run. If your original account is already open, Claude hands the launch to that window and brings it forward, as most Electron apps do. Pin it to your Dock in place of `Claude.app`. `aidentity setup` offers to build it for you.

From a terminal, `open -na /Applications/Claude.app` does the same thing.

A main launcher never touches the app's data: `rm --purge` does not delete it, and `rename` only renames the launcher.

---

## Per-profile settings

A profile can carry a few launch settings of its own — a proxy for a client's network, a language, a display scale:

```bash
aidentity add Claude --profile Client --arg --proxy-server=socks5://127.0.0.1:1080
aidentity set "Claude Client" --arg --lang=de --env HTTPS_PROXY=http://proxy.example:8080
aidentity add "Visual Studio Code" --profile Client --own-extensions
```

Only an allowlist gets through: a launcher is one click for anyone at this Mac, and many switches and variables can hand the app to another program or switch off its protections. Allowed switches: `--proxy-server`, `--proxy-bypass-list`, `--no-proxy-server`, `--lang`, `--locale`, `--force-device-scale-factor`, `--disable-gpu`, `--disable-lcd-text`. Allowed variables: the proxy ones (`HTTP_PROXY`, `HTTPS_PROXY`, `ALL_PROXY`, `NO_PROXY`, also lower-case), `LANG`, `LC_ALL`, `LC_CTYPE`, `LC_MESSAGES`, `TZ`. Each value must have the exact shape its job needs, and the same check runs again on `rebuild`, `rename` and `restore`: a stored setting that is not allowed is dropped with a note, never passed on. Do not put passwords in launch settings; a launcher that carries settings is readable by you only, but it is still a plain file.

The settings are stored in the launcher, and in the restore record inside the profile folder. `aidentity list` shows the switches and the names of the variables, never their values.

VS Code and its forks keep extensions outside the profile folder, so by default every profile shares yours. `--own-extensions` gives the profile its own `extensions` folder inside its profile folder. aidentity recognises VS Code, Cursor and Kiro by their `product.json`.

Every launcher also removes variables like `NODE_OPTIONS`, `ELECTRON_*` and `VSCODE_*` before it opens the app. `open` passes its own environment on, so a profile opened from a terminal used to inherit them.

---

## Signing in to a new profile

When several copies of one app run, macOS hands an opened link to the copy that started **first**. A browser sign-in comes back as such a link, so signing in to a new profile while another copy runs can land the sign-in in the other profile.

So the first time a new profile opens while another copy of the app runs, its launcher says so once and offers **Cancel** or **Open Anyway**. The safe order is to quit the other windows of that app, sign in to the new profile, then open the others again. After that first sign-in, each profile stays signed in on its own. `add` and `setup` print the same advice when the app is already open.

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

**Clicking a profile that is already open.** Its launcher starts the app again with the same profile folder; the app sees its own copy already running, hands the click to it, and that copy comes forward — reopening its window if you had closed it. Bringing the running copy forward directly would skip that step, but a copy whose window was closed would come forward with no window at all, so the launcher keeps the handoff.

Renaming a running copy from outside the app does not work either: macOS ignores the change. Only the app itself could rename its entry, and that would mean modifying it.

---

## Is this safe?

**Your existing account and data are not touched.** `aidentity` never reads, moves or modifies your current profile. New profiles start in their own directory, empty except for a small restore record. Your original app keeps its account and its data. One thing does change: while a profile is running, clicking the app itself switches to that profile instead of opening your original account. A `--main` launcher fixes that — see [Opening your original account](#opening-your-original-account-while-a-profile-runs).

**The app is never copied, patched or re-signed.** The launcher is a short shell script in a hand-written `.app` bundle that calls `open -na` on the app already installed. Because the real bundle is untouched, its Apple signature stays valid, its keychain access groups keep working (SSO, passkeys) and its auto-updater keeps updating it.

**Every launcher is marked, and nothing unmarked is ever touched.** Each bundle `aidentity` builds carries a custom `Info.plist` key, `AIdentityProfile`. Any command that modifies or deletes a bundle checks for that key first and refuses without it. That is what makes a profile named after a real app harmless: if `~/Applications/Claude Work.app` existed and `aidentity` did not create it, `add` refuses to overwrite it and `rm` refuses to delete it.

**`--purge` only deletes inside its own data root.** It checks the recorded data path against `AIDENTITY_DATA_ROOT` before removing anything. A path outside that root is reported and left alone.

**Where things live:**

```text
~/Applications/<App> <Profile>.app                          the launcher
~/Library/Application Support/aidentity/profiles/<slug>/    that account's data
```

**No special permissions.** No `sudo` for anything except optionally installing the script into `/usr/local/bin`. No Accessibility or Full Disk Access prompts, no TCC grants, no background process, no network access — `aidentity` never phones home, because there is nothing to phone home to. It is a single readable shell script; [read it](bin/aidentity) before you run it.

**To uninstall completely**, see "How do I remove everything?" below.

---

## Frequently asked

**Does it break auto-update?**
No. Your app updates itself the way it always has, because it is still the same untouched install in `/Applications`. Only the app can update itself, and `aidentity` is not in that path.

**What happens when the app updates?**
Nothing you need to do. The launcher stores the *path* to the app, not a copy of it, so the next launch picks up the new version automatically. The one case that needs a hand is the app *moving* — reinstalled into `~/Applications` instead of `/Applications`, say. Then run `aidentity rebuild --all`, which finds it again by name and rewrites the launchers.

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
`aidentity doctor`. It reports the writability of the launcher directory, whether `codesign` is present, and how many compatible apps it can see. If a launcher other than a `--main` one opens the app on your *original* account, the app is probably native rather than Chromium — check `aidentity apps` for whether it is listed at all.

**How do I remove everything?**

The uninstaller does all of it in one go. It removes the command, then lists every launcher it can find — in `~/Applications` and the folders inside it, in `/Applications`, and through Spotlight — and every profile directory, including data no launcher points at any more. It deletes them only after you type `delete`. Download it, then run it in a terminal:

```bash
curl -fsSLO https://raw.githubusercontent.com/PiniShv/aidentity/main/uninstall.sh
```

```bash
bash uninstall.sh
```

It leaves a Homebrew install alone (remove that with `brew uninstall aidentity`), and it refuses to delete the data of a profile that is running.

By hand, it is:

```bash
aidentity list                              # see what exists
aidentity rm "Claude Work" --purge -y       # repeat for each profile
aidentity prune -y                          # data no launcher points at
brew uninstall aidentity                    # if installed via Homebrew
rm -f "$(command -v aidentity)"             # if installed via curl or make
rm -rf ~/Library/Application\ Support/aidentity   # the now-empty data folder
```

The curl installer puts the command in `/usr/local/bin`, or in `~/.local/bin` when that is not writable, so `command -v` is the safe way to find it. That is everything. Nothing else was installed, and your real apps are exactly as they were.

**Clicking Claude.app opens one of my profiles, not my original account.**
macOS sees every profile as Claude itself, so it switches to whichever one is running. Use `aidentity add Claude --main` — see [Opening your original account](#opening-your-original-account-while-a-profile-runs).

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
