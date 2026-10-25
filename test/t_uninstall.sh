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
# AIDENTITY_APP_DIRS keep its launcher search inside the sandbox. HOME also
# keeps the Trash it moves profile data to in the sandbox.
UN_BIN="$SB/un-bin"
UN_TRASH="$SANDBOX/tty-home/.Trash"
mkdir -p "$UN_BIN"
trash_reset
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
assert_contains "and says nothing was removed" "$RUN_OUT" "Kept. Nothing was removed."
assert_dir "the launcher stays" "$APPS/Fake Bye.app"
assert_file "the data stays" "$DATA/fake-bye/Cookies"
assert_contains "the prompt says the data goes to the Trash" "$RUN_OUT" "moves the profile data listed above to the Trash"

cp "$REPO_DIR/bin/aidentity" "$UN_BIN/aidentity"
RUN_OUT=$(HOME="$SANDBOX/tty-home" AIDENTITY_BIN_DIRS="$UN_BIN" detached "$BASH_BIN" "$REPO_DIR/uninstall.sh" 2>&1 </dev/null); RUN_RC=$?
assert_rc_nonzero "with no terminal to confirm on, it exits non-zero" "$RUN_RC" "$RUN_OUT"
assert_dir "and deletes no launcher" "$APPS/Fake Bye.app"

# A Trash it cannot write to: the data stays, and the end says so.
un_prepare
mkdir -p "$UN_TRASH"
chmod 500 "$UN_TRASH"
un_tty 'delete\n'
chmod 700 "$UN_TRASH"
assert_no_dir "with a Trash it cannot write to, the launcher is still removed" "$APPS/Fake Bye.app"
assert_file "but the data stays where it was" "$DATA/fake-bye/Cookies"
assert_contains "it says why" "$RUN_OUT" "Could not move $DATA/fake-bye to the Trash"
assert_contains "and that nothing was deleted" "$RUN_OUT" "Nothing was deleted."
assert_contains "and the end does not claim it is all gone" "$RUN_OUT" "some things were left in place"
assert_not_contains "nor that the data moved" "$RUN_OUT" "Moved the data"
rm -rf "$DATA/fake-bye"

un_prepare
mkdir -p "$DATA/stray-profile"
un_tty 'delete\n'
assert_rc "typing delete removes everything" 0 "$RUN_RC" "$RUN_OUT"
assert_no_file "the command" "$UN_BIN/aidentity"
assert_no_dir "the launcher" "$APPS/Fake Bye.app"
assert_no_dir "its data" "$DATA/fake-bye"
assert_file "which is in the Trash" "$UN_TRASH/fake-bye/Cookies"
assert_no_dir "data no launcher pointed at" "$DATA/stray-profile"
assert_dir "is in the Trash too" "$UN_TRASH/stray-profile"
assert_contains "it says it moved the data" "$RUN_OUT" "Moved the data for Fake Bye to the Trash"
assert_contains "and how to get an account back" "$RUN_OUT" "To get an account back"
assert_contains "with the data folder made first, as it may be gone" "$RUN_OUT" "mkdir -p \"$DATA\""
assert_contains "then names restore" "$RUN_OUT" "    aidentity restore"
assert_contains "and add, for a folder restore does not list" "$RUN_OUT" "If restore does not list it, add the profile again"
assert_not_contains "and never that it deleted the data" "$RUN_OUT" "Deleted data"
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
assert_dir "and its data goes to the Trash under the next free name" "$UN_TRASH/fake-bye 2"
rm -f "$UN_BIN/aidentity"
mkdir -p "$DATA"
trash_reset

# A running profile stops it before the question: nothing is removed, and the
# reason talks about moving the data, not deleting it.
make_pgrep_stubs
ai add "$ELECTRON_APP" --profile Busy
printf 'session\n' > "$BUSY_DATA/Cookies"
PATH="$PGREP_STUB:$PATH" un_tty 'delete\n'
assert_rc_nonzero "a running profile stops the uninstall" "$RUN_RC" "$RUN_OUT"
assert_contains "it says why" "$RUN_OUT" "Moving a profile's data while its app is open"
assert_not_contains "and never says Deleting" "$RUN_OUT" "Deleting"
assert_dir "the launcher stays" "$APPS/Fake Busy.app"
assert_file "and so does its data" "$BUSY_DATA/Cookies"
ai rm "Fake Busy" --purge -y
trash_reset
