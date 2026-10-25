# shellcheck shell=bash
# SC2016: single-quoted scripts are handed to "$BASH_BIN" -c and to generated
# stubs, which expand them later, on purpose. shellcheck only recognises that
# when the interpreter is spelled literally as `bash -c`.
# shellcheck disable=SC2016
#
# Area "release": release notes, the release check, and the build of
# bin/aidentity from src/.
# Sourced by test/run_tests.sh after test/lib.sh. Run it alone with:
#   bash test/run_tests.sh release

group "release notes, from the changelog"

# scripts/release-notes.sh builds the text of a GitHub release: an install
# header, then the version's CHANGELOG section. stdout and stderr stay apart,
# because the release workflow writes stdout into the release.
RELNOTES="$REPO_DIR/scripts/release-notes.sh"
relnotes() { # version, optional changelog path
  RUN_OUT=$(detached "$BASH_BIN" "$RELNOTES" "$@" 2>"$SANDBOX/stderr" </dev/null)
  RUN_RC=$?
  RUN_ERR=$(cat "$SANDBOX/stderr")
  return 0
}

# The 1.3.0 section, cut from the real changelog a different way (sed between
# the two headings, blank edges trimmed). The release is old, so it is frozen.
want_130=$(sed -n '/^## \[1\.3\.0\]/,/^## \[1\.2\.0\]/p' "$REPO_DIR/CHANGELOG.md" | sed '1d;$d' | sed '/./,$!d')
relnotes 1.3.0
assert_rc "the 1.3.0 notes are produced" 0 "$RUN_RC" "$RUN_ERR"
assert_eq "nothing goes to stderr on success" "" "$RUN_ERR"
want_lines=$(printf '%s\n' "$want_130" | wc -l | tr -d ' ')
assert_eq "the 1.3.0 section is extracted exactly, to its last line" "$want_130" \
  "$(printf '%s\n' "$RUN_OUT" | tail -n "$want_lines")"
assert_eq "it starts with the section's first line, after a blank line" "" \
  "$(printf '%s\n' "$RUN_OUT" | tail -n "$((want_lines + 1))" | head -n 1)"
assert_contains "the header has the install line for this tag" "$RUN_OUT" \
  "curl -fsSL https://raw.githubusercontent.com/PiniShv/aidentity/v1.3.0/install.sh | bash"
assert_contains "and the Homebrew line" "$RUN_OUT" "brew install pinishv/tap/aidentity"
# GitHub lists its own "Source code" archives under the notes. They are not
# signed, so the header must name the four files that are, not say "each file".
assert_contains "the header names the four signed files" "$RUN_OUT" \
  '`aidentity`, `install.sh`, `uninstall.sh` and `SHA256SUMS`, have signed build provenance'
assert_contains "and says the Source code archives are not signed" "$RUN_OUT" \
  'The "Source code" archives that GitHub adds to every release are not signed.'
assert_not_contains "it does not claim every file on the page is signed" "$RUN_OUT" "Each file below"
assert_eq "the header comes first" "**Install or upgrade**" "$(printf '%s\n' "$RUN_OUT" | head -n 1)"
assert_not_contains "the heading line is left out" "$RUN_OUT" "## [1.3.0]"
assert_not_contains "the next version's section is not included" "$RUN_OUT" "## [1.2.0]"
assert_not_contains "nor is its text" "$RUN_OUT" "aidentity add APP --main"
assert_not_contains "the link list at the bottom is not included" "$RUN_OUT" "[1.3.0]: https://"

# A tiny changelog for the edges: the first, last and empty sections, a blank
# line inside a section, and a version that only starts the same.
CL_FIX="$SB/fixture-changelog.md"
cat > "$CL_FIX" <<'CL'
# Changelog

## [Unreleased]

## [2.0.0] - 2030-01-02


### Added

- First.

  Still the first.

### Fixed

- Second.


## [1.5.0] - 2029-06-01

## [1.0.0] - 2028-01-01

Only text, then the link list.

[Unreleased]: https://example.invalid/compare/v2.0.0...HEAD
[2.0.0]: https://example.invalid/compare/v1.0.0...v2.0.0
[1.0.0]: https://example.invalid/releases/tag/v1.0.0
CL
relnotes 2.0.0 "$CL_FIX"
want_fix=$(printf '### Added\n\n- First.\n\n  Still the first.\n\n### Fixed\n\n- Second.')
assert_eq "a section keeps its inner blank lines and loses the ones at its edges" "$want_fix" \
  "$(printf '%s\n' "$RUN_OUT" | tail -n 9)"
