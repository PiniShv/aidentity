# shellcheck shell=bash
# SC2016: single-quoted scripts are handed to "$BASH_BIN" -c and to generated
# stubs, which expand them later, on purpose. shellcheck only recognises that
# when the interpreter is spelled literally as `bash -c`.
# shellcheck disable=SC2016
#
# Area "uninstall": uninstall.sh end to end.
# Sourced by test/run_tests.sh after test/lib.sh. Run it alone with:
#   bash test/run_tests.sh uninstall

group "uninstall.sh end to end, every search path in the sandbox"

# AIDENTITY_BIN_DIRS keeps it from finding a real installed copy; HOME and
# AIDENTITY_APP_DIRS keep its launcher search inside the sandbox.
UN_BIN="$SB/un-bin"
mkdir -p "$UN_BIN"
un_prepare() {
  cp "$REPO_DIR/bin/aidentity" "$UN_BIN/aidentity"
  ai add "$ELECTRON_APP" --profile Bye
  printf 'session\n' > "$DATA/fake-bye/Cookies"
}
un_tty() { # typed input
  RUN_OUT=$( { { sleep 0.3; printf '%b' "$1"; sleep 1; } \
      | HOME="$SANDBOX/tty-home" AIDENTITY_BIN_DIRS="$UN_BIN" PATH="$STUB_BIN:$PATH" \
        script -q /dev/null "$BASH_BIN" "$REPO_DIR/uninstall.sh"
      echo "__rc=${PIPESTATUS[1]}"; } 2>&1 | tr -d '\r')
  RUN_RC=${RUN_OUT##*__rc=}
  RUN_OUT=${RUN_OUT%__rc=*}
  return 0
}

un_prepare
un_tty 'no\n'
assert_rc "declining exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "and says nothing was deleted" "$RUN_OUT" "Kept"
assert_dir "the launcher stays" "$APPS/Fake Bye.app"
assert_file "the data stays" "$DATA/fake-bye/Cookies"

cp "$REPO_DIR/bin/aidentity" "$UN_BIN/aidentity"
RUN_OUT=$(HOME="$SANDBOX/tty-home" AIDENTITY_BIN_DIRS="$UN_BIN" detached "$BASH_BIN" "$REPO_DIR/uninstall.sh" 2>&1 </dev/null); RUN_RC=$?
assert_rc_nonzero "with no terminal to confirm on, it exits non-zero" "$RUN_RC" "$RUN_OUT"
assert_dir "and deletes no launcher" "$APPS/Fake Bye.app"

un_prepare
mkdir -p "$DATA/stray-profile"
un_tty 'delete\n'
assert_rc "typing delete removes everything" 0 "$RUN_RC" "$RUN_OUT"
assert_no_file "the command" "$UN_BIN/aidentity"
assert_no_dir "the launcher" "$APPS/Fake Bye.app"
assert_no_dir "its data" "$DATA/fake-bye"
assert_no_dir "data no launcher pointed at" "$DATA/stray-profile"
assert_contains "and only then says aidentity is gone" "$RUN_OUT" "aidentity is gone"
assert_file "it never touched this checkout" "$REPO_DIR/bin/aidentity"
mkdir -p "$DATA"

# A Homebrew-managed copy is left for brew, so "gone" would be false.
mkdir -p "$SB/Cellar/aidentity/1.1.0/bin"
cp "$REPO_DIR/bin/aidentity" "$SB/Cellar/aidentity/1.1.0/bin/aidentity"
ln -sfn "$SB/Cellar/aidentity/1.1.0/bin/aidentity" "$UN_BIN/aidentity"
ai add "$ELECTRON_APP" --profile Bye
un_tty 'delete\n'
assert_contains "a Homebrew copy is left for brew" "$RUN_OUT" "managed by Homebrew"
assert_not_contains "and the end does not claim it is all gone" "$RUN_OUT" "aidentity is gone"
assert_no_dir "the launcher is still removed" "$APPS/Fake Bye.app"
rm -f "$UN_BIN/aidentity"
mkdir -p "$DATA"
