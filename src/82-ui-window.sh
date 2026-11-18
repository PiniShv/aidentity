# ------------------------------------------------------------------ ui: window --
#
# `aidentity ui --window`: the profiles and the menu's actions, in a window.
#
# The window is a small program for osascript (uiw_host_script) that shows one
# page (uiw_page_html). It keeps nothing and decides nothing. For everything it
# shows or does, it runs this script again, once for each request, as a hidden
# command:
#
#   aidentity __window page            the page to show
#   aidentity __window state [PART…]   what to draw, as JSON
#   aidentity __window do VERB WORD…   one action, as the command line runs it
#
# So nothing listens on a port, aidentity writes no file for the window, and
# nothing is left running when it closes. An action names a profile the way its card
# showed it: the launcher's name, and which data folder it was (see uiw_id).
# It runs only while the launcher of that name still opens that same folder,
# so a profile that was renamed or made again elsewhere since the card was
# drawn is refused, never guessed at. Actions run with no terminal to ask on:
# a question fails instead of waiting.

# Exit statuses of `__window do`, beside a command's own 0 and 1.
UIW_REFUSED=3     # nothing ran: the request was not understood, or the list has changed
UIW_PROBLEMS=10   # check and fix: problems are left
UIW_FIXABLE=11    # check: problems were found, and doctor --fix can mend some
UIW_ROW=0         # set by uiw_same: where the profile is in launcher_rows' lists

ui_window() {
  local v session err rc=0
  # The window runs this file again for each request, so it must be one.
  [ -n "$SELF_PATH" ] && [ -f "$SELF_PATH" ] \
    || die "The window needs aidentity installed as a file.
    Use the menu in this terminal instead:  aidentity ui"
  v=$(/usr/bin/sw_vers -productVersion 2>/dev/null) || v=""
  uiw_macos_ok "$v" || die "The window needs macOS 12.3 or later (this is $v).
    Use the menu in this terminal instead:  aidentity ui"
  # A login with no desktop, over SSH say, has no screen to put a window on.
  session=$(/bin/launchctl managername 2>/dev/null) || session=""
  case "$session" in
    Background|StandardIO|System|LoginWindow)
      die "The window needs a desktop session, and this is not one (an SSH login, perhaps).
    Use the menu in this terminal instead:  aidentity ui" ;;
  esac
  info "Opening the window. Close it to come back here."
  # What the window's program writes is kept, and shown only if it fails.
  err=$(uiw_host_script | /usr/bin/osascript - "$BASH" "$SELF_PATH" 2>&1 >/dev/null) || rc=$?
  [ "$rc" -ne 0 ] || return 0
  warn "The window did not open, or it closed because of an error."
  [ -z "$err" ] || printf '%s\n' "$err" | sed -n '1,3s/^/    /p' >&2
  dim "  Use the menu in this terminal instead:  aidentity ui"
  return 1
}

# macOS 12.3 or later: the page needs the WebKit that came with it. A version
# that cannot be read is let through; the window then says what it is missing.
uiw_macos_ok() { # version, as sw_vers prints it
  local major=${1%%.*} minor=0
  case "$1" in *.*) minor=${1#*.}; minor=${minor%%.*} ;; esac
  case "$major" in ''|*[!0-9]*) return 0 ;; esac
  case "$minor" in ''|*[!0-9]*) minor=0 ;; esac
  [ "$major" -gt 12 ] || { [ "$major" -eq 12 ] && [ "$minor" -ge 3 ]; }
}

# The hidden command the window runs. It is not for people: its words and its
# output can change with any release, together with the window that uses them.
cmd_window() {
  local what="${1:-}"
  [ $# -eq 0 ] || shift
  case "$what" in
    page) uiw_page_html ;;
    state) uiw_state "$@" ;;
    do) uiw_do "$@" ;;
    *) die "__window is run by the window that 'aidentity ui --window' opens. It is not a command to type." ;;
  esac
}