assert_not_contains "and stops at the next heading" "$RUN_OUT" "1.5.0"
relnotes 1.0.0 "$CL_FIX"
assert_eq "the last section ends where the link list starts" "Only text, then the link list." \
  "$(printf '%s\n' "$RUN_OUT" | tail -n 1)"
assert_not_contains "no link line from the bottom is included" "$RUN_OUT" "example.invalid"
relnotes 1.5.0 "$CL_FIX"
assert_rc "a section with nothing in it is an error" 1 "$RUN_RC" "$RUN_OUT"
assert_contains "that says which version" "$RUN_ERR" "No notes for 1.5.0"
assert_eq "and prints no notes" "" "$RUN_OUT"
relnotes 2.0 "$CL_FIX"
assert_rc "a version that is not x.y.z is refused" 2 "$RUN_RC" "$RUN_ERR"

# An unknown version must fail, so a release is never published with blank notes.
relnotes 9.9.9
assert_rc "an unknown version fails" 1 "$RUN_RC" "$RUN_OUT"
assert_contains "and names the version" "$RUN_ERR" "No notes for 9.9.9"
assert_eq "and prints nothing on stdout" "" "$RUN_OUT"
relnotes 1.3
assert_rc "x.y is not a version" 2 "$RUN_RC" "$RUN_ERR"
relnotes v1.3.0
assert_rc "a leading v is refused" 2 "$RUN_RC" "$RUN_ERR"
assert_contains "with the usage line" "$RUN_ERR" "Usage: scripts/release-notes.sh x.y.z"
relnotes "1.3.0; touch $SB/pwned"
assert_rc "text after a version is refused" 2 "$RUN_RC" "$RUN_ERR"
assert_no_file "and runs nothing it was handed" "$SB/pwned"
relnotes ""
assert_rc "no version is refused" 2 "$RUN_RC" "$RUN_ERR"
relnotes 1.3.0 "$SB/no-such-changelog.md"
assert_rc "a changelog that cannot be read is an error" 1 "$RUN_RC" "$RUN_ERR"
assert_contains "that names the file" "$RUN_ERR" "no-such-changelog.md"

# The release workflow calls this with the version in bin/aidentity. If a
# release is prepared without a changelog section, the tag run would fail.
cur_version=$(sed -n 's/^AIDENTITY_VERSION="\(.*\)"$/\1/p' "$AIDENTITY")
relnotes "$cur_version"
assert_rc "the changelog has notes for the version in the script ($cur_version)" 0 "$RUN_RC" "$RUN_ERR"


group "release check, before anything is signed"

# scripts/release-check.sh is the release workflow's first step. It runs on a
# copy of the tree, from another directory, so it is also shown to find the
# repository by its own path. The copy is made release-ready first: install.sh
# pointing at this version's tag, as `make release` leaves it.
RC_DIR="$SB/release-check-repo"
rc_version=$(sed -n 's/^AIDENTITY_VERSION="\(.*\)"$/\1/p' "$REPO_DIR/bin/aidentity")
rc_fresh() {
  rm -rf "$RC_DIR"
  mkdir -p "$RC_DIR/bin" "$RC_DIR/scripts" "$RC_DIR/test"
  cp "$REPO_DIR/bin/aidentity" "$RC_DIR/bin/"
  cp -R "$REPO_DIR/src" "$RC_DIR/"
  cp "$REPO_DIR/uninstall.sh" "$REPO_DIR/SHA256SUMS" "$REPO_DIR/CHANGELOG.md" "$RC_DIR/"
  cp "$REPO_DIR/scripts/"*.sh "$RC_DIR/scripts/"
  cp "$REPO_DIR/test/"*.sh "$RC_DIR/test/"
  sed "s|^REF=.*|REF=\"\${AIDENTITY_REF:-v$rc_version}\"|" "$REPO_DIR/install.sh" > "$RC_DIR/install.sh"
}
rc_sed() { # file, sed script: edit one file of the copy
  sed "$2" "$RC_DIR/$1" > "$RC_DIR/$1.new" && mv "$RC_DIR/$1.new" "$RC_DIR/$1"
}
rc_run() { # tag
  RUN_OUT=$(cd "$SB" && detached "$BASH_BIN" "$RC_DIR/scripts/release-check.sh" "$@" 2>"$SANDBOX/stderr" </dev/null)
  RUN_RC=$?
  RUN_ERR=$(cat "$SANDBOX/stderr")
  return 0
}
rc_tree() { (cd "$RC_DIR" && find . -type f -exec shasum {} + | sort); }

