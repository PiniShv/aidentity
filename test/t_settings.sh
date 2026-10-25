# shellcheck shell=bash
# SC2016: single-quoted scripts are handed to "$BASH_BIN" -c and to generated
# stubs, which expand them later, on purpose. shellcheck only recognises that
# when the interpreter is spelled literally as `bash -c`.
# shellcheck disable=SC2016
#
# Area "settings": launch settings (switches and variables) and the VS Code socket path limit.
# Sourced by test/run_tests.sh after test/lib.sh. Run it alone with:
#   bash test/run_tests.sh settings

group "launch settings: an allowlist, kept across rename, rebuild and restore"

ai add "$ELECTRON_APP" --profile Flags --arg --lang=de --arg "--proxy-server=socks5://127.0.0.1:1080" \
  --env "HTTPS_PROXY=http://proxy.example:8080"
assert_rc "add accepts allowed switches and variables" 0 "$RUN_RC" "$RUN_OUT"
FL_LAUNCHER="$APPS/Fake Flags.app/Contents/MacOS/launcher"
FL_SRC=$(cat "$FL_LAUNCHER")
assert_contains "the switch reaches the app" "$FL_SRC" "'--lang=de'"
assert_contains "the variable reaches the app" "$FL_SRC" "--env 'HTTPS_PROXY=http://proxy.example:8080'"
if sh -n "$FL_LAUNCHER" 2>/dev/null; then _pass "the launcher is valid sh"; else _fail "the launcher is valid sh" "sh -n failed"; fi
ai list
assert_contains "list shows the switches" "$RUN_OUT" "--lang=de"
assert_contains "list names the variables" "$RUN_OUT" "HTTPS_PROXY (values hidden)"
assert_not_contains "but never shows their values" "$RUN_OUT" "proxy.example"

for bad in --remote-debugging-port=9222 -remote-debugging-port=9222 --inspect --no-sandbox \
           --disable-web-security --js-flags=--x --lang=../x --force-device-scale-factor=9; do
  ai add "$ELECTRON_APP" --profile Denied --arg "$bad"
  assert_rc_nonzero "the switch [$bad] is refused" "$RUN_RC" "$RUN_OUT"
done
for bad in NODE_OPTIONS=--require=/x ELECTRON_RUN_AS_NODE=1 DYLD_INSERT_LIBRARIES=/x FOO=bar HOME=/tmp; do
  ai add "$ELECTRON_APP" --profile Denied --env "$bad"
  assert_rc_nonzero "the variable [$bad] is refused" "$RUN_RC" "$RUN_OUT"
done
assert_no_dir "no launcher is built for a refused setting" "$APPS/Fake Denied.app"

ai set "Fake Flags" --env "HTTPS_PROXY=http://other.example:3128"
assert_eq "set replaces a variable of the same name" "HTTPS_PROXY=http://other.example:3128" \
  "$(/usr/libexec/PlistBuddy -c 'Print :AIdentityEnv:0' "$APPS/Fake Flags.app/Contents/Info.plist" 2>/dev/null)"
ai rename "Fake Flags" Flagged
assert_contains "rename keeps the switches" "$(cat "$APPS/Fake Flagged.app/Contents/MacOS/launcher")" "'--lang=de'"
ai rebuild "Fake Flagged"
assert_contains "rebuild keeps the switches" "$(cat "$APPS/Fake Flagged.app/Contents/MacOS/launcher")" "'--lang=de'"
rm -rf "$APPS/Fake Flagged.app"
ai restore "Fake Flagged"
assert_contains "restore keeps the switches" "$(cat "$APPS/Fake Flagged.app/Contents/MacOS/launcher")" "'--lang=de'"
ai set "Fake Flagged" --clear-args --clear-env
assert_not_contains "set --clear-args removes the switches" "$(cat "$APPS/Fake Flagged.app/Contents/MacOS/launcher")" "--lang"
assert_not_contains "set --clear-env removes the variables" "$(cat "$APPS/Fake Flagged.app/Contents/MacOS/launcher")" "HTTPS_PROXY"

# A restore record is a file anyone with the folder can edit: its settings go
# through the same allowlist.
rm -rf "$APPS/Fake Flagged.app"
/usr/libexec/PlistBuddy -c "Add :AIdentityArgs:0 string --remote-debugging-port=9222" \
  "$DATA/fake-flagged/.aidentity-profile.plist" >/dev/null 2>&1
