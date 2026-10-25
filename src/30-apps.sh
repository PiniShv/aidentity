# --------------------------------------------------------- app discovery --

# True if the bundle is Chromium- or Electron-based, i.e. it understands
# --user-data-dir. Two structural signals, both just directory probes:
#   1. an Electron Framework                        (Claude, Slack, VS Code, Notion…)
#   2. a *.framework with Versions/*/Helpers/*.app  (Chromium forks: ChatGPT, Edge…)
#
# Deliberately no binary scanning here — this runs across every installed app,
# and grepping frameworks for the flag turned a listing into a 30-second wait.
is_chromium_app() {
  local app="$1" fw helper

  [ -d "$app/Contents/Frameworks/Electron Framework.framework" ] && return 0

  # A plain glob, not `compgen -G "$fw/…"`: compgen reads the whole argument as
  # a pattern, so an app at a path containing [ ] * or ? was never detected.
  for fw in "$app"/Contents/Frameworks/*.framework; do
    [ -d "$fw" ] || continue
    for helper in "$fw"/Versions/*/Helpers/*.app; do
      [ -d "$helper" ] && return 0
    done
  done

  return 1
}

# Same question, but allowed to be slow. Used only when the user names one
# specific app, so an unusual bundle layout still gets a fair hearing.
is_chromium_app_deep() {
  local app="$1" fw bin

  is_chromium_app "$app" && return 0
  command -v strings >/dev/null 2>&1 || return 1

  for fw in "$app"/Contents/Frameworks/*.framework; do
    [ -d "$fw" ] || continue
    bin="${fw%.framework}"; bin="$fw/Versions/Current/${bin##*/}"
    [ -f "$bin" ] || continue
    # No -q: grep -q stops at the first match, strings dies of SIGPIPE, and
    # pipefail turns that into "no match" — so this check could never succeed
    # on a binary big enough to matter.
    if strings -a "$bin" 2>/dev/null | grep -x -- "--user-data-dir" >/dev/null; then return 0; fi
  done

  return 1
}

bundle_id()   { /usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$1/Contents/Info.plist" 2>/dev/null; }
bundle_name() { basename "$1" .app; }

# Resolve a user-supplied app name or path to a bundle path.
# Always returns an ABSOLUTE path. A relative one ("Claude.app", typed from
# /Applications) was embedded verbatim in the launcher, which then resolved
# against the Finder's working directory of / and could never start the app.
# Only relative paths are rewritten. An absolute path is passed through as the
# user gave it, symlinks and all — resolving those too would silently repoint a
# launcher away from a deliberately symlinked app.
abs_bundle() {
  local p="${1%/}" d b
  case "$p" in /*) printf '%s' "$p"; return 0 ;; esac
  d=$(dirname "$p"); b=$(basename "$p")
  d=$(command cd -P "$d" 2>/dev/null && pwd) || return 1
  printf '%s/%s' "${d%/}" "$b"
}

resolve_app() {
  local q="$1" cand
  q="${q%/}"
  if [ -d "$q" ] && [ "${q##*.}" = "app" ]; then abs_bundle "$q"; return $?; fi
  local dir
  while IFS= read -r dir; do
    for cand in "$dir/$q.app" "$dir/$q"; do
      [ -d "$cand" ] && { printf '%s' "${cand%/}"; return 0; }
    done
  done <<EOF
$(app_search_dirs)
/System/Applications
EOF

  # Case-insensitive fallback over the same search path.
  local want; want=$(printf '%s' "$q" | tr '[:upper:]' '[:lower:]')
  while IFS= read -r dir; do
    [ -d "$dir" ] || continue
    for cand in "$dir"/*.app; do
      [ -d "$cand" ] || continue
      local n; n=$(bundle_name "$cand")
      if [ "$(printf '%s' "$n" | tr '[:upper:]' '[:lower:]')" = "$want" ]; then
        printf '%s' "$cand"; return 0
      fi
    done
  done <<EOF
$(app_search_dirs)
EOF
  return 1
}

# Where to look for installed apps, colon-separated.
#
# Overridable so the test suite and the documentation recording run against
# fixtures instead of whatever is really installed. Without this the suite
# scans the developer's own /Applications — which weakens its isolation claim —
# and any recorded demo would publish the operator's full app list.
app_search_dirs() {
  local raw="${AIDENTITY_APP_DIRS:-/Applications:$HOME/Applications}" d
  local oldifs="$IFS"; IFS=':'
  for d in $raw; do [ -n "$d" ] && printf '%s\n' "${d%/}"; done
  IFS="$oldifs"
}

# Every Chromium/Electron app installed, one path per line.
list_compatible_apps() {
  local dir app
  while IFS= read -r dir; do
    [ -d "$dir" ] || continue
    for app in "$dir"/*.app; do
      [ -d "$app" ] || continue
      is_our_launcher "$app" && continue
      is_chromium_app "$app" && printf '%s\n' "$app"
    done
  done <<EOF
$(app_search_dirs)
EOF
}

# Path of an app's .icns icon, if it declares one.
app_icns() {
  local icon_name
  icon_name=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIconFile" "$1/Contents/Info.plist" 2>/dev/null) || return 1
  [ -n "$icon_name" ] || return 1
  [ -f "$1/Contents/Resources/${icon_name%.icns}.icns" ] || return 1
  printf '%s' "$1/Contents/Resources/${icon_name%.icns}.icns"
}

copy_plain_icon() {
  local src
  src=$(app_icns "$1") || return 1
  cp "$src" "$2"
}

# Show a numbered menu of compatible apps and echo the chosen bundle path.
# The menu is drawn on stderr so that only the chosen path reaches stdout,
# which is what the caller captures.
pick_app() {
  local apps=() a i=1 choice
  while IFS= read -r a; do [ -n "$a" ] && apps+=("$a"); done <<EOF
$(list_compatible_apps)
EOF
  if [ "${#apps[@]}" -eq 0 ]; then
    warn "No compatible apps found on this Mac."
    return 1
  fi
  {
    printf '%sWhich app needs another account?%s\n\n' "$C_BOLD" "$C_RESET"
    for a in "${apps[@]}"; do printf '  %2d) %s\n' "$i" "$(bundle_name "$a")"; i=$((i+1)); done
    printf '\n'
  } >&2
  # Ask again on a typo. Returning on bad input ended the whole `setup`
  # walkthrough, because its loop cannot tell a typo from the end of input.
  # Only end of input (or q) gives up.
  while :; do
    choice=$(ask 'Number: ') || return 1
    choice=$(printf '%s' "$choice" | tr -d '[:space:]')
    case "$choice" in
      q|Q|quit) return 1 ;;
      # Five digits or more is never a menu number, and a long enough string
      # wraps bash's 64-bit arithmetic back into range.
      ''|*[!0-9]*|?????*) warn "Please enter a number from 1 to ${#apps[@]} (or q to stop)."; continue ;;
    esac
    if [ "$((10#$choice))" -lt 1 ] || [ "$((10#$choice))" -gt "${#apps[@]}" ]; then
      warn "Please enter a number from 1 to ${#apps[@]} (or q to stop)."; continue
    fi
    break
  done
  # 10# forces base 10. Plain $((choice-1)) reads a leading zero as octal, so
  # "010" selected the 8th app and "08"/"09" aborted the wizard outright.
  printf '%s' "${apps[$((10#$choice - 1))]}"
}
