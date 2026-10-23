# Publishing aidentity to Homebrew

A tap is just a GitHub repo named `homebrew-<something>` with a `Formula/`
directory in it. Homebrew clones it and reads the `.rb` files. There is no
registry to apply to and nothing to approve.

The tap is live at <https://github.com/PiniShv/homebrew-tap>, so users install
with `brew install pinishv/tap/aidentity`. The formula in this repo
(`Formula/aidentity.rb`) is the copy of record; publishing means copying it into
the tap with a `sha256` that matches the tag it points at.

## Checklist

Steps 3 and 8 are one-time and already done. For a routine release, see
[Releasing a new version later](#releasing-a-new-version-later) below.

1. **Tag and push the release.** The tarball URL in the formula points at a tag,
   so the tag has to exist first.

   ```sh
   git tag -a v1.0.0 -m "aidentity 1.0.0"
   git push origin v1.0.0
   ```

   Confirm GitHub is serving the tarball before going further:

   ```sh
   curl -sIL https://github.com/PiniShv/aidentity/archive/refs/tags/v1.0.0.tar.gz | head -n 1
   ```

2. **Compute the sha256** of that exact tarball.

   ```sh
   curl -sL https://github.com/PiniShv/aidentity/archive/refs/tags/v1.0.0.tar.gz | shasum -a 256
   ```

   That prints 64 hex characters followed by `-`. Copy the hex only.

3. **Create the tap repo.** Done once, in August 2026 — the repo exists and is
   public. It must be named `homebrew-tap`, because Homebrew maps `PiniShv/tap`
   to `github.com/PiniShv/homebrew-tap`.

   ```sh
   gh repo create PiniShv/homebrew-tap --public --description "Homebrew formulae by Pini Shvartsman"
   ```

4. **Copy the formula in** and replace the placeholder.

   ```sh
   git clone https://github.com/PiniShv/homebrew-tap
   mkdir -p homebrew-tap/Formula
   cp Formula/aidentity.rb homebrew-tap/Formula/aidentity.rb
   ```

   Open `homebrew-tap/Formula/aidentity.rb` and put the hex from step 2 in the
   `sha256` line. Check the `url` names the tag you just pushed: a formula whose
   checksum and tarball disagree fails on the user's machine, not yours.

5. **Test it through the tap, not a file path.** Current Homebrew refuses to
   install or audit a formula given as a path (`brew install path/to/x.rb`
   fails, and `brew audit <path>` is disabled), and a relative path is read as a
   tap name. Push the formula to a branch of the tap, point your local tap at
   it, then:

   ```sh
   brew tap PiniShv/tap
   brew install --build-from-source pinishv/tap/aidentity
   brew test pinishv/tap/aidentity
   brew audit --strict pinishv/tap/aidentity
   ```

   `brew audit` is the one that catches naming and metadata mistakes. Add
   `--new` only the first time a formula is published. Running `brew audit`
   switches on Homebrew's developer mode; `brew developer off` turns it off.

6. **Push the tap.**

   ```sh
   cd homebrew-tap
   git add Formula/aidentity.rb
   git commit -m "aidentity 1.0.0"
   git push
   ```

7. **Verify the path a stranger takes.** Uninstall your local build first so you
   are testing the tap and not leftovers.

   ```sh
   brew uninstall aidentity
   brew untap PiniShv/tap 2>/dev/null
   brew tap PiniShv/tap
   brew install aidentity
   aidentity version
   ```

8. **Put the install lines in the README** so people never have to find this
   file. Done — the README lists both spellings alongside the `curl` installer:

   ```sh
   brew install pinishv/tap/aidentity
   brew tap pinishv/tap && brew install aidentity
   ```

## Releasing a new version later

Do it in this order. A tag is never moved once it is pushed: people's
Homebrew installs and the `curl` installer both pin to it.

1. **Prepare the release on a branch.**

   ```sh
   make release VERSION=X.Y.Z
   ```

   This sets `AIDENTITY_VERSION`, points `install.sh`'s default ref at
   `vX.Y.Z` (so `curl | bash` installs the release, script and checksum from the
   same tag), turns `[Unreleased]` in the changelog into `[X.Y.Z]`, regenerates
   `SHA256SUMS` and runs the guards. Check `bin/aidentity version` prints
   `X.Y.Z`: the formula's `test do` block only checks the format, so that
   `--HEAD` builds pass.
2. **Commit, open a PR, let CI pass, merge.**
3. **Tag the merge commit and push the tag — right after the merge.** From
   the merge on, `main`'s installer asks for `vX.Y.Z`; until that tag exists,
   `curl | bash` fails with a download error.

   ```sh
   git tag vX.Y.Z <merge commit> && git push origin vX.Y.Z
   ```

4. **Point the formula at the tag.** The tarball's checksum exists only once
   the tag does.

   ```sh
   make formula VERSION=X.Y.Z
   ```

   Commit that change to this repository, copy `Formula/aidentity.rb` into the
   tap, and test it through the tap (step 5 above) before you push the tap.

Users get it with `brew update && brew upgrade aidentity`, and the `curl`
installer serves it as soon as `main` carries the new default ref.

## Notes

- `depends_on :macos` is correct and load-bearing. aidentity builds `.app`
  bundles and shells out to `iconutil`, `PlistBuddy`, `codesign` and
  `lsregister`; on Linux the formula should refuse to install, not fail later.
- No bottles. The formula installs one shell script, so building from source is
  instant and there is nothing to compile or host.
- Nothing in the formula touches `~/Applications` or the profile data root.
  Homebrew installs the CLI; the CLI creates those directories the first time
  you run `aidentity add`. `brew uninstall aidentity` therefore leaves your
  launchers and profiles alone — remove those with `aidentity rm` first if you
  want them gone.