ai restore "Fake Flagged"
assert_rc "a record carrying a refused switch is still restored" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "the refused switch is dropped, with a note" "$RUN_OUT" "Dropped a stored launch setting"
assert_not_contains "and never reaches the launcher" \
  "$(cat "$APPS/Fake Flagged.app/Contents/MacOS/launcher")" "remote-debugging"
ai rm "Fake Flagged" --purge -y

# Changed values replace old ones by switch name; the newest wins.
ai add "$ELECTRON_APP" --profile Merge --arg --lang=de --arg --lang=de
ai set "Fake Merge" --arg --lang=fr
M_SRC=$(cat "$APPS/Fake Merge.app/Contents/MacOS/launcher")
assert_contains "a new value replaces the old one" "$M_SRC" "'--lang=fr'"
assert_not_contains "the old value is gone" "$M_SRC" "--lang=de"
ai set "Fake Merge" --arg --lang=de
assert_not_contains "setting an earlier value again applies it" \
  "$(cat "$APPS/Fake Merge.app/Contents/MacOS/launcher")" "--lang=fr"
assert_contains "and says when it applies" "$RUN_OUT" "next time"
ai set "Fake Merge" --arg "--proxy-server=socks5://127.0.0.1:1080"
ai set "Fake Merge" --arg --no-proxy-server
assert_not_contains "--no-proxy-server replaces --proxy-server" \
  "$(cat "$APPS/Fake Merge.app/Contents/MacOS/launcher")" "--proxy-server="
assert_eq "a launcher with settings is owner-only" "600" \
  "$(stat -f '%Lp' "$APPS/Fake Merge.app/Contents/Info.plist")"
# A stored setting that is no longer allowed is dropped on rebuild, not fatal.
/usr/libexec/PlistBuddy -c "Add :AIdentityArgs:0 string --inspect" \
  "$APPS/Fake Merge.app/Contents/Info.plist" >/dev/null 2>&1
ai rebuild "Fake Merge"
assert_rc "rebuild drops a stored setting that is not allowed" 0 "$RUN_RC" "$RUN_OUT"
assert_not_contains "and the launcher never carries it" \
  "$(cat "$APPS/Fake Merge.app/Contents/MacOS/launcher")" "--inspect"
ai rm "Fake Merge" --purge -y

for bad in '--locale=ab-CDE$(id)' --force-device-scale-factor=1.0e308 --force-device-scale-factor=4.5 \
           '--proxy-server=http://a --inspect' --lang=d; do
  ai add "$ELECTRON_APP" --profile Shape --arg "$bad"
  assert_rc_nonzero "the value in [$bad] is refused" "$RUN_RC" "$RUN_OUT"
done
for bad in 'TZ=/etc/../x' 'LANG=../x' 'LANG TZ=x' 'HTTPS_PROXY=http://a b'; do
  ai add "$ELECTRON_APP" --profile Shape --env "$bad"
  assert_rc_nonzero "the variable [$bad] is refused" "$RUN_RC" "$RUN_OUT"
done
ai add "$ELECTRON_APP" --profile Shape --arg --lang=pt-BR --arg --force-device-scale-factor=1.25 \
  --env TZ=Europe/Berlin --env LANG=de_DE.UTF-8
assert_rc "well-formed values are accepted" 0 "$RUN_RC" "$RUN_OUT"
ai rm "Fake Shape" --purge -y

ai add "$ELECTRON_APP" --profile Ext --own-extensions
assert_rc_nonzero "--own-extensions is refused for an app that is not VS Code" "$RUN_RC" "$RUN_OUT"
VSC_APP="$SRC/Codish.app"
make_electron_app "$VSC_APP"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.example.codish" "$VSC_APP/Contents/Info.plist"
mkdir -p "$VSC_APP/Contents/Resources/app"
printf '{"darwinBundleIdentifier":"com.example.codish","dataFolderName":".codish"}\n' \
  > "$VSC_APP/Contents/Resources/app/product.json"
AIDENTITY_DATA_ROOT="$VSC_DATA" ai add "$VSC_APP" --profile Iso --own-extensions
assert_rc "a VS Code-style app accepts --own-extensions" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "its launcher gets its own extensions folder" \
  "$(cat "$APPS/Codish Iso.app/Contents/MacOS/launcher")" "--extensions-dir='$VSC_DATA/codish-iso/extensions'"
AIDENTITY_DATA_ROOT="$VSC_DATA" ai rm "Codish Iso" --purge -y
rm -rf "$VSC_APP"


group "VS Code-style apps: the socket path limit"

