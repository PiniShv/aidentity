# shellcheck shell=bash
# SC2016: the injection payloads below hold $( ) and backticks that must reach
# the script unexpanded.
# shellcheck disable=SC2016
#
# Area "transfer": export and import.
# Sourced by test/run_tests.sh after test/lib.sh. Run it alone with:
#   bash test/run_tests.sh transfer

# The VS Code-style app needs a short profile folder (see the settings area),
# so every launcher this area builds keeps its data in VSC_DATA. import makes a
# temporary folder: TMPDIR points into the sandbox, so a test can see that it
# is gone afterwards.
TR_TMP="$SANDBOX/transfer-tmp"
mkdir -p "$TR_TMP"
tx() { TMPDIR="$TR_TMP" AIDENTITY_DATA_ROOT="$VSC_DATA" ai "$@"; }
tx_stdout() { TMPDIR="$TR_TMP" AIDENTITY_DATA_ROOT="$VSC_DATA" ai_stdout "$@"; }
tx_in() { TMPDIR="$TR_TMP" AIDENTITY_DATA_ROOT="$VSC_DATA" ai_in "$@"; }
tr_tmp_gone() { assert_eq "$1 leaves no temporary folder" "" "$(ls -A "$TR_TMP")"; }

# A string as JSON, by the script's own json_str.
js() { libcall json_str "$1"; printf '%s' "$RUN_OUT"; }

# One launcher entry for an import file. Each KEY=VALUE replaces a key or adds
# one; VALUE is JSON as it is.
tr_entry() {
  local name='"Fake Inj"' app='"Fake"' bid='"com.aidentity.test.electron"' profile='"Inj"'
  local main=false badge='"I"' color='"2E7DF6"' args='[]' env='[]' own=false more="" kv
  for kv in "$@"; do
    case "$kv" in
      name=*) name=${kv#*=} ;;
      app=*) app=${kv#*=} ;;
      bundle_id=*) bid=${kv#*=} ;;
      profile=*) profile=${kv#*=} ;;
      main=*) main=${kv#*=} ;;
      badge=*) badge=${kv#*=} ;;
      color=*) color=${kv#*=} ;;
      args=*) args=${kv#*=} ;;
      env=*) env=${kv#*=} ;;
      own_extensions=*) own=${kv#*=} ;;
      *) more="$more,\"${kv%%=*}\":${kv#*=}" ;;
    esac
  done
  printf '{"name":%s,"app":%s,"bundle_id":%s,"profile":%s,"main":%s,"badge":%s,"color":%s,"args":%s,"env":%s,"own_extensions":%s%s}' \
    "$name" "$app" "$bid" "$profile" "$main" "$badge" "$color" "$args" "$env" "$own" "$more"
}

# An import file at $1 that lists the entries after it.
tr_file() { # path, entries...
  local f="$1" IFS=,
  shift
  printf '{"aidentity_export": 1, "exported_by": "test", "launchers": [%s]}\n' "$*" > "$f"
}

# How many lines of $1 contain $2.
lines_with() { printf '%s\n' "$1" | grep -c -- "$2"; }

group "export"

ai version
TR_VERSION=${RUN_OUT#aidentity }

tx_stdout export
assert_rc "export with no launchers exits 0" 0 "$RUN_RC" "$RUN_ERR"
assert_eq "and prints an empty list" \
  "{\"aidentity_export\": 1, \"exported_by\": \"$TR_VERSION\", \"launchers\": []}" "$RUN_OUT"
assert_eq "and nothing on stderr" "" "$RUN_ERR"
ai export extra
assert_rc_nonzero "export takes no argument" "$RUN_RC" "$RUN_OUT"
ai export --json
assert_rc_nonzero "and no option" "$RUN_RC" "$RUN_OUT"
assert_contains "and names it" "$RUN_OUT" "--json"

# A switch can carry a user name and password too: export warns about it, as
# it does about a variable's value. A switch without one is not warned about.
tx add "$ELECTRON_APP" --profile Creds --arg "--proxy-server=http://user:secret@proxy.example:8080"
tx_stdout export
assert_contains "a switch with a user name and password: export warns" "$RUN_ERR" \
  "The file holds a launch switch with a user name or password in it."
assert_contains "and says to keep the file private" "$RUN_ERR" "keep the file private"
assert_not_contains "the warning is not in the file" "$RUN_OUT" "private"
tx rm "Fake Creds" --purge -y
tx add "$ELECTRON_APP" --profile Nocreds --arg "--proxy-server=http://proxy.example:8080"
tx_stdout export
assert_eq "a switch with no user name in it: no warning" "" "$RUN_ERR"
tx rm "Fake Nocreds" --purge -y

CODEY="$SRC/Codey.app"
make_electron_app "$CODEY"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.example.codey" "$CODEY/Contents/Info.plist"
mkdir -p "$CODEY/Contents/Resources/app"
printf '{"darwinBundleIdentifier":"com.example.codey","dataFolderName":".codey"}\n' \
  > "$CODEY/Contents/Resources/app/product.json"
# An app name with a quote and non-ASCII, which the JSON must escape.
WEIRD="$SRC/Wëird \"Q\".app"
make_electron_app "$WEIRD"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.example.weird" "$WEIRD/Contents/Info.plist"

tx add "$ELECTRON_APP" --profile Work --badge Q --color purple --arg --lang=de \
  --env "HTTPS_PROXY=http://proxy.example:8080"
assert_rc "made a profile with a badge, a colour and settings" 0 "$RUN_RC" "$RUN_OUT"
tx add "$ELECTRON_APP" --profile Plain --no-badge --color 1A2B3C
assert_rc "one with no badge and a hex colour" 0 "$RUN_RC" "$RUN_OUT"
tx add "$ELECTRON_APP" --main
assert_rc "a main launcher" 0 "$RUN_RC" "$RUN_OUT"
tx add "$FORK_APP" --profile Home --arg --disable-gpu --arg --force-device-scale-factor=1.25 \
  --env TZ=Europe/Berlin --env LANG=de_DE.UTF-8
assert_rc "one for another app, with the default badge and colour" 0 "$RUN_RC" "$RUN_OUT"
tx add "$CODEY" --profile Ext --own-extensions
assert_rc "one for a VS Code-style app with its own extensions" 0 "$RUN_RC" "$RUN_OUT"
tx add "$WEIRD" --profile Odd --badge é
assert_rc "one for an app with a quote in its name" 0 "$RUN_RC" "$RUN_OUT"
printf 'session\n' > "$VSC_DATA/fake-work/Cookies"
TR_LIST=("Codey Ext" "Fake Main" "Fake Plain" "Fake Work" "Forky Home" "Wëird \"Q\" Odd")

TR_FILE="$SB/profiles.json"
tx_stdout export
assert_rc "export exits 0" 0 "$RUN_RC" "$RUN_ERR"
TR_JSON=$RUN_OUT
printf '%s\n' "$TR_JSON" > "$TR_FILE"
if /usr/bin/plutil -convert xml1 -o "$SB/profiles.plist" "$TR_FILE" >/dev/null 2>&1; then
  _pass "plutil reads the export"
else
  _fail "plutil reads the export" "$TR_JSON"
fi
# The value at a key path of the export, as plutil reads it.
xv() { /usr/bin/plutil -extract "$1" raw -o - "$SB/profiles.plist" 2>/dev/null; }
# The value at a key path of the exported launcher named $1.
xget() { # name, key path inside its object
  local i=0 n
  n=$(xv launchers)
  while [ "$i" -lt "$n" ]; do
    if [ "$(xv "launchers.$i.name")" = "$1" ]; then xv "launchers.$i.$2"; return 0; fi
    i=$((i + 1))
  done
  printf '<no launcher named %s>' "$1"
}
assert_eq "it says it is format 1" "1" "$(xv aidentity_export)"
assert_eq "made by this version" "$TR_VERSION" "$(xv exported_by)"
assert_eq "one object per launcher" "6" "$(xv launchers)"
assert_eq "in the order list shows them" "$(IFS='|'; printf '%s' "${TR_LIST[*]}")" \
  "$(json_get "$TR_JSON" 'd.launchers.map(function (o) { return o.name; }).join("|")')"
assert_eq "every object has the same keys, in the same order" "true" \
  "$(json_get "$TR_JSON" 'd.launchers.every(function (o) { return Object.keys(o).join() === arg; })' \
     "name,app,bundle_id,profile,main,badge,color,args,env,own_extensions")"
assert_eq "app is the app's name" "Fake" "$(xget "Fake Work" app)"
assert_eq "bundle_id is the app's" "com.aidentity.test.electron" "$(xget "Fake Work" bundle_id)"
assert_eq "profile is the profile name" "Work" "$(xget "Fake Work" profile)"
assert_eq "main is false for a profile" "false" "$(xget "Fake Work" main)"
assert_eq "badge is the badge" "Q" "$(xget "Fake Work" badge)"
assert_eq "color is the hex value" "8E4EC6" "$(xget "Fake Work" color)"
assert_eq "args lists the switch" "--lang=de" "$(xget "Fake Work" args.0)"
assert_eq "env holds the variable with its value" "HTTPS_PROXY=http://proxy.example:8080" "$(xget "Fake Work" env.0)"
assert_eq "own_extensions is false by default" "false" "$(xget "Fake Work" own_extensions)"
assert_eq "no badge is an empty badge, not null" "" "$(xget "Fake Plain" badge)"
assert_eq "a hex colour is kept" "1A2B3C" "$(xget "Fake Plain" color)"
assert_eq "a main launcher is marked main" "true" "$(xget "Fake Main" main)"
assert_eq "with its profile name" "Main" "$(xget "Fake Main" profile)"
assert_eq "another app has its own bundle_id" "com.aidentity.test.fork" "$(xget "Forky Home" bundle_id)"
assert_eq "the default badge is written out" "H" "$(xget "Forky Home" badge)"
libcall eval 'color_hex "$(auto_color "Forky Home")"'
assert_eq "and the default colour" "$RUN_OUT" "$(xget "Forky Home" color)"
assert_eq "every switch, in order" "2 --disable-gpu --force-device-scale-factor=1.25" \
  "$(xget "Forky Home" args) $(xget "Forky Home" args.0) $(xget "Forky Home" args.1)"
assert_eq "every variable, in order" "2 TZ=Europe/Berlin LANG=de_DE.UTF-8" \
  "$(xget "Forky Home" env) $(xget "Forky Home" env.0) $(xget "Forky Home" env.1)"
assert_eq "own_extensions is true when asked for" "true" "$(xget "Codey Ext" own_extensions)"
assert_eq "a quote and UTF-8 in an app name survive" "Wëird \"Q\"" "$(xget "Wëird \"Q\" Odd" app)"
assert_eq "and a UTF-8 badge" "é" "$(xget "Wëird \"Q\" Odd" badge)"
for bad in "$SANDBOX" "$VSC_DATA" "$SRC" "/Applications" ".app" "data_dir" "app_path" "user-data-dir" "null"; do
  assert_not_contains "the export holds no path or data folder [$bad]" "$TR_JSON" "$bad"
