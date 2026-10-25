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
# take longer than linear time on a long value.
IMPORT_MAX_LAUNCHERS=200
IMPORT_MAX_SETTINGS=32
IMPORT_MAX_VALUE=1024
IMPORT_MAX_BYTES=4194304

# The bundle ID of the app a launcher opens. When the app is gone, the one the
# profile folder's restore record kept. Empty when neither is known.
export_bundle_id() { # app, data dir
  local bid=""
  [ -d "$1" ] && bid=$(bundle_id "$1")
  [ -z "$bid" ] && [ -n "$2" ] && bid=$(record_get "$2" AIdentityTargetBundleID)
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
#   args            launch switches
#   env             launch variables, as NAME=value: values included
#   own_extensions  true when a VS Code-style app has its own extensions folder
# Every value is a string, a boolean or a list of strings, never null:
# plutil, which import reads the file with, refuses null. Warnings go to
# stderr, so stdout is always the file.
cmd_export() {
  while [ $# -gt 0 ]; do
    case "$1" in
      -*) die "Unknown option for export: $1" ;;
      *) die "Unexpected argument: $1" ;;
    esac
  done
  local i=0 app target ex bid obj flag v secrets=0
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
  if [ "$secrets" -gt 0 ]; then
    warn "The file holds the values of $(count "$secrets" "launch variable"). A proxy setting can
    carry a password: keep the file private."
  fi
  return 0
}

# The value at a key path of the converted file, into IV, when it has the
# type asked for. Returns 1 when there is nothing at that path, and 2 when
# there is something of another type. plutil ends its raw output with a line
# break of its own; the x keeps a line break that belongs to the value, so the
# checks see it.
import_value() { # key path, type
  local f="$IMPORT_TMP/export.plist" nl=$'\n'
  if IV=$(/usr/bin/plutil -extract "$1" raw -expect "$2" -o - "$f" 2>/dev/null && printf x); then
    IV=${IV%x}; IV=${IV%"$nl"}
    return 0
  fi
  IV=""
  /usr/bin/plutil -extract "$1" xml1 -o /dev/null "$f" >/dev/null 2>&1 && return 2
  return 1
}

# Run a check quietly. When it refuses, its first line goes into E_WHY, made
# safe to print. Only the first line: the lines after it can repeat the value,
# and the value came from the file. A list of allowed values is left out.
import_check() { # check, then its arguments
  local out nl=$'\n'
  out=$("$@" 2>&1 >/dev/null) && return 0
  out=${out%%"$nl"*}
  out=${out#*"!$C_RESET "}
  shown E_WHY "${out%%. Allowed:*}"
  return 1
}

# The installed app with this bundle ID, into IMPORT_FOUND. Only the apps that
# `apps` lists are looked at: a path in the file is never used. They are read
# once, into cmd_import's own variables.
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
    if [ "${IMPORT_IDS[$i]}" = "$1" ]; then IMPORT_FOUND=${IMPORT_APPS[$i]}; return 0; fi
    i=$((i + 1))
  done
  return 1
}

# The launcher here, other than the one named $1, that keeps its profile in
# the folder $2, into IMPORT_OWNER: create_profile's test, so the plan skips
# what it would refuse. The same text, or the same folder spelled another way.
# The launchers' folders are read once, into cmd_import's own variables;
# nothing is built while the plan is made.
import_folder_owner() { # launcher name, data dir
  local a d i=0 id
  if [ "$IMPORT_OWNERS_READ" -eq 0 ]; then
    IMPORT_OWNERS_READ=1
    for a in "$APPS_DIR"/*.app; do
      [ -d "$a" ] || continue
      is_our_launcher "$a" || continue
      d=$(plist_get "$a" AIdentityDataDir)
      [ -n "$d" ] || continue
      IMPORT_OWNERS[${#IMPORT_OWNERS[@]}]=$(bundle_name "$a")
      IMPORT_DIRS[${#IMPORT_DIRS[@]}]=$d
      IMPORT_DIR_IDS[${#IMPORT_DIR_IDS[@]}]=$(dir_id "$d")
    done
  fi
  id=$(dir_id "$2")
  while [ "$i" -lt "${#IMPORT_OWNERS[@]}" ]; do
    if [ "${IMPORT_OWNERS[$i]}" != "$1" ] && { [ "${IMPORT_DIRS[$i]}" = "$2" ] ||
         { [ -n "$id" ] && [ "${IMPORT_DIR_IDS[$i]}" = "$id" ]; }; }; then
      IMPORT_OWNER=${IMPORT_OWNERS[$i]}; return 0
    fi
    i=$((i + 1))
  done
  return 1
}

# A badge character that can be drawn: one that prints, in any locale. Under
# C, [[:cntrl:]] misses the C1 controls, which some terminals and fonts treat
# as the start of an escape sequence.
badge_drawable() {
  local LC_ALL=en_US.UTF-8
  case "$1" in ''|*[![:print:]]*) return 1 ;; esac
  return 0
}

# The switches (arg) or variables (env) an entry lists, each checked as add
# checks it, added to E_EXTRAS. A list that is not there is an empty one.
import_list() { # entry key path, key, kind, check
  local n i=0 rc=0
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
    E_EXTRAS="${E_EXTRAS:+$E_EXTRAS
}$3$TAB$IV"
    i=$((i + 1))
  done
  return 0
}

# Read entry $1 of the file and check each value as add checks it on the
# command line. Sets the E_ variables of cmd_import for create_profile, and
# E_SHOW, the entry's name as it is printed. Returns 1, with the reason in
# E_WHY, for an entry to skip.
import_entry() { # index
  local k="launchers.$1" rc kind="" other dir
  E_SHOW="entry $(($1 + 1))"; E_WHY=""; E_APP=""; E_PROFILE=""; E_LABEL=""
  E_MAIN=0; E_BADGE=""; E_NOBADGE=0; E_HEX=""; E_EXTRAS=""
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
  E_LABEL="$(bundle_name "$E_APP") $E_PROFILE"
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
    dir="$DATA_ROOT/$(slugify "$E_LABEL")"
    if import_folder_owner "$E_LABEL" "$dir"; then
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
# this says so in the plan, before anything is built.
import_clash() { # slug of the entry's profile folder
  local j=0
  while [ "$j" -lt "${#P_ACT[@]}" ]; do
    if [ "${P_ACT[$j]}" = create ]; then
      if [ "${P_LABEL[$j]}" = "$E_LABEL" ]; then
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

# The launch settings an entry brings, under its line in the plan, as list
# shows them: switches in full, variables by name only, as a value may be a
# password. They come from the file, and a proxy among them sends the
# profile's traffic through a server the file names, so they are shown before
# the question.
import_show_settings() { # extras
  local sw envs
  shown sw "$(extras_lines arg "$1" | tr '\n' ' ')"
  shown envs "$(extras_lines env "$1" | sed 's/=.*//' | tr '\n' ' ')"
  [ -n "$sw" ] && printf '          flags  %s\n' "${sw% }"
  [ -n "$envs" ] && printf '          env    %s\n' "$(dim "${envs% } (values hidden)")"
  [ -n "$(extras_lines ext "$1")" ] && printf '          ext    %s\n' "$(dim "its own extensions folder")"
  return 0
}