# VS Code and its forks quit at start when the path of the socket they keep in
# the profile folder, "<first four characters of the version>-main.sock", is
# longer than 103 bytes.
SOCK_APP="$SRC/Codish.app"
make_electron_app "$SOCK_APP"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.example.codish" "$SOCK_APP/Contents/Info.plist"
mkdir -p "$SOCK_APP/Contents/Resources/app"
sock_version() { # version, or nothing for a product.json without one
  printf '{"darwinBundleIdentifier":"com.example.codish","dataFolderName":".codish"%s}\n' \
    "${1:+,\"version\":\"$1\"}" > "$SOCK_APP/Contents/Resources/app/product.json"
}

sock_version 1.142.0
libcall socket_path_bytes "$SOCK_APP" "/p"
assert_eq "the socket is named after the version's first four characters" "17" "$RUN_OUT"
sock_version 1.0
libcall socket_path_bytes "$SOCK_APP" "/p"
assert_eq "a shorter version gives a shorter name" "16" "$RUN_OUT"
sock_version ""
libcall socket_path_bytes "$SOCK_APP" "/p"
assert_eq "with no version, the longest name is assumed" "17" "$RUN_OUT"
sock_version 1.142.0

ai add "$SOCK_APP" --main
assert_rc "a main launcher has no profile folder, so nothing to check" 0 "$RUN_RC" "$RUN_OUT"
ai rm "Codish Main" -y
ai add "$ELECTRON_APP" --profile "$(repeat_char 40 a)"
assert_rc "an app that is not VS Code-style is not checked" 0 "$RUN_RC" "$RUN_OUT"
ai rm "Fake $(repeat_char 40 a)" --purge -y

