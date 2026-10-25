# shellcheck shell=bash
# SC2016: single-quoted scripts are handed to "$BASH_BIN" -c and to generated
# stubs, which expand them later, on purpose. shellcheck only recognises that
# when the interpreter is spelled literally as `bash -c`.
# shellcheck disable=SC2016
#
# Area "json": list --json.
# Sourced by test/run_tests.sh after test/lib.sh. Run it alone with:
#   bash test/run_tests.sh json

group "list --json"

# What this area borrows: the stub pgrep (a profile that is running, and a pgrep
# that fails) and the script's own version line, for built_by.
make_pgrep_stubs
ai version
VERSION_LINE="$RUN_OUT"

JSON_LAUNCHERS_BEFORE=$(count_launchers)
# App names and paths are whatever is on disk. A quote, a backslash, a tab and
# non-ASCII in the app's name reach the name, app and app_path fields.
ODD_APP="$SRC/Wëird \"Q\" \\ Tab	App.app"
ODD="Wëird \"Q\" \\ Tab	App Work"
make_electron_app "$ODD_APP"
ai add "$ODD_APP" --profile Work --badge "é" --color teal --arg --lang=de \
  --env "HTTPS_PROXY=http://secret.example:8080"
assert_rc "add takes an app whose name has quotes, a backslash and a tab" 0 "$RUN_RC" "$RUN_OUT"
ai add "$ELECTRON_APP" --main
ai add "$ELECTRON_APP" --profile Busy --no-badge
printf 'session\n' > "$BUSY_DATA/Cookies"
GONE_APP="$SRC/Gone.app"
make_electron_app "$GONE_APP"
ai add "$GONE_APP" --profile Lost
rm -rf "$GONE_APP"
EXT_APP="$SRC/Codey.app"
make_electron_app "$EXT_APP"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.example.codey" "$EXT_APP/Contents/Info.plist"
mkdir -p "$EXT_APP/Contents/Resources/app"
printf '{"darwinBundleIdentifier":"com.example.codey","dataFolderName":".codey"}\n' \
  > "$EXT_APP/Contents/Resources/app/product.json"
AIDENTITY_DATA_ROOT="$VSC_DATA" ai add "$EXT_APP" --profile Ext --own-extensions

ai_stdout list --json
J=$RUN_OUT
assert_rc "list --json exits 0" 0 "$RUN_RC" "$RUN_ERR"
assert_eq "stdout parses as JSON, one object per launcher" "5" "$(json_get "$J" 'd.length')"
assert_eq "every object has the same keys, in the same order" "true" \
  "$(json_get "$J" 'd.every(function (o) { return Object.keys(o).join() === arg; })' \
     "name,app,app_path,profile,data_dir,main,status,badge,color,built_by,args,env,own_extensions")"
assert_eq "name survives quotes, a backslash, a tab and UTF-8" "true" \
  "$(json_get "$J" 'byName(arg) !== undefined' "$ODD")"
assert_eq "app is the app's name" "Wëird \"Q\" \\ Tab	App" "$(json_get "$J" 'byName(arg).app' "$ODD")"
assert_eq "app_path is the app's path" "$ODD_APP" "$(json_get "$J" 'byName(arg).app_path' "$ODD")"
assert_eq "profile is the profile name" "Work" "$(json_get "$J" 'byName(arg).profile' "$ODD")"
assert_eq "data_dir is the profile folder" "$(plist_key "$APPS/$ODD.app" AIdentityDataDir)" \
  "$(json_get "$J" 'byName(arg).data_dir' "$ODD")"
assert_eq "main is false for a profile" "false" "$(json_get "$J" 'byName(arg).main' "$ODD")"
assert_eq "a fresh profile is signed out / new" "signed out / new" "$(json_get "$J" 'byName(arg).status' "$ODD")"
assert_eq "badge keeps a non-ASCII character" "é" "$(json_get "$J" 'byName(arg).badge' "$ODD")"
assert_eq "color is the hex value" "12A594" "$(json_get "$J" 'byName(arg).color' "$ODD")"
assert_eq "built_by is the version that built it" "${VERSION_LINE#aidentity }" \
  "$(json_get "$J" 'byName(arg).built_by' "$ODD")"
