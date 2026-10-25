# shellcheck shell=bash
# SC2153: RUN_OUT and RUN_RC are set in lib.sh, which shellcheck does not read
# together with this file; it takes them for a misspelling of REN_OUT and REN_RC.
# shellcheck disable=SC2153
#
# Area "accounts": the name prompt, the setup walkthrough, --main, a failed build, status
# and permissions, option values.
# Sourced by test/run_tests.sh after test/lib.sh. Run it alone with:
#   bash test/run_tests.sh accounts

group "add asks for the account name"

ai add "$ELECTRON_APP"
assert_contains "with no terminal, add says how to give the name" "$RUN_OUT" "--profile"
ai_tty 'Typed\n' add "$ELECTRON_APP"
assert_rc "on a terminal, add asks for a missing name" 0 "$RUN_RC" "$RUN_OUT"
assert_dir "the typed name is used" "$APPS/Fake Typed.app"
ai_tty 'bad/name\nRetyped\n' add "$ELECTRON_APP"
assert_contains "a refused name says why" "$RUN_OUT" "may only contain"
assert_dir "a refused name is asked for again" "$APPS/Fake Retyped.app"
ai rm "Fake Typed" --purge -y
ai rm "Fake Retyped" --purge -y


group "setup survives a typo, and offers a main launcher"

libcall list_compatible_apps
FAKE_IDX=$(printf '%s\n' "$RUN_OUT" | grep -n -x -F "$ELECTRON_APP" | cut -d: -f1)
assert_nonempty "the fake Electron app is in the walkthrough menu" "$FAKE_IDX"

ai_tty "y\nabc\n0\n${FAKE_IDX}\nWizard\nn\nn\nn\n" setup
assert_rc "setup finishes after typos at the menu" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "a typo is answered with a hint" "$RUN_OUT" "Please enter a number"
assert_dir "the account after the typos is created" "$APPS/Fake Wizard.app"
assert_contains "setup reports one profile" "$RUN_OUT" "1 profile(s) created"
assert_no_dir "declining the main launcher builds none" "$APPS/Fake Main.app"

ai_tty "y\n${FAKE_IDX}\nWizard Two\ny\nn\nn\n" setup
assert_dir "accepting the offer builds a main launcher" "$APPS/Fake Main.app"
assert_eq "it is marked as a main launcher" "true" "$(plist_key "$APPS/Fake Main.app" AIdentityMain)"
assert_not_contains "setup never opened a real Finder window" "$RUN_OUT" "Opening"
for p in "Fake Wizard" "Fake Wizard Two"; do ai rm "$p" --purge -y; done
ai rm "Fake Main" -y


group "--main opens the original account"

ai add "$ELECTRON_APP" --main
assert_rc "add --main succeeds" 0 "$RUN_RC" "$RUN_OUT"
MAIN_APP="$APPS/Fake Main.app"
assert_dir "it is named <App> Main" "$MAIN_APP"
assert_eq "it is marked as a main launcher" "true" "$(plist_key "$MAIN_APP" AIdentityMain)"
assert_eq "it records no data directory" "" "$(plist_key "$MAIN_APP" AIdentityDataDir)"
MAIN_SRC=$(cat "$MAIN_APP/Contents/MacOS/launcher")
assert_not_contains "it passes no --user-data-dir" "$MAIN_SRC" "user-data-dir"
assert_contains "it still starts a new instance (-na) of the real app" "$MAIN_SRC" "-na '$ELECTRON_APP'"
assert_no_dir "no profile directory is created for it" "$DATA/fake-main"

ai add "$ELECTRON_APP" --main --profile Second
assert_rc_nonzero "a second main launcher for the same app is refused" "$RUN_RC" "$RUN_OUT"
ai add "$ELECTRON_APP" --profile Main
assert_rc_nonzero "a profile cannot take over the main launcher's name" "$RUN_RC" "$RUN_OUT"
assert_eq "the main launcher is unchanged" "true" "$(plist_key "$MAIN_APP" AIdentityMain)"

ai add "$ELECTRON_APP" --profile Regular
ai add "$ELECTRON_APP" --main --profile Regular
assert_rc_nonzero "a separate profile is never turned into a main launcher" "$RUN_RC" "$RUN_OUT"
assert_eq "the profile keeps its own data directory" \
  "$DATA/fake-regular" "$(plist_key "$APPS/Fake Regular.app" AIdentityDataDir)"
