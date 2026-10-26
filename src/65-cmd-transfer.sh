# ---------------------------------------------- commands: export, import --

# `export` prints every launcher's recipe as JSON, and `import` builds the
# launchers in such a file again, on this Mac or another. A recipe is what a
# launcher looks like and how it starts: its app (by bundle ID), the profile
# name, the badge, the colour and the launch settings. Never a data folder or
# any other path, so no account goes with the file: an imported profile starts
# signed out, unless a folder of its name is still in the data root. Format 1
# is the only one so far; import refuses any other.
EXPORT_FORMAT=1

# What import reads is capped, because the file may come from someone else.
# Up to 200 launchers, each with at most 32 switches and 32 variables (far
# more than the allowlists hold, so an export has fewer), each switch or
# variable at most 1024 characters (a proxy value, the longest allowed, is
# at most 512), and 4 MiB in all: 200 launchers with every proxy setting at
# its longest take less than half of that. The file is copied up to that size
# before anything parses it. The per-value cap keeps the checks quick: they
# take longer than linear time on a long value. The file is read once, as
# JSON only, and the launchers on this Mac are read once, so the plan is
# ready in seconds even at these limits.
IMPORT_MAX_LAUNCHERS=200
IMPORT_MAX_SETTINGS=32
IMPORT_MAX_VALUE=1024
IMPORT_MAX_BYTES=4194304

# The bundle ID of the app a launcher opens. When the app is gone, the one the
# profile folder's restore record kept. Empty when neither is known. A read
# that fails gives nothing: PlistBuddy prints its error, with the file's path,
# on stdout, and that must never reach the file.
export_bundle_id() { # app, data dir
  local bid=""
  [ -d "$1" ] && { bid=$(bundle_id "$1") || bid=""; }
  [ -z "$bid" ] && [ -n "$2" ] && { bid=$(record_get "$2" AIdentityTargetBundleID) || bid=""; }
  printf '%s' "$bid"
}

# `aidentity export`: one JSON object, written in one piece to stdout, with
# these keys for each launcher, in the order `list` shows them:
#   name            launcher name, for the person reading the file
#   app             the name of the app it opens, also only for reading
#   bundle_id       the app's bundle ID: import finds the app by this alone
#   profile         profile name
#   main            true for a launcher that opens the app's own account
#   badge           badge character; "" for the app's own icon
#   color           badge colour, six hex digits
#   args            launch switches, in full
#   env             launch variables, as NAME=value: values included
#   own_extensions  true when a VS Code-style app has its own extensions folder
# Every value is a string, a boolean or a list of strings, never null:
# import refuses a file with a null in it. Warnings go to stderr, so stdout is
# always the file. A proxy setting can carry a user name and password, in a
# variable's value or in a switch (user:password@host), so export warns when
# the file holds either.
cmd_export() {
  while [ $# -gt 0 ]; do
    case "$1" in
      -*) die "Unknown option for export: $1" ;;
      *) die "Unexpected argument: $1. export prints the file to the screen; save it with:
    aidentity export > profiles.json" ;;
    esac
  done
  local i=0 app target ex bid obj flag v secrets=0 creds=0 held=""
  launcher_rows
  printf '{"aidentity_export": %s, "exported_by": %s, "launchers": [' \
    "$EXPORT_FORMAT" "$(json_str "$AIDENTITY_VERSION")"
  while [ "$i" -lt "$LR_N" ]; do
    app=${LR_PATH[$i]}; target=${LR_TARGET[$i]}
    ex=$(extras_of "$app/Contents/Info.plist")
    bid=$(export_bundle_id "$target" "${LR_DATA[$i]}")
    if [ -z "$bid" ]; then
      shown v "${LR_NAME[$i]}"
      warn "'$v': its app is missing and no bundle ID is recorded, so import will skip it."
    fi
    while IFS= read -r v; do [ -n "$v" ] && secrets=$((secrets + 1)); done <<EOF
$(extras_lines env "$ex")
EOF
    while IFS= read -r v; do case "$v" in *@*) creds=$((creds + 1)) ;; esac; done <<EOF