# The socket path is: root / "codish-" name / "1.14-main.sock", so the longest
# name that fits follows from the root's length in bytes (LC_ALL=C here).
FIT=$((103 - ${#VSC_DATA} - 23))
if [ "$FIT" -lt 2 ] || [ "$FIT" -gt 39 ]; then
  _skip "socket path limit for add, rename, restore and doctor" "the sandbox path is ${#SANDBOX} bytes"
else
  NAME_FIT=$(repeat_char "$FIT" a)
  NAME_OVER=$(repeat_char $((FIT + 1)) a)

  AIDENTITY_DATA_ROOT="$VSC_DATA" ai add "$SOCK_APP" --profile "$NAME_OVER"
  assert_rc_nonzero "add refuses a profile whose socket path would be 104 bytes" "$RUN_RC" "$RUN_OUT"
  assert_contains "and says how long it would be" "$RUN_OUT" "this one would be 104"
  assert_contains "and the limit" "$RUN_OUT" "103 bytes"
  assert_contains "and the longest name that fits" "$RUN_OUT" "Use a profile name of at most $FIT characters, or set AIDENTITY_DATA_ROOT"
  assert_no_dir "it builds no launcher" "$APPS/Codish $NAME_OVER.app"
  assert_no_dir "and makes no profile folder" "$VSC_DATA/codish-$NAME_OVER"

  # é is one character and two bytes. Counted as characters, this path would
  # be 103 and pass.
  U_ROOT="$SANDBOX/é"
  LC_ALL=en_US.UTF-8 AIDENTITY_DATA_ROOT="$U_ROOT" ai add "$SOCK_APP" --profile "$NAME_FIT"
  assert_rc_nonzero "bytes are counted, not characters" "$RUN_RC" "$RUN_OUT"
  assert_contains "so a UTF-8 path is 104 bytes" "$RUN_OUT" "this one would be 104"
  assert_no_dir "and nothing is created" "$U_ROOT"

  # A data folder so deep that a one-character name would be 106 bytes: no
  # name fits, and the folder must be 3 bytes shorter.
  DEEP_ROOT="$VSC_DATA/$(repeat_char $((82 - ${#VSC_DATA} - 1)) d)"
  AIDENTITY_DATA_ROOT="$DEEP_ROOT" ai add "$SOCK_APP" --profile A
  assert_rc_nonzero "a data folder too deep for any name is refused" "$RUN_RC" "$RUN_OUT"
  assert_contains "and says no name fits" "$RUN_OUT" "Even a one-character name is too long in this data folder"
  assert_contains "and how much shorter the folder must be" "$RUN_OUT" \
    "AIDENTITY_DATA_ROOT to a folder whose path is at least 3 bytes shorter"
  assert_no_dir "and nothing is created" "$DEEP_ROOT"

  AIDENTITY_DATA_ROOT="$VSC_DATA" ai add "$SOCK_APP" --profile A
  assert_rc "a short name is fine" 0 "$RUN_RC" "$RUN_OUT"
  printf 'session\n' > "$VSC_DATA/codish-a/Cookies"
  AIDENTITY_DATA_ROOT="$VSC_DATA" ai rename "Codish A" "$NAME_OVER"
  assert_rc_nonzero "rename refuses a name whose socket path would be too long" "$RUN_RC" "$RUN_OUT"
  assert_contains "and asks for a shorter one" "$RUN_OUT" "of at most $FIT characters"
  assert_dir "the launcher is untouched" "$APPS/Codish A.app"
  assert_file "and the profile is not moved" "$VSC_DATA/codish-a/Cookies"
  assert_no_dir "to the new name" "$VSC_DATA/codish-$NAME_OVER"
  AIDENTITY_DATA_ROOT="$VSC_DATA" ai rename "Codish A" "$NAME_FIT"
  assert_rc "rename takes a name of exactly 103 bytes" 0 "$RUN_RC" "$RUN_OUT"
  assert_file "and moves the profile" "$VSC_DATA/codish-$NAME_FIT/Cookies"
  AIDENTITY_DATA_ROOT="$VSC_DATA" ai doctor
  assert_not_contains "doctor finds nothing wrong at exactly 103 bytes" "$RUN_OUT" "cannot open it"

  # A launcher deleted in Finder, and a folder one byte too deep to restore.
  FIT_DATA="$VSC_DATA/codish-$NAME_FIT"
  LONG_DATA="$VSC_DATA/codish-${NAME_FIT}x"
  rm -rf "$APPS/Codish $NAME_FIT.app"
  mv "$FIT_DATA" "$LONG_DATA"
  AIDENTITY_DATA_ROOT="$VSC_DATA" ai restore --all
  assert_rc_nonzero "restore refuses a folder whose socket path is too long" "$RUN_RC" "$RUN_OUT"
  assert_contains "and says to rename the folder" "$RUN_OUT" "Rename this folder to a name of at most $((FIT + 7)) characters"
  assert_no_dir "it builds no launcher" "$APPS/Codish $NAME_FIT.app"
  assert_file "and leaves the profile alone" "$LONG_DATA/Cookies"
  mv "$LONG_DATA" "$FIT_DATA"
  AIDENTITY_DATA_ROOT="$VSC_DATA" ai restore --all
  assert_rc "with a shorter folder name it restores" 0 "$RUN_RC" "$RUN_OUT"
  assert_dir "the launcher is back" "$APPS/Codish $NAME_FIT.app"

  # A profile made before this check, one byte too deep.
  mv "$FIT_DATA" "$LONG_DATA"
  /usr/libexec/PlistBuddy -c "Set :AIdentityDataDir $LONG_DATA" "$APPS/Codish $NAME_FIT.app/Contents/Info.plist"
  AIDENTITY_DATA_ROOT="$VSC_DATA" ai doctor
  assert_rc "doctor reports, it does not fail" 0 "$RUN_RC" "$RUN_OUT"
  assert_contains "doctor reports a profile whose socket path is too long" "$RUN_OUT" \
    "Codish cannot open it: the socket path in its profile folder would be 104 bytes, and macOS allows 103"
  assert_contains "with the rename that fixes it" "$RUN_OUT" \
    "rename it to a name of at most $FIT characters: aidentity rename \"Codish $NAME_FIT\""
  AIDENTITY_DATA_ROOT="$VSC_DATA" ai doctor --fix
  assert_contains "--fix leaves the new name to the user" "$RUN_OUT" "Codish cannot open it"
  assert_eq "and the profile folder stays where it is" "$LONG_DATA" \
    "$(plist_key "$APPS/Codish $NAME_FIT.app" AIdentityDataDir)"
  AIDENTITY_DATA_ROOT="$VSC_DATA" ai add "$SOCK_APP" --profile "$NAME_FIT"
  assert_rc_nonzero "re-adding it is refused too" "$RUN_RC" "$RUN_OUT"
  assert_contains "and points to a rename" "$RUN_OUT" "Rename it to a name of at most $FIT characters:"
  assert_contains "with the command" "$RUN_OUT" "aidentity rename \"Codish $NAME_FIT\""
  AIDENTITY_DATA_ROOT="$VSC_DATA" ai rm "Codish $NAME_FIT" --purge -y
  assert_no_dir "rm --purge still removes it" "$LONG_DATA"
fi
rm -rf "$SOCK_APP"
