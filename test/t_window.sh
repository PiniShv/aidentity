# shellcheck shell=bash
# SC2016: single-quoted scripts are handed to "$BASH_BIN" -c, which expands
# them later, on purpose.
# shellcheck disable=SC2016
#
# Area "window": aidentity ui --window. The window runs the hidden __window
# command for all it shows and does, so most of this area runs that command
# the way the window does, with no window. The last group opens the real
# window, kept off the screen, on a Mac that has a desktop session.
# Sourced by test/run_tests.sh after test/lib.sh. Run it alone with:
#   bash test/run_tests.sh window
#
# AIDENTITY_TEST_REQUIRE_WINDOW=1 makes the last group fail where it would be
# skipped. CI sets it, so that a green run always means the window was opened.

# One request, as the window's host sends it. RUN_OUT is its whole answer.
win() { ai __window "$@"; }
# One action: `__window do`, with its verb and words.
act() { ai __window "do" "$@"; }
# The list, as the window gets it. WIN_STATE is the JSON; wj reads from it.
state() { ai_stdout __window state "$@"; WIN_STATE=$RUN_OUT; }
wj() { json_get "$WIN_STATE" "$1" "${2:-}"; }
# The id the list gives a profile: what an action sends back with its name.
wid() { wj 'd.profiles.filter(function (p) { return p.name === arg; })[0].id' "$1"; }
# The first line of an answer to `do` is the command that ran.
shown() { printf '%s\n' "$RUN_OUT" | head -n 1; }

group "window: the list"

ai add "$ELECTRON_APP" --profile Alpha --badge A --color teal
ai add "$ELECTRON_APP" --profile Beta --badge B
ai add "$ELECTRON_APP" --profile Gone --badge G
printf 'session\n' > "$DATA/fake-gone/Cookies"
rm -rf "$APPS/Fake Gone.app"

state
assert_rc "state ends well" 0 "$RUN_RC" "$RUN_ERR"
assert_eq "and writes nothing but the JSON" "" "$RUN_ERR"
assert_eq "it lists both profiles" "Fake Alpha,Fake Beta" "$(wj 'd.profiles.map(function (p) { return p.name; }).join()')"
assert_eq "a badge is passed on" "A" "$(wj 'd.profiles[0].badge')"
assert_eq "a colour is passed as hex" "12A594" "$(wj 'd.profiles[0].color')"
assert_eq "the app and the profile are named apart" "Fake|Alpha" "$(wj 'd.profiles[0].app + "|" + d.profiles[0].profile')"
assert_eq "a profile that never ran says so" "signed out / new" "$(wj 'd.profiles[0].status')"
assert_eq "each profile has an id, and the two differ" "true" \
  "$(wj '/^dir:[0-9]+:[0-9]+$/.test(d.profiles[0].id) && d.profiles[0].id !== d.profiles[1].id')"
assert_eq "no data folder or app path goes to the page with a profile" "false" \
  "$(wj '"data" in d.profiles[0] || "target" in d.profiles[0]')"
assert_eq "the apps list has the apps a profile can be made for" "true" \
  "$(wj 'd.apps.some(function (a) { return a.name === "Fake"; })')"
assert_eq "and not the native one" "false" "$(wj 'd.apps.some(function (a) { return a.name === "Nativey"; })')"
assert_eq "an app is named by its path too" "$ELECTRON_APP" \
  "$(wj 'd.apps.filter(function (a) { return a.name === "Fake"; })[0].path')"
assert_eq "the colours have a name and a hex each" "true" \
  "$(wj 'd.colors.length > 3 && d.colors.every(function (c) { return c.name && /^[0-9A-F]{6}$/i.test(c.hex); })')"
assert_eq "the removed profiles: the one whose launcher is gone" "Fake Gone" \
  "$(wj 'd.restorable.map(function (r) { return r.label; }).join()')"
assert_eq "with the folder an action sends back" "$DATA/fake-gone" "$(wj 'd.restorable[0].dir')"
assert_eq "and a short name for it" "fake-gone" "$(wj 'd.restorable[0].folder')"
assert_eq "the search behind them was complete" "true" "$(wj 'd.restorable_ok')"
ai version
assert_eq "the version is the script's own" "$RUN_OUT" "aidentity $(wj 'd.version')"

state launchers
assert_eq "one part alone: the launchers, and nothing of the rest" "true false false" \
  "$(wj 'Array.isArray(d.profiles) + " " + ("apps" in d) + " " + ("restorable" in d)')"
state apps restorable
assert_eq "two parts: those two, and no launchers" "false true true" \
  "$(wj '("profiles" in d) + " " + Array.isArray(d.apps) + " " + Array.isArray(d.restorable)')"
libcall uiw_tilde "$HOME/Applications"
# shellcheck disable=SC2088  # the ~ is what the window shows, as text
assert_eq "a path in the home folder is shown with ~" '~/Applications' "$RUN_OUT"
libcall uiw_tilde "/Applications"
assert_eq "and any other path as it is" "/Applications" "$RUN_OUT"

state
ALPHA_ID=$(wid "Fake Alpha")
BETA_ID=$(wid "Fake Beta")

group "window: requests that are not understood"

WIN_BEFORE=$(fingerprint "$APPS")
win
assert_rc_nonzero "__window alone is not a command" "$RUN_RC" "$RUN_OUT"
assert_contains "and says what it is for" "$RUN_OUT" "ui --window"
win bogus
assert_rc_nonzero "nor is an unknown word after it" "$RUN_RC" "$RUN_OUT"
win state launchers junk
assert_rc "an unknown part of the list is refused" 3 "$RUN_RC" "$RUN_OUT"
act
assert_rc "an action with no verb is refused" 3 "$RUN_RC" "$RUN_OUT"
assert_contains "and says to open the window again" "$RUN_OUT" "open it again"
assert_eq "a refusal names no command: its first line is empty" "" "$(shown)"
act bogus "Fake Alpha" "$ALPHA_ID"
assert_rc "an unknown verb is refused" 3 "$RUN_RC" "$RUN_OUT"
act remove "Fake Alpha" "$ALPHA_ID"
assert_rc "remove without keep or purge is refused" 3 "$RUN_RC" "$RUN_OUT"
act remove "Fake Alpha" "$ALPHA_ID" maybe
assert_rc "and with another word in their place" 3 "$RUN_RC" "$RUN_OUT"
act remove "Fake Alpha" "$ALPHA_ID" purge --yes
assert_rc "and with a word too many" 3 "$RUN_RC" "$RUN_OUT"
act open "Fake Alpha"
assert_rc "open without an id is refused" 3 "$RUN_RC" "$RUN_OUT"
act edit "Fake Alpha" "$ALPHA_ID" Other
assert_rc "edit with words missing is refused" 3 "$RUN_RC" "$RUN_OUT"
act add "Fake.app" Other "" ""
assert_rc "add for an app that is not a full path is refused" 3 "$RUN_RC" "$RUN_OUT"
act add --main Other "" ""
assert_rc "so an option can never stand where the app goes" 3 "$RUN_RC" "$RUN_OUT"
act restore
assert_rc "restore without a folder is refused" 3 "$RUN_RC" "$RUN_OUT"
act check extra
assert_rc "check takes no words" 3 "$RUN_RC" "$RUN_OUT"
act fix --all
assert_rc "nor does fix" 3 "$RUN_RC" "$RUN_OUT"
assert_eq "none of them changed a launcher" "$WIN_BEFORE" "$(fingerprint "$APPS")"
assert_no_dir "or made one" "$APPS/Fake Other.app"