$(extras_lines arg "$ex")
EOF
    obj="{\"name\":$(json_str "${LR_NAME[$i]}")"
    v=""
    [ -n "$target" ] && v=$(bundle_name "$target")
    obj="$obj,\"app\":$(json_str "$v")"
    obj="$obj,\"bundle_id\":$(json_str "$bid")"
    obj="$obj,\"profile\":$(json_str "${LR_PROFILE[$i]}")"
    flag=false
    [ "${LR_MAIN[$i]}" = "1" ] && flag=true
    obj="$obj,\"main\":$flag"
    obj="$obj,\"badge\":$(json_str "$(launcher_badge "$app" "$target" "${LR_PROFILE[$i]}")")"
    obj="$obj,\"color\":$(json_str "$(launcher_color "$app" "${LR_NAME[$i]}")")"
    obj="$obj,\"args\":$(json_lines "$(extras_lines arg "$ex")")"
    obj="$obj,\"env\":$(json_lines "$(extras_lines env "$ex")")"
    flag=false
    [ -n "$(extras_lines ext "$ex")" ] && flag=true
    obj="$obj,\"own_extensions\":$flag}"
    [ "$i" -eq 0 ] || printf ','
    printf '\n  %s' "$obj"
    i=$((i + 1))
  done
  [ "$LR_N" -eq 0 ] || printf '\n'
  printf ']}\n'
  [ "$secrets" -gt 0 ] && held="the values of $(count "$secrets" "launch variable")"
  if [ "$creds" -eq 1 ]; then
    held="${held:+$held, and }a launch switch with a user name or password in it"
  elif [ "$creds" -gt 1 ]; then
    held="${held:+$held, and }$creds launch switches with a user name or password in them"
  fi
  if [ -n "$held" ]; then
    warn "The file holds $held. A proxy setting can
    carry a password: keep the file private."
  fi
  return 0
}

# Read the copied file in one go, with the JavaScript engine that ships with
# macOS. JSON.parse reads JSON and nothing else: a binary or XML property
# list is refused at its first byte, and nothing is converted (plutil reads
# both, and can expand a small binary one without bound). A null is refused,
# as export never writes one, and so is a NUL character in a text, which the
# shell cannot hold, or a text that is not valid Unicode, which cannot be
# written out. The keys import reads are written out as records, one file
# for the top of the file (top) and one per entry (e0, e1 ...), each record
# "key path<TAB>type<TAB>value" and a NUL. The value is the text, true or
# false, the number, or a list's length. Only the keys below are written, in
# the order import reads them, and the items of a list only when there are
# few enough, so what is written is never much bigger than the file. Prints
# ok, or json for a file that is not one.
import_read() { # file, folder for the records
  /usr/bin/osascript -l JavaScript - "$1" "$2" "$IMPORT_MAX_LAUNCHERS" "$IMPORT_MAX_SETTINGS" \
    2>/dev/null <<'JXA'
ObjC.import("Foundation");
function run(argv) {
  var text = $.NSString.stringWithContentsOfFileEncodingError(argv[0], $.NSUTF8StringEncoding, null);
  if (text.isNil()) return "json";
  var d, todo, v, i;
  try { d = JSON.parse(text.js); } catch (e) { return "json"; }
  function has(o, k) { return Object.prototype.hasOwnProperty.call(o, k); }
  // Every value, without recursion, which a deep file could exhaust. A
  // reviver function in JSON.parse would do the same with four times the
  // memory.
  todo = [d];
  while (todo.length > 0) {
    v = todo.pop();
    if (v === null || (typeof v === "string" && v.indexOf("\0") !== -1)) return "json";
    if (Array.isArray(v)) { for (i = 0; i < v.length; i++) todo.push(v[i]); }
    else if (typeof v === "object") { for (i in v) if (has(v, i)) todo.push(v[i]); }
  }
  var recs = [], keys = ["name", "profile", "bundle_id", "main", "badge", "color", "args", "env", "own_extensions"];
  function isDict(v) { return typeof v === "object" && v !== null && !Array.isArray(v); }
  function put(path, v) {
    var t = "dictionary", s = "";
    if (typeof v === "string") { t = "string"; s = v; }
    else if (typeof v === "boolean") { t = "bool"; s = String(v); }
    else if (typeof v === "number") { t = Number.isSafeInteger(v) ? "integer" : "real"; s = String(v); }
    else if (Array.isArray(v)) { t = "array"; s = String(v.length); }
    recs.push(path + "\t" + t + "\t" + s + "\0");
  }
  function save(name) {
    var ok = $(recs.join("")).writeToFileAtomicallyEncodingError(argv[1] + "/" + name, false, $.NSUTF8StringEncoding, null);
    recs = [];
    return ok;
  }
  var list = [];
  if (isDict(d)) {
    if (has(d, "aidentity_export")) put("aidentity_export", d.aidentity_export);
    if (has(d, "launchers")) put("launchers", d.launchers);
    if (Array.isArray(d.launchers) && d.launchers.length <= Number(argv[2])) list = d.launchers;
  }
  if (!save("top")) return "json";
  for (i = 0; i < list.length; i++) {
    var e = list[i], k = "launchers." + i;
    put(k, e);
    if (isDict(e)) {
      keys.forEach(function (key) {
        if (!has(e, key)) return;
        put(k + "." + key, e[key]);
        if ((key === "args" || key === "env") && Array.isArray(e[key]) && e[key].length <= Number(argv[3])) {
          e[key].forEach(function (v, j) { put(k + "." + key + "." + j, v); });
        }
      });
    }
    if (!save("e" + i)) return "json";
  }
  return "ok";
}
JXA
}