done
assert_contains "a warning says the file holds variable values" "$RUN_ERR" "the values of 3 launch variables"
assert_contains "and to keep it private" "$RUN_ERR" "keep the file private"
assert_not_contains "the warning is not in the file" "$TR_JSON" "private"

# A launcher whose app is gone: the bundle ID its restore record kept. A main
# launcher has no record, so the file says no bundle ID, and why.
GONE="$SRC/Gone.app"
make_electron_app "$GONE"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.example.gone" "$GONE/Contents/Info.plist"
tx add "$GONE" --profile Lost
tx add "$GONE" --main
rm -rf "$GONE"
tx_stdout export
J=$RUN_OUT
assert_eq "an app that is gone: the bundle ID from the restore record" "com.example.gone" \
  "$(json_get "$J" 'd.launchers.filter(function (o) { return o.name === "Gone Lost"; })[0].bundle_id')"
assert_eq "a main launcher whose app is gone: an empty bundle ID" "" \
  "$(json_get "$J" 'd.launchers.filter(function (o) { return o.name === "Gone Main"; })[0].bundle_id')"
assert_contains "and a warning that import will skip it" "$RUN_ERR" "'Gone Main': its app is missing"
tx rm "Gone Lost" --purge -y
tx rm "Gone Main" -y

# A profile whose app is gone and whose folder has no restore record (made
# before records existed, or the record was deleted): no bundle ID is known.
# The same for an app folder with no Info.plist. PlistBuddy prints its error,
# with the path, on stdout: none of it reaches the file.
NOREC="$SRC/Norec.app"
make_electron_app "$NOREC"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.example.norec" "$NOREC/Contents/Info.plist"
tx add "$NOREC" --profile Old
rm -f "$VSC_DATA/norec-old/.aidentity-profile.plist"
rm -rf "$NOREC"
HALF="$SRC/Half.app"
make_electron_app "$HALF"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.example.half" "$HALF/Contents/Info.plist"
tx add "$HALF" --profile Broken
rm -f "$VSC_DATA/half-broken/.aidentity-profile.plist" "$HALF/Contents/Info.plist"
tx_stdout export
J=$RUN_OUT
assert_eq "no app and no restore record: an empty bundle ID" "" \
  "$(json_get "$J" 'd.launchers.filter(function (o) { return o.name === "Norec Old"; })[0].bundle_id')"
assert_contains "and a warning that import will skip it" "$RUN_ERR" "'Norec Old': its app is missing"
assert_eq "an app with no Info.plist and no restore record: an empty bundle ID" "" \
  "$(json_get "$J" 'd.launchers.filter(function (o) { return o.name === "Half Broken"; })[0].bundle_id')"
assert_contains "and a warning for it too" "$RUN_ERR" "'Half Broken': its app is missing"
assert_not_contains "no path of a profile folder reaches the file" "$J" "$VSC_DATA"
assert_not_contains "nor of an app" "$J" "$SRC"
assert_not_contains "nor PlistBuddy's error" "$J" "Doesn't Exist"
assert_not_contains "nor the name of a plist file" "$J" ".plist"
libcall record_get "$VSC_DATA/norec-old" AIdentityTargetBundleID
assert_rc_nonzero "record_get fails for a folder with no restore record" "$RUN_RC" "$RUN_OUT"
assert_eq "and prints nothing" "" "$RUN_OUT"
tx rm "Norec Old" --purge -y
tx rm "Half Broken" --purge -y
rm -rf "$HALF"


group "import: a round trip"

TR_BEFORE=()
for l in "${TR_LIST[@]}"; do
  TR_BEFORE+=("$(cat "$APPS/$l.app/Contents/Info.plist" "$APPS/$l.app/Contents/MacOS/launcher")")
done
for l in "${TR_LIST[@]}"; do tx rm "$l" --purge -y; done
assert_eq "every launcher is removed" "0" "$(count_launchers)"
assert_eq "with its data" "" "$(ls -A "$VSC_DATA")"

tx import "$TR_FILE" -y
assert_rc "import -y exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "it shows the plan" "$RUN_OUT" "create  Fake Work"
assert_contains "it says a main launcher opens the original account" "$RUN_OUT" \
  "create  Fake Main — opens the original account"