group "window: an action reaches only the profile its card showed"

act remove "Fake Alpha" "dir:1:1" purge
assert_rc "a wrong id is refused" 3 "$RUN_RC" "$RUN_OUT"
assert_contains "with the reason" "$RUN_OUT" "list changed"
act remove "Fake Alpha" "$BETA_ID" purge
assert_rc "so is the id of another profile" 3 "$RUN_RC" "$RUN_OUT"
act remove "Fake Nobody" "$ALPHA_ID" purge
assert_rc "and a name that no launcher has" 3 "$RUN_RC" "$RUN_OUT"
assert_dir "Alpha is untouched" "$APPS/Fake Alpha.app"
assert_dir "with its data" "$DATA/fake-alpha"

# The case the id is for: a card whose name now belongs to another profile,
# after renames made elsewhere. rename moves each data folder to the path that
# goes with the new name, so the path alone would not tell the two apart.
printf 'alpha session\n' > "$DATA/fake-alpha/Cookies"
printf 'beta session\n' > "$DATA/fake-beta/Cookies"
ai rename "Fake Alpha" Old
ai rename "Fake Beta" Alpha
assert_eq "(the name Fake Alpha now opens the other account, at the same path)" \
  "beta session|$DATA/fake-alpha" "$(cat "$DATA/fake-alpha/Cookies")|$(plist_key "$APPS/Fake Alpha.app" AIdentityDataDir)"
WIN_TRASH=$(trash_names "$SB_TRASH")
act remove "Fake Alpha" "$ALPHA_ID" purge
assert_rc "a card drawn before two renames is refused" 3 "$RUN_RC" "$RUN_OUT"
assert_contains "with the reason" "$RUN_OUT" "list changed"
assert_eq "and names no command, since none ran" "" "$(shown)"
assert_dir "the profile that took the name keeps its launcher" "$APPS/Fake Alpha.app"
assert_eq "and its data" "beta session" "$(cat "$DATA/fake-alpha/Cookies" 2>/dev/null)"
assert_eq "nothing went to the Trash" "$WIN_TRASH" "$(trash_names "$SB_TRASH")"
# Every action that names a profile asks the same question first.
WIN_LOOK="$(plist_key "$APPS/Fake Alpha.app" AIdentityBadge) $(plist_key "$APPS/Fake Alpha.app" AIdentityColor)"
PATH="$STUB_BIN:$PATH" act open "Fake Alpha" "$ALPHA_ID"
assert_rc "Open from that card is refused too" 3 "$RUN_RC" "$RUN_OUT"
assert_not_contains "and opens nothing" "$RUN_OUT" "stub open"
act quit "Fake Alpha" "$ALPHA_ID"
assert_rc "so is Quit" 3 "$RUN_RC" "$RUN_OUT"
act edit "Fake Alpha" "$ALPHA_ID" Other Z red
assert_rc "and Edit" 3 "$RUN_RC" "$RUN_OUT"
assert_dir "which renames nothing" "$APPS/Fake Alpha.app"
assert_eq "and changes no badge and no colour" "$WIN_LOOK" \
  "$(plist_key "$APPS/Fake Alpha.app" AIdentityBadge) $(plist_key "$APPS/Fake Alpha.app" AIdentityColor)"
state
assert_eq "an id stays with its account through a rename" "$ALPHA_ID $BETA_ID" "$(wid "Fake Old") $(wid "Fake Alpha")"
ai rename "Fake Alpha" Beta
ai rename "Fake Old" Alpha

# A profile removed with its data and made again under the same name is
# another account: its old card must not reach it either.
ai add "$ELECTRON_APP" --profile Twice
state
TWICE_ID=$(wid "Fake Twice")
ai rm "Fake Twice" --purge -y
ai add "$ELECTRON_APP" --profile Twice
act remove "Fake Twice" "$TWICE_ID" keep
assert_rc "a card of a profile that was purged and made again is refused" 3 "$RUN_RC" "$RUN_OUT"
assert_dir "and the new profile keeps its launcher" "$APPS/Fake Twice.app"
ai rm "Fake Twice" --purge -y
trash_reset

group "window: edit"

act edit "Fake Alpha" "$ALPHA_ID" Aaa "" ""
assert_rc "a new name runs rename" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "and shows the command a person would type" "aidentity rename 'Fake Alpha' Aaa" "$(shown)"
assert_dir "the launcher has the new name" "$APPS/Fake Aaa.app"
assert_no_dir "and the old name is gone" "$APPS/Fake Alpha.app"
act edit "Fake Aaa" "$ALPHA_ID" "Alpha Two" "" ""
assert_eq "a name with a space is quoted in the shown command" "aidentity rename 'Fake Aaa' 'Alpha Two'" "$(shown)"
act edit "Fake Alpha Two" "$ALPHA_ID" Alpha "" ""
assert_dir "renamed back, still by the same id" "$APPS/Fake Alpha.app"

act edit "Fake Alpha" "$ALPHA_ID" "" Z ""
assert_rc "a badge runs set" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "and shows it" "aidentity set 'Fake Alpha' --badge Z" "$(shown)"
assert_eq "the launcher has the badge" "Z" "$(plist_key "$APPS/Fake Alpha.app" AIdentityBadge)"
act edit "Fake Alpha" "$ALPHA_ID" "" "" red
assert_eq "a colour shows --color" "aidentity set 'Fake Alpha' --color red" "$(shown)"
assert_eq "and the launcher has it, with the badge it had" "E5484D Z" \
  "$(plist_key "$APPS/Fake Alpha.app" AIdentityColor) $(plist_key "$APPS/Fake Alpha.app" AIdentityBadge)"