ai rm "Fake Regular" --purge -y

ai list
assert_contains "list says it opens the original account" "$RUN_OUT" "your original account"

ai rename "Fake Main" Original
assert_rc "a main launcher can be renamed" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "it is still a main launcher" "true" "$(plist_key "$APPS/Fake Original.app" AIdentityMain)"
assert_no_dir "renaming creates no profile directory" "$DATA/fake-original"
ai set "Fake Original" --color red
assert_rc "set works on a main launcher" 0 "$RUN_RC" "$RUN_OUT"
ai rebuild "Fake Original"
assert_rc "rebuild works on a main launcher" 0 "$RUN_RC" "$RUN_OUT"
assert_not_contains "rebuild keeps it on the original account" \
  "$(cat "$APPS/Fake Original.app/Contents/MacOS/launcher")" "user-data-dir"
ai rm "Fake Original" --purge -y
assert_rc "rm --purge on a main launcher removes only the launcher" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "and says --purge did nothing" "$RUN_OUT" "does nothing"
assert_no_dir "the main launcher is gone" "$APPS/Fake Original.app"


group "a failed build never loses a launcher"

ai add "$ELECTRON_APP" --profile Safe
printf 'session\n' > "$DATA/fake-safe/Cookies"
SAFE_COLOR=$(plist_key "$APPS/Fake Safe.app" AIdentityColor)
chmod 500 "$APPS"
ai set "Fake Safe" --color red
SET_RC=$RUN_RC; SET_OUT=$RUN_OUT
ai rename "Fake Safe" Moved
REN_RC=$RUN_RC; REN_OUT=$RUN_OUT
chmod 755 "$APPS"
assert_rc_nonzero "set fails when the launcher cannot be rebuilt" "$SET_RC" "$SET_OUT"
assert_rc_nonzero "rename fails when the launcher cannot be rebuilt" "$REN_RC" "$REN_OUT"
assert_dir "the launcher survives both failures" "$APPS/Fake Safe.app"
assert_eq "its colour is unchanged" "$SAFE_COLOR" "$(plist_key "$APPS/Fake Safe.app" AIdentityColor)"
assert_contains "rename says nothing changed" "$REN_OUT" "Nothing was changed"
assert_file "the session was moved back by rename's roll-back" "$DATA/fake-safe/Cookies"
assert_no_dir "no half-renamed data directory is left" "$DATA/fake-moved"
assert_eq "no staging directory is left behind" "0" \
  "$(find "$APPS" -maxdepth 1 -name '.aidentity-build.*' | wc -l | tr -d ' ')"
ai rm "Fake Safe" --purge -y


group "status, permissions and option values"

ai add "$ELECTRON_APP" --profile Used
mkdir -p "$DATA/fake-used/Local Storage"
printf 'x\n' > "$DATA/fake-used/Cookies"
ai list
USED_STATUS=$(printf '%s\n' "$RUN_OUT" | awk '/^Fake Used$/ { f = 1; next } f && /status/ { print; exit }')
assert_contains "an Electron-shaped profile (no Default/) reads as in use" "$USED_STATUS" "in use"
assert_eq "profile directories are owner-only" "700" "$(stat -f '%Lp' "$DATA/fake-used")"
ai rm "Fake Used" --purge -y

ai add "$ELECTRON_APP" --profile --seed
assert_rc_nonzero "an option cannot be swallowed as a profile name" "$RUN_RC" "$RUN_OUT"
assert_contains "and says what is missing" "$RUN_OUT" "needs a value"
assert_no_dir "no launcher named after the option" "$APPS/Fake --seed.app"

ai add "$ELECTRON_APP" --profile Accent --badge "é"
assert_rc "a non-ASCII badge works under LC_ALL=C" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "the whole character is recorded" "é" "$(plist_key "$APPS/Fake Accent.app" AIdentityBadge)"
ai rm "Fake Accent" --purge -y

ai add "$ELECTRON_APP" --profile One
ai add "$ELECTRON_APP" --profile Two
ai rm "Fake One" "Fake Two" -y
assert_rc_nonzero "rm refuses two names instead of removing only the last" "$RUN_RC" "$RUN_OUT"
assert_dir "the first is untouched" "$APPS/Fake One.app"
assert_dir "the second is untouched" "$APPS/Fake Two.app"
ai rm "Fake One" --purge -y
ai rm "Fake Two" --purge -y