rc_fresh
rc_before=$(rc_tree)
rc_run "v$rc_version"
assert_rc "a release-ready tree passes with its own tag (v$rc_version)" 0 "$RUN_RC" "$RUN_OUT$RUN_ERR"
assert_contains "and says so" "$RUN_OUT" "Tag v$rc_version matches version $rc_version."
assert_contains "after the source guards ran" "$RUN_OUT" "SHA256SUMS matches bin/aidentity"
assert_eq "nothing goes to stderr on success" "" "$RUN_ERR"
assert_eq "it changes no file" "$rc_before" "$(rc_tree)"

rc_run
assert_rc "no tag is a usage error" 2 "$RUN_RC" "$RUN_OUT$RUN_ERR"
assert_contains "that shows the usage" "$RUN_ERR" "Usage: scripts/release-check.sh vX.Y.Z"

# The tag must be v + the script's version. A pushed tag that is not (a tag on
# the wrong commit, a pre-release name, a missing v) is not released.
for bad_tag in v9.9.9 "$rc_version" "v$rc_version-rc1" "V$rc_version" "v$rc_version.0"; do
  rc_run "$bad_tag"
  assert_rc "tag '$bad_tag' is refused" 1 "$RUN_RC" "$RUN_OUT$RUN_ERR"
  assert_contains "with both versions named" "$RUN_ERR" "The tag is $bad_tag but bin/aidentity is version $rc_version"
done

# SHA256SUMS: stale, in shasum's binary-mode spelling, and missing.
rc_fresh
printf '%064d  bin/aidentity\n' 0 > "$RC_DIR/SHA256SUMS"
rc_run "v$rc_version"
assert_rc "stale sums are refused" 1 "$RUN_RC" "$RUN_OUT$RUN_ERR"
assert_contains "with the reason" "$RUN_ERR" "SHA256SUMS does not match bin/aidentity"
assert_contains "and the fix" "$RUN_ERR" "make checksums"
(cd "$RC_DIR" && shasum -a 256 -b bin/aidentity) > "$RC_DIR/SHA256SUMS"
assert_contains "(the sums line really is '*bin/aidentity')" "$(cat "$RC_DIR/SHA256SUMS")" " *bin/aidentity"
rc_run "v$rc_version"
assert_rc "a '*bin/aidentity' sums line is refused, as the installer would not read it" 1 "$RUN_RC" "$RUN_OUT$RUN_ERR"
assert_contains "as having no usable line" "$RUN_ERR" "expected nothing"
rm -f "$RC_DIR/SHA256SUMS"
rc_run "v$rc_version"
assert_rc "a missing SHA256SUMS is refused" 1 "$RUN_RC" "$RUN_OUT$RUN_ERR"

# A version that is not x.y.z is refused before it is compared or printed.
for odd in 1.4 1.4.0-rc1 1.2.3.4 1..0 .1.0 1.0. ""; do
  rc_fresh
  rc_sed bin/aidentity "s/^AIDENTITY_VERSION=.*/AIDENTITY_VERSION=\"$odd\"/"
  rc_run "v$odd"
  assert_rc "version '$odd' is refused" 1 "$RUN_RC" "$RUN_OUT$RUN_ERR"
  assert_contains "as not a version" "$RUN_ERR" "Could not read a version (x.y.z)"
done
rc_fresh
rc_sed bin/aidentity '/^AIDENTITY_VERSION=/d'
rc_run "v$rc_version"
assert_rc "a script with no version line is refused" 1 "$RUN_RC" "$RUN_OUT$RUN_ERR"
rc_fresh
rc_sed bin/aidentity 's|^AIDENTITY_VERSION=.*|AIDENTITY_VERSION="1.0.0$(touch pwned)"|'
rc_run 'v1.0.0$(touch pwned)'
assert_rc "a version with a command in it is refused" 1 "$RUN_RC" "$RUN_OUT$RUN_ERR"
assert_no_file "and the command never runs" "$RC_DIR/pwned"
assert_no_file "wherever it would have landed" "$SB/pwned"