act edit "Fake Alpha" "$ALPHA_ID" "" none ""
assert_eq "badge none shows --no-badge" "aidentity set 'Fake Alpha' --no-badge" "$(shown)"
assert_eq "and the launcher has no badge" "" "$(plist_key "$APPS/Fake Alpha.app" AIdentityBadge)"
# `set --color` alone gives a profile without a badge one. In the window, a
# badge that is left alone stays as it is, so "no badge" is said again.
act edit "Fake Alpha" "$ALPHA_ID" "" "" blue
assert_eq "a colour for a profile with no badge keeps it without one" \
  "aidentity set 'Fake Alpha' --no-badge --color blue" "$(shown)"
assert_eq "on the launcher too" "2E7DF6 " \
  "$(plist_key "$APPS/Fake Alpha.app" AIdentityColor) $(plist_key "$APPS/Fake Alpha.app" AIdentityBadge)"
act edit "Fake Alpha" "$ALPHA_ID" Both Q teal
assert_rc "a name, a badge and a colour at once run" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "the look first, under the old name" "aidentity set 'Fake Alpha' --badge Q --color teal" "$(shown)"
assert_contains "then the new name" "$RUN_OUT" "aidentity rename 'Fake Alpha' Both"
assert_eq "the launcher has all three" "Q 12A594" \
  "$(plist_key "$APPS/Fake Both.app" AIdentityBadge) $(plist_key "$APPS/Fake Both.app" AIdentityColor)"
act edit "Fake Both" "$ALPHA_ID" Alpha A ""
act edit "Fake Alpha" "$ALPHA_ID" "" "" ""
assert_rc "nothing to change is refused" 3 "$RUN_RC" "$RUN_OUT"
assert_contains "and says so" "$RUN_OUT" "Nothing was changed"
act edit "Fake Alpha" "$ALPHA_ID" Later "" notacolour
assert_rc "an unknown colour fails" 1 "$RUN_RC" "$RUN_OUT"
assert_dir "and the new name is not tried after it" "$APPS/Fake Alpha.app"
act edit "Fake Alpha" "$ALPHA_ID" "Bad!" "" ""
assert_rc "a name aidentity does not take fails" 1 "$RUN_RC" "$RUN_OUT"
assert_contains "with aidentity's own reason" "$RUN_OUT" "may only contain"

# A word that looks like an option, wherever a name, a badge or a colour goes.
win_look() {
  printf '%s %s %s' "$(fingerprint "$APPS")" "$(plist_key "$APPS/Fake Alpha.app" AIdentityBadge)" \
    "$(plist_key "$APPS/Fake Alpha.app" AIdentityColor)"
}
WIN_BEFORE=$(win_look)
WIN_ODD=""
for WIN_W in --main --yes --purge --help -h -x -; do
  act edit "Fake Alpha" "$ALPHA_ID" "$WIN_W" "" ""; [ "$RUN_RC" -ne 0 ] || WIN_ODD="$WIN_ODD name:$WIN_W"
  act edit "Fake Alpha" "$ALPHA_ID" "" "$WIN_W" ""; [ "$RUN_RC" -ne 0 ] || WIN_ODD="$WIN_ODD badge:$WIN_W"
  act edit "Fake Alpha" "$ALPHA_ID" "" "" "$WIN_W"; [ "$RUN_RC" -ne 0 ] || WIN_ODD="$WIN_ODD colour:$WIN_W"
  act add "$ELECTRON_APP" "$WIN_W" "" ""; [ "$RUN_RC" -ne 0 ] || WIN_ODD="$WIN_ODD add-name:$WIN_W"
  act add "$ELECTRON_APP" Other "$WIN_W" ""; [ "$RUN_RC" -ne 0 ] || WIN_ODD="$WIN_ODD add-badge:$WIN_W"
  act add "$ELECTRON_APP" Other "" "$WIN_W"; [ "$RUN_RC" -ne 0 ] || WIN_ODD="$WIN_ODD add-colour:$WIN_W"
done
assert_eq "a word that looks like an option is never taken, in any place" "" "$WIN_ODD"
assert_eq "and none of them changed a launcher" "$WIN_BEFORE" "$(win_look)"

group "window: open, quit, remove and restore"

PATH="$STUB_BIN:$PATH" act open "Fake Alpha" "$ALPHA_ID"
assert_rc "open runs" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "and shows its command" "aidentity open 'Fake Alpha'" "$(shown)"
assert_contains "it opens that launcher" "$RUN_OUT" "stub open: $APPS/Fake Alpha.app"
act quit "Fake Alpha" "$ALPHA_ID"
assert_eq "quit shows its command" "aidentity quit 'Fake Alpha'" "$(shown)"
assert_contains "and runs for that profile" "$RUN_OUT" "'Fake Alpha' is not running"

act remove "Fake Beta" "$BETA_ID" keep
assert_rc "remove with keep runs" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "and shows rm --yes" "aidentity rm 'Fake Beta' --yes" "$(shown)"
assert_no_dir "the launcher is gone" "$APPS/Fake Beta.app"
assert_dir "the data is kept" "$DATA/fake-beta"
state
assert_eq "the profile left the list" "Fake Alpha" "$(wj 'd.profiles.map(function (p) { return p.name; }).join()')"
assert_eq "and is offered for restore" "true" "$(wj 'd.restorable.some(function (r) { return r.label === "Fake Beta"; })')"

act restore "$DATA/fake-beta"
assert_rc "restore runs" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "and shows aidentity restore" "aidentity restore 'Fake Beta'" "$(shown)"
assert_dir "the launcher is back" "$APPS/Fake Beta.app"
assert_eq "with its own data folder" "$DATA/fake-beta" "$(plist_key "$APPS/Fake Beta.app" AIdentityDataDir)"
state
assert_eq "and has the id it had before" "$BETA_ID" "$(wid "Fake Beta")"
act restore "$DATA/fake-beta"
assert_rc "a restore of a folder that has a launcher again is refused" 3 "$RUN_RC" "$RUN_OUT"
assert_contains "and says why" "$RUN_OUT" "not in the list of removed profiles"
act restore "$DATA/no-such-folder"
assert_rc "so is a folder that is not there" 3 "$RUN_RC" "$RUN_OUT"

