# ------------------------------------------------------------ validation --

# A profile name becomes a directory name, a bundle name and a shell string.
# Restricting it up front is what lets everything downstream stay simple.
# Returns non-zero and explains, rather than exiting. The wizard needs to
# re-prompt on a bad name, and the old exit-based version forced it to spawn a
# subshell and throw the message away — so the user saw a generic rule that did
# not match the actual reason their name was refused.
#
# LC_ALL=C in this function and the other checks below: in a UTF-8 locale,
# the default in Terminal, bash lets [A-Za-z] match letters such as é, ß and
# fullwidth ａ. Under C it means the ASCII letters only, whatever the locale.
validate_profile_name() {
  local LC_ALL=C name="$1"
  [ -n "$name" ] || { warn "Profile name cannot be empty."; return 1; }
  case "$name" in
    *[!A-Za-z0-9\ _-]*)
      warn "Profile name may only contain letters, numbers, spaces, hyphens and underscores.
    Got: '$name'"; return 1 ;;
  esac
  [ "${#name}" -le 40 ] || { warn "Profile name is too long (max 40 characters)."; return 1; }
  case "$name" in
    " "*|*" ") warn "Profile name cannot start or end with a space."; return 1 ;;
    .*) warn "Profile name cannot start with a dot."; return 1 ;;
    -*) warn "Profile name cannot start with a hyphen — it would read as an option."; return 1 ;;
  esac
  return 0
}

slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr ' _' '-' | tr -cd 'a-z0-9-'
}

# Quote an arbitrary string as a single-quoted shell literal, so it can be
# embedded in the generated launcher without any escaping ambiguity.
shquote() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

# Escape a string for use as XML character data in the generated Info.plist.
# Profile names are validated, but APP names are whatever is on disk — and
# "Barnes & Noble.app" or any name containing < or > produced a plist that
# plutil rejects, leaving a bundle the tool could no longer read or remove.
xmlescape() {
  printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'
}

# A string as a JSON string, quotes included, for `list --json`. App names and
# paths are whatever is on disk, so a quote, a backslash or a control
# character must not end the string early. Quote and backslash get a
# backslash, \n \r \t their short forms, every other control character
# \u00XX. Anything else, UTF-8 included, is valid JSON as it is. A loop in the
# shell, not sed: sed works a line at a time and never sees a newline.
JSON_CTRL=$'\001\002\003\004\005\006\007\010\011\012\013\014\015\016\017\020\021\022\023\024\025\026\027\030\031\032\033\034\035\036\037'

json_str() {
  local s="$1" out="" c u i=0 n=${#1}
  while [ "$i" -lt "$n" ]; do
    c=${s:$i:1}
    case "$c" in
      '"')   out="$out\\\"" ;;
      \\)    out="$out\\\\" ;;
      $'\n') out="$out\\n" ;;
      $'\r') out="$out\\r" ;;
      $'\t') out="$out\\t" ;;
      *) case "$JSON_CTRL" in
           *"$c"*) printf -v u '\\u%04x' "'$c"; out="$out$u" ;;
           *) out="$out$c" ;;
         esac ;;
    esac
    i=$((i+1))
  done
  printf '"%s"' "$out"
}

# The same, but null for an empty value: a key that was never recorded.
json_str_or_null() { if [ -n "$1" ]; then json_str "$1"; else printf 'null'; fi; }

# One value per line -> a JSON array of strings. Blank lines are skipped.
json_lines() {
  local v sep=""
  printf '['
  while IFS= read -r v; do
    [ -n "$v" ] || continue
    printf '%s%s' "$sep" "$(json_str "$v")"; sep=","
  done <<EOF
$1
EOF
  printf ']'
}
