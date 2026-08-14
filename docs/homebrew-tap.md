# Publishing aidentity to Homebrew

A tap is just a GitHub repo named `homebrew-<something>` with a `Formula/`
directory in it. Homebrew clones it and reads the `.rb` files. There is no
registry to apply to and nothing to approve.

The formula in this repo (`Formula/aidentity.rb`) is the file you copy into the
tap. It carries a placeholder checksum marked `REPLACE_AFTER_TAGGING`, because
the checksum cannot exist until the tag does.

## Checklist

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

3. **Create the tap repo.** It must be named `homebrew-tap` — Homebrew maps
   `PiniShv/tap` to `github.com/PiniShv/homebrew-tap`. Public, MIT, no README
   needed (though one is polite).

   ```sh
   gh repo create PiniShv/homebrew-tap --public --description "Homebrew formulae by Pini Shvartsman"
   ```

4. **Copy the formula in** and replace the placeholder.

   ```sh
   git clone https://github.com/PiniShv/homebrew-tap
   mkdir -p homebrew-tap/Formula
   cp Formula/aidentity.rb homebrew-tap/Formula/aidentity.rb
   ```

   Open `homebrew-tap/Formula/aidentity.rb`, put the hex from step 2 in the
   `sha256` line, and delete the `REPLACE_AFTER_TAGGING` comment block above it.
   If that marker is still in the file, the formula is not ready to ship.

5. **Test it locally before pushing.**

   ```sh
   brew install --build-from-source homebrew-tap/Formula/aidentity.rb
   brew test aidentity
   brew audit --strict --new homebrew-tap/Formula/aidentity.rb
   ```

   `brew audit` is the one that catches naming and metadata mistakes. Fix
   whatever it flags. `--new` is only meaningful the first time; drop it on
   later versions.

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

8. **Put the two lines in the README** so people never have to find this file:

   ```sh
   brew tap PiniShv/tap
   brew install aidentity
   ```

## Releasing a new version later

1. Tag `vX.Y.Z` and push it.
2. Bump `AIDENTITY_VERSION` in `bin/aidentity` **before** tagging — the formula's
   `test do` block asserts that `aidentity version` prints the formula's version,
   so a mismatch fails `brew test`.
3. In the tap: update `url` to the new tag, recompute `sha256` (step 2 above),
   commit, push. Nothing else changes.

Users get it with `brew update && brew upgrade aidentity`.

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