# Two removed profiles with one name. In a terminal, `restore NAME` brings back
# every one of them; the window restores the one folder of its row, and says so.
ai add "$ELECTRON_APP" --profile Twin
ai rm "Fake Twin" --yes
cp -R "$DATA/fake-twin" "$DATA/fake-twin-2"
state restorable
assert_eq "two removed profiles can have one name, and are told apart by their folders" \
  "Fake Twin:fake-twin,Fake Twin:fake-twin-2" \
  "$(wj 'd.restorable.filter(function (r) { return r.label === "Fake Twin"; }).map(function (r) { return r.label + ":" + r.folder; }).sort().join()')"
act restore "$DATA/fake-twin-2"
assert_rc "restore of one of them runs" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "and says that only that one is restored" "$RUN_OUT" "Only the one in the folder fake-twin-2 is restored."
assert_eq "the launcher opens that folder" "$DATA/fake-twin-2" "$(plist_key "$APPS/Fake Twin.app" AIdentityDataDir)"
assert_dir "and the other one is still there, with no launcher" "$DATA/fake-twin"
ai rm "Fake Twin" --purge -y
rm -rf "${DATA:?}/fake-twin"
trash_reset

# Purge: the data goes to the sandbox's Trash.
trash_reset
act remove "Fake Beta" "$BETA_ID" purge
assert_rc "remove with purge runs" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "and shows rm --purge --yes" "aidentity rm 'Fake Beta' --purge --yes" "$(shown)"
assert_no_dir "the launcher is gone" "$APPS/Fake Beta.app"
assert_no_dir "the data left its folder" "$DATA/fake-beta"
assert_contains "and is in the Trash of the sandbox's home" "$(ls -A "$SB_TRASH" 2>/dev/null)" "fake-beta"
trash_reset

# A main launcher has no data folder of its own.
ai add "$ELECTRON_APP" --main
state
MAIN_ID=$(wid "Fake Main")
assert_eq "a main launcher is marked, and its id says which app" "true main:$ELECTRON_APP" \
  "$(wj 'd.profiles.filter(function (p) { return p.name === "Fake Main"; })[0].main') $MAIN_ID"
act remove "Fake Main" "$MAIN_ID" keep
assert_rc "it can be removed" 0 "$RUN_RC" "$RUN_OUT"
assert_no_dir "and is gone" "$APPS/Fake Main.app"

# An unreadable folder among the launchers: nothing is offered for restore,
# and a restore is refused, since a launcher in it would not be seen.
mkdir -p "$APPS/Private"; chmod 000 "$APPS/Private"
state restorable
WIN_SEARCH="$(wj 'd.restorable_ok') $(wj 'd.restorable.length')"
act restore "$DATA/fake-gone"
chmod 755 "$APPS/Private"; rmdir "$APPS/Private"
assert_eq "restorable_ok is false, with nothing offered" "false 0" "$WIN_SEARCH"
assert_rc "a restore while a launcher folder cannot be read is refused" 3 "$RUN_RC" "$RUN_OUT"
assert_contains "and says to check the folder's permissions" "$RUN_OUT" "Check its permissions"
assert_no_dir "and makes no launcher" "$APPS/Fake Gone.app"

group "window: add"

# A second app that sorts after Fake.
make_electron_app "$SRC/Zed.app"
act add "$SRC/Zed.app" Gamma none teal
assert_rc "add runs" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "and shows the app by its path" \
  "aidentity add '$SRC/Zed.app' --profile Gamma --no-badge --color teal" "$(shown)"
assert_eq "the launcher is for that app" "$SRC/Zed.app" "$(plist_key "$APPS/Zed Gamma.app" AIdentityTargetApp)"
assert_eq "badge none makes no badge" "" "$(plist_key "$APPS/Zed Gamma.app" AIdentityBadge)"
assert_eq "the colour is passed" "12A594" "$(plist_key "$APPS/Zed Gamma.app" AIdentityColor)"
act add "$SRC/Zed.app" Delta Q ""
assert_eq "add with a badge passes it" "Q" "$(plist_key "$APPS/Zed Delta.app" AIdentityBadge)"
act add "$SRC/Zed.app" Plain "" ""
assert_eq "add with neither leaves both to aidentity" "aidentity add '$SRC/Zed.app' --profile Plain" "$(shown)"
assert_eq "which gives the first letter as the badge" "P" "$(plist_key "$APPS/Zed Plain.app" AIdentityBadge)"
act add "$SRC/Zed.app" "" "" ""
assert_rc "add without a profile name fails" 1 "$RUN_RC" "$RUN_OUT"
act add "$SRC/Zed.app" "Bad!" "" ""
assert_rc "so does a name aidentity does not take" 1 "$RUN_RC" "$RUN_OUT"
assert_contains "with aidentity's own reason" "$RUN_OUT" "may only contain"
act add "$NATIVE_APP" Native "" ""
assert_rc "and an app that cannot have profiles" 1 "$RUN_RC" "$RUN_OUT"
assert_no_dir "which makes no launcher" "$APPS/Nativey Native.app"
ai rm "Zed Gamma" --purge -y
ai rm "Zed Delta" --purge -y
ai rm "Zed Plain" --purge -y
rm -rf "$SRC/Zed.app"
trash_reset

group "window: a name that starts with a hyphen"

cp -R "$APPS/Fake Alpha.app" "$APPS/-dash.app"
/usr/libexec/PlistBuddy -c "Set :AIdentityProfile dash" "$APPS/-dash.app/Contents/Info.plist" >/dev/null 2>&1
state launchers
assert_eq "it is listed as not usable in the window" "false" \
  "$(wj 'd.profiles.filter(function (p) { return p.name.charAt(0) === "-"; })[0].usable')"
act remove "-dash" "$(wid "-dash")" purge
assert_rc "an action on it is refused" 3 "$RUN_RC" "$RUN_OUT"
assert_contains "and the terminal is named" "$RUN_OUT" "terminal"
assert_dir "and the launcher is untouched" "$APPS/-dash.app"
assert_dir "as is the data it points at" "$DATA/fake-alpha"
# What its card tells the person to do: the terminal, with ./ before the name.
ai rm "./-dash" --yes
assert_rc "in a terminal, ./ before the name reaches it" 0 "$RUN_RC" "$RUN_OUT"
assert_no_dir "and removes that launcher" "$APPS/-dash.app"
assert_dir "and only that one" "$APPS/Fake Alpha.app"