# A request turned down before anything ran. The first line of every answer to
# `__window do` is the command that ran; here it is empty.
uiw_refuse() { # message
  printf '\n%s\n' "$1"
  exit "$UIW_REFUSED"
}

# The window and this script did not come from the same release: `update` ran
# while the window was open, say.
uiw_bad() {
  uiw_refuse "The window asked for something this aidentity does not know. Close the window and open it again."
}

# A path as a person reads it, with ~ for the home folder: a window can be on
# a shared screen, and the home folder carries the account's name.
uiw_tilde() {
  case "$1" in
    "$HOME"/*) printf '~%s' "${1#"$HOME"}" ;;
    *) printf '%s' "$1" ;;
  esac
}

# One word of a command, quoted the way a person would type it.
uiw_q() {
  local q="'\\''" s
  case "$1" in
    ''|*[!A-Za-z0-9_./:@%+=,-]*) s=${1//\'/$q}; printf "'%s'" "$s" ;;
    *) printf '%s' "$1" ;;
  esac
}

# ---- what to draw

# The parts of the list, as one JSON object. The launchers are quick to read;
# the apps a profile can be made for and the search behind the removed
# profiles take seconds, so the window asks for each part only when it needs it.
uiw_state() { # parts: launchers, apps, restorable (none: all three)
  local part c sep=""
  [ $# -gt 0 ] || set -- launchers apps restorable
  for part in "$@"; do
    case "$part" in launchers|apps|restorable) ;; *) uiw_bad ;; esac
  done
  printf '{"version":%s,"apps_dir":%s,"colors":[' \
    "$(json_str "$AIDENTITY_VERSION")" "$(json_str "$(uiw_tilde "$APPS_DIR")")"
  for c in $UI_COLORS; do
    printf '%s{"name":%s,"hex":%s}' "$sep" "$(json_str "$c")" "$(json_str "$(color_hex "$c")")"
    sep=","
  done
  printf ']'
  for part in "$@"; do "uiw_json_$part"; done
  printf '}\n'
}

# Which account a launcher opens, whatever the launcher is called: its data
# folder, as the folder itself and not as a path. `rename` moves the folder to
# a path that goes with the new name, so after two renames a path can lead to
# another account's folder; the folder's own identity moves with it. A folder
# that is not there yet has only its path. A main launcher has no folder of
# its own: it is the app's own account.
uiw_id() { # data folder ("" for a main launcher), target app
  local id
  if [ -z "$1" ]; then
    printf 'main:%s' "$2"
  elif id=$(dir_id "$1"); then
    printf 'dir:%s' "$id"
  else
    printf 'path:%s' "$1"
  fi
}

# "id" is what an action sends back with the name: see uiw_same. "icon"
# changes when the icon file does, so the window draws an icon again only then.
uiw_json_launchers() {
  local i=0 app target name icon main usable badge STATUS PS_RC="" PS_LIST="" PS_IDS="" PS_ALL=""
  launcher_rows
  [ "$LR_N" -eq 0 ] || proc_snapshot 2>/dev/null
  printf ',"profiles":['
  while [ "$i" -lt "$LR_N" ]; do
    app=${LR_PATH[$i]}; target=${LR_TARGET[$i]}
    launcher_status "$target" "${LR_DATA[$i]}" "${LR_MAIN[$i]}"
    badge=$(launcher_badge "$app" "$target" "${LR_PROFILE[$i]}")
    [ "${#badge}" -le 1 ] || badge=$(first_char "$badge")
    icon=$app
    [ ! -f "$app/Contents/Resources/icon.icns" ] || icon="$app/Contents/Resources/icon.icns"
    name=""
    [ -z "$target" ] || name=$(bundle_name "$target")
    main=false; [ "${LR_MAIN[$i]}" != 1 ] || main=true
    # A name that starts with a hyphen would be read as an option.
    usable=true; case "${LR_NAME[$i]}" in -*) usable=false ;; esac
    [ "$i" -eq 0 ] || printf ','
    printf '{"name":%s,"id":%s,"app":%s,"profile":%s,"status":%s,"main":%s,"badge":%s,"color":%s,"usable":%s,"icon":%s,"iconfile":%s}' \
      "$(json_str "${LR_NAME[$i]}")" "$(json_str "$(uiw_id "${LR_DATA[$i]}" "$target")")" \
      "$(json_str "$name")" "$(json_str "${LR_PROFILE[$i]}")" \
      "$(json_str "$STATUS")" "$main" "$(json_str "$badge")" \
      "$(json_str "$(launcher_color "$app" "${LR_NAME[$i]}")")" "$usable" \
      "$(json_str "$icon|$(/usr/bin/stat -f %m "$icon" 2>/dev/null)")" "$(json_str "$icon")"
    i=$((i + 1))
  done
  printf ']'
}

uiw_json_apps() {
  local app sep=""
  printf ',"apps":['
  while IFS= read -r app; do
    [ -n "$app" ] || continue
    printf '%s{"name":%s,"path":%s,"where":%s}' "$sep" "$(json_str "$(bundle_name "$app")")" \
      "$(json_str "$app")" "$(json_str "$(uiw_tilde "${app%/*}")")"
    sep=","
  done <<EOF
$(list_compatible_apps 2>/dev/null)
EOF
  printf ']'
}

# Not knowing which folders still have a launcher is not "none do": when the
# search was incomplete, nothing is offered for restore.
uiw_json_restorable() {
  local d label list ok=true sep=""
  list=$(orphan_dirs 2>/dev/null) || { ok=false; list=""; }
  printf ',"restorable":['
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    label=$(restore_label "$d") || continue
    printf '%s{"label":%s,"dir":%s,"folder":%s}' "$sep" "$(json_str "$label")" "$(json_str "$d")" \
      "$(json_str "${d##*/}")"
    sep=","
  done <<EOF