# install.sh must install this tag. scripts/guards.sh accepts main there, so
# without this check a hand-made release would ship an installer for main.
rc_fresh
rc_sed install.sh 's|^REF=.*|REF="${AIDENTITY_REF:-main}"|'
rc_run "v$rc_version"
assert_rc "an installer that installs main is refused" 1 "$RUN_RC" "$RUN_OUT$RUN_ERR"
assert_contains "with what it installs" "$RUN_ERR" "installs 'main' by default"
assert_contains "and what it must install" "$RUN_ERR" "must install v$rc_version"
rc_fresh
rc_sed install.sh 's|^REF=.*|REF="${AIDENTITY_REF:-v0.0.1}"|'
rc_run "v$rc_version"
assert_rc "an installer for another tag is refused" 1 "$RUN_RC" "$RUN_OUT$RUN_ERR"
rc_fresh
rc_sed install.sh '/^REF=/d'
rc_run "v$rc_version"
assert_rc "an installer with no REF line is refused" 1 "$RUN_RC" "$RUN_OUT$RUN_ERR"
assert_contains "that says there is none" "$RUN_ERR" "installs 'nothing' by default"

# The changelog must have notes for the version.
rc_fresh
rc_sed CHANGELOG.md "s/^## \[$rc_version\]/## [0.0.1]/"
rc_run "v$rc_version"
assert_rc "a changelog without the version is refused" 1 "$RUN_RC" "$RUN_OUT$RUN_ERR"
assert_contains "naming the version" "$RUN_ERR" "No notes for $rc_version"
assert_contains "and the release" "$RUN_ERR" "has no notes for $rc_version"
assert_not_contains "and it does not say the tag matches" "$RUN_OUT" "matches version"

# The published script is checked once, here, so installed copies need not
# check it: valid shell, #! first, main "$@" last. Each break fails the guards
# even with a checksum made for the broken file.
rc_guard() { # description, guard message, sed script for bin/aidentity
  rc_fresh
  rc_sed bin/aidentity "$3"
  (cd "$RC_DIR" && shasum -a 256 bin/aidentity) > "$RC_DIR/SHA256SUMS"
  rc_run "v$rc_version"
  assert_rc "$1" 1 "$RUN_RC" "$RUN_OUT$RUN_ERR"
  assert_contains "with the guard's message" "$RUN_ERR" "$2"
}
rc_guard "a script that is not valid shell is refused" "is not valid shell (bash -n)" '$a\
if then fi'
rc_guard "a script without #! is refused" "must start with #!" '1d'
rc_guard "a script that does not end on main \"\$@\" is refused" 'must end on [main "$@"]' '$a\
echo after'
# bin/aidentity is built from src/. A change made in it alone would be lost at
# the next build, so the guards refuse it, even with a matching checksum.
rc_guard "a script edited by hand, not built from src/, is refused" "is not the build of src/" '2s/.*/# edited by hand/'

# install.sh carries a pasted copy of the download code. A copy that drifted,
# or a function defined again after it, fails the guards.
rc_fresh
rc_sed install.sh 's/--max-time 60 /--max-time 600 /'
rc_run "v$rc_version"
assert_rc "an installer whose download block differs is refused" 1 "$RUN_RC" "$RUN_OUT$RUN_ERR"
assert_contains "with the guard's message" "$RUN_ERR" "the download block differs between bin/aidentity and install.sh"
rc_fresh
rc_sed install.sh '/^main "\$@"$/i\
file_version() { echo 9.9.9; }
'
rc_run "v$rc_version"
assert_rc "an installer that defines a shared function again is refused" 1 "$RUN_RC" "$RUN_OUT$RUN_ERR"
assert_contains "with the guard's message" "$RUN_ERR" "file_version must be defined once, inside the download block"
for redef in 'function file_version { echo 9.9.9; }' 'file_version () { echo 9.9.9; }'; do
  rc_fresh
  rc_sed install.sh "/^main \"\\\$@\"\$/i\\
$redef
"
  rc_run "v$rc_version"
  assert_rc "so is one written as [$redef]" 1 "$RUN_RC" "$RUN_OUT$RUN_ERR"
  assert_contains "with the guard's message" "$RUN_ERR" "must be defined once, inside the download block"
done
# Every curl call of the installer goes through https_fetch, on error paths too.
rc_fresh
rc_sed install.sh '/^verify() {$/a\
  curl -fsS "$SUMS_URL" >/dev/null || true