# The records import_read wrote for the top of the file or for one entry,
# into IMPORT_KEYS, IMPORT_TYPES and IMPORT_VALS, for import_value.
import_records() { # records file
  local rec rest
  IMPORT_KEYS=(); IMPORT_TYPES=(); IMPORT_VALS=(); IMPORT_NEXT=0
  while IFS= read -r -d '' rec; do
    IMPORT_KEYS[${#IMPORT_KEYS[@]}]=${rec%%"$TAB"*}
    rest=${rec#*"$TAB"}
    IMPORT_TYPES[${#IMPORT_TYPES[@]}]=${rest%%"$TAB"*}
    IMPORT_VALS[${#IMPORT_VALS[@]}]=${rest#*"$TAB"}
  done < "$1"
  return 0
}

# The value at a key path, into IV, when it has the type asked for. Returns 1
# when there is nothing at that path, and 2 when there is something of
# another type. The records are in the order import asks for them, so the
# search starts after the last one found, and goes round once.
import_value() { # key path, type
  local i=$IMPORT_NEXT left=${#IMPORT_KEYS[@]}
  IV=""
  while [ "$left" -gt 0 ]; do
    [ "$i" -lt "${#IMPORT_KEYS[@]}" ] || i=0
    if [ "${IMPORT_KEYS[$i]}" = "$1" ]; then
      IMPORT_NEXT=$((i + 1))
      [ "${IMPORT_TYPES[$i]}" = "$2" ] || return 2
      IV=${IMPORT_VALS[$i]}
      return 0
    fi
    i=$((i + 1)); left=$((left - 1))
  done
  return 1
}

# Run a check quietly. When it refuses, its first line goes into E_WHY, made
# safe to print. Only the first line: the lines after it can repeat the value,
# and the value came from the file. A list of allowed values is left out. The
# check runs in this shell, not a subshell, as it runs for every value: each
# one only warns and returns, and never exits.
import_check() { # check, then its arguments
  local out=""
  "$@" 2>"$IMPORT_TMP/why" >/dev/null && return 0
  IFS= read -r out < "$IMPORT_TMP/why"
  out=${out#*"!$C_RESET "}
  shown E_WHY "${out%%. Allowed:*}"
  return 1
}

# The installed app with this bundle ID, into IMPORT_FOUND, and its name into
# IMPORT_FOUND_NAME. Only the apps that `apps` lists are looked at: a path in
# the file is never used. They are read once, into cmd_import's own
# variables.
import_find_app() { # bundle id
  local a i=0
  if [ "$IMPORT_SCANNED" -eq 0 ]; then
    IMPORT_SCANNED=1
    while IFS= read -r a; do
      [ -n "$a" ] || continue
      IMPORT_APPS[${#IMPORT_APPS[@]}]=$a
      IMPORT_IDS[${#IMPORT_IDS[@]}]=$(bundle_id "$a")
    done <<EOF
$(list_compatible_apps)
EOF
  fi
  while [ "$i" -lt "${#IMPORT_APPS[@]}" ]; do
    if [ "${IMPORT_IDS[$i]}" = "$1" ]; then
      [ -n "${IMPORT_NAMES[$i]:-}" ] || IMPORT_NAMES[i]=$(bundle_name "${IMPORT_APPS[$i]}")
      IMPORT_FOUND=${IMPORT_APPS[$i]}; IMPORT_FOUND_NAME=${IMPORT_NAMES[$i]}
      return 0
    fi
    i=$((i + 1))
  done
  return 1
}

# The launchers, other than the one named $1, that keep their profile in the
# folder $2, into IMPORT_OWNER: create_profile's test (launchers_sharing), so
# the plan skips what it would refuse. It matches as launchers_sharing does:
# the same text, or the same folder spelled another way, and a launcher by
# its name in the launcher folder, by its path anywhere else. Every launcher
# is found and read once, on the first call, into cmd_import's own
# variables: read again for each entry, the plan's time grew with the number
# of entries times the number of launchers. Nothing is built while the plan
# is made. When the search fails, every entry with a folder of its own is
# reported as one that might share, with IMPORT_OWNER empty.
import_folder_owner() { # launcher name, data dir
  local list app app_id d seen=" " id i=0
  if [ "$IMPORT_OWNERS_READ" -eq 0 ]; then
    IMPORT_OWNERS_READ=1
    list=$(all_launchers) || IMPORT_SEARCH_FAILED=1
    while IFS= read -r app; do
      [ -n "$app" ] || continue
      # One launcher can be found under two spellings: read it once.
      app_id=$(dir_id "$app") || continue
      case "$seen" in *" $app_id "*) continue ;; esac
      seen="$seen$app_id "
      d=$(plist_get "$app" AIdentityDataDir)
      [ -n "$d" ] || continue
      IMPORT_OWNER_APPS[${#IMPORT_OWNER_APPS[@]}]=$app
      IMPORT_OWNER_DIRS[${#IMPORT_OWNER_DIRS[@]}]=$d
      IMPORT_OWNER_IDS[${#IMPORT_OWNER_IDS[@]}]=$(dir_id "$d")
      [ "${app%/*}" = "$APPS_DIR" ] && app=$(bundle_name "$app")
      IMPORT_OWNER_NAMES[${#IMPORT_OWNER_NAMES[@]}]=$app
    done <<EOF
$list
EOF
  fi
  IMPORT_OWNER=""
  [ "$IMPORT_SEARCH_FAILED" -eq 0 ] || return 0
  id=$(dir_id "$2") || id=""
  while [ "$i" -lt "${#IMPORT_OWNER_APPS[@]}" ]; do
    if { [ "${IMPORT_OWNER_DIRS[$i]}" = "$2" ] || { [ -n "$id" ] && [ "${IMPORT_OWNER_IDS[$i]}" = "$id" ]; }; } \
       && [ ! "${IMPORT_OWNER_APPS[$i]}" -ef "$APPS_DIR/$1.app" ]; then
      IMPORT_OWNER="${IMPORT_OWNER:+$IMPORT_OWNER, }${IMPORT_OWNER_NAMES[$i]}"
    fi
    i=$((i + 1))
  done
  [ -n "$IMPORT_OWNER" ]
}

# A badge character that can be drawn: one that prints, in any locale. Under
# C, [[:cntrl:]] misses the C1 controls, which some terminals and fonts treat
# as the start of an escape sequence. The line and paragraph separators,
# U+2028 and U+2029, count as printing characters but draw nothing.
badge_drawable() {
  local LC_ALL=en_US.UTF-8
  case "$1" in ''|*[![:print:]]*|*$'\xe2\x80\xa8'*|*$'\xe2\x80\xa9'*) return 1 ;; esac
  return 0
}

# The switches (arg) or variables (env) an entry lists, each checked as add
# checks it, added to E_EXTRAS. A list that is not there is an empty one. A
# setting listed twice is refused: add keeps only the last of the two, so an
# export never holds one twice, and the plan would show one that is not
# built. It also caps the work: each check runs at most twice for each
# setting the allowlists hold, and some checks start other programs.
import_list() { # entry key path, key, kind, check
  local n i=0 rc=0 name names=" "
  import_value "$1.$2" array || rc=$?
  [ "$rc" -ne 1 ] || return 0
  [ "$rc" -eq 0 ] || { E_WHY="$2 is not a list"; return 1; }
  n=$IV
  [ "$n" -le "$IMPORT_MAX_SETTINGS" ] \
    || { E_WHY="$2 has more than $IMPORT_MAX_SETTINGS entries"; return 1; }
  while [ "$i" -lt "$n" ]; do
    import_value "$1.$2.$i" string || { E_WHY="$2 holds something that is not text"; return 1; }
    [ "${#IV}" -le "$IMPORT_MAX_VALUE" ] || { E_WHY="$2 has a value that is too long"; return 1; }
    if ! import_check "$4" "$IV"; then
      # A variable's value can be a password: never print it.
      if [ "$3" = env ]; then
        case "$E_WHY" in *"'$IV'"*) E_WHY="a variable must look like NAME=value" ;; esac
      fi
      return 1
    fi
    # The check passed, so the name is one from the allowlist.
    name=${IV%%=*}
    case "$names" in *" $name "*) E_WHY="$2 lists $name twice"; return 1 ;; esac
    names="$names$name "
    E_EXTRAS="${E_EXTRAS:+$E_EXTRAS
}$3$TAB$IV"
    i=$((i + 1))
  done
  return 0
}

# Read entry $1 of the file and check each value as add checks it on the
# command line. Sets the E_ variables of cmd_import for create_profile, and
# E_SHOW, the entry's name as it is printed, and E_SLUG, the name of a
# profile's folder. Returns 1, with the reason in E_WHY, for an entry to skip.
import_entry() { # index
  local k="launchers.$1" rc kind="" other dir
  E_SHOW="entry $(($1 + 1))"; E_WHY=""; E_APP=""; E_PROFILE=""; E_LABEL=""; E_SLUG=""
  E_MAIN=0; E_BADGE=""; E_NOBADGE=0; E_HEX=""; E_EXTRAS=""
  import_records "$IMPORT_TMP/e$1"
  import_value "$k" dictionary || { E_WHY="not a launcher"; return 1; }
  # The name in the file only says which entry this is, until the app is found.
  if import_value "$k.name" string && [ -n "$IV" ]; then shown E_SHOW "${IV:0:60}"; fi

  import_value "$k.profile" string || { E_WHY="no profile name"; return 1; }
  import_check validate_profile_name "$IV" || return 1
  E_PROFILE=$IV

  import_value "$k.bundle_id" string || { E_WHY="no bundle_id"; return 1; }
  if ! is_bundle_id "$IV" || [ "${#IV}" -gt 255 ]; then E_WHY="bundle_id is not a bundle ID"; return 1; fi
  import_find_app "$IV" || { E_WHY="no app with the bundle ID $IV is installed"; return 1; }
  E_APP=$IMPORT_FOUND
  # The name add would give it, whatever the file calls it.
  E_LABEL="$IMPORT_FOUND_NAME $E_PROFILE"
  shown E_SHOW "$E_LABEL"

  rc=0; import_value "$k.main" bool || rc=$?
  case "$rc" in
    0) [ "$IV" = true ] && E_MAIN=1 && kind=main ;;
    1) ;;
    *) E_WHY="main is not true or false"; return 1 ;;
  esac

  # Empty means no badge, and no badge key the profile's first letter, as on
  # add. Otherwise add's rule: the first character of what is given.
  rc=0; import_value "$k.badge" string || rc=$?
  case "$rc" in
    0) if [ -z "$IV" ]; then
         E_NOBADGE=1
       else
         E_BADGE=$(first_char "$IV")
         badge_drawable "$E_BADGE" || { E_WHY="the badge is not a character that can be drawn"; return 1; }
       fi ;;
    1) ;;
    *) E_WHY="badge is not text"; return 1 ;;
  esac

  # No colour key: the colour add would pick.
  rc=0; import_value "$k.color" string || rc=$?
  case "$rc" in
    0) E_HEX=$(color_hex "$IV") || { shown E_WHY "unknown colour '${IV:0:20}'"; return 1; } ;;
    1) ;;
    *) E_WHY="color is not text"; return 1 ;;
  esac

  import_list "$k" args arg validate_switch || return 1
  import_list "$k" env env validate_env || return 1
  rc=0; import_value "$k.own_extensions" bool || rc=$?
  case "$rc" in
    0) if [ "$IV" = true ]; then E_EXTRAS="${E_EXTRAS:+$E_EXTRAS
}ext${TAB}1"; fi ;;
    1) ;;
    *) E_WHY="own_extensions is not true or false"; return 1 ;;
  esac
  import_check validate_extras "$E_EXTRAS" "$E_APP" "$kind" || return 1

  # A launcher that exists is never changed. add would rebuild it.
  if [ -e "$APPS_DIR/$E_LABEL.app" ]; then E_WHY="already exists"; return 1; fi
  if [ "$E_MAIN" -eq 1 ]; then
    if other=$(main_launcher_for "$E_APP"); then
      shown other "$(bundle_name "$other")"
      E_WHY="'$other' already opens the original account"; return 1
    fi
  else
    E_SLUG=$(slugify "$E_LABEL")
    dir="$DATA_ROOT/$E_SLUG"
    if import_folder_owner "$E_LABEL" "$dir"; then
      [ -n "$IMPORT_OWNER" ] || { E_WHY="could not look through every launcher, so it might share a profile folder"; return 1; }
      shown other "$IMPORT_OWNER"
      E_WHY="would share a profile folder with '$other'"; return 1
    fi
    import_check socket_path_ok "$E_APP" "$dir" "$E_LABEL" new || return 1
  fi
  return 0
}

# Whether the entry in the E_ variables clashes with one already planned: the
# same launcher twice, two launchers for one app's original account, or two
# profiles that would share a folder. create_profile would refuse the second;
# this says so in the plan, before anything is built. Launcher names are
# compared lower-cased, as the launcher folder ignores case: "Fake Work" and
# "Fake work" are one launcher there.
import_clash() { # slug of the entry's profile folder, lower-cased launcher name
  local j=0
  while [ "$j" -lt "${#P_ACT[@]}" ]; do
    if [ "${P_ACT[$j]}" = create ]; then
      if [ "${P_LOWER[$j]}" = "$2" ]; then
        E_WHY="listed twice in the file"; return 0
      fi
      if [ "$E_MAIN" -eq 1 ] && [ "${P_MAIN[$j]}" -eq 1 ] && [ "${P_APP[$j]}" = "$E_APP" ]; then
        E_WHY="another entry opens the original account"; return 0
      fi
      if [ "$E_MAIN" -eq 0 ] && [ "${P_MAIN[$j]}" -eq 0 ] && [ "${P_SLUG[$j]}" = "$1" ]; then
        E_WHY="would share a profile folder with ${P_SHOW[$j]}"; return 0
      fi
    fi
    j=$((j + 1))
  done
  return 1
}

# The launch settings an entry brings, under its line in the plan. They come
# from the file, and a proxy among them sends the profile's traffic through a
# server the file names, so every server is shown before the question: a
# switch in full, as list shows it, and a proxy variable by its scheme, host
# and port. Other variables by name only, as a value may be a password.
import_show_settings() { # extras
  local line v px sw="" proxies="" envs="" ext=0
  while IFS= read -r line; do
    v=${line#*"$TAB"}
    case "$line" in
      "arg$TAB"*) sw="$sw $v" ;;
      "env$TAB"*)
        case "${v%%=*}" in
          NO_PROXY|no_proxy) envs="$envs ${v%%=*}" ;;
          *_PROXY|*_proxy) import_proxy_shown px "${v#*=}"; proxies="$proxies ${v%%=*}=$px" ;;
          *) envs="$envs ${v%%=*}" ;;
        esac ;;
      "ext$TAB"*) ext=1 ;;
    esac
  done <<EOF
