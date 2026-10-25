# ------------------------------------------------- per-profile launch settings
#
# Extra switches and environment variables a launcher hands its app, and
# whether a VS Code-family app gets its own extensions folder. They travel as
# one text value, a line per setting: "arg<TAB>--lang=de", "env<TAB>NAME=value",
# "ext<TAB>1". validate_extras refuses a tab or line break inside a value, so
# the format cannot be confused.
TAB=$'\t'

extras_lines() { # kind (arg, env or ext), extras -> that kind's values
  local line
  while IFS= read -r line; do
    case "$line" in "$1$TAB"*) printf '%s\n' "${line#*"$TAB"}" ;; esac
  done <<EOF
$2
EOF
}

plist_array_get() { # plist file, key -> one value per line
  local i=0 v
  while v=$(/usr/libexec/PlistBuddy -c "Print :$2:$i" "$1" 2>/dev/null); do
    printf '%s\n' "$v"; i=$((i+1))
  done
}

# The settings a launcher's Info.plist (or a restore record) was built with.
extras_of() { # plist file
  local v
  while IFS= read -r v; do [ -n "$v" ] && printf 'arg%s%s\n' "$TAB" "$v"; done <<EOF
$(plist_array_get "$1" AIdentityArgs)
EOF
  while IFS= read -r v; do [ -n "$v" ] && printf 'env%s%s\n' "$TAB" "$v"; done <<EOF
$(plist_array_get "$1" AIdentityEnv)
EOF
  [ "$(/usr/libexec/PlistBuddy -c 'Print :AIdentityOwnExtensions' "$1" 2>/dev/null)" = "true" ] \
    && printf 'ext%s1\n' "$TAB"
  return 0
}

extras_plist_xml() { # extras -> the <key>…</key> entries that record them
  local v
  printf '<key>AIdentityArgs</key><array>'
  while IFS= read -r v; do [ -n "$v" ] && printf '<string>%s</string>' "$(xmlescape "$v")"; done <<EOF
$(extras_lines arg "$1")
EOF
  printf '</array><key>AIdentityEnv</key><array>'
  while IFS= read -r v; do [ -n "$v" ] && printf '<string>%s</string>' "$(xmlescape "$v")"; done <<EOF
$(extras_lines env "$1")
EOF
  printf '</array>'
  [ -n "$(extras_lines ext "$1")" ] && printf '<key>AIdentityOwnExtensions</key><true/>'
  return 0
}

# Launch settings are an allowlist. Many Chromium and Electron switches and
# variables can hand the app to another program or switch off its protections,
# and a launcher is one click for anyone at this Mac. Only settings with a
# plain job pass, and each value must have the exact shape that job needs.
ALLOWED_SWITCHES="--proxy-server --proxy-bypass-list --no-proxy-server --lang --locale --force-device-scale-factor --disable-gpu --disable-lcd-text"
ALLOWED_ENV="HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY http_proxy https_proxy all_proxy no_proxy LANG LC_ALL LC_CTYPE LC_MESSAGES TZ"

# A language tag: 2-3 lower-case letters, optionally "-" and 2-8 letters or
# digits (de, pt-BR, zh-Hant).
is_lang_tag() {
  local LC_ALL=C base="${1%%-*}" rest=""
  case "$1" in *-*) rest="${1#*-}" ;; esac
  case "$base" in [a-z][a-z]|[a-z][a-z][a-z]) ;; *) return 1 ;; esac
  case "$1" in *-) return 1 ;; esac
  [ -z "$rest" ] && return 0
  case "$rest" in *[!A-Za-z0-9]*) return 1 ;; esac
  [ "${#rest}" -ge 2 ] && [ "${#rest}" -le 8 ]
}

# A proxy server or bypass list: the characters those lists use, nothing else.
is_proxy_value() {
  local LC_ALL=C
  [ -n "$1" ] && [ "${#1}" -le 512 ] || return 1
  case "$1" in *[!A-Za-z0-9:/._\;=*,\<\>@+-]*) return 1 ;; esac
  return 0
}