'
rc_run "v$rc_version"
assert_rc "an installer with a curl call of its own is refused" 1 "$RUN_RC" "$RUN_OUT$RUN_ERR"
assert_contains "with the guard's message" "$RUN_ERR" "curl may run only in https_fetch in install.sh"

# The source guards run too, and their failure stops the release.
rc_fresh
rc_sed uninstall.sh 's/^running_on_profile() {/running_on_profile() { :;/'
rc_run "v$rc_version"
assert_rc "a failing source guard is refused" 1 "$RUN_RC" "$RUN_OUT$RUN_ERR"
assert_contains "with the guard's own message" "$RUN_ERR" "running_on_profile differs between bin/aidentity and uninstall.sh"
assert_contains "and the release check's" "$RUN_ERR" "scripts/guards.sh failed"
assert_not_contains "and it does not say the tag matches" "$RUN_OUT" "matches version"
# The running check is four functions, and a drift in any of them in
# uninstall.sh is a dead guard too.
for fn in proc_snapshot running_in_snapshot proc_dir_ids; do
  rc_fresh
  rc_sed uninstall.sh "s/^$fn() {/$fn() { :;/"
  RUN_OUT=$(cd "$SB" && "$BASH_BIN" "$RC_DIR/scripts/guards.sh" 2>&1); RUN_RC=$?
  assert_rc "the guards refuse a changed $fn in uninstall.sh" 1 "$RUN_RC" "$RUN_OUT"
  assert_contains "and name it" "$RUN_OUT" "$fn differs between bin/aidentity and uninstall.sh"
done


group "bin/aidentity is built from src/"

# scripts/build.sh joins src/ into the one file that ships. It runs on a copy
# here, so nothing in this checkout is rebuilt.
BLD_DIR="$SB/build-repo"
bld_fresh() {
  rm -rf "$BLD_DIR"
  mkdir -p "$BLD_DIR/bin" "$BLD_DIR/scripts"
  cp -R "$REPO_DIR/src" "$BLD_DIR/"
  cp "$REPO_DIR/scripts/build.sh" "$BLD_DIR/scripts/"
}
bld() { # build.sh arguments
  RUN_OUT=$(cd "$SB" && detached "$BASH_BIN" "$BLD_DIR/scripts/build.sh" "$@" 2>"$SANDBOX/stderr" </dev/null)
  RUN_RC=$?
  RUN_ERR=$(cat "$SANDBOX/stderr")
  return 0
}

bld_fresh
bld
assert_rc "the build writes bin/aidentity" 0 "$RUN_RC" "$RUN_OUT$RUN_ERR"
if cmp -s "$BLD_DIR/bin/aidentity" "$REPO_DIR/bin/aidentity"; then _pass "byte for byte the committed file"
else _fail "byte for byte the committed file" "the build of src/ differs from bin/aidentity: run make build"; fi
assert_exec "and executable" "$BLD_DIR/bin/aidentity"
bld --check
assert_rc "--check passes on what it just built" 0 "$RUN_RC" "$RUN_OUT$RUN_ERR"
printf '# edited by hand\n' >> "$BLD_DIR/bin/aidentity"
bld --check
assert_rc "--check refuses a hand edit" 1 "$RUN_RC" "$RUN_OUT$RUN_ERR"
assert_contains "and says where to make it" "$RUN_ERR" "Make changes in src/*.sh, not in bin/aidentity, then run: make build"
assert_contains "and shows the edit" "$RUN_ERR" "# edited by hand"

# Only NN-name.sh files are joined. Anything else in src/ would be left out
# without a word, so it stops the build.
bld_fresh
: > "$BLD_DIR/src/notes.sh"
bld
assert_rc "a stray file in src/ stops the build" 1 "$RUN_RC" "$RUN_OUT$RUN_ERR"
assert_contains "and is named" "$RUN_ERR" "src/notes.sh"
assert_no_file "and nothing is written" "$BLD_DIR/bin/aidentity"
bld_fresh
printf 'echo no newline' > "$BLD_DIR/src/50-zz.sh"
bld
assert_rc "a file without a final newline stops the build" 1 "$RUN_RC" "$RUN_OUT$RUN_ERR"
assert_contains "and is named" "$RUN_ERR" "src/50-zz.sh must end with a newline"