$list
EOF
  printf '],"restorable_ok":%s' "$ok"
}

# ---- one action

# Nothing to ask on: no input, and every question is answered "no".
uiw_quiet() {
  exec </dev/null
  # shellcheck disable=SC2329  # called by the cmd_* functions run after this
  { ask() { return 1; }; have_tty() { return 1; }; tty_opens() { return 1; }; }
}

# The card a click came from showed this name for this account. Go on only if
# the launcher of that name still opens the same account, read the same way as
# for the card. The name alone is not enough: after a rename made elsewhere,
# it can belong to another profile.
uiw_same() { # name, the id its card had
  local i=0
  case "$1" in
    -*) uiw_refuse "Its name starts with a hyphen. Use the terminal for it, and put ./ before the name." ;;
  esac
  launcher_rows
  while [ "$i" -lt "$LR_N" ]; do
    if [ "${LR_NAME[$i]}" = "$1" ]; then
      UIW_ROW=$i
      [ "$(uiw_id "${LR_DATA[$i]}" "${LR_TARGET[$i]}")" != "$2" ] || return 0
      break
    fi
    i=$((i + 1))
  done
  uiw_refuse "The list changed while you were choosing. It is up to date now; try again."
}

# Print a command as a person would type it, then run it.
uiw_run() { # command, then its words
  local a shown="aidentity $1"
  for a in "${@:2}"; do shown="$shown $(uiw_q "$a")"; done
  printf '%s\n' "$shown"
  "cmd_$1" "${@:2}"
}