validate_switch() {
  local LC_ALL=C s="$1" name val=""
  case "$s" in *[[:cntrl:]]*) warn "A switch cannot contain a tab, a line break or another control character."; return 1 ;; esac
  # Under C, [[:cntrl:]] stops at byte 127, but a terminal can read some later
  # bytes as control codes too. No allowed setting needs them, so refuse them
  # here, without printing the value back.
  case "$s" in *[!\ -~]*) warn "A switch can use only ASCII letters, digits and symbols."; return 1 ;; esac
  case "$s" in
    --[a-z]*) ;;
    *) warn "'$s' is not a switch. A switch looks like --lang=de or --disable-gpu."; return 1 ;;
  esac
  name=${s#--}
  case "$name" in *=*) val=${name#*=}; name=${name%%=*} ;; esac
  case "$name" in
    proxy-server|proxy-bypass-list)
      is_proxy_value "$val" || { warn "--$name needs a proxy value, e.g. --$name=socks5://127.0.0.1:1080"; return 1; } ;;
    no-proxy-server|disable-gpu|disable-lcd-text)
      case "$s" in *=*) warn "--$name takes no value."; return 1 ;; esac ;;
    lang|locale)
      is_lang_tag "$val" || { warn "--$name needs a language code, e.g. --$name=de or --$name=pt-BR."; return 1; } ;;
    force-device-scale-factor)
      if ! printf '%s' "$val" | grep -Eq '^[0-9]{1,2}(\.[0-9]{1,3})?$' \
         || ! awk -v v="$val" 'BEGIN { exit !(v >= 0.5 && v <= 4) }'; then
        warn "--force-device-scale-factor needs a number from 0.5 to 4."; return 1
      fi ;;
    *)
      warn "--$name is not one aidentity passes on. Allowed: $ALLOWED_SWITCHES."
      return 1 ;;
  esac
  return 0
}

validate_env() {
  local LC_ALL=C kv="$1" name val
  case "$kv" in *[[:cntrl:]]*) warn "An environment value cannot contain a tab, a line break or another control character."; return 1 ;; esac
  # Bytes above 127 too, as in validate_switch.
  case "$kv" in *[!\ -~]*) warn "An environment value can use only ASCII letters, digits and symbols."; return 1 ;; esac
  case "$kv" in
    *=*) ;;
    *) warn "'$kv' must look like NAME=value."; return 1 ;;
  esac
  name=${kv%%=*}; val=${kv#*=}
  case "$name" in
    ''|[0-9]*|*[!A-Za-z0-9_]*) warn "'$name' is not a variable name."; return 1 ;;
  esac
  case " $ALLOWED_ENV " in
    *" $name "*) ;;
    *) warn "$name is not one aidentity passes on. Allowed: $ALLOWED_ENV."; return 1 ;;
  esac
  case "$name" in
    *_PROXY|*_proxy)
      is_proxy_value "$val" || { warn "$name needs a proxy value, e.g. $name=http://proxy.example:8080"; return 1; } ;;
    LANG|LC_*)
      case "$val" in ''|*[!A-Za-z0-9_.@-]*) warn "$name needs a locale, e.g. $name=de_DE.UTF-8"; return 1 ;; esac ;;
    TZ)
      case "$val" in ''|*..*|*[!A-Za-z0-9_+:/-]*) warn "TZ needs a time zone, e.g. TZ=Europe/Berlin"; return 1 ;; esac ;;
  esac
  return 0
}

# A bundle identifier as restore trusts one: ASCII letters, digits, dots and
# hyphens.
is_bundle_id() {
  local LC_ALL=C
  case "$1" in ''|*[!A-Za-z0-9.-]*) return 1 ;; esac
  return 0
}

# VS Code and its forks keep extensions outside --user-data-dir, so profiles
# share them unless each gets its own --extensions-dir. A fork is recognised by
# its product.json naming the same bundle identifier as the app itself.
is_vscode_family() {
  local pj="$1/Contents/Resources/app/product.json" bid pbid
  [ -f "$pj" ] || return 1
  bid=$(/usr/bin/plutil -extract CFBundleIdentifier raw -o - "$1/Contents/Info.plist" 2>/dev/null) || return 1
  pbid=$(/usr/bin/plutil -extract darwinBundleIdentifier raw -o - "$pj" 2>/dev/null) || return 1
  [ -n "$bid" ] && [ "$bid" = "$pbid" ] && \
    /usr/bin/plutil -extract dataFolderName raw -o - "$pj" >/dev/null 2>&1
}

# VS Code and its forks open a socket in their --user-data-dir, named after the
# first four characters of their version: ".../1.14-main.sock". When that path
# does not fit in a macOS socket address, the app quits at start and no window
# opens. The address holds 104 bytes, and C code keeps the last one for a
# closing zero, so 103 is the longest safe path. The default data folder, a
# long app name and a 40-character profile name together go past it, so add,
# rename and restore check first.
SOCKET_PATH_MAX=103

socket_path_bytes() { # app, data dir -> bytes in the path of the app's socket
  local ver name=14
  ver=$(/usr/bin/plutil -extract version raw -o - "$1/Contents/Resources/app/product.json" 2>/dev/null) || ver=""
  # No version to read: assume four characters, the most the name takes.
  [ -n "$ver" ] && name=$(( $(printf '%s' "${ver:0:4}" | wc -c) + 10 ))
  # Bytes, not characters: a home folder's name can hold UTF-8.
  printf '%s' $(( $(printf '%s' "$2" | wc -c) + 1 + name ))
}

# The longest profile name the app can open in the data folder, where `add`
# and `rename` put its folder: "$DATA_ROOT/<app>-<name>". Each character of a
# profile name is one byte of that folder's name. Below 1, no name fits: the
# data folder itself is too deep, which a long user name alone can cause.
profile_name_room() { # app
  printf '%s' $(( SOCKET_PATH_MAX - $(socket_path_bytes "$1" "$DATA_ROOT/$(slugify "$(bundle_name "$1") ")") ))
}