assert_contains "it reports each result" "$RUN_OUT" "Created Fake Work"
assert_contains "and a count" "$RUN_OUT" "6 created, 0 skipped, 0 failed."
assert_contains "and how to sign in to them" "$RUN_OUT" "Open each new profile to sign in, e.g.:  aidentity open \"Codey Ext\""
assert_contains "the plan shows the launch settings each launcher brings" "$RUN_OUT" "  create  Fake Work
          flags  --lang=de
          proxy  HTTPS_PROXY=http://proxy.example:8080"
assert_contains "every switch, and every other variable by name" "$RUN_OUT" "  create  Forky Home
          flags  --disable-gpu --force-device-scale-factor=1.25
          env    TZ LANG (values hidden)"
assert_contains "and its own extensions folder" "$RUN_OUT" "  create  Codey Ext
          ext    its own extensions folder"
assert_not_contains "never the value of a variable that is not a proxy" "$RUN_OUT" "Europe/Berlin"
assert_not_contains "nor this one's" "$RUN_OUT" "de_DE"
i=0
for l in "${TR_LIST[@]}"; do
  assert_eq "$l is the same launcher again: app, look, settings, folder" "${TR_BEFORE[$i]}" \
    "$(cat "$APPS/$l.app/Contents/Info.plist" "$APPS/$l.app/Contents/MacOS/launcher" 2>&1)"
  i=$((i + 1))
done
assert_dir "a profile gets a new folder" "$VSC_DATA/fake-work"
assert_no_file "and starts signed out" "$VSC_DATA/fake-work/Cookies"
tr_tmp_gone "an import"


group "import: what exists is skipped, never changed"

tx set "Fake Work" --color red
TR_RED=$(cat "$APPS/Fake Work.app/Contents/Info.plist")
TR_TREE=$(fingerprint "$APPS")
tx import "$TR_FILE" -y
assert_rc "importing launchers that exist exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "each one is skipped" "6" "$(lines_with "$RUN_OUT" "— already exists")"
assert_contains "and nothing is created" "$RUN_OUT" "Nothing to create."
assert_eq "a launcher that exists is not changed" "$TR_RED" "$(cat "$APPS/Fake Work.app/Contents/Info.plist")"
assert_eq "nothing is added or removed" "$TR_TREE" "$(fingerprint "$APPS")"

# A main launcher for an app that has one under another name.
TR_F="$SB/one.json"
tr_file "$TR_F" "$(tr_entry profile='"Original"' main=true)"
tx import "$TR_F" -y
assert_contains "a second main launcher for an app is skipped" "$RUN_OUT" \
  "skip    Fake Original — 'Fake Main' already opens the original account"
assert_no_dir "and not built" "$APPS/Fake Original.app"
for l in "${TR_LIST[@]}"; do tx rm "$l" --purge -y; done


group "import: the app is found by bundle ID, among installed apps only"

# Outside the app folders, so not installed as far as aidentity knows.
HIDDEN="$SANDBOX/elsewhere/Hidden.app"
make_electron_app "$HIDDEN"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.example.hidden" "$HIDDEN/Contents/Info.plist"
DECOY="$SB/Decoy.app"
make_decoy_app "$DECOY"
DECOY_FP=$(fingerprint "$DECOY")
tx add "$ELECTRON_APP" --profile Built
tr_file "$TR_F" \
  "$(tr_entry bundle_id='"com.example.nothere"' profile='"Nowhere"' name='"Some Nowhere"')" \
  "$(tr_entry profile='"Second"')" \
  "$(tr_entry bundle_id='"com.example.hidden"' profile='"Hid"')" \
  "$(tr_entry bundle_id='"com.aidentity.fake-built"' profile='"Selfish"')" \
  "$(tr_entry profile='"Pathy"' "data_dir=$(js "$SB/elsewhere-data")" "app_path=$(js "$DECOY")" \
      "path=$(js "$SB/elsewhere-data")" "user_data_dir=$(js "$SB/elsewhere-data")")" \
  "$(tr_entry profile='"Named"' name='"Totally Different"' app='"Other App"')"
tx import "$TR_F" -y
assert_rc "an import with skipped entries exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "an unknown bundle ID is skipped, by the name the file gives" "$RUN_OUT" \
  "skip    Some Nowhere — no app with the bundle ID com.example.nothere is installed"
assert_contains "an app outside the app folders is not found" "$RUN_OUT" \
  "no app with the bundle ID com.example.hidden is installed"
assert_contains "a launcher is never taken for an app" "$RUN_OUT" \
  "no app with the bundle ID com.aidentity.fake-built is installed"
assert_contains "the rest go on" "$RUN_OUT" "Created Fake Second"
assert_contains "with a count" "$RUN_OUT" "3 created, 3 skipped, 0 failed."
assert_dir "the entry after a skipped one is built" "$APPS/Fake Second.app"
assert_eq "a data folder in the file is ignored" "$VSC_DATA/fake-pathy" \
  "$(plist_key "$APPS/Fake Pathy.app" AIdentityDataDir)"
assert_eq "and so is an app path" "$ELECTRON_APP" "$(plist_key "$APPS/Fake Pathy.app" AIdentityTargetApp)"
assert_no_dir "the folder the file names is never made" "$SB/elsewhere-data"
assert_eq "the app it names is untouched" "$DECOY_FP" "$(fingerprint "$DECOY")"
assert_dir "the launcher name is the one add gives, not the file's" "$APPS/Fake Named.app"
assert_no_dir "not the name in the file" "$APPS/Totally Different.app"
assert_no_dir "an unknown app gets no launcher" "$APPS/Fake Nowhere.app"
for l in "Fake Second" "Fake Pathy" "Fake Named" "Fake Built"; do tx rm "$l" --purge -y; done
rm -rf "$SANDBOX/elsewhere" "$DECOY"
tr_tmp_gone "an import with skips"

# Not even the path of an app that is installed: the app is the one the
# bundle ID names.
tr_file "$TR_F" "$(tr_entry profile='"Pathed"' "app=$(js "$FORK_APP")" "path=$(js "$FORK_APP")" \
  "app_path=$(js "$FORK_APP")")"
tx import "$TR_F" -y
assert_eq "an installed app's path in the file is not used" "$ELECTRON_APP" \
  "$(plist_key "$APPS/Fake Pathed.app" AIdentityTargetApp)"
assert_no_dir "and no launcher is built for that app" "$APPS/Forky Pathed.app"
tx rm "Fake Pathed" --purge -y


group "import: every value is checked as add checks it"

# Each field that becomes part of a launcher, with values add refuses:
# injection attempts, and plain bad values. Every entry is skipped, so the
# file builds nothing.
TR_PWN="$SANDBOX/tr-pwned"
TR_INJ=(
  'Inj$(touch '"$TR_PWN"')'
  'Inj`touch '"$TR_PWN"'`'
  'Inj; touch '"$TR_PWN"
  '../../../../etc/pwned'
  'Inj" /><key>x</key><string>y</string><!--'
  "Inj"$'\033'"[31m red"
  "Inj"$'\n'"two"
)
tr_refused() { # description, field, how many of its lines carry the reason, the reason, values...
  local desc="$1" field="$2" want="$3" why="$4" v entries=() before
  shift 4
  for v in "$@"; do entries+=("$(tr_entry "$field=$v")"); done
  tr_file "$TR_F" "${entries[@]}"
  before=$(fingerprint "$APPS")
  tx import "$TR_F" -y
  assert_rc "$desc: the import exits 0" 0 "$RUN_RC" "$RUN_OUT"
  assert_eq "$desc: every entry is skipped" "$#" "$(lines_with "$RUN_OUT" "^  skip    ")"
  assert_eq "$desc: for the reason" "$want" "$(lines_with "$RUN_OUT" "$why")"
  assert_contains "$desc: nothing is created" "$RUN_OUT" "Nothing to create."
  assert_eq "$desc: no launcher is built" "$before" "$(fingerprint "$APPS")"
  assert_no_file "$desc: no injected command ran" "$TR_PWN"
  assert_not_contains "$desc: no escape reaches the terminal" "$RUN_OUT" $'\033'
}
tr_js_all() { # the values, each as a JSON string, into TR_VALUES
  local v
  TR_VALUES=()
  for v in "$@"; do TR_VALUES+=("$(js "$v")"); done
}