# Copy the file, up to the size limit, and convert it with plutil. Dies,
# having changed nothing, unless it is an export in this format. Sets
# IMPORT_N, the number of launchers it lists.
import_load() { # file, its name as printed
  local tmp="${TMPDIR:-/tmp}" size
  IMPORT_TMP=$(mktemp -d "${tmp%/}/aidentity-import.XXXXXX" 2>/dev/null) \
    || { IMPORT_TMP=""; die "Could not create a temporary folder."; }
  head -c $((IMPORT_MAX_BYTES + 1)) < "$1" > "$IMPORT_TMP/file" 2>/dev/null \
    || die "Could not read $2"
  size=$(wc -c < "$IMPORT_TMP/file" | tr -d ' ')
  [ "$size" -le "$IMPORT_MAX_BYTES" ] \
    || die "$2 is bigger than 4 MB, so it is not a file made by 'aidentity export'. Nothing was changed."
  /usr/bin/plutil -convert xml1 -o "$IMPORT_TMP/export.plist" "$IMPORT_TMP/file" >/dev/null 2>&1 \
    || die "$2 is not valid JSON, or it holds a null, so it is not a file made by
    'aidentity export'. Nothing was changed."
  import_value aidentity_export integer \
    || die "$2 is not a file made by 'aidentity export'. Nothing was changed."
  [ "$IV" = "$EXPORT_FORMAT" ] \
    || die "$2 is in export format $IV, and this aidentity reads format $EXPORT_FORMAT. Nothing was changed."
  import_value launchers array || die "$2 has no list of launchers. Nothing was changed."
  [ "$IV" -le "$IMPORT_MAX_LAUNCHERS" ] \
    || die "$2 lists $IV launchers; import reads at most $IMPORT_MAX_LAUNCHERS. Nothing was changed."
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

  local IV="" IMPORT_N=0 IMPORT_SCANNED=0 IMPORT_FOUND="" IMPORT_APPS=() IMPORT_IDS=()
  local IMPORT_OWNERS_READ=0 IMPORT_OWNER="" IMPORT_OWNERS=() IMPORT_DIRS=() IMPORT_DIR_IDS=()
  import_load "$file" "$name"

  # The plan, an entry each: create or skip, and what create_profile needs.
  local P_ACT=() P_SHOW=() P_WHY=() P_APP=() P_PROFILE=() P_LABEL=() P_SLUG=() P_MAIN=()
  local P_BADGE=() P_NOBADGE=() P_HEX=() P_EXTRAS=()
  local E_SHOW E_WHY E_APP E_PROFILE E_LABEL E_MAIN E_BADGE E_NOBADGE E_HEX E_EXTRAS
  local i=0 slug act note n_new=0 n_skip=0
  if [ "$IMPORT_N" -eq 0 ]; then
    info "$name lists no launchers. Nothing to do."
    return 0
  fi
  info "${C_BOLD}The launchers in $name:${C_RESET}"
  info ""
  while [ "$i" -lt "$IMPORT_N" ]; do
    act=skip; slug=""
    if import_entry "$i"; then
      [ "$E_MAIN" -eq 1 ] || slug=$(slugify "$E_LABEL")
      import_clash "$slug" || act=create
    fi
    P_ACT[i]=$act; P_SHOW[i]=$E_SHOW; P_WHY[i]=$E_WHY; P_APP[i]=$E_APP
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

  local made=0 failed=0 first=""
  i=0
  while [ "$i" -lt "$IMPORT_N" ]; do
    if [ "${P_ACT[$i]}" != create ]; then i=$((i + 1)); continue; fi
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
      [ -n "$first" ] || [ "${P_MAIN[$i]}" -eq 1 ] || first=${P_SHOW[$i]}
    else
      warn "Could not create ${P_SHOW[$i]}."
      failed=$((failed + 1))
    fi
    i=$((i + 1))
  done
  info ""
  info "$made created, $n_skip skipped, $failed failed."
  [ -z "$first" ] || dim "  Open each new profile to sign in, e.g.:  aidentity open \"$first\""
  [ "$failed" -eq 0 ]
}