# A number and its unit, in the singular when it is 1: "1 byte", "3 bytes".
count() { # number, unit
  if [ "$1" -eq 1 ]; then printf '1 %s' "$2"; else printf '%s %ss' "$1" "$2"; fi
}

# Warn and fail when a VS Code-family app could not open a profile kept in this
# data dir. What to do instead depends on the command: a new profile or a
# rename needs a shorter name, a profile that exists needs a rename, and a
# profile being restored keeps its folder, so that folder needs a shorter name.
socket_path_ok() { # app, data dir, label, new|existing|restore
  local n room fix
  is_vscode_family "$1" || return 0
  n=$(socket_path_bytes "$1" "$2")
  [ "$n" -gt "$SOCKET_PATH_MAX" ] || return 0
  if [ "$4" = "restore" ]; then
    room=$(( $(printf '%s' "${2##*/}" | wc -c) - (n - SOCKET_PATH_MAX) ))
  else
    room=$(profile_name_room "$1")
  fi
  if [ "$room" -lt 1 ]; then
    fix="Even a one-character name is too long in this data folder. Set
    AIDENTITY_DATA_ROOT to a folder whose path is at least $(count $((1 - room)) byte) shorter."
  else
    case "$4" in
      existing) fix="Rename it to a name of at most $(count "$room" character):
      aidentity rename \"$3\" \"<new name>\"" ;;
      restore) fix="Rename this folder to a name of at most $(count "$room" character), then run restore again:
      $2" ;;
      *) fix="Use a profile name of at most $(count "$room" character), or set AIDENTITY_DATA_ROOT
    to a shorter folder." ;;
    esac
  fi
  warn "$(bundle_name "$1") cannot open '$3': its profile folder path is too long.
    The app makes a socket in that folder. macOS allows a socket path of
    $SOCKET_PATH_MAX bytes, and this one would be $n.
    $fix"
  return 1
}

validate_extras() { # extras, target app, kind
  local v
  while IFS= read -r v; do [ -z "$v" ] || validate_switch "$v" || return 1; done <<EOF
$(extras_lines arg "$1")
EOF
  while IFS= read -r v; do [ -z "$v" ] || validate_env "$v" || return 1; done <<EOF
$(extras_lines env "$1")
EOF
  if [ -n "$(extras_lines ext "$1")" ]; then
    if [ "${3:-}" = "main" ]; then
      warn "--own-extensions applies to profiles, not to the original account."; return 1
    fi
    if ! is_vscode_family "$2"; then
      warn "--own-extensions only applies to VS Code and its forks (Cursor, Kiro)."; return 1
    fi
  fi
  return 0
}

# Stored settings that are no longer allowed — from an older version, a
# hand-edited file, or an app that stopped being a VS Code fork — are dropped
# with a note, so rebuild, restore and doctor --fix can still finish. New
# settings from the command line are checked strictly instead.
filter_extras() { # extras, target app, kind -> the allowed lines
  local line
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    if validate_extras "$line" "$2" "$3" 2>/dev/null; then
      printf '%s\n' "$line"
    else
      warn "Dropped a stored launch setting that is not allowed: ${line#*"$TAB"}"
    fi
  done <<EOF
$1
EOF
}

# Merge new settings into old ones, the newest winning: a switch replaces one
# with the same name (--lang=fr replaces --lang=de; the app would only use the
# last anyway), a variable replaces one with the same NAME, --proxy-server and
# --no-proxy-server replace each other, and "ext" follows the last word.
extras_merge() { # old extras, new extras (lines; "noext" clears ext)
  local line out="" name
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    case "$line" in
      "env$TAB"*)
        name=${line#*"$TAB"}; name=${name%%=*}
        out=$(printf '%s\n' "$out" | /usr/bin/grep -v "^env$TAB$name=" || true) ;;
      "arg$TAB"*)
        name=${line#*"$TAB"}; name=${name%%=*}
        case "$name" in
          --proxy-server|--no-proxy-server)
            out=$(printf '%s\n' "$out" | /usr/bin/grep -v -e "^arg$TAB--proxy-server=" -e "^arg$TAB--no-proxy-server\$" || true) ;;
          *)
            out=$(printf '%s\n' "$out" | /usr/bin/grep -v -e "^arg$TAB$name=" -e "^arg$TAB$name\$" || true) ;;
        esac ;;
      "ext$TAB"*|"noext")
        out=$(printf '%s\n' "$out" | /usr/bin/grep -v "^ext$TAB" || true)
        [ "$line" = "noext" ] && continue ;;
    esac
    out="${out:+$out
}$line"
  done <<EOF
$1
$2
EOF
  printf '%s' "$out" | /usr/bin/grep -v '^$' || true
}