uiw_do() { # verb, then its words
  local verb="${1:-}" list label d twins=0 nl=$'\n'
  local look=()
  [ $# -eq 0 ] || shift
  uiw_quiet
  case "$verb" in
    open|quit) # name, id
      [ $# -eq 2 ] || uiw_bad
      uiw_same "$1" "$2"
      uiw_run "$verb" "$1" ;;
    edit) # name, id, then what to change, each "" to leave it: a new profile
          # name, a badge ("none" or one character), a colour
      [ $# -eq 5 ] || uiw_bad
      uiw_same "$1" "$2"
      [ -n "$3$4$5" ] || uiw_refuse "Nothing was changed."
      case "$4" in
        none) look=(--no-badge) ;;
        ?*) look=(--badge "$4") ;;
        # The badge stays as it is. For a profile that has none, `set --color`
        # alone would give it one, so "no badge" is said again.
        *) [ -z "$5" ] || [ -n "$(launcher_badge "${LR_PATH[$UIW_ROW]}" "${LR_TARGET[$UIW_ROW]}" "${LR_PROFILE[$UIW_ROW]}")" ] \
             || look=(--no-badge) ;;
      esac
      [ -z "$5" ] || look=("${look[@]+"${look[@]}"}" --color "$5")
      # The look first, under the name the card showed; then the new name.
      [ "${#look[@]}" -eq 0 ] || uiw_run set "$1" "${look[@]}" || exit $?
      [ -z "$3" ] || uiw_run rename "$1" "$3" ;;
    remove) # name, id, keep or purge
      [ $# -eq 3 ] || uiw_bad
      uiw_same "$1" "$2"
      case "$3" in
        keep) uiw_run rm "$1" --yes ;;
        purge) uiw_run rm "$1" --purge --yes ;;
        *) uiw_bad ;;
      esac ;;
    add) # app (its path: two apps can share a name), profile name, badge, colour
      [ $# -eq 4 ] || uiw_bad
      case "$1" in /*) ;; *) uiw_bad ;; esac
      look=("$1" --profile "$2")
      case "$3" in '') ;; none) look=("${look[@]}" --no-badge) ;; *) look=("${look[@]}" --badge "$3") ;; esac
      [ -z "$4" ] || look=("${look[@]}" --color "$4")
      uiw_run add "${look[@]}" ;;
    restore) # the profile's folder
      [ $# -eq 1 ] || uiw_bad
      # Only while the folder still has no launcher, as far as can be known:
      # one may have been made for it since the list was read.
      list=$(orphan_dirs 2>/dev/null) \
        || uiw_refuse "A folder in $(uiw_tilde "$APPS_DIR") could not be read, so restoring here is not safe now. Check its permissions, then try again."
      case "$nl$list$nl" in
        *"$nl$1$nl"*) ;;
        *) uiw_refuse "That profile is not in the list of removed profiles any more: it has a launcher again, or its folder was moved. The list is up to date now." ;;
      esac
      label=$(restore_label "$1") || uiw_refuse "That profile's restore record cannot be read any more."
      printf 'aidentity restore %s\n' "$(uiw_q "$label")"
      # Typed in a terminal, that restores every removed profile of this name.
      # Here it is one folder, so say which when the name is not the only one.
      while IFS= read -r d; do
        [ -z "$d" ] || [ "$(restore_label "$d" 2>/dev/null)" != "$label" ] || twins=$((twins + 1))
      done <<EOF
$list
EOF
      [ "$twins" -le 1 ] || info "More than one removed profile is called $label. Only the one in the folder ${1##*/} is restored."
      restore_one "$1" ;;
    check)
      [ $# -eq 0 ] || uiw_bad
      uiw_run doctor || exit $?
      [ "$DOCTOR_PROBLEMS" -eq 0 ] || { [ "$DOCTOR_FIXABLE" -eq 0 ] || exit "$UIW_FIXABLE"; exit "$UIW_PROBLEMS"; } ;;
    fix)
      [ $# -eq 0 ] || uiw_bad
      uiw_run doctor --fix || exit $?
      [ "$DOCTOR_PROBLEMS" -eq 0 ] || exit "$UIW_PROBLEMS" ;;
    *) uiw_bad ;;
  esac
}