# --where turns a line of bin/aidentity, as bash and shellcheck name it, back
# into the src/ line to edit. The file names are read, not written in here.
bld_fresh
bld_files=("$BLD_DIR"/src/[0-9][0-9]-*.sh)
bld_first="src/${bld_files[0]##*/}"; bld_second="src/${bld_files[1]##*/}"
bld_last="src/${bld_files[${#bld_files[@]}-1]##*/}"
bld_n1=$(wc -l < "${bld_files[0]}" | tr -d ' ')
bld_total=$(wc -l < "$REPO_DIR/bin/aidentity" | tr -d ' ')
bld --where 1
assert_eq "--where 1 is the first file's first line" "$bld_first:1" "$RUN_OUT"
bld --where "$((bld_n1 + 1))"
assert_eq "the line the build adds between two files is named as such" "the blank line between $bld_first and $bld_second" "$RUN_OUT"
bld --where "$((bld_n1 + 2))"
assert_eq "the next line is the second file's first" "$bld_second:1" "$RUN_OUT"
bld --where "$bld_total"
assert_eq "the last line is the last file's last" "$bld_last:$(wc -l < "${bld_files[${#bld_files[@]}-1]}" | tr -d ' ')" "$RUN_OUT"
bld --where "$((bld_total + 1))"
assert_rc "a line past the end is refused" 1 "$RUN_RC" "$RUN_OUT$RUN_ERR"
assert_contains "with the length" "$RUN_ERR" "bin/aidentity has only $bld_total lines"
for bad_line in 0 007 x ""; do
  bld --where "$bad_line"
  assert_rc "--where [$bad_line] is a usage error" 1 "$RUN_RC" "$RUN_OUT$RUN_ERR"
  assert_contains "that shows the usage" "$RUN_ERR" "Usage: scripts/build.sh --where LINE"
done

# make test, lint, install and release read bin/aidentity, so each stops first
# when a src/ change was not built. They run on the release-check copy, with a
# stand-in suite that only leaves a mark: a stop that failed would show there.
rc_fresh
cp "$REPO_DIR/Makefile" "$RC_DIR/"
printf 'touch "%s"\n' "$SANDBOX/suite-ran" > "$RC_DIR/test/run_tests.sh"
mk_src=("$RC_DIR"/src/[0-9][0-9]-*.sh)
printf '# not built yet\n' >> "${mk_src[0]}"
mk_before=$(rc_tree)
for target in test lint install release; do
  RUN_OUT=$(cd "$SB" && detached make --no-print-directory -C "$RC_DIR" "$target" VERSION=9.9.9 \
    PREFIX="$SB/make-prefix" 2>&1 </dev/null); RUN_RC=$?
  assert_rc_nonzero "make $target stops when bin/aidentity is not the build of src/" "$RUN_RC" "$RUN_OUT"
  assert_contains "and says why" "$RUN_OUT" "bin/aidentity is not the build of src/"
done
assert_no_file "the suite never ran" "$SANDBOX/suite-ran"
assert_no_file "nothing was installed" "$SB/make-prefix/bin/aidentity"
assert_eq "and no file changed" "$mk_before" "$(rc_tree)"

# On a built tree, make release sets the version in src/, rebuilds
# bin/aidentity from it and updates SHA256SUMS.
rc_fresh
cp "$REPO_DIR/Makefile" "$RC_DIR/"
RUN_OUT=$(cd "$SB" && detached make --no-print-directory -C "$RC_DIR" release VERSION=9.9.9 2>&1 </dev/null); RUN_RC=$?
assert_rc "make release on a built tree" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "sets the version in src/00-header.sh" 'AIDENTITY_VERSION="9.9.9"' \
  "$(grep '^AIDENTITY_VERSION=' "$RC_DIR/src/00-header.sh")"
assert_eq "and in bin/aidentity" 'AIDENTITY_VERSION="9.9.9"' \
  "$(grep '^AIDENTITY_VERSION=' "$RC_DIR/bin/aidentity")"
RUN_OUT=$(cd "$SB" && "$BASH_BIN" "$RC_DIR/scripts/build.sh" --check 2>&1); RUN_RC=$?
assert_rc "which is the build of src/" 0 "$RUN_RC" "$RUN_OUT"
RUN_OUT=$(cd "$RC_DIR" && shasum -a 256 -c SHA256SUMS 2>&1); RUN_RC=$?
assert_rc "and SHA256SUMS matches it" 0 "$RUN_RC" "$RUN_OUT"