tr_js_all "${TR_INJ[@]}" "" " Lead" "Trail " "-dash" ".dot" "$(repeat_char 41 a)" "Wörk"
tr_refused "profile" profile 9 "Profile name may only contain" "${TR_VALUES[@]}"
assert_contains "profile: an empty name says so" "$RUN_OUT" "Profile name cannot be empty"
assert_contains "profile: a long name says so" "$RUN_OUT" "too long"
assert_contains "profile: the reason is one line, without the value" "$RUN_OUT" \
  "skip    Fake Inj — Profile name may only contain letters, numbers, spaces, hyphens and underscores."
assert_not_contains "profile: the value is never printed" "$RUN_OUT" "touch"

tr_js_all "${TR_INJ[@]}" "" "com.example/x" "com example" "$(repeat_char 256 a)"
tr_refused "bundle_id" bundle_id 11 "bundle_id is not a bundle ID" "${TR_VALUES[@]}"

tr_js_all "${TR_INJ[@]}" "" "chartreuse" "12345" "GGGGGG" "1234567" "#2E7DF6"
tr_refused "color" color 13 "unknown colour" "${TR_VALUES[@]}"

TR_VALUES=()
for v in "${TR_INJ[@]}"; do TR_VALUES+=("[$(js "--lang=$v")]"); done
for v in --inspect --remote-debugging-port=9222 --no-sandbox --js-flags=--x -x lang=de \
         "--proxy-server=http://a --inspect" --force-device-scale-factor=9 --disable-gpu=1; do
  TR_VALUES+=("[\"--lang=de\",$(js "$v")]")
done
tr_refused "args" args 16 "^  skip    Fake Inj — " "${TR_VALUES[@]}"
assert_contains "args: a switch that is not allowed is named" "$RUN_OUT" "--inspect is not one aidentity passes on"
assert_not_contains "args: without the long list of what is" "$RUN_OUT" "Allowed:"

TR_VALUES=()
for v in "${TR_INJ[@]}"; do TR_VALUES+=("[$(js "LANG=$v")]"); done
for v in NODE_OPTIONS=--require=/x DYLD_INSERT_LIBRARIES=/x ELECTRON_RUN_AS_NODE=1 HOME=/tmp \
         "TZ=../../x" "HTTPS_PROXY=http://user:hunter2@a b" "nameonly-hunter2" "=x"; do
  TR_VALUES+=("[$(js "$v")]")
done
tr_refused "env" env 15 "^  skip    Fake Inj — " "${TR_VALUES[@]}"
assert_contains "env: a variable that is not allowed is named" "$RUN_OUT" "NODE_OPTIONS is not one aidentity passes on"
assert_not_contains "env: a value is never printed" "$RUN_OUT" "hunter2"

# A switch or variable longer than 1024 characters is refused before it is
# checked: the checks take longer than linear time on a long value, and a
# file of a few MB once kept import busy for over an hour.
tr_long() { head -c "$1" /dev/zero | tr '\0' "$2"; }
tr_file "$TR_F" \
  "$(tr_entry profile='"Longarg"' args="[\"--proxy-server=$(tr_long 2000 a)\"]")" \
  "$(tr_entry profile='"Longenv"' env="[\"HTTPS_PROXY=$(tr_long 2000 a)\"]")" \
  "$(tr_entry profile='"Hugearg"' args="[\"--lang=$(tr_long 400000 a)\"]")" \
  "$(tr_entry profile='"Hugeenv"' env="[\"$(tr_long 400000 X)=1\"]")" \
  "$(tr_entry profile='"Edge"' args="[\"--proxy-server=$(tr_long 1009 a)\"]")"
before=$(fingerprint "$APPS")
TR_T0=$SECONDS
tx import "$TR_F" -y
TR_DT=$((SECONDS - TR_T0))
assert_rc "values that are too long: the import exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "a switch over 1024 characters is skipped as too long" "2" \
  "$(lines_with "$RUN_OUT" "— args has a value that is too long")"
assert_eq "and a variable" "2" "$(lines_with "$RUN_OUT" "— env has a value that is too long")"
assert_contains "one of exactly 1024 is checked as usual" "$RUN_OUT" \
  "skip    Fake Edge — --proxy-server needs a proxy value"
assert_eq "nothing is built" "$before" "$(fingerprint "$APPS")"
assert_eq "values of 400000 characters are refused quickly" "quick" \
  "$(if [ "$TR_DT" -le 15 ]; then echo quick; else echo "took $TR_DT s"; fi)"
