# shellcheck shell=bash
# SC2016: single-quoted scripts are handed to "$BASH_BIN" -c and to generated
# stubs, which expand them later, on purpose. shellcheck only recognises that
# when the interpreter is spelled literally as `bash -c`.
# shellcheck disable=SC2016
#
# Area "install": install.sh end to end, against a stub curl, and the make targets
# around it.
# Sourced by test/run_tests.sh after test/lib.sh. Run it alone with:
#   bash test/run_tests.sh install

group "install.sh end to end, against a stub curl"

# A stub curl that serves this checkout instead of GitHub. It knows the two
# files install.sh fetches; STUB_SUMS picks which checksum file it serves.
mkdir -p "$CURL_STUB"
cat > "$CURL_STUB/curl" <<STUB
#!/bin/sh
out="" url=""
while [ \$# -gt 0 ]; do
  case "\$1" in
    -o) out="\$2"; shift 2 ;;
    --proto|--proto-redir|--connect-timeout|--max-time|--retry|--max-filesize) shift 2 ;;
    -*) shift ;;
    *) url="\$1"; shift ;;
  esac
done
case "\$url" in
  */bin/aidentity) src='$REPO_DIR/bin/aidentity' ;;
  */SHA256SUMS)
    case "\${STUB_SUMS:-good}" in
      good) src='$REPO_DIR/SHA256SUMS' ;;
      bad) printf '%064d  bin/aidentity\n' 0; exit 0 ;;
      *) exit 22 ;;
    esac ;;
  *) exit 22 ;;
esac
if [ -n "\$out" ]; then cat "\$src" > "\$out"; else cat "\$src"; fi
STUB
chmod +x "$CURL_STUB/curl"

INST_A="$SB/inst a"
inst "$INST_A"
assert_rc "install.sh installs with no terminal and exits 0" 0 "$RUN_RC" "$RUN_OUT"
if cmp -s "$INST_A/aidentity" "$REPO_DIR/bin/aidentity"; then _pass "the installed file is this checkout's script"
else _fail "the installed file is this checkout's script" "differs or missing"; fi
assert_exec "it is executable" "$INST_A/aidentity"
assert_contains "the checksum was verified" "$RUN_OUT" "checksum verified"
assert_not_contains "no walkthrough is offered without a terminal" "$RUN_OUT" "Set up your first"
inst "$INST_A"
assert_contains "a second run reports a reinstall" "$RUN_OUT" "Reinstalled"

inst "$SB/inst b" STUB_SUMS=bad
assert_rc_nonzero "a checksum mismatch refuses to install" "$RUN_RC" "$RUN_OUT"
assert_no_file "and writes nothing" "$SB/inst b/aidentity"
inst "$SB/inst c" STUB_SUMS=missing AIDENTITY_REF=main
assert_rc_nonzero "a missing checksum file refuses to install" "$RUN_RC" "$RUN_OUT"
assert_contains "and names the ref it tried" "$RUN_OUT" "SHA256SUMS for AIDENTITY_REF=main"
assert_no_file "and writes nothing" "$SB/inst c/aidentity"
inst --piped "$SB/inst p"
assert_rc "install.sh works piped into bash, as curl | bash runs it" 0 "$RUN_RC" "$RUN_OUT"
if cmp -s "$SB/inst p/aidentity" "$REPO_DIR/bin/aidentity"; then _pass "and installs this checkout's script"
else _fail "and installs this checkout's script" "differs or missing"; fi
inst "$SB/inst d" "AIDENTITY_REF=../../evil/repo/main"
assert_rc_nonzero "a ref that walks out of the repository is refused" "$RUN_RC" "$RUN_OUT"
mkdir -p "$SB/inst e/aidentity"
inst "$SB/inst e"
assert_rc_nonzero "a directory at the target is refused" "$RUN_RC" "$RUN_OUT"
mkdir -p "$SB/inst f" "$SB/elsewhere"
ln -s "$SB/elsewhere" "$SB/inst f/aidentity"
inst "$SB/inst f"
assert_rc "a symlink at the target is replaced" 0 "$RUN_RC" "$RUN_OUT"
if [ -f "$SB/inst f/aidentity" ] && [ ! -L "$SB/inst f/aidentity" ]; then _pass "by a real file"
else _fail "by a real file" "still a link or missing"; fi
assert_eq "nothing was dropped into the link's target" "" "$(ls -A "$SB/elsewhere")"

# GNU coreutils first on PATH (common with Homebrew): its mv has no -h. The
# installer must not depend on whichever mv comes first.
printf '#!/bin/sh\ncase " $* " in *" -h"*|*" -fh "*) echo "mv: invalid option -- h" >&2; exit 1 ;; esac\nexec /bin/mv "$@"\n' \
  > "$CURL_STUB/mv"
chmod +x "$CURL_STUB/mv"
inst "$SB/inst g"
assert_rc "an mv without -h first on PATH does not break the install" 0 "$RUN_RC" "$RUN_OUT"
assert_file "the file is installed" "$SB/inst g/aidentity"
rm -f "$CURL_STUB/mv"

# make formula against a tag that cannot be downloaded must change nothing.
# It used to hash the empty download and write that checksum into the formula.
FORMULA_SB="$SB/formula-copy"
mkdir -p "$FORMULA_SB/Formula"
cp "$REPO_DIR/Makefile" "$FORMULA_SB/"
cp "$REPO_DIR/Formula/aidentity.rb" "$FORMULA_SB/Formula/"
mkdir -p "$SANDBOX/stub-curl-404"
printf '#!/bin/sh\necho "curl: (22) The requested URL returned error: 404" >&2\nexit 22\n' > "$SANDBOX/stub-curl-404/curl"
chmod +x "$SANDBOX/stub-curl-404/curl"
RUN_OUT=$(cd "$FORMULA_SB" && PATH="$SANDBOX/stub-curl-404:$PATH" make -s formula VERSION=9.9.9 2>&1); RUN_RC=$?
assert_rc_nonzero "make formula fails when the tag cannot be downloaded" "$RUN_RC" "$RUN_OUT"
if cmp -s "$FORMULA_SB/Formula/aidentity.rb" "$REPO_DIR/Formula/aidentity.rb"; then
  _pass "and leaves the formula untouched"
else
  _fail "and leaves the formula untouched" "the formula changed"
fi
RUN_OUT=$(cd "$FORMULA_SB" && make -s release VERSION='1.0.0"; touch pwned; "' 2>&1); RUN_RC=$?
assert_rc_nonzero "make release refuses a version that is not x.y.z" "$RUN_RC" "$RUN_OUT"
assert_no_file "and runs nothing it was handed" "$FORMULA_SB/pwned"
# A valid first line used to carry a second one past a line-by-line check.
for target in release formula; do
  RUN_OUT=$(cd "$FORMULA_SB" && PATH="$SANDBOX/stub-curl-404:$PATH" \
    make -s "$target" VERSION="1.2.3
touch pwned" 2>&1); RUN_RC=$?
  assert_rc_nonzero "make $target refuses a version with a second line" "$RUN_RC" "$RUN_OUT"
  assert_contains "with the usage line, before anything else runs" "$RUN_OUT" "Usage: make $target"
done
assert_no_file "and the second line never runs" "$FORMULA_SB/pwned"
