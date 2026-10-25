# shellcheck shell=bash
# SC2016: single-quoted scripts are handed to "$BASH_BIN" -c and to generated
# stubs, which expand them later, on purpose. shellcheck only recognises that
# when the interpreter is spelled literally as `bash -c`.
# shellcheck disable=SC2016
#
# Area "launcher": the generated launcher script: its sign-in guard and a clean environment.
# Sourced by test/run_tests.sh after test/lib.sh. Run it alone with:
#   bash test/run_tests.sh launcher

group "the generated launcher: sign-in guard and a clean environment"

# The launcher is run here with pgrep, osascript and open swapped for stubs,
# so nothing real is launched and no dialog is shown.
GUARD_STUB="$SANDBOX/stub-guard"
mkdir -p "$GUARD_STUB"
printf '#!/bin/sh\nexit "${STUB_PGREP:-0}"\n' > "$GUARD_STUB/pgrep"
printf '#!/bin/sh\necho "${STUB_ANSWER:-open}"\n' > "$GUARD_STUB/osascript"
printf '#!/bin/sh\n{ echo "ARGS $*"; env; } > "%s/opened"\n' "$SANDBOX" > "$GUARD_STUB/open"
chmod +x "$GUARD_STUB/pgrep" "$GUARD_STUB/osascript" "$GUARD_STUB/open"
ai add "$ELECTRON_APP" --profile Guard
G_DATA="$DATA/fake-guard"
sed -e "s|/usr/bin/pgrep|$GUARD_STUB/pgrep|; s|/usr/bin/osascript|$GUARD_STUB/osascript|; s|/usr/bin/open|$GUARD_STUB/open|" \
  "$APPS/Fake Guard.app/Contents/MacOS/launcher" > "$SANDBOX/guard-launcher.sh"
run_guard() { rm -f "$SANDBOX/opened"; env "$@" /bin/sh "$SANDBOX/guard-launcher.sh"; }

run_guard STUB_ANSWER=cancel
assert_no_file "Cancel in the first-open dialog opens nothing" "$SANDBOX/opened"
run_guard STUB_ANSWER=open
assert_file "Open Anyway opens the profile" "$SANDBOX/opened"
run_guard STUB_PGREP=1 STUB_ANSWER=cancel
assert_file "with no other copy running there is no dialog" "$SANDBOX/opened"
printf '{}' > "$G_DATA/Local State"
run_guard STUB_ANSWER=cancel
assert_file "a profile that was opened before has no dialog" "$SANDBOX/opened"
run_guard "AA_BYTES=$(printf 'caf\351')" LC_ALL=en_US.UTF-8 \
  NODE_OPTIONS=--require=/x VSCODE_PID=1 ELECTRON_RUN_AS_NODE=1 LANG=de_DE.UTF-8
OPENED=$(cat "$SANDBOX/opened")
assert_not_contains "NODE_OPTIONS never reaches the app, even beside a value that is not UTF-8" "$OPENED" "NODE_OPTIONS="
assert_not_contains "VSCODE_* from the caller never reaches the app" "$OPENED" "VSCODE_PID="
assert_not_contains "ELECTRON_* from the caller never reaches the app" "$OPENED" "ELECTRON_RUN_AS_NODE="
assert_contains "ordinary variables still do" "$OPENED" "LANG=de_DE.UTF-8"
assert_contains "and the profile directory is passed" "$OPENED" "--user-data-dir=$G_DATA"
ai rm "Fake Guard" --purge -y