assert_eq "and never printed" "short" \
  "$(if [ "${#RUN_OUT}" -le 4000 ]; then echo short; else echo "${#RUN_OUT} characters"; fi)"

# What is checked for its type: each of these is skipped, for its own reason.
tr_file "$TR_F" '"just text"' '7' \
  "$(tr_entry profile='7')" \
  "$(tr_entry bundle_id='["com.aidentity.test.electron"]')" \
  "$(tr_entry main='"yes"')" \
  "$(tr_entry main='1')" \
  "$(tr_entry badge='5')" \
  "$(tr_entry color='true')" \
  "$(tr_entry args='"--lang=de"')" \
  "$(tr_entry args='[1]')" \
  "$(tr_entry env='{"LANG":"de_DE.UTF-8"}')" \
  "$(tr_entry own_extensions='"true"')" \
  "$(tr_entry own_extensions=true)" \
  "$(tr_entry profile='"Mainext"' main=true own_extensions=true bundle_id='"com.example.codey"')" \
  "$(tr_entry args="[$(i=0; while [ "$i" -le 32 ]; do printf '"--lang=de",'; i=$((i + 1)); done)\"--lang=de\"]")" \
  '{"bundle_id":"com.aidentity.test.electron"}' \
  '{"profile":"Nobundle"}'
before=$(fingerprint "$APPS")
tx import "$TR_F" -y
assert_rc "entries of the wrong type: the import exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "every one is skipped" "17" "$(lines_with "$RUN_OUT" "^  skip    ")"
assert_eq "and nothing is built" "$before" "$(fingerprint "$APPS")"
for why in "entry 1 — not a launcher" "entry 2 — not a launcher" "no profile name" "no bundle_id" \
           "main is not true or false" "badge is not text" "color is not text" "args is not a list" \
           "args holds something that is not text" "env is not a list" "own_extensions is not true or false" \
           "only applies to VS Code" "applies to profiles, not to the original account" \
           "args has more than 32 entries"; do
  assert_contains "skipped for its reason: $why" "$RUN_OUT" "$why"
done
assert_eq "main of the wrong type, both ways" "2" "$(lines_with "$RUN_OUT" "main is not true or false")"
assert_eq "a missing profile and a profile that is not text" "2" "$(lines_with "$RUN_OUT" "no profile name")"

# A value that ends in a line break is refused like any other line break: the
# file's own, not the one plutil adds to what it prints.
tr_file "$TR_F" \
  "$(tr_entry profile="$(js $'Tail\n')")" \
  "$(tr_entry profile='"Bid"' bundle_id="$(js $'com.aidentity.test.electron\n')")" \
  "$(tr_entry profile='"Argnl"' args="[$(js $'--lang=de\n')]")" \
  "$(tr_entry profile='"Envnl"' env="[$(js $'LANG=de_DE.UTF-8\n')]")"
before=$(fingerprint "$APPS")
tx import "$TR_F" -y
assert_eq "values that end in a line break: every one is skipped" "4" "$(lines_with "$RUN_OUT" "^  skip    ")"
assert_contains "a profile name" "$RUN_OUT" "Profile name may only contain"
assert_contains "a bundle ID" "$RUN_OUT" "skip    Fake Inj — bundle_id is not a bundle ID"
assert_contains "a switch" "$RUN_OUT" "skip    Fake Argnl — A switch cannot contain a tab, a line break"
assert_contains "a variable" "$RUN_OUT" "skip    Fake Envnl — An environment value cannot contain a tab, a line break"
assert_eq "and nothing is built" "$before" "$(fingerprint "$APPS")"

# A setting listed twice: add keeps only the last, so the plan would show one
# that is not built. The entry is skipped.
tr_file "$TR_F" \
  "$(tr_entry profile='"Twoarg"' args='["--lang=de","--disable-gpu","--lang=fr"]')" \
  "$(tr_entry profile='"Twoflag"' args='["--disable-gpu","--disable-gpu"]')" \
  "$(tr_entry profile='"Twoenv"' env='["TZ=UTC","LANG=de_DE.UTF-8","TZ=Europe/Berlin"]')" \
  "$(tr_entry profile='"Twocase"' env='["HTTPS_PROXY=http://a.example:1","https_proxy=http://a.example:1"]')"
before=$(fingerprint "$APPS")
tx import "$TR_F" -y
assert_contains "a switch listed twice: the entry is skipped" "$RUN_OUT" "skip    Fake Twoarg — args lists --lang twice"
assert_contains "a switch with no value too" "$RUN_OUT" "skip    Fake Twoflag — args lists --disable-gpu twice"
assert_contains "a variable listed twice too" "$RUN_OUT" "skip    Fake Twoenv — env lists TZ twice"
assert_contains "two variables whose names differ in case are two variables" "$RUN_OUT" "create  Fake Twocase"
assert_contains "so only that one is built" "$RUN_OUT" "1 created, 3 skipped, 0 failed."
assert_not_contains "a value is never printed" "$RUN_OUT" "Europe/Berlin"
tx rm "Fake Twocase" --purge -y
assert_eq "and nothing else is built" "$before" "$(fingerprint "$APPS")"

# A badge is one character, add's rule: the first of what is given. One that
# cannot be drawn (a control character, a line break) is refused.
tr_file "$TR_F" \
  "$(tr_entry profile='"Dollar"' badge="$(js '$(touch '"$TR_PWN"')')")" \
  "$(tr_entry profile='"Quote"' badge="$(js '" /><key>x</key><string>y</string><!--')")" \
  "$(tr_entry profile='"Tick"' badge="$(js '`touch '"$TR_PWN"'`')")" \
  "$(tr_entry profile='"Esc"' badge="$(js $'\033[31m')")" \
  "$(tr_entry profile='"Csi"' badge="$(js $'\xc2\x9b31m')")" \
  "$(tr_entry profile='"Newline"' badge="$(js $'\nX')")" \
  "$(tr_entry profile='"Linesep"' badge="$(js $'\xe2\x80\xa8')")" \
  "$(tr_entry profile='"Parasep"' badge="$(js $'\xe2\x80\xa9X')")"
tx import "$TR_F" -y
assert_eq "a badge of \$( ) is just the character \$" '$' "$(plist_key "$APPS/Fake Dollar.app" AIdentityBadge)"
assert_eq "a badge of XML is just a quote" '"' "$(plist_key "$APPS/Fake Quote.app" AIdentityBadge)"
assert_eq "a badge of backticks is just a backtick" '`' "$(plist_key "$APPS/Fake Tick.app" AIdentityBadge)"
for l in "Fake Dollar" "Fake Quote" "Fake Tick"; do
  if plutil -lint "$APPS/$l.app/Contents/Info.plist" >/dev/null 2>&1; then
    _pass "$l: the Info.plist is well formed"
  else
    _fail "$l: the Info.plist is well formed" "plutil rejected it"
  fi
done
assert_eq "a control character, a C1 control, a line break or a line or paragraph separator is refused" "5" \
  "$(lines_with "$RUN_OUT" "the badge is not a character that can be drawn")"
assert_no_dir "a separator, which draws nothing, gets no launcher" "$APPS/Fake Linesep.app"
assert_no_file "no injected command ran" "$TR_PWN"
for l in "Fake Dollar" "Fake Quote" "Fake Tick"; do tx rm "$l" --purge -y; done

# The name in the file is only printed, and only as text.
tr_file "$TR_F" "$(tr_entry name="$(js $'Red \033[31m name')" bundle_id='"com.example.nothere"')"
tx import "$TR_F" -y
assert_contains "a name with an escape in it is shown with ? for it" "$RUN_OUT" "skip    Red ?[31m name"
assert_not_contains "so no escape reaches the terminal" "$RUN_OUT" $'\033'

# The same for an escape and a C1 control, U+009B, which some terminals read
# as the start of an escape sequence, in a name and in a colour. Under C,
# [[:cntrl:]] misses U+009B, so this runs under C and under UTF-8.
TR_ESC=$'\033'; TR_CSI=$'\xc2\x9b'; TR_RLO=$'\xe2\x80\xae'
tr_file "$TR_F" \
  "$(tr_entry name="$(js "Red ${TR_ESC}[31m ${TR_CSI}31m ${TR_RLO}eman name")" bundle_id='"com.example.nothere"')" \
  "$(tr_entry profile='"Paint"' color="$(js "re${TR_ESC}[31md${TR_CSI}31m")")"
for loc in C en_US.UTF-8; do
  LC_ALL=$loc tx import "$TR_F" -y
  assert_contains "$loc: a name with ESC, U+009B and a right-to-left override is shown with ? for each" "$RUN_OUT" \
    "skip    Red ?[31m ?31m ?eman name"
  assert_contains "$loc: and so is such a colour" "$RUN_OUT" \
    "skip    Fake Paint — unknown colour 're?[31md?31m'"
  assert_not_contains "$loc: no ESC reaches the terminal" "$RUN_OUT" "$TR_ESC"
  assert_not_contains "$loc: and no U+009B" "$RUN_OUT" "$TR_CSI"
  assert_not_contains "$loc: and no override that turns the text around" "$RUN_OUT" "$TR_RLO"
done
assert_no_dir "and nothing is built" "$APPS/Fake Paint.app"

# name, app and exported_by are only for the person reading the file: each
# injection attempt in them, and a printf format, is only text.
TR_ENTRIES=()
for v in "${TR_INJ[@]}" 'Fmt %s%n%s%n'; do
  TR_ENTRIES+=("$(tr_entry name="$(js "$v")" app="$(js "$v")" bundle_id='"com.example.nothere"')")
done
printf '{"aidentity_export": 1, "exported_by": %s, "launchers": [%s]}\n' \
  "$(js "$(printf '%s ' "${TR_INJ[@]}")%s%n")" "$(IFS=,; printf '%s' "${TR_ENTRIES[*]}")" > "$TR_F"
before=$(fingerprint "$APPS")
tx import "$TR_F" -y
assert_rc "injection attempts in name, app and exported_by: the import exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "every entry is skipped, as its app is not installed" "8" \
  "$(lines_with "$RUN_OUT" "no app with the bundle ID com.example.nothere is installed")"
assert_contains "a format in a name is printed as it is" "$RUN_OUT" "skip    Fmt %s%n%s%n"
assert_contains "a line break in a name is shown as ?" "$RUN_OUT" "skip    Inj?two"
assert_eq "nothing is built" "$before" "$(fingerprint "$APPS")"
assert_no_file "no injected command ran" "$TR_PWN"
assert_not_contains "no escape reaches the terminal" "$RUN_OUT" $'\033'

# What the file leaves out, add decides: the first letter and the colour add
# would pick. An empty badge is no badge.
tr_file "$TR_F" '{"bundle_id":"com.aidentity.test.electron","profile":"Bare"}' \
  "$(tr_entry profile='"Nobadge"' badge='""')"
tx import "$TR_F" -y
assert_rc "an entry with only a bundle ID and a profile is built" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "with the default badge" "B" "$(plist_key "$APPS/Fake Bare.app" AIdentityBadge)"
libcall eval 'color_hex "$(auto_color "Fake Bare")"'
assert_eq "and the default colour" "$RUN_OUT" "$(plist_key "$APPS/Fake Bare.app" AIdentityColor)"
assert_eq "an empty badge is no badge" "" "$(plist_key "$APPS/Fake Nobadge.app" AIdentityBadge)"
tx rm "Fake Bare" --purge -y
tx rm "Fake Nobadge" --purge -y
tr_tmp_gone "every one of these imports"


group "import: entries that clash with each other"

tr_file "$TR_F" \
  "$(tr_entry profile='"Twice"')" "$(tr_entry profile='"Twice"' color='"red"')" \
  "$(tr_entry profile='"Same 2"')" "$(tr_entry profile='"Same_2"')" \
  "$(tr_entry profile='"Main"' main=true bundle_id='"com.example.codey"')" \
  "$(tr_entry profile='"Orig"' main=true bundle_id='"com.example.codey"')"
tx import "$TR_F" -y
assert_rc "an import with clashing entries exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "the same launcher twice: the second is skipped" "$RUN_OUT" \
  "skip    Fake Twice — listed twice in the file"
assert_eq "and the first is built as it says" "2E7DF6" "$(plist_key "$APPS/Fake Twice.app" AIdentityColor)"
assert_contains "two that would share a profile folder: the second is skipped" "$RUN_OUT" \
  "skip    Fake Same_2 — would share a profile folder with Fake Same 2"
assert_contains "two main launchers for one app: the second is skipped" "$RUN_OUT" \
  "skip    Codey Orig — another entry opens the original account"
assert_contains "the first ones are built" "$RUN_OUT" "3 created, 3 skipped, 0 failed."
for l in "Fake Twice" "Fake Same 2" "Codey Main"; do tx rm "$l" --purge -y; done

# The launcher folder ignores case, so two names that differ only in case
# are one launcher: the plan skips the second, here a main launcher, which
# has no profile folder to compare.
tr_file "$TR_F" "$(tr_entry profile='"Case"')" "$(tr_entry profile='"case"' main=true)"
tx import "$TR_F" -y
assert_contains "two names that differ only in case: the second is skipped in the plan" "$RUN_OUT" \
  "skip    Fake case — listed twice in the file"
assert_contains "and the first is built" "$RUN_OUT" "1 created, 1 skipped, 0 failed."
tx rm "Fake Case" --purge -y

# A launcher here whose profile folder the entry would share: create_profile
# would refuse it, so the plan skips it, and the rest are built.
tx add "$ELECTRON_APP" --profile "Work 2"
tr_file "$TR_F" "$(tr_entry profile='"Work_2"')" "$(tr_entry profile='"Fine"')"
tx import "$TR_F" -y
assert_rc "an entry that would share an existing launcher's folder: the import exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "it is skipped, with the launcher named" "$RUN_OUT" \
  "skip    Fake Work_2 — would share a profile folder with 'Fake Work 2'"
assert_not_contains "the plan does not say the folder is used" "$RUN_OUT" "is here already"
assert_contains "the rest are built" "$RUN_OUT" "1 created, 1 skipped, 0 failed."
assert_no_dir "and it is not" "$APPS/Fake Work_2.app"
tx rm "Fake Fine" --purge -y
# A launcher filed into a folder shares the folder just the same.
mkdir -p "$APPS/Filed"
mv "$APPS/Fake Work 2.app" "$APPS/Filed/"
tr_file "$TR_F" "$(tr_entry profile='"Work_2"')"
tx import "$TR_F" -y
assert_contains "a launcher filed into a folder is found too, named by its path" "$RUN_OUT" \
  "would share a profile folder with '$APPS/Filed/Fake Work 2.app'"
assert_no_dir "and nothing is built" "$APPS/Fake Work_2.app"
mv "$APPS/Filed/Fake Work 2.app" "$APPS/"
rmdir "$APPS/Filed"
# The same folder reached by another path: the data root through a link.
ln -s "$VSC_DATA" "$SANDBOX/v-link"
tr_file "$TR_F" "$(tr_entry profile='"Work-2"')"
TMPDIR="$TR_TMP" AIDENTITY_DATA_ROOT="$SANDBOX/v-link" ai import "$TR_F" -y
assert_contains "the same folder spelled another way is found too" "$RUN_OUT" \
  "skip    Fake Work-2 — would share a profile folder with 'Fake Work 2'"
rm -f "$SANDBOX/v-link"
tx rm "Fake Work 2" --purge -y

# A VS Code-style app makes a socket in the profile folder, and macOS caps the
# length of its path: add refuses a profile that would go past it, and so does
# the plan.
tr_file "$TR_F" "$(tr_entry profile="\"$(repeat_char 40 a)\"" bundle_id='"com.example.codey"')" \
  "$(tr_entry profile="\"$(repeat_char 40 b)\"")"
