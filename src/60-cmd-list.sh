# -------------------------------------------------------------- commands --

cmd_apps() {
  local app n=0
  info "${C_BOLD}Apps on this Mac that aidentity can give extra accounts:${C_RESET}"
  info ""
  while IFS= read -r app; do
    [ -n "$app" ] || continue
    n=$((n+1))
    printf '  %-28s %s\n' "$(bundle_name "$app")" "$(dim "$(bundle_id "$app")")"
  done <<EOF
$(list_compatible_apps)
EOF
  info ""
  if [ "$n" -eq 0 ]; then
    warn "No compatible apps found."
    dim "  aidentity works with Chromium- and Electron-based apps."
  else
    dim "  $n app(s). Add one with:  aidentity add \"<name>\" --profile Work"
  fi
}

# Whether a profile directory has been used. Chromium browsers keep their
# profile in Default/, but Electron apps (Claude, Slack, VS Code, Notion) write
# straight into the root — so testing only for Default/ showed every signed-in
# Electron profile as "signed out / new".
profile_has_data() {
  local f
  for f in Default "Local State" Preferences Cookies "Local Storage"; do
    [ -e "$1/$f" ] && return 0
  done
  return 1
}

# What a launcher is doing, in the words list prints: running, in use,
# signed out / new, app missing, or not running (a main launcher). One place,
# so `list`, `list --json` and the menu can never disagree. It asks under the
# caller's snapshot and sets STATUS, which the caller makes local: printed from
# a subshell, what the snapshot reads would be lost after each launcher.
launcher_status() { # app, data dir, main (1 or 0) -> STATUS
  if [ ! -d "$1" ]; then
    STATUS="app missing"
  elif [ "$3" = "1" ]; then
    STATUS="not running"
    main_running "$1" && STATUS="running"
  else
    STATUS="signed out / new"
    profile_has_data "$2" && STATUS="in use"
    running_in_snapshot "$2" && STATUS="running"
  fi
  return 0
}

# Text from the disk or from a file as a person sees it, into the variable
# named $1: each control character becomes "?", so an escape sequence cannot
# reach the terminal. The text is read as UTF-8 whatever the locale: under C,
# [[:cntrl:]] misses the C1 controls (U+0080 to U+009F), and some terminals
# read U+009B as the start of an escape sequence. Read as UTF-8, some invisible
# characters count as controls too, such as the joiner inside some emoji. The
# caller's locale is back when this returns.
shown() { # variable, text
  local LC_ALL=en_US.UTF-8
  printf -v "$1" '%s' "${2//[[:cntrl:]]/?}"
}

# Every launcher, for list, list --json, the menu and completion: LR_N of them,
# launcher i at LR_PATH[i] named LR_NAME[i] (as on the disk), opening the app
# LR_TARGET[i] with LR_DATA[i], LR_PROFILE[i] and LR_MAIN[i] (1 or 0). A main
# launcher has no data folder of its own, whatever its Info.plist says. With
# "names", only paths and names are read: completion runs on every Tab.
launcher_rows() { # [names]
  local app label
  LR_N=0; LR_PATH=(); LR_NAME=(); LR_TARGET=(); LR_DATA=(); LR_PROFILE=(); LR_MAIN=()
  for app in "$APPS_DIR"/*.app; do
    [ -d "$app" ] || continue
    is_our_launcher "$app" || continue
    label=${app##*/}
    LR_PATH[LR_N]=$app; LR_NAME[LR_N]=${label%.app}
    if [ "${1:-}" != names ]; then
      LR_TARGET[LR_N]=$(plist_get "$app" AIdentityTargetApp)
      LR_DATA[LR_N]=$(plist_get "$app" AIdentityDataDir)
      LR_PROFILE[LR_N]=$(plist_get "$app" "$MARKER_KEY")
      LR_MAIN[LR_N]=0
      if is_main_launcher "$app"; then LR_MAIN[LR_N]=1; LR_DATA[LR_N]=""; fi
    fi
    LR_N=$((LR_N + 1))
  done
}

cmd_list() {
  local json=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --json) json=1; shift ;;
      -*) die "Unknown option for list: $1" ;;
      *) die "Unexpected argument: $1" ;;
    esac
  done
  if [ "$json" -eq 1 ]; then list_json; return; fi

  # One look at the processes for all the rows. Disk text goes through shown.
  local i=0 label app profile data status ex sw envs STATUS PS_RC="" PS_LIST="" PS_IDS="" PS_ALL=""
  launcher_rows
  [ "$LR_N" -eq 0 ] || proc_snapshot
  while [ "$i" -lt "$LR_N" ]; do
    launcher_status "${LR_TARGET[$i]}" "${LR_DATA[$i]}" "${LR_MAIN[$i]}"
    shown label "${LR_NAME[$i]}"
    shown app "$(bundle_name "${LR_TARGET[$i]}")"
    shown profile "${LR_PROFILE[$i]}"
    case "$STATUS" in
      running) status="${C_GREEN}running${C_RESET}" ;;
      "app missing") status="${C_YELLOW}app missing${C_RESET} — run: aidentity rebuild \"$label\"" ;;
      *) status=$STATUS ;;
    esac
    printf '%s%s%s\n' "$C_BOLD" "$label" "$C_RESET"
    printf '   app      %s\n' "$app"
    printf '   profile  %s\n' "$profile"
    printf '   status   %s\n' "$status"
    if [ "${LR_MAIN[$i]}" = "1" ]; then
      printf '   data     %s\n' "$(dim "the app's own — your original account, never touched")"
    else
      shown data "${LR_DATA[$i]}"
      printf '   data     %s\n' "$(dim "$data")"
    fi
    ex=$(extras_of "${LR_PATH[$i]}/Contents/Info.plist")
    shown sw "$(extras_lines arg "$ex" | tr '\n' ' ')"
    # Names only: a value may be a token or a password.
    shown envs "$(extras_lines env "$ex" | sed 's/=.*//' | tr '\n' ' ')"
    [ -n "$sw" ] && printf '   flags    %s\n' "${sw% }"
    [ -n "$envs" ] && printf '   env      %s\n' "$(dim "${envs% } (values hidden)")"
    [ -n "$(extras_lines ext "$ex")" ] && printf '   ext      %s\n' "$(dim "its own extensions folder, inside the profile folder")"
    info ""
    i=$((i + 1))
  done
  if [ "$LR_N" -eq 0 ]; then
    info "No profiles yet."
    dim "  Create one with:  aidentity add"
  fi
}