assert_eq "args lists the switches" '["--lang=de"]' "$(json_get "$J" 'byName(arg).args' "$ODD")"
assert_eq "env lists variable names" '["HTTPS_PROXY"]' "$(json_get "$J" 'byName(arg).env' "$ODD")"
assert_not_contains "and never their values" "$J" "secret.example"
assert_eq "own_extensions is false by default" "false" "$(json_get "$J" 'byName(arg).own_extensions' "$ODD")"
assert_eq "own_extensions is true when asked for" "true" "$(json_get "$J" 'byName("Codey Ext").own_extensions')"

assert_eq "a main launcher has no data_dir" "null" "$(json_get "$J" 'byName("Fake Main").data_dir')"
assert_eq "a main launcher is marked main" "true" "$(json_get "$J" 'byName("Fake Main").main')"
assert_eq "a main launcher that is not running says so" "not running" "$(json_get "$J" 'byName("Fake Main").status')"
assert_eq "a used profile is in use" "in use" "$(json_get "$J" 'byName("Fake Busy").status')"
assert_eq "no badge is null" "null" "$(json_get "$J" 'byName("Fake Busy").badge')"
assert_eq "a launcher whose app is gone says app missing" "app missing" "$(json_get "$J" 'byName("Gone Lost").status')"

PATH="$PGREP_STUB:$PATH" ai_stdout list --json
assert_eq "a running profile is running" "running" "$(json_get "$RUN_OUT" 'byName("Fake Busy").status')"
PATH="$PGREP_STUB:$PATH" ai list
BUSY_STATUS=$(printf '%s\n' "$RUN_OUT" | awk '/^Fake Busy$/ { f = 1; next } f && /status/ { print; exit }')
assert_contains "the plain list agrees" "$BUSY_STATUS" "running"
assert_contains "the plain list still says how to fix a missing app" "$RUN_OUT" \
  'app missing — run: aidentity rebuild "Gone Lost"'

# Warnings go to stderr, so stdout still parses when the running check fails.
PATH="$FAIL_PGREP:$PATH" ai_stdout list --json
assert_eq "stdout parses even when a warning is printed" "5" "$(json_get "$RUN_OUT" 'd.length')"
assert_contains "the warning goes to stderr" "$RUN_ERR" "Could not check which profiles are running"
assert_eq "once, not once for each of the five launchers" "1" \
  "$(printf '%s\n' "$RUN_ERR" | grep -c 'Could not check which profiles are running')"