TMPDIR="$TR_TMP" AIDENTITY_DATA_ROOT="$VSC_DATA/$(repeat_char 40 d)" ai import "$TR_F" -y
assert_rc "a profile folder too deep for a VS Code-style app: the import exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "it is skipped" "$RUN_OUT" \
  "skip    Codey $(repeat_char 40 a) — Codey cannot open 'Codey $(repeat_char 40 a)': its profile folder path is too long."
assert_contains "another app's profile there is built" "$RUN_OUT" "1 created, 1 skipped, 0 failed."
assert_no_dir "no launcher is left for the skipped one" "$APPS/Codey $(repeat_char 40 a).app"
TMPDIR="$TR_TMP" AIDENTITY_DATA_ROOT="$VSC_DATA/$(repeat_char 40 d)" ai rm "Fake $(repeat_char 40 b)" --purge -y
rm -rf "${VSC_DATA:?}/$(repeat_char 40 d)"

# The closing hint names a new profile, never a main launcher: that opens the
# app's own account, which is signed in already.
tr_file "$TR_F" "$(tr_entry profile='"Main"' main=true bundle_id='"com.example.codey"')" \
  "$(tr_entry profile='"Hinted"')"
tx import "$TR_F" -y
assert_contains "the hint names the first new profile" "$RUN_OUT" \
  "Open each new profile to sign in, e.g.:  aidentity open \"Fake Hinted\""
tx rm "Fake Hinted" --purge -y
tx rm "Codey Main" -y
tr_file "$TR_F" "$(tr_entry profile='"Main"' main=true bundle_id='"com.example.codey"')"
tx import "$TR_F" -y
assert_contains "a main launcher alone is built" "$RUN_OUT" "1 created, 0 skipped, 0 failed."
assert_not_contains "with no hint to sign in" "$RUN_OUT" "Open each new profile"
tx rm "Codey Main" -y