# `list --json`: one JSON array, one object per launcher, for scripts and other
# front ends. The plain list is for people and may change its wording; these
# keys stay. Every object has every key, in this order:
#   name            launcher name, as `open`, `set` and `rm` take it
#   app, app_path   the app it opens: name and path (null if not recorded)
#   profile         profile name
#   data_dir        profile folder; null for a main launcher
#   main            true for a launcher that opens the app's own account
#   status          running, in use, signed out / new, app missing, not running
#   badge           badge character; null for the app's own icon
#   color           badge colour, six hex digits
#   built_by        the aidentity version that built it (null if not recorded)
#   args            launch switches
#   env             names of launch variables, never their values: a value
#                   may be a token or a password
#   own_extensions  true when a VS Code-style app has its own extensions folder
# Nothing else is written to stdout, so the output always parses: warnings go
# to stderr and there is no colour. No launchers prints [].
list_json() {
  local i=0 app target main ex obj STATUS PS_RC="" PS_LIST="" PS_IDS="" PS_ALL=""
  launcher_rows
  [ "$LR_N" -eq 0 ] || proc_snapshot
  while [ "$i" -lt "$LR_N" ]; do
    app=${LR_PATH[$i]}; target=${LR_TARGET[$i]}
    launcher_status "$target" "${LR_DATA[$i]}" "${LR_MAIN[$i]}"
    main=false
    [ "${LR_MAIN[$i]}" = "1" ] && main=true
    ex=$(extras_of "$app/Contents/Info.plist")
    obj="{\"name\":$(json_str "${LR_NAME[$i]}")"
    if [ -n "$target" ]; then
      obj="$obj,\"app\":$(json_str "$(bundle_name "$target")")"
    else
      obj="$obj,\"app\":null"
    fi
    obj="$obj,\"app_path\":$(json_str_or_null "$target")"
    obj="$obj,\"profile\":$(json_str "${LR_PROFILE[$i]}")"
    obj="$obj,\"data_dir\":$(json_str_or_null "${LR_DATA[$i]}")"
    obj="$obj,\"main\":$main"
    obj="$obj,\"status\":$(json_str "$STATUS")"
    obj="$obj,\"badge\":$(json_str_or_null "$(launcher_badge "$app" "$target" "${LR_PROFILE[$i]}")")"
    obj="$obj,\"color\":$(json_str "$(launcher_color "$app" "${LR_NAME[$i]}")")"
    obj="$obj,\"built_by\":$(json_str_or_null "$(plist_get "$app" CFBundleShortVersionString)")"
    obj="$obj,\"args\":$(json_lines "$(extras_lines arg "$ex")")"
    obj="$obj,\"env\":$(json_lines "$(extras_lines env "$ex" | sed 's/=.*//')")"
    if [ -n "$(extras_lines ext "$ex")" ]; then
      obj="$obj,\"own_extensions\":true}"
    else
      obj="$obj,\"own_extensions\":false}"
    fi
    if [ "$i" -eq 0 ]; then printf '[\n  %s' "$obj"; else printf ',\n  %s' "$obj"; fi
    i=$((i + 1))
  done
  if [ "$LR_N" -eq 0 ]; then printf '[]\n'; else printf '\n]\n'; fi
}

cmd_open() {
  local want="${1:-}"
  [ -n "$want" ] || die "Usage: aidentity open \"<profile>\""
  [ $# -le 1 ] || die "Unexpected argument: $2  (quote a name that has spaces)"
  local app="$APPS_DIR/$want.app"
  [ -d "$app" ] || die "No launcher named '$want'. Run 'aidentity list' to see what exists."
  assert_ours "$app"
  open "$app" || die "Could not open '$want'."
  # Braces are required here, not cosmetic. Bash folds a following multi-byte
  # character into the parameter name, so an unbraced name directly before the
  # ellipsis is read as part of the name and dies under `set -u`. A CI guard
  # enforces this, which is why the bad form is described rather than written.
  ok "Opening ${want}…"
}

cmd_version() { printf 'aidentity %s\n' "$AIDENTITY_VERSION"; }