group "window: check and fix"

ai restore "Fake Gone"
act check
assert_rc "a check that finds nothing ends with 0" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "and shows its command" "aidentity doctor" "$(shown)"
assert_contains "and doctor's report" "$RUN_OUT" "No problems found"
chmod 755 "$DATA/fake-alpha"
act check
assert_rc "a check that finds something doctor can fix ends with 11" 11 "$RUN_RC" "$RUN_OUT"
act fix
assert_rc "fix mends it and ends with 0" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "and shows its command" "aidentity doctor --fix" "$(shown)"
assert_eq "the folder is private again" "700" "$(stat -f '%Lp' "$DATA/fake-alpha")"
# A profile folder with no launcher is a problem that fix does not mend.
rm -rf "$APPS/Fake Gone.app"
act check
assert_rc "a check that finds only what doctor cannot fix ends with 10" 10 "$RUN_RC" "$RUN_OUT"
act fix
assert_rc "and fix says problems are left, with 10" 10 "$RUN_RC" "$RUN_OUT"

group "window: a question inside an action fails at once"

RUN_OUT=$(/usr/bin/perl -e 'alarm 30; exec @ARGV' -- "$BASH_BIN" -c '. "$1" >/dev/null 2>&1 || exit 99
uiw_quiet
ask "Go on? " >/dev/null && echo ASKED_YES
have_tty && echo TTY
tty_opens && echo OPENS
cmd_rm "Fake Alpha"' aidentity-lib "$LIB" 2>&1)
RUN_RC=$?
assert_rc "rm without --yes does not wait for an answer: it fails" 1 "$RUN_RC" "$RUN_OUT"
assert_not_contains "ask answers no" "$RUN_OUT" "ASKED_YES"
assert_not_contains "have_tty is false" "$RUN_OUT" "TTY"
assert_not_contains "tty_opens is false" "$RUN_OUT" "OPENS"
assert_dir "and the launcher is still there" "$APPS/Fake Alpha.app"
# An action sets that up by itself. Here Open is replaced by a command that
# asks, and a "yes" waits on its input.
RUN_OUT=$(printf 'yes\n' | /usr/bin/perl -e 'alarm 30; exec @ARGV' -- "$BASH_BIN" -c '. "$1" >/dev/null 2>&1 || exit 99
cmd_open() { local r; r=$(ask "Go on? ") && echo "ASKED:$r"; have_tty && echo TTY; echo "ran for $1"; }
uiw_do open "Fake Alpha" "$2"' aidentity-lib "$LIB" "$ALPHA_ID" 2>&1)
assert_contains "an action runs its command" "$RUN_OUT" "ran for Fake Alpha"
assert_not_contains "with no answer to read, even when one is waiting" "$RUN_OUT" "ASKED"
assert_not_contains "and no terminal" "$RUN_OUT" "TTY"

group "window: the shown command reads back as typed"

uiw_q_roundtrip() { # word
  local quoted back
  quoted=$("$BASH_BIN" -c '. "$1" >/dev/null 2>&1; uiw_q "$2"' aidentity-lib "$LIB" "$1")
  back=$("$BASH_BIN" -c 'eval "printf %s $1"' x "$quoted")
  assert_eq "uiw_q reads back the same: $1" "$1" "$back"
}
uiw_q_roundtrip "plain"
uiw_q_roundtrip "two words"
uiw_q_roundtrip "it's"
uiw_q_roundtrip 'a "quoted" $HOME `x` \ back'
uiw_q_roundtrip "semi;colon & amp | pipe"
uiw_q_roundtrip "tab	inside"
uiw_q_roundtrip "é ü"
libcall uiw_q ""
assert_eq "an empty word is two quotes" "''" "$RUN_OUT"
libcall uiw_q "Fake.app"
assert_eq "a plain word is left as it is" "Fake.app" "$RUN_OUT"

group "window: the command that opens it"

ai ui --window extra
assert_rc_nonzero "ui --window with an extra word fails" "$RUN_RC" "$RUN_OUT"
assert_contains "and names it" "$RUN_OUT" "extra"
ai ui extra
assert_rc_nonzero "ui with a word fails" "$RUN_RC" "$RUN_OUT"
assert_contains "and names it" "$RUN_OUT" "extra"
ai help ui
assert_contains "help ui shows --window" "$RUN_OUT" "--window"
ai help
assert_not_contains "the hidden command is not in the overview" "$RUN_OUT" "__window"

for WIN_V in 12.3 12.3.1 12.10 13.0 14 15.7.1; do
  libcall uiw_macos_ok "$WIN_V"
  assert_rc "macOS $WIN_V can show the window" 0 "$RUN_RC" "$RUN_OUT"
done
for WIN_V in 12.2.1 12.0 12 11.7.10 10.15.7; do
  libcall uiw_macos_ok "$WIN_V"
  assert_rc "macOS $WIN_V cannot" 1 "$RUN_RC" "$RUN_OUT"
done
libcall uiw_macos_ok ""
assert_rc "a version that cannot be read is let through" 0 "$RUN_RC" "$RUN_OUT"

# ui_window with stand-ins for the three programs it runs. bash runs a
# function before it looks for a program, even when the command is a path.
WIN_SEEN="$SANDBOX/window-host-args"
win_open() { # function definitions that stand in for programs
  : > "$WIN_SEEN"
  RUN_OUT=$(WIN_SEEN="$WIN_SEEN" detached "$BASH_BIN" -c '. "$1" >/dev/null 2>&1 || exit 99
function /usr/bin/sw_vers { echo 14.5; }
function /bin/launchctl { echo Aqua; }
function /usr/bin/osascript { cat > "$WIN_SEEN.script"; printf "%s\n" "$@" > "$WIN_SEEN"; }
eval "$2"
ui_window' aidentity-lib "$LIB" "$1" 2>&1 </dev/null)
  RUN_RC=$?
}
win_open ''
assert_rc "ui --window ends well when the window does" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "and says that closing it brings the terminal back" "$RUN_OUT" "Close it to come back here"
assert_eq "the window's program gets the bash to use and this script" "-|$BASH_BIN|$LIB" \
  "$(tr '\n' '|' < "$WIN_SEEN" | sed 's/|$//')"
assert_contains "and its own text on its input" "$(cat "$WIN_SEEN.script")" 'use framework "WebKit"'
win_open 'function /usr/bin/osascript { cat >/dev/null; echo "execution error: it broke (-2700)" >&2; return 1; }'
assert_rc "a window that fails makes the command fail" 1 "$RUN_RC" "$RUN_OUT"
assert_contains "and says so" "$RUN_OUT" "did not open, or it closed because of an error"
assert_contains "with the program's own message" "$RUN_OUT" "it broke"
assert_contains "and points at the menu in the terminal" "$RUN_OUT" "aidentity ui"
win_open 'function /usr/bin/sw_vers { echo 12.2.1; }'
assert_rc "on a macOS that is too old the command fails" 1 "$RUN_RC" "$RUN_OUT"
assert_contains "and says which one it needs" "$RUN_OUT" "needs macOS 12.3 or later (this is 12.2.1)"
assert_eq "without starting the window" "" "$(cat "$WIN_SEEN")"
win_open 'function /bin/launchctl { echo Background; }'
assert_rc "with no desktop session the command fails" 1 "$RUN_RC" "$RUN_OUT"
assert_contains "and says so" "$RUN_OUT" "needs a desktop session"
assert_eq "without starting the window" "" "$(cat "$WIN_SEEN")"
rm -f "$WIN_SEEN" "$WIN_SEEN.script"

group "window: the page and the window's program are sound"

# Never skipped: these need no desktop session.
ai_stdout __window page
WIN_PAGE=$RUN_OUT
assert_rc "the page is printed" 0 "$RUN_RC" "$RUN_ERR"
assert_contains "it is a whole page" "$WIN_PAGE" "</html>"
assert_contains "its policy lets nothing in from outside" "$WIN_PAGE" "default-src 'none'"
assert_not_contains "and it names no address to load from" "$WIN_PAGE" "://"
assert_not_contains "it builds no markup from text" "$WIN_PAGE" "innerHTML"
assert_eq "the key for script and style is left for the window to fill in, in four places" "4" \
  "$(printf '%s\n' "$WIN_PAGE" | grep -o '__AIDENTITY_NONCE__' | wc -l | tr -d ' ')"
# The script of the page, parsed by the JavaScript engine of macOS.
printf '%s\n' "$WIN_PAGE" | awk '/^<script nonce=/ { on = 1; next } /^<\/script>/ { on = 0 } on' > "$SANDBOX/window-page.js"
RUN_OUT=$(/usr/bin/osascript -l JavaScript - "$SANDBOX/window-page.js" 2>&1 <<'JXA'
ObjC.import('Foundation');
function run(argv) {
  var src = $.NSString.stringWithContentsOfFileEncodingError(argv[0], $.NSUTF8StringEncoding, $()).js;
  new Function(src);
  return "parsed " + (src.length > 5000 ? "all of it" : "too little");
}
JXA
)
assert_eq "the page's script parses" "parsed all of it" "$RUN_OUT"
"$BASH_BIN" -c '. "$1" >/dev/null 2>&1 || exit 99; uiw_host_script' aidentity-lib "$LIB" > "$SANDBOX/window-host.applescript"
RUN_OUT=$(/usr/bin/osacompile -o "$SANDBOX/window-host.scpt" "$SANDBOX/window-host.applescript" 2>&1); RUN_RC=$?
assert_rc "the window's program compiles" 0 "$RUN_RC" "$RUN_OUT"
rm -f "$SANDBOX/window-page.js" "$SANDBOX/window-host.applescript" "$SANDBOX/window-host.scpt"

group "window: the real window, kept off the screen"

# The real program, the real page and the real commands, in the sandbox. A
# script that runs in the page does what a person would do: it clicks, waits
# for each answer, and at the end reports what it saw. Nothing in it waits on
# a timer: a web view that is not on screen is not sure to run one.
"$BASH_BIN" -c '. "$1" >/dev/null 2>&1 || exit 99; uiw_host_script' aidentity-lib "$LIB" > "$SANDBOX/window-host.applescript"
WIN_DRIVER="$SANDBOX/window-driver.js"
WIN_CANARY="$SANDBOX/window-canary"
# Run the window with the script in WIN_DRIVER. WIN_OUT is its report.
win_drive() {
  WIN_OUT=$(/usr/bin/perl -e 'alarm 150; exec @ARGV' -- /usr/bin/osascript "$SANDBOX/window-host.applescript" \
    "$BASH_BIN" "$AIDENTITY" hidden "$WIN_DRIVER" 2>"$SANDBOX/window-host.err" </dev/null)
  WIN_RC=$?
  WIN_ERR=$(head -n 5 "$SANDBOX/window-host.err")
  WIN_WHY="exit $WIN_RC, session $(/bin/launchctl managername 2>/dev/null || echo unknown)"
  [ "$WIN_RC" -ne 142 ] || WIN_WHY="no report within 150 seconds, session $(/bin/launchctl managername 2>/dev/null || echo unknown)"
}
# One line when the window did not run at all: a skip where there is no
# desktop session, a failure where there is one or where CI asks for it.
win_ran() { # what the run was for
  if [ "$WIN_RC" -eq 0 ] && [ -n "$WIN_OUT" ]; then return 0; fi
  if [ -z "${AIDENTITY_TEST_REQUIRE_WINDOW:-}" ] && [ "$(/bin/launchctl managername 2>/dev/null)" != Aqua ]; then
    _skip "$1" "no desktop session here ($WIN_WHY)"
  else
    _fail "$1" "$WIN_WHY" "$WIN_ERR"
  fi
  return 1
}
wo() { json_get "$WIN_OUT" "$1"; }

ai restore "Fake Gone"
printf 'gone session\n' > "$DATA/fake-gone/Cookies"
printf 'alpha session\n' > "$DATA/fake-alpha/Cookies"
WIN_ODD_APP='<b>Bold & "Q"'
make_electron_app "$SRC/$WIN_ODD_APP.app"
trash_reset
cat > "$WIN_DRIVER" <<'DRIVER'
(function () {
  "use strict";
  var seen = {}, got = {}, si = 0, done = false, real = window.aidReply, ODD = '<b>Bold & "Q"';
  function $1(s) { return document.querySelector(s); }
  function all(s) { return Array.prototype.slice.call(document.querySelectorAll(s)); }
  function texts(s) { return all(s).map(function (n) { return n.textContent; }).join(","); }
  function btn(fk, who) {
    return all("button[data-fk]").filter(function (b) {
      return b.getAttribute("data-fk") === fk && b.getAttribute("data-who") === who;
    })[0];
  }
  function dlg() { return $1("dialog[open]"); }
  function idle() { return $1("#main").getAttribute("aria-busy") === "false"; }
  function type(sel, v) { dlg().querySelector(sel).value = v; }
  function ok() { dlg().querySelector("button.primary").click(); }
  function sum() { return $1("#sum").textContent + "|" + $1("#sum").className; }
  function raw(id, kind, args) { window.webkit.messageHandlers.aid.postMessage({ id: id, kind: kind, args: args }); }
  function have(ids) { return ids.every(function (i) { return i in got; }); }
  function stray() { return all("b, i, img[onerror], script:not([nonce])").length; }
  function report() {
    done = true;
    window.webkit.messageHandlers.aid.postMessage({ id: 0, kind: "report", args: [JSON.stringify(seen)] });
  }
  var steps = [
    // The list is drawn, and the apps are read: Add can be chosen.
    function () {
      if (!idle() || $1("#add").disabled) return false;
      seen.cards = texts(".card .name");
      seen.labels = btn("open", "Fake Alpha").getAttribute("aria-label") + "|" +
        btn("remove", "Fake Alpha").getAttribute("aria-label");
      seen.version = /^v[0-9]/.test($1("#ver").textContent);
      seen.icon = $1(".card .icon").tagName;
      // Requests the page itself never makes: the host must turn each one down.
      raw(9001, "bogus", []);
      raw(9002, "do", ["open", "a", "b", "c", "d", "e", "f", "g", "h"]);
      raw(9003, "do", ["open", "two\nlines"]);
      raw(9004, "do", ["open", 5]);
      raw(9005, "do", ["open", new Array(1026).join("x")]);
      return true;
    },
    // Words full of shell signs are words: they reach aidentity as they are.
    function () {
      if (!have([9001, 9002, 9003, 9004, 9005])) return false;
      seen.shape = [9001, 9002, 9003, 9004, 9005].map(function (i) { return got[i]; }).join();
      raw(9006, "do", ["open", "$(touch __CANARY__)", "`touch __CANARY__`; touch __CANARY__"]);
      return true;
    },
    // A second request while a command runs is not run beside it.
    function () {
      if (!have([9006])) return false;
      seen.shell = got[9006];
      raw(9007, "state", ["launchers"]);
      raw(9008, "state", ["launchers"]);
      return true;
    },
    function () {
      if (!have([9007, 9008])) return false;
      seen.overlap = got[9007] + "," + got[9008];
      $1("#add").click();
      seen.first = document.activeElement === dlg().querySelector("input[type=text]");
      // An app whose name is markup shows as text.
      seen.apps = all("dialog option").map(function (o) { return o.textContent; }).join("|");
      all("dialog option").forEach(function (o, i) { if (o.textContent === ODD) dlg().querySelector("select").selectedIndex = i; });
      // A name aidentity refuses: the dialog stays, with the reason and what was typed.
      type("input[type=text]", "Bad!");
      ok();
      seen.locked = all("dialog button").map(function (b) { return b.disabled; }).join();
      return true;
    },
    function () {
      if (!idle()) return false;
      seen.refused = (dlg() ? "open" : "closed") + "|" + dlg().querySelector("input[type=text]").value + "|" +
        dlg().querySelector(".alert").textContent;
      // No name at all is caught by the page itself: nothing is asked.
      type("input[type=text]", "");
      ok();
      seen.empty = dlg().querySelector(".alert").textContent;
      type("input[type=text]", "Gamma");
      ok();
      return true;
    },
    function () {
      if (!idle()) return false;
      seen.added = (dlg() ? "open" : "closed") + "|" + texts(".card .name");
      seen.sum = sum();
      seen.cmd = $1("#cmd").textContent;
      seen.markup = stray();
      // Two steps, of which the second fails: a colour, and a name that is refused.
      btn("edit", ODD + " Gamma").click();
      type("input[type=text]", "Bad!");
      all("dialog input[type=radio]").forEach(function (r) { if (r.value === "red") r.click(); });
      ok();
      return true;
    },
    function () {
      if (!idle()) return false;
      seen.twostep = (dlg() ? "open" : "closed") + "|" + dlg().querySelector(".alert").textContent;
      type("input[type=text]", "Delta");
      ok();
      return true;
    },
    function () {
      if (!idle()) return false;
      seen.edited = texts(".card .name");
      btn("remove", ODD + " Delta").click();
      seen.choices = all("dialog input[type=radio]").map(function (r) { return r.checked; }).join(",");
      ok();
      return true;
    },
    function () {
      if (!idle()) return false;
      seen.removed = texts(".card .name") + "|" + texts("#removed .row span");
      seen.sum2 = sum();
      seen.focus2 = document.activeElement.getAttribute("data-fk") + ":" + document.activeElement.getAttribute("data-who");
      btn("restore", ODD + " Delta").click();
      return true;
    },
    function () {
      if (!idle()) return false;
      seen.restored = texts(".card .name") + "|" + $1("#removed").hidden;
      $1("#check").click();
      return true;
    },
    // The window is closed while a command runs: the command must still finish.
    function () {
      if (!idle()) return false;
      seen.check = $1("#sum").textContent + "|" + $1("#fix").hidden;
      seen.markup += stray();
      seen.hook = typeof window.aidFocus;
      btn("remove", "Fake Gone").click();
      all("dialog input[type=radio]")[1].click();
      ok();
      report();
      return true;
    }
  ];
  function advance() {
    try {
      while (!done && si < steps.length && steps[si]()) si += 1;
    } catch (e) { seen.error = String(e) + " at step " + si; report(); return; }
    if (!done && si >= steps.length) report();
  }
  window.aidReply = function (m) {
    if (m && m.id >= 9000) got[m.id] = m.rc;
    real(m);
    advance();
  };
})();
DRIVER
sed "s|__CANARY__|$WIN_CANARY|g" "$WIN_DRIVER" > "$WIN_DRIVER.tmp" && mv "$WIN_DRIVER.tmp" "$WIN_DRIVER"
win_drive
if win_ran "the window opens, does a person's work and closes"; then
  assert_eq "the page's script ran to its end" "" "$(wo 'd.error || ""')"
  assert_eq "it drew a card for each profile" "Fake Alpha,Fake Gone" "$(wo 'd.cards')"
  assert_eq "each button says whose it is" "Open Fake Alpha|Remove Fake Alpha" "$(wo 'd.labels')"
  assert_eq "it shows the version" "true" "$(wo 'd.version')"
  assert_eq "a launcher's icon arrives as a picture" "IMG" "$(wo 'd.icon')"
  assert_eq "the host turns down a request of a wrong shape: kind, count, control character, type, length" \
    "-3,-3,-3,-3,-3" "$(wo 'd.shape')"
  assert_eq "words full of shell signs reach aidentity as words, and are refused there" "3" "$(wo 'd.shell')"
  assert_no_file "and no shell ever read them" "$WIN_CANARY"
  assert_eq "a request that comes while a command runs is told so, and is not run" "0,-1" "$(wo 'd.overlap')"
  assert_eq "Add starts in the name" "true" "$(wo 'd.first')"
  assert_eq "an app whose name is markup is listed as text" "true" \
    "$(json_get "$WIN_OUT" 'd.apps.split("|").indexOf(arg) >= 0' "$WIN_ODD_APP")"
  assert_eq "while an action runs, its dialog offers no Cancel and no second try" "true,true" "$(wo 'd.locked')"
  assert_eq "a refused name keeps the dialog open, with what was typed" "open|Bad!" \
    "$(wo 'd.refused.split("|").slice(0, 2).join("|")')"
  assert_contains "and with aidentity's reason" "$(wo 'd.refused')" "may only contain"
  assert_eq "an empty name is asked for by the page" "Type a name for the profile." "$(wo 'd.empty')"
  assert_eq "Add closes its dialog and draws the new card" "closed|$WIN_ODD_APP Gamma,Fake Alpha,Fake Gone" "$(wo 'd.added')"
  # The made-up app has no icon, which add warns about: the result says so.
  assert_eq "the result says it is done, and names add's warning" \
    "Done, with a warning: $WIN_ODD_APP has no icon to copy; the launcher uses the default one.|warn" "$(wo 'd.sum')"
  assert_eq "with the command that ran" "aidentity add '$SRC/$WIN_ODD_APP.app' --profile Gamma" "$(wo 'd.cmd')"
  assert_eq "markup in a name never becomes an element: not in a card, a row, a result or the output" "0" "$(wo 'd.markup')"
  assert_eq "when the second of two steps fails, the dialog stays" "open" "$(wo 'd.twostep.split("|")[0]')"
  assert_contains "and gives the reason of the step that failed" "$(wo 'd.twostep')" "may only contain"
  assert_not_contains "not the success of the step before it" "$(wo 'd.twostep')" "Updated"
  assert_eq "Edit renames" "$WIN_ODD_APP Delta,Fake Alpha,Fake Gone" "$(wo 'd.edited')"
  assert_eq "and sets the colour" "E5484D" "$(plist_key "$APPS/$WIN_ODD_APP Delta.app" AIdentityColor)"
  assert_eq "Remove offers to keep the data first" "true,false" "$(wo 'd.choices')"
  assert_eq "and moves the profile to the removed ones" "Fake Alpha,Fake Gone|$WIN_ODD_APP Delta" "$(wo 'd.removed')"
  assert_eq "a plain success says what was done, in the colour of one" \
    "Done. Removed launcher '$WIN_ODD_APP Delta'.|good" "$(wo 'd.sum2')"
  assert_eq "focus goes to a card when its own button is gone" "open:Fake Alpha" "$(wo 'd.focus2')"
  assert_eq "Restore brings it back" "$WIN_ODD_APP Delta,Fake Alpha,Fake Gone|true" "$(wo 'd.restored')"
  assert_dir "on the disk too" "$APPS/$WIN_ODD_APP Delta.app"
  assert_eq "Check reports, with no Fix to offer" "The check found no problems.|true" "$(wo 'd.check')"
  assert_eq "the page can be told that the window is in front again" "function" "$(wo 'd.hook')"
  # The last click was Remove with the data to the Trash, and the window was
  # closed at once. rm prints a line before it moves the data.
  assert_no_dir "a command still running when the window closes is not cut off: the launcher is gone" "$APPS/Fake Gone.app"
  assert_no_dir "and its data left the folder" "$DATA/fake-gone"
  assert_contains "for the Trash" "$(ls -A "$SB_TRASH" 2>/dev/null)" "fake-gone"
fi

# The same for Quit, which ends the program another way.
cat > "$WIN_DRIVER" <<'DRIVER'
(function () {
  "use strict";
  var real = window.aidReply, done = false;
  function step() {
    var b, d;
    // Everything is read, so the click below is sent at once and Quit meets it running.
    if (done || document.getElementById("main").getAttribute("aria-busy") !== "false" ||
        document.getElementById("add").disabled) return;
    b = Array.prototype.slice.call(document.querySelectorAll('button[data-fk="remove"]')).filter(function (x) {
      return x.getAttribute("data-who") === "Fake Alpha";
    })[0];
    if (!b) return;
    done = true;
    b.click();
    d = document.querySelector("dialog[open]");
    d.querySelectorAll("input[type=radio]")[1].click();
    d.querySelector("button.primary").click();
    window.webkit.messageHandlers.aid.postMessage({ id: 0, kind: "report", args: ["{\"quit\":true}", "quit"] });
  }
  window.aidReply = function (m) { real(m); step(); };
})();
DRIVER
trash_reset
win_drive
if win_ran "the window quits while a command runs"; then
  assert_eq "Quit was asked for while Remove ran" "true" "$(wo 'd.quit')"
  assert_no_dir "and the command was not cut off: the launcher is gone" "$APPS/Fake Alpha.app"
  assert_no_dir "and its data left the folder" "$DATA/fake-alpha"
  assert_contains "for the Trash" "$(ls -A "$SB_TRASH" 2>/dev/null)" "fake-alpha"
fi
assert_eq "no window program of this run is left" "0" \
  "$(/bin/ps -axo args | grep -F "$SANDBOX/window-host.applescript" | grep -c -v grep)"
rm -f "$WIN_DRIVER" "$WIN_CANARY" "$SANDBOX/window-host.applescript" "$SANDBOX/window-host.err"

# Leave nothing behind, whatever the window did or did not do.
for WIN_LEFT in "$WIN_ODD_APP Gamma" "$WIN_ODD_APP Delta" "Fake Alpha" "Fake Gone"; do
  [ ! -d "$APPS/$WIN_LEFT.app" ] || ai rm "$WIN_LEFT" --purge -y
done
ai prune --yes
rm -rf "${SRC:?}/${WIN_ODD_APP:?}.app"
trash_reset