# A profile folder that is there already is used, as add uses it: the plan says
# so, because that profile may be signed in.
mkdir -p "$VSC_DATA/fake-again"
printf 'session\n' > "$VSC_DATA/fake-again/Cookies"
tr_file "$TR_F" "$(tr_entry profile='"Again"')"
tx import "$TR_F" -y
assert_contains "the plan says the folder is there" "$RUN_OUT" \
  "create  Fake Again — its profile folder is here already, and is used"
assert_file "and it is kept" "$VSC_DATA/fake-again/Cookies"
tx rm "Fake Again" --purge -y


group "import: files that are refused whole"

tr_refused_file() { # description, text the message holds, then the import's arguments
  local desc="$1" msg="$2" before
  shift 2
  before="$(fingerprint "$APPS")|$(fingerprint "$VSC_DATA")"
  tx import "$@"
  assert_rc_nonzero "$desc is refused" "$RUN_RC" "$RUN_OUT"
  assert_contains "$desc: the message says why" "$RUN_OUT" "$msg"
  assert_eq "$desc: nothing is written" "$before" "$(fingerprint "$APPS")|$(fingerprint "$VSC_DATA")"
  tr_tmp_gone "$desc"
}
printf '{"aidentity_export": 1, "launchers": [' > "$TR_F"
tr_refused_file "malformed JSON" "is not valid JSON" "$TR_F" -y
printf '{"aidentity_export": 1, "exported_by": null, "launchers": [%s]}\n' "$(tr_entry profile='"Nul"')" > "$TR_F"
tr_refused_file "a file with a null in it" "it holds a null" "$TR_F" -y
printf '{"aidentity_export": 1, "launchers": [%s]}\n' "$(tr_entry profile=null)" > "$TR_F"
tr_refused_file "a null in an entry" "it holds a null" "$TR_F" -y
: > "$TR_F"
tr_refused_file "an empty file" "is not valid JSON" "$TR_F" -y
printf '{"aidentity_export": 2, "launchers": [%s]}\n' "$(tr_entry profile='"Two"')" > "$TR_F"
tr_refused_file "format 2" "is in export format 2, and this aidentity reads format 1" "$TR_F" -y
for fmt in '"1"' '1.5' 'true' '[1]'; do
  printf '{"aidentity_export": %s, "launchers": [%s]}\n' "$fmt" "$(tr_entry profile='"Fmt"')" > "$TR_F"
  tr_refused_file "a format number of $fmt" "is not a file made by 'aidentity export'" "$TR_F" -y
done
printf '{"launchers": [%s]}\n' "$(tr_entry profile='"Nofmt"')" > "$TR_F"
tr_refused_file "a file with no format number" "is not a file made by 'aidentity export'" "$TR_F" -y
printf '[%s]\n' "$(tr_entry profile='"Arr"')" > "$TR_F"
tr_refused_file "a list instead of an export" "is not a file made by 'aidentity export'" "$TR_F" -y
printf '{"aidentity_export": 1, "launchers": %s}\n' "$(tr_entry profile='"Obj"')" > "$TR_F"
tr_refused_file "launchers that are not a list" "has no list of launchers" "$TR_F" -y
# The shell cannot hold a NUL: a text with one in it would end there.
printf '{"aidentity_export": 1, "launchers": [%s]}\n' "$(tr_entry profile='"Nul\u0000char"')" > "$TR_F"
tr_refused_file "a NUL character in a text" "is not valid JSON" "$TR_F" -y

# The file is JSON and nothing else. plutil reads binary and XML property
# lists too, and expands a binary one that shares its parts without bound, so
# a property list is refused before anything reads it, even one that holds
# an export.
TR_SRC="$SB/plist-src.json"
tr_file "$TR_SRC" "$(tr_entry profile='"Plist"')"
/usr/bin/plutil -convert binary1 -o "$TR_F" "$TR_SRC"
tr_refused_file "a binary property list" "is not valid JSON" "$TR_F" -y
/usr/bin/plutil -convert xml1 -o "$TR_F" "$TR_SRC"
tr_refused_file "an XML property list" "is not valid JSON" "$TR_F" -y
printf '{ aidentity_export = 1; launchers = ( { bundle_id = com.aidentity.test.electron; profile = Plist; } ); }\n' > "$TR_F"
tr_refused_file "an OpenStep property list" "is not valid JSON" "$TR_F" -y
tx import "$TR_SRC" -y
assert_contains "the same export as JSON is read" "$RUN_OUT" "1 created, 0 skipped, 0 failed."
tx rm "Fake Plist" --purge -y
rm -f "$TR_SRC"
printf '{"aidentity_export": 1}\n' > "$TR_F"
tr_refused_file "no launchers at all" "has no list of launchers" "$TR_F" -y

TR_MANY=()
i=0
while [ "$i" -lt 201 ]; do TR_MANY+=(1); i=$((i + 1)); done
tr_file "$TR_F" "${TR_MANY[@]}"
tr_refused_file "201 entries" "lists 201 launchers; import reads at most 200" "$TR_F" -y
tr_file "$TR_F" "${TR_MANY[@]:1}"
tx import "$TR_F" -y
assert_rc "200 entries are read" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "every one of them" "200" "$(lines_with "$RUN_OUT" "— not a launcher")"

{ printf '{"aidentity_export": 1, "launchers": [], "pad": "'
  head -c 4194304 /dev/zero | tr '\0' x
  printf '"}\n'; } > "$TR_F"
tr_refused_file "a file over 4 MB" "is bigger than 4 MB" "$TR_F" -y
rm -f "$TR_F"

# Only the first 4 MB are ever read: a file that does not end is refused, and
# what feeds it is stopped by the closed pipe, long before it is done.
TR_FIFO="$SB/endless.json"
mkfifo "$TR_FIFO"
{ head -c 67108864 /dev/zero; printf '%s' "$?" > "$SB/writer.rc"; } > "$TR_FIFO" 2>/dev/null &
TR_WRITER=$!
tx import "$TR_FIFO" -y
w=0
while kill -0 "$TR_WRITER" 2>/dev/null && [ "$w" -lt 100 ]; do sleep 0.1; w=$((w + 1)); done
# Still there only if the import never opened the file: stop that writer.
kill "$TR_WRITER" 2>/dev/null
wait "$TR_WRITER" 2>/dev/null
assert_contains "a file that does not end is refused" "$RUN_OUT" "is bigger than 4 MB"
assert_eq "and read no further than the limit" "stopped" \
  "$(rc=$(cat "$SB/writer.rc" 2>/dev/null); if [ -n "$rc" ] && [ "$rc" -ne 0 ]; then echo stopped; else echo "writer rc '$rc'"; fi)"
rm -f "$TR_FIFO" "$SB/writer.rc"
tr_tmp_gone "a file that does not end"

# The file is read once. A file near the size limit, its entries full of
# settings, takes seconds: read a value at a time, it took minutes.
TR_ARGS='["--lang=de","--locale=de-DE","--disable-gpu","--disable-lcd-text","--force-device-scale-factor=1.25","--proxy-server=http://p.example:8080","--proxy-bypass-list=localhost"]'
TR_ENV='["HTTP_PROXY=http://p.example:1","HTTPS_PROXY=http://p.example:2","ALL_PROXY=socks5://p.example:3","NO_PROXY=localhost","http_proxy=http://p.example:1","https_proxy=http://p.example:2","all_proxy=socks5://p.example:3","no_proxy=localhost","LANG=de_DE.UTF-8","LC_ALL=de_DE.UTF-8","LC_CTYPE=de_DE.UTF-8","LC_MESSAGES=de_DE.UTF-8","TZ=Europe/Berlin"]'
TR_ENTRIES=()
i=0
while [ "$i" -lt 20 ]; do
  TR_ENTRIES+=("$(tr_entry profile="\"Full $i\"" args="$TR_ARGS" env="$TR_ENV")")
  i=$((i + 1))