ai_tty '' list --json
assert_not_contains "no colour codes, even on a terminal" "$RUN_OUT" $'\033'
# A slow run outlasts ai_tty's input, and the terminal then echoes the end of
# input as "^D" and two backspaces into the output. That echo is the
# terminal's, not the script's, so it is removed before parsing.
assert_eq "and it still parses" "5" "$(json_get "${RUN_OUT//^D$'\b\b'/}" 'd.length')"

ai_stdout ls --json
assert_eq "ls --json works too" "5" "$(json_get "$RUN_OUT" 'd.length')"
ai list --jsn
assert_rc_nonzero "list refuses an option it does not know" "$RUN_RC" "$RUN_OUT"
assert_contains "and names it" "$RUN_OUT" "--jsn"
ai list extra
assert_rc_nonzero "list refuses an extra argument" "$RUN_RC" "$RUN_OUT"

# One look at the processes for all the rows: one pgrep, and one ps however
# many main launchers there are. Once per row took seconds with a dozen
# profiles.
ai add "$EXT_APP" --main
COUNT_BIN="$SANDBOX/stub-count"
COUNT_LOG="$SANDBOX/count-log"
mkdir -p "$COUNT_BIN"
printf '#!/bin/sh\necho pgrep >> "%s"\nexit 1\n' "$COUNT_LOG" > "$COUNT_BIN/pgrep"
printf '#!/bin/sh\necho ps >> "%s"\nexec /bin/ps "$@"\n' "$COUNT_LOG" > "$COUNT_BIN/ps"
chmod +x "$COUNT_BIN/pgrep" "$COUNT_BIN/ps"
count_calls() { rm -f "$COUNT_LOG"; PATH="$COUNT_BIN:$PATH" ai "$@"; sort "$COUNT_LOG" | tr '\n' ' '; }
assert_eq "list looks once for six launchers, two of them main" "pgrep ps " "$(count_calls list)"
assert_eq "list --json too" "pgrep ps " "$(count_calls list --json)"
# A snapshot ends with the command that took it. rm asks again after its
# prompt, in the same process, so a later check must look again.
RUN_OUT=$(PATH="$COUNT_BIN:$PATH" "$BASH_BIN" -c '. "$1" >/dev/null 2>&1; rm -f "$2"
  cmd_list >/dev/null; list_json >/dev/null; ui_load; echo "held after: [${PS_RC-unset}]"
  running_on_profile "$3"; running_on_profile "$3"; echo "pgrep: $(grep -c pgrep "$2")"' \
  x "$LIB" "$COUNT_LOG" "$BUSY_DATA" 2>&1)
assert_contains "no snapshot is held after list, list --json and the menu" "$RUN_OUT" "held after: [unset]"
assert_contains "so each later check looks again" "$RUN_OUT" "pgrep: 5"
# A ps that fails is asked once as well, not again for each main launcher.
printf '#!/bin/sh\necho ps >> "%s"\nexit 1\n' "$COUNT_LOG" > "$COUNT_BIN/ps"
assert_eq "a ps that fails is asked once too" "pgrep ps " "$(count_calls list)"
ai rm "Codey Main" -y

# A launcher name is whatever is on disk. Spaces, quotes, an escape and a line
# break must not split a row or reach the terminal: list --json prints the name
# exactly, list shows "?" for each control character, completion leaves it out,
# and rm still takes the real name.
CTRL_NAME="Ctl \"Q\" 'S' "$'\033'"[31m line"$'\n'"two"
cp -R "$APPS/Fake Busy.app" "$APPS/$CTRL_NAME.app"
ai_stdout list --json
assert_eq "list --json still has one object per launcher" "6" "$(json_get "$RUN_OUT" 'd.length')"
assert_eq "and the name with control characters in it is exact" "true" \
  "$(json_get "$RUN_OUT" 'byName(arg) !== undefined' "$CTRL_NAME")"
ai list
assert_contains "list shows each control character as ?" "$RUN_OUT" "Ctl \"Q\" 'S' ?[31m line?two"
assert_not_contains "so no escape reaches the terminal" "$RUN_OUT" $'\033'
assert_contains "the tab in an app's name too" "$RUN_OUT" 'Wëird "Q" \ Tab?App Work'
ai_stdout __complete launchers
assert_not_contains "completion leaves the name out" "$RUN_OUT" "Ctl "
assert_contains "and offers the others" "$RUN_OUT" "Fake Busy"
# The menu acts on the real launcher: it reads the name exactly.
RUN_OUT=$("$BASH_BIN" -c '. "$1" >/dev/null 2>&1; ui_load; echo "N=$UI_N"
  i=0; while [ "$i" -lt "$UI_N" ]; do
    [ "${UI_L_APP[$i]}" = "$2/$3.app" ] && [ "${UI_L_NAME[$i]}" = "$3" ] && echo "found it"
    i=$((i + 1)); done' x "$LIB" "$APPS" "$CTRL_NAME" 2>&1)
assert_contains "the menu reads all six launchers" "$RUN_OUT" "N=6"
assert_contains "and the name exactly, with its own launcher" "$RUN_OUT" "found it"
ai rm "$CTRL_NAME" -y
assert_rc "rm takes the real name" 0 "$RUN_RC" "$RUN_OUT"
assert_no_dir "and removes it" "$APPS/$CTRL_NAME.app"
# In a UTF-8 locale a C1 control counts too: some terminals start an escape
# sequence at one.
C1_NAME="Csi "$'\xc2\x9b'"31m red"
cp -R "$APPS/Fake Busy.app" "$APPS/$C1_NAME.app"
LC_ALL=en_US.UTF-8 ai list
assert_contains "under UTF-8, list shows a C1 control as ?" "$RUN_OUT" "Csi ?31m red"
assert_not_contains "so it does not reach the terminal" "$RUN_OUT" $'\xc2\x9b'
ai rm "$C1_NAME" -y
assert_no_dir "rm takes that name too" "$APPS/$C1_NAME.app"

for l in "$ODD" "Fake Busy" "Gone Lost"; do ai rm "$l" --purge -y; done
AIDENTITY_DATA_ROOT="$VSC_DATA" ai rm "Codey Ext" --purge -y
ai rm "Fake Main" -y
rm -rf "$ODD_APP" "$EXT_APP"
assert_eq "every launcher this group made is gone" "$JSON_LAUNCHERS_BEFORE" "$(count_launchers)"