$1
EOF
  shown sw "${sw# }"; shown proxies "${proxies# }"; shown envs "${envs# }"
  [ -n "$sw" ] && printf '          flags  %s\n' "$sw"
  [ -n "$proxies" ] && printf '          proxy  %s\n' "$proxies"
  [ -n "$envs" ] && printf '          env    %s%s (values hidden)%s\n' "$C_DIM" "$envs" "$C_RESET"
  [ "$ext" -eq 0 ] || printf '          ext    %sits own extensions folder%s\n' "$C_DIM" "$C_RESET"
  return 0
}

# A proxy variable's server as the plan shows it, into the variable named $1:
# the scheme, host and port, read as a client reads them. A user name and
# password before the host become ***, and a path is left out.
import_proxy_shown() { # variable, proxy value
  local rest="$2" scheme="" host
  case "$rest" in
    *://*) case "${rest%%://*}" in
             ''|*[!A-Za-z0-9+.-]*) ;;
             *) scheme="${rest%%://*}://"; rest=${rest#*://} ;;
           esac ;;
  esac
  host=${rest%%/*}
  case "$host" in *@*) host="***@${host##*@}" ;; esac
  printf -v "$1" '%s%s' "$scheme" "$host"
}

# Copy the file, up to the size limit, and read it. Dies, having changed
# nothing, unless it is an export in this format. Sets IMPORT_N, the number
# of launchers it lists.
import_load() { # file, its name as printed
  local tmp="${TMPDIR:-/tmp}" size status
  IMPORT_TMP=$(mktemp -d "${tmp%/}/aidentity-import.XXXXXX" 2>/dev/null) \
    || { IMPORT_TMP=""; die "Could not create a temporary folder."; }
  head -c $((IMPORT_MAX_BYTES + 1)) < "$1" > "$IMPORT_TMP/file" 2>/dev/null \
    || die "Could not read $2"
  size=$(wc -c < "$IMPORT_TMP/file" | tr -d ' ')
  [ "$size" -le "$IMPORT_MAX_BYTES" ] \
    || die "$2 is bigger than 4 MB, so it is not a file made by 'aidentity export'. Nothing was changed."
  status=$(import_read "$IMPORT_TMP/file" "$IMPORT_TMP")
  case "$status" in
    ok) ;;
    json) die "$2 is not valid JSON, or it holds a null, so it is not a file made by
    'aidentity export'. Nothing was changed." ;;
    *) die "Could not read $2: osascript did not run. Nothing was changed." ;;
  esac
  import_records "$IMPORT_TMP/top"
  import_value aidentity_export integer \
    || die "$2 is not a file made by 'aidentity export'. Nothing was changed."
  if [ "$IV" -gt "$EXPORT_FORMAT" ]; then
    die "$2 is in export format $IV, and this aidentity reads format $EXPORT_FORMAT. Nothing was changed.
    A newer aidentity made it. Run aidentity update, then try again."
  fi
  [ "$IV" = "$EXPORT_FORMAT" ] \
    || die "$2 is in export format $IV, and this aidentity reads format $EXPORT_FORMAT. Nothing was changed."
  import_value launchers array || die "$2 has no list of launchers. Nothing was changed."
  [ "$IV" -le "$IMPORT_MAX_LAUNCHERS" ] \
    || die "$2 lists $IV launchers; import reads at most $IMPORT_MAX_LAUNCHERS. Nothing was changed.
    Split the file into parts of at most $IMPORT_MAX_LAUNCHERS, and import each part."
  IMPORT_N=$IV
}

# `aidentity import FILE`: build the launchers listed in a file that export
# made. The file is untrusted: it may come from someone else. Every value is
# checked as add checks it, the app is found by its bundle ID among the
# installed apps only, and a launcher that exists is skipped, never changed.
# The whole plan is shown and confirmed before anything is built.
cmd_import() {
  local file="" yes=0 name
  while [ $# -gt 0 ]; do
    case "$1" in
      -y|--yes) yes=1; shift ;;
      -*) die "Unknown option for import: $1" ;;
      *) [ -z "$file" ] && file="$1" || die "Unexpected argument: $1"; shift ;;
    esac
  done
  [ -n "$file" ] || die "Usage: aidentity import FILE   (a file made by 'aidentity export')"
  shown name "$file"
  { [ -r "$file" ] && [ ! -d "$file" ]; } || die "Cannot read $name"

  local IV="" IMPORT_N=0 IMPORT_SCANNED=0 IMPORT_FOUND="" IMPORT_FOUND_NAME=""
  local IMPORT_APPS=() IMPORT_IDS=() IMPORT_NAMES=()
  local IMPORT_KEYS=() IMPORT_TYPES=() IMPORT_VALS=() IMPORT_NEXT=0
  local IMPORT_OWNERS_READ=0 IMPORT_OWNER="" IMPORT_SEARCH_FAILED=0
  local IMPORT_OWNER_APPS=() IMPORT_OWNER_DIRS=() IMPORT_OWNER_IDS=() IMPORT_OWNER_NAMES=()
  import_load "$file" "$name"

  # The plan, an entry each: create or skip, and what create_profile needs.
  local P_ACT=() P_SHOW=() P_APP=() P_PROFILE=() P_LABEL=() P_SLUG=() P_MAIN=()
  local P_BADGE=() P_NOBADGE=() P_HEX=() P_EXTRAS=() P_LOWER=()
  local E_SHOW E_WHY E_APP E_PROFILE E_LABEL E_SLUG E_MAIN E_BADGE E_NOBADGE E_HEX E_EXTRAS
  local i=0 slug low act note n_new=0 n_skip=0
  if [ "$IMPORT_N" -eq 0 ]; then
    info "$name lists no launchers. Nothing to do."
    return 0
  fi
  info "${C_BOLD}The launchers in $name:${C_RESET}"
  info ""
  while [ "$i" -lt "$IMPORT_N" ]; do
    act=skip; slug=""; low=""
    if import_entry "$i"; then
      slug=$E_SLUG; low=$(lower "$E_LABEL")
      import_clash "$slug" "$low" || act=create
    fi
    P_ACT[i]=$act; P_SHOW[i]=$E_SHOW; P_APP[i]=$E_APP; P_LOWER[i]=$low
    P_PROFILE[i]=$E_PROFILE; P_LABEL[i]=$E_LABEL; P_SLUG[i]=$slug; P_MAIN[i]=$E_MAIN
    P_BADGE[i]=$E_BADGE; P_NOBADGE[i]=$E_NOBADGE; P_HEX[i]=$E_HEX; P_EXTRAS[i]=$E_EXTRAS
    if [ "$act" = create ]; then
      n_new=$((n_new + 1)); note=""
      if [ "$E_MAIN" -eq 1 ]; then
        note=" $(dim "— opens the original account")"
      elif [ -d "$DATA_ROOT/$slug" ]; then
        # add reuses a profile folder that is there. Say so: it may be signed in.
        note=" $(dim "— its profile folder is here already, and is used")"
      fi
      printf '  create  %s%s\n' "$E_SHOW" "$note"
      import_show_settings "$E_EXTRAS"
    else
      n_skip=$((n_skip + 1))
      printf '  skip    %s %s\n' "$E_SHOW" "$(dim "— $E_WHY")"
    fi
    i=$((i + 1))
  done
  info ""

  if [ "$n_new" -eq 0 ]; then
    info "Nothing to create."
    return 0
  fi
  if [ "$yes" -eq 0 ]; then
    local reply; reply=$(ask "Create $(count "$n_new" launcher)? Type yes to confirm: ") \
      || die "Nothing to confirm with."
    [ "$reply" = "yes" ] || die "Cancelled. Nothing was created."
  fi

  # The closing hint names a new profile, never a main launcher: that opens
  # the app's own account, which is signed in already. A profile whose folder
  # was here before may be signed in too, so it gets no sign-in hint.
  local made=0 failed=0 first="" reused="" had
  i=0
  while [ "$i" -lt "$IMPORT_N" ]; do
    if [ "${P_ACT[$i]}" != create ]; then i=$((i + 1)); continue; fi
    had=0
    [ "${P_MAIN[$i]}" -eq 1 ] || [ ! -d "$DATA_ROOT/${P_SLUG[$i]}" ] || had=1
    if [ -e "$APPS_DIR/${P_LABEL[$i]}.app" ]; then
      # Made since the plan was shown. It is not changed either.
      warn "Skipped ${P_SHOW[$i]}: it exists now."
      n_skip=$((n_skip + 1))
    # create_profile's own report is for one profile at a time; its warnings
    # still reach stderr.
    elif create_profile "${P_APP[$i]}" "${P_PROFILE[$i]}" "${P_BADGE[$i]}" "${P_HEX[$i]}" 0 \
           "${P_NOBADGE[$i]}" "${P_MAIN[$i]}" "${P_EXTRAS[$i]}" >/dev/null; then
      ok "Created ${C_BOLD}${P_SHOW[$i]}${C_RESET}"
      made=$((made + 1))
      if [ "${P_MAIN[$i]}" -eq 0 ]; then
        if [ "$had" -eq 0 ]; then [ -n "$first" ] || first=${P_SHOW[$i]}
        else [ -n "$reused" ] || reused=${P_SHOW[$i]}; fi
      fi
    else
      warn "Could not create ${P_SHOW[$i]}."
      failed=$((failed + 1))
    fi
    i=$((i + 1))
  done
  info ""
  info "$made created, $n_skip skipped, $failed failed."
  if [ -n "$first" ]; then
    dim "  Open each new profile to sign in, e.g.:  aidentity open \"$first\""
  elif [ -n "$reused" ]; then
    dim "  Open one with:  aidentity open \"$reused\""
  fi
  [ "$failed" -eq 0 ]
}