done
{ printf '{"aidentity_export": 1, "launchers": [%s], "pad": [' "$(IFS=,; printf '%s' "${TR_ENTRIES[*]}")"
  yes 1 | head -n 1700000 | paste -sd, -
  printf ']}\n'; } > "$TR_F"
TR_T0=$SECONDS
tx import "$TR_F"
TR_DT=$((SECONDS - TR_T0))
assert_eq "a full file near the size limit: every entry is planned" "20" "$(lines_with "$RUN_OUT" "^  create  Fake Full")"
assert_eq "in seconds" "quick" \
  "$(if [ "$TR_DT" -le 20 ]; then echo quick; else echo "took $TR_DT s"; fi)"
rm -f "$TR_F"
tr_tmp_gone "a full file"

tr_refused_file "a file that is not there" "Cannot read" "$SB/no-such.json" -y
tr_refused_file "a folder" "Cannot read" "$SB" -y
tr_refused_file "no file" "Usage: aidentity import FILE" -y
tr_refused_file "an option import does not take" "Unknown option for import: --force" "$TR_FILE" --force
tr_refused_file "two files" "Unexpected argument" "$TR_FILE" "$TR_FILE"

tr_file "$TR_F"
tx import "$TR_F" -y
assert_rc "an export with no launchers is fine" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "and says there is nothing to do" "$RUN_OUT" "lists no launchers"


group "import: the plan shows the proxy server"

# A proxy variable sends the profile's traffic through the server it names,
# so the plan shows that server: the scheme, host and port a client would
# use. Never a user name or password, nor a path. Other variables by name.
tr_file "$TR_F" \
  "$(tr_entry profile='"Px"' env='["HTTPS_PROXY=http://user:hunter2@attacker.example:8080/x","ALL_PROXY=socks5://attacker.example:1080","NO_PROXY=localhost,.example.com","LANG=de_DE.UTF-8"]')" \
  "$(tr_entry profile='"Px2"' env='["http_proxy=user:hunter2@attacker.example:3128"]')" \
  "$(tr_entry profile='"Px3"' env='["HTTP_PROXY=http://attacker.example:8080/@innocent.example"]')" \
  "$(tr_entry profile='"Px4"' env='["HTTP_PROXY=user:hunter2@x://innocent.example"]')"
before=$(fingerprint "$APPS")
tx import "$TR_F"
assert_contains "each proxy variable's server is shown: scheme, host and port" "$RUN_OUT" "  create  Fake Px
          proxy  HTTPS_PROXY=http://***@attacker.example:8080 ALL_PROXY=socks5://attacker.example:1080
          env    NO_PROXY LANG (values hidden)"
assert_contains "a server with no scheme" "$RUN_OUT" "proxy  http_proxy=***@attacker.example:3128"
assert_contains "the host a client connects to, not one after an @ in the path" "$RUN_OUT" \
  "proxy  HTTP_PROXY=http://attacker.example:8080"
assert_contains "a value that is not a URL: what comes before the @ is hidden all the same" "$RUN_OUT" \
  "proxy  HTTP_PROXY=***@x:"
assert_not_contains "never a password" "$RUN_OUT" "hunter2"
assert_not_contains "nor a path" "$RUN_OUT" "innocent"
assert_not_contains "nor the value of a variable that is not a proxy" "$RUN_OUT" "de_DE"
assert_eq "nothing is built before the question" "$before" "$(fingerprint "$APPS")"
tr_tmp_gone "a plan with proxy servers"


group "import: the confirmation"

tr_file "$TR_F" "$(tr_entry profile='"Ask"')" "$(tr_entry profile='"Ask"')"
tr_refused_file "with no terminal and no -y, it" "Nothing to confirm with" "$TR_F"
assert_contains "the plan is shown first" "$RUN_OUT" "create  Fake Ask"
assert_contains "with what is skipped and why" "$RUN_OUT" "skip    Fake Ask — listed twice in the file"
assert_contains "and the question" "$RUN_OUT" "Create 1 launcher? Type yes to confirm:"
tx_in no import "$TR_F"
assert_rc_nonzero "answering no cancels" "$RUN_RC" "$RUN_OUT"
assert_contains "and says so" "$RUN_OUT" "Cancelled. Nothing was created."
assert_no_dir "and builds nothing" "$APPS/Fake Ask.app"
tx_in yes import "$TR_F"
assert_rc "answering yes builds it" 0 "$RUN_RC" "$RUN_OUT"
assert_dir "the launcher is there" "$APPS/Fake Ask.app"
tx rm "Fake Ask" --purge -y

# A launcher made between the plan and the answer is skipped, never changed.
# The answer comes from a pipe: it waits for the question, makes the launcher
# with add, then types yes.
tr_file "$TR_F" "$(tr_entry profile='"Race"' badge='"Z"' color='"red"')"
TR_OUT="$SB/race.out"
: > "$TR_OUT"
# SC2094: the left side reads the file the import writes on purpose, to see
# the question before it answers.
# shellcheck disable=SC2094
{ w=0
  while ! grep -q "Type yes to confirm" "$TR_OUT" && [ "$w" -lt 300 ]; do sleep 0.1; w=$((w + 1)); done
  tx add "$ELECTRON_APP" --profile Race
  printf 'yes\n'
} | TMPDIR="$TR_TMP" AIDENTITY_DATA_ROOT="$VSC_DATA" detached "$BASH_BIN" "$AIDENTITY" import "$TR_F" > "$TR_OUT" 2>&1
RUN_RC=${PIPESTATUS[1]}
RUN_OUT=$(cat "$TR_OUT")
assert_rc "a launcher made while the question waits: the import exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "the plan said create" "$RUN_OUT" "create  Fake Race"
assert_contains "the build skips it" "$RUN_OUT" "Skipped Fake Race: it exists now."
assert_contains "and counts it" "$RUN_OUT" "0 created, 1 skipped, 0 failed."
assert_eq "the launcher add made is not changed: its badge" "R" "$(plist_key "$APPS/Fake Race.app" AIdentityBadge)"
assert_not_contains "no hint to sign in, as nothing was created" "$RUN_OUT" "Open each new profile"
tx rm "Fake Race" --purge -y
rm -f "$TR_OUT"

# --help shows the help and imports nothing.
tx import "$TR_F" -y --help
assert_contains "import --help shows the help" "$RUN_OUT" "USAGE"
assert_no_dir "and imports nothing" "$APPS/Fake Ask.app"
tx_stdout export --help
assert_contains "export --help shows the help, not the file" "$RUN_OUT" "USAGE"


group "import: a build that fails"

tr_file "$TR_F" "$(tr_entry profile='"Locked"')"
chmod 500 "$APPS"
tx import "$TR_F" -y
chmod 700 "$APPS"
assert_rc_nonzero "import exits non-zero when a build fails" "$RUN_RC" "$RUN_OUT"
assert_contains "and says which" "$RUN_OUT" "Could not create Fake Locked."
assert_contains "and counts it" "$RUN_OUT" "0 created, 0 skipped, 1 failed."
assert_no_dir "no launcher is left" "$APPS/Fake Locked.app"
assert_no_dir "and no empty profile folder" "$VSC_DATA/fake-locked"
tr_tmp_gone "a failed import"

rm -rf "$CODEY" "$WEIRD"
rm -f "$TR_F"
assert_eq "this area leaves no profile data in the short folder either" "" "$(ls -A "$VSC_DATA")"
