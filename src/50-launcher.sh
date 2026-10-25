# -------------------------------------------------------------- launcher --

is_our_launcher() {
  [ -d "$1" ] || return 1
  /usr/libexec/PlistBuddy -c "Print :$MARKER_KEY" "$1/Contents/Info.plist" >/dev/null 2>&1
}

plist_get() { /usr/libexec/PlistBuddy -c "Print :$2" "$1/Contents/Info.plist" 2>/dev/null; }

# A launcher made with `add --main` opens the app's own, original account. It
# records no data directory, and nothing ever deletes or moves the app's data.
is_main_launcher() { [ "$(plist_get "$1" AIdentityMain)" = "true" ]; }

# The badge and colour a launcher was built with. 1.0.0 recorded neither key,
# and an empty badge means "no badge" — so reading a missing key as empty
# stripped the badge from every 1.0.0 launcher on its first rebuild or rename.
# For those, rebuild 1.0.0's defaults: the profile's first letter, unless the
# icon is the app's own byte for byte, which is what 1.0.0's --no-badge wrote.
is_legacy_launcher() {
  ! /usr/libexec/PlistBuddy -c "Print :AIdentityBadge" "$1/Contents/Info.plist" >/dev/null 2>&1
}

launcher_badge() { # launcher, target app, profile
  local src
  if ! is_legacy_launcher "$1"; then plist_get "$1" AIdentityBadge; return 0; fi
  if src=$(app_icns "$2") && cmp -s "$src" "$1/Contents/Resources/icon.icns"; then
    return 0
  fi
  first_upper "$3"
}

launcher_color() { # launcher, label
  local hex
  hex=$(plist_get "$1" AIdentityColor)
  [ -n "$hex" ] || hex=$(color_hex "$(auto_color "$2")")
  printf '%s' "$hex"
}

# A directory's identity, so two spellings of one directory compare equal: a
# symlinked root, "//", a trailing slash, /var against /private/var.
# /usr/bin/stat by full path: a GNU stat earlier on PATH reads -f as "file
# system" and prints one value for every directory, which made every
# directory look claimed. -L: the directory a symlink points at, not the link
# itself — or a profile whose recorded path is a symlink read as unclaimed,
# and prune deleted what it pointed to.
dir_id() { [ -d "$1" ] && /usr/bin/stat -L -f '%d:%i' "$1" 2>/dev/null; }

# Refuse to touch a bundle unless it is demonstrably one of ours.
assert_ours() {
  local app="$1"
  case "$app" in
    */*.app) ;;
    *) die "Refusing to operate on '$app' — not an .app bundle." ;;
  esac
  is_our_launcher "$app" || die "Refusing to touch '$app' — it was not created by aidentity."
}

# Two traps here, both of which produced a wrong answer in testing:
#
#   1. On macOS `pgrep -a` means "include ancestors", not "print the command
#      line" as it does on Linux: -l is what prints argv. -a alone gives bare
#      PIDs and the match below can never succeed; -afl prints argv AND keeps
#      the caller's own ancestors in the list.
#   2. The list must be captured BEFORE matching. Piping pgrep straight into
#      grep starts both at once, and the grep's own argv contains the path we
#      are searching for — so pgrep matches the grep and every profile looks
#      like it is running.
#
# One look at the processes, held in the caller's own
# `local PS_RC="" PS_LIST="" PS_IDS="" PS_ALL=""`: pgrep's exit status (2 or
# more is a failure) and its list; then, worked out when first needed, the
# folder identities in that list (proc_dir_ids) and every process (ps).
proc_snapshot() {
  # -a: on macOS pgrep leaves out the caller's own ancestors unless asked.
  PS_RC=0; PS_LIST=$(pgrep -afl "user-data-dir=" 2>/dev/null) || PS_RC=$?
  PS_IDS=""; PS_ALL=""
  [ "$PS_RC" -le 1 ] || warn "Could not check which profiles are running (pgrep exited $PS_RC); assuming they are."
}

# Whether a process runs on the profile folder $1, from a fresh look: every
# delete asks this, and rm asks again after its prompt.
running_on_profile() {
  [ -n "$1" ] || return 1
  local PS_RC="" PS_LIST="" PS_IDS="" PS_ALL=""
  proc_snapshot
  running_in_snapshot "$1"
}

# The same question against the caller's snapshot, for list and the menu.
# Never for a delete.
#
# The match is anchored on purpose. A bare substring test made ".../claude-work"
# match a process running ".../claude-work-2", so one profile reported another
# as running and refused to remove or rebuild it. The flag is always followed by
# a space or the end of the argument list, so require one of those.
#
# The match runs in the shell, never as `printf … | grep -q`. grep -q exits at
# the first match; real Electron helpers make this list 100 KB, so printf then
# died of SIGPIPE and pipefail turned the pipeline into "no match". A running
# profile read as stopped exactly when its line came early — fail OPEN, on a
# guard whose whole job is to stop a delete. Quoting "$1" inside the pattern
# keeps [ * ? in a path literal.
running_in_snapshot() {
  local want nl=$'\n'
  [ -n "$1" ] || return 1
  # pgrep exits 1 for "no match" but >=2 for a real failure. Treating those the
  # same made a data-loss guard fail OPEN — a broken pgrep read as "nothing is
  # running" and the delete went ahead. Anything but 0 or 1 is reported as
  # running, so the caller refuses to delete.
  [ "$PS_RC" -le 1 ] || return 0
  [ "$PS_RC" -eq 0 ] && [ -n "$PS_LIST" ] || return 1
  case "$PS_LIST$nl" in
    *"user-data-dir=$1 "*|*"user-data-dir=$1$nl"*) return 0 ;;
  esac
  # The same directory under another spelling — a symlinked root, "//", a
  # trailing slash — is the same profile: compare directory identities.
  want=$(/usr/bin/stat -L -f '%d:%i' "$1" 2>/dev/null) || return 1
  [ -n "$PS_IDS" ] || PS_IDS=$(proc_dir_ids "$PS_LIST")
  case "$PS_IDS" in *"|$want|"*) return 0 ;; esac
  return 1
}

# The identity (device:inode) of each path a process in the list names with
# --user-data-dir, up to the next " --" or the end of its line, as "|id|id|".
# Each distinct path is looked at once.
proc_dir_ids() { # process list
  local line rest path id seen="|" ids="|"
  while IFS= read -r line; do
    rest=$line
    while :; do
      case "$rest" in *user-data-dir=*) rest=${rest#*user-data-dir=} ;; *) break ;; esac
      path=${rest%% --*}
      case "$seen" in *"|$path|"*) continue ;; esac
      seen="$seen$path|"
      id=$(/usr/bin/stat -L -f '%d:%i' "$path" 2>/dev/null) && ids="$ids$id|"
    done
  done <<EOF
$1
EOF
  printf '%s' "$ids"
}

# The app's main executable, from its Info.plist.
app_exe() {
  local exe
  exe=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$1/Contents/Info.plist" 2>/dev/null) || return 1
  [ -n "$exe" ] || return 1
  printf '%s' "$1/Contents/MacOS/$exe"
}

# Whether any copy of the app is running, on any account.
app_running() {
  local exe list line
  exe=$(app_exe "$1") || return 1
  list=$(ps -axww -o command= 2>/dev/null) || return 1
  while IFS= read -r line; do
    case "$line" in "$exe"|"$exe "*) return 0 ;; esac
  done <<EOF
$list
EOF
  return 1
}

# A file's own identity (device:inode). No -L: an executable that is a
# symlink is told apart from the file it points to. Symlinks earlier in the
# path are followed, as for any path.
exe_id() { /usr/bin/stat -f '%d:%i' "$1" 2>/dev/null; }

# Whether a command line starts with the app's main executable $1, then a
# space or the end. First by the path as recorded, then by the file itself:
# Launch Services starts an app by its real path, symlinks resolved and each
# name in its real case, so a launcher that records ".../claude.app" or a path
# through a symlink sees a copy started as ".../Claude.app/...". The path may
# hold spaces, so each place where "/<executable name>" ends at a space or at
# the end of the line is tried, and compared by exe_id with $2.
starts_with_exe() { # executable, its exe_id or "", command line
  local exe="$1" want="$2" cmd="$3" base pre="" rest
  case "$cmd" in "$exe"|"$exe "*) return 0 ;; /*) ;; *) return 1 ;; esac
  [ -n "$want" ] || return 1
  base=${exe##*/}; rest=$cmd
  while :; do
    case "$rest" in
      *"/$base "*) pre="$pre${rest%%"/$base "*}/$base"; rest=${rest#*"/$base "} ;;
      *"/$base") pre="$pre$rest"; rest="" ;;
      *) return 1 ;;
    esac
    [ "$(exe_id "$pre")" = "$want" ] && return 0
    [ -n "$rest" ] || return 1
    pre="$pre "
  done
}

# Whether the app is running on its own account, with no --user-data-dir: the
# instance a --main launcher opens. Matched in the shell for the same reason as
# above — a pipe into grep -q fails open on a long process list. ps runs once
# per snapshot, in UTF-8: in the C locale it writes a non-ASCII byte as
# "M-CM-)", and a path with "é" never matched. " " stands for a ps that failed.
main_running() { # app
  local exe id line
  exe=$(app_exe "$1") || return 1
  id=$(exe_id "$exe") || id=""
  [ -n "$PS_ALL" ] || PS_ALL=$(LC_ALL=en_US.UTF-8 ps -axww -o command= 2>/dev/null) || PS_ALL=" "
  while IFS= read -r line; do
    case "$line" in *--user-data-dir=*) continue ;; esac
    starts_with_exe "$exe" "$id" "$line" && return 0
  done <<EOF
$PS_ALL
EOF
  return 1
}

# A recorded data directory is ours only if it sits genuinely inside the data
# root. This is the last thing standing between a hand-edited Info.plist and a
# move to the Trash, so it resolves the path rather than pattern-matching the
# string.
#
# Three ways a string test alone was shown to fail:
#   "$DATA_ROOT/../elsewhere"  — traversal
#   "$DATA_ROOT//"             — matches "$DATA_ROOT"/?* yet IS the root, so
#                                rm -rf took every profile with it
#   "$DATA_ROOT/link/x"        — link is a symlink out of the root, and rm -rf
#                                follows it
# Resolving both sides with `cd -P` collapses all three: a path that resolves
# to the root itself, or to anywhere outside it, is rejected.
data_is_ours() {
  local d="$1" real root head tail
  [ -n "$d" ] || return 1

  # Absolute only. A relative path also made the walk-up loop below spin
  # forever: "${head%/*}" reaches a fixed point that never equals the input,
  # so the guard never fired and `tail` grew without bound.
  case "$d" in /*) ;; *) return 1 ;; esac

  # No dot segments at all. The tail is re-attached lexically further down, so
  # a ".." inside it would never be resolved and the answer would be wrong.
  case "$d" in
    *"/../"*|*"/.."|*"/./"*|*"/."|*"/") return 1 ;;
  esac

  root=$(command cd -P "$DATA_ROOT" 2>/dev/null && pwd -P) || return 1
  [ -n "$root" ] || return 1

  # Resolve the deepest existing ancestor, then re-attach the rest, so a
  # not-yet-created directory is still judged by where it would land. This
  # terminates because the path is absolute: head shrinks one component per
  # pass and bottoms out at "/", which always exists.
  head="$d"; tail=""
  while [ ! -d "$head" ]; do
    tail="${head##*/}${tail:+/$tail}"
    head="${head%/*}"
    [ -z "$head" ] && head="/"
  done
  real=$(command cd -P "$head" 2>/dev/null && pwd -P) || return 1
  [ -n "$tail" ] && real="${real%/}/$tail"

  # Must be strictly below the root — never the root itself.
  [ "$real" = "$root" ] && return 1
  case "$real" in
    "$root"/?*) return 0 ;;
    *) return 1 ;;
  esac
}

# A launcher is built in a hidden staging directory beside its final place and
# moved in only once it is complete, so a failed `set`, `rebuild` or `rename`
# leaves the working launcher exactly as it was. The old code deleted the
# launcher first and then died half way, which left the profile with no
# launcher — and its signed-in data looking orphaned to `prune`. If we are
# interrupted mid-build, the staging directory is removed on the way out.
BUILD_STAGE=""
# While a launcher is being swapped, the old one sits in the staging directory
# under SWAP_PREV. If anything stops us there — an interrupt, a failed second
# move — it goes back to SWAP_DST before the stage is removed. Deleting the
# stage blindly deleted the only copy of the launcher.
SWAP_DST=""
SWAP_PREV=""
# Set by rename between moving a profile's data and finishing its launcher, as
# "new path|old path": an interrupt in that window moves the data back, so the
# old launcher still finds it.
RENAME_UNDO=""

# Returns non-zero when something in the staging directory could not be
# removed (a locked file), so a caller can say so instead of claiming success.
_cleanup_stage() {
  local rc=0
  if [ -n "$SWAP_PREV" ] && [ -e "$SWAP_PREV" ] && [ ! -e "$SWAP_DST" ]; then
    if ! mv "$SWAP_PREV" "$SWAP_DST" 2>/dev/null; then
      warn "Interrupted while replacing a launcher. The old one is still at:
    $SWAP_PREV
    Move it back to: $SWAP_DST"
      SWAP_PREV=""; SWAP_DST=""; BUILD_STAGE=""
      return 1
    fi
  fi
  SWAP_PREV=""; SWAP_DST=""
  if [ -n "$BUILD_STAGE" ]; then
    rm -rf "$BUILD_STAGE" 2>/dev/null
    [ -e "$BUILD_STAGE" ] && rc=1
    BUILD_STAGE=""
  fi
  return "$rc"
}

_undo_rename() {
  local from to
  [ -n "$RENAME_UNDO" ] || return 0
  from=${RENAME_UNDO%%|*}; to=${RENAME_UNDO#*|}
  RENAME_UNDO=""
  if [ -d "$from" ] && [ ! -e "$to" ] && mv "$from" "$to" 2>/dev/null; then
    warn "Interrupted: the profile was moved back to $to; nothing was renamed."
  else
    warn "Interrupted during rename. The profile data is at: $from"
  fi
}

# Set by update while it holds a download folder and a staged copy of the new
# script beside the old one. Both go on the way out, finished or not, so a
# failed or interrupted update leaves nothing behind. VERIFIED_SUM is the
# checksum the download passed (set by verify_release_file).
UPDATE_TMP=""
INSTALL_STAGED=""
VERIFIED_SUM=""

_cleanup_update() {
  [ -n "$INSTALL_STAGED" ] && rm -f "$INSTALL_STAGED" 2>/dev/null
  # Only ever a folder update made itself with mktemp.
  case "$UPDATE_TMP" in */aidentity-update.?*) rm -rf "$UPDATE_TMP" 2>/dev/null ;; esac
  INSTALL_STAGED=""; UPDATE_TMP=""
  return 0
}

# Set by import while it holds the folder it converts its file in.
IMPORT_TMP=""

_cleanup_import() {
  # Only ever a folder import made itself with mktemp.
  case "$IMPORT_TMP" in */aidentity-import.?*) rm -rf "$IMPORT_TMP" 2>/dev/null ;; esac
  IMPORT_TMP=""
  return 0
}

_on_exit() { _cleanup_stage; _undo_rename; _cleanup_update; _cleanup_import; return 0; }
trap '_on_exit' EXIT
trap '_on_exit; exit 130' INT
trap '_on_exit; exit 143' TERM
trap '_on_exit; exit 129' HUP

# Build or replace a launcher. On failure it warns and returns non-zero; it
# never exits. Every caller has a recovery path — rename moves the data back,
# setup carries on with the next account, rebuild --all counts the failure —
# and the die() calls that used to live here skipped every one of them.
# kind is "main" for a launcher that opens the app's own account (no data dir).
build_launcher() {
  local src_app="$1" profile="$2" data_dir="$3" label="$4" letter="$5" hex="$6" kind="${7:-}"
  local extras="${8:-}"
  local dst="$APPS_DIR/$label.app" rc

  # Only ever replace a bundle that is ours.
  if [ -e "$dst" ] && ! is_our_launcher "$dst"; then
    warn "Refusing to replace '$dst' — it was not created by aidentity."
    return 1
  fi
  # Without a data directory a launcher opens the app's own account. That must
  # only ever happen on purpose, never because a plist lost its key.
  if [ "$kind" != "main" ] && [ -z "$data_dir" ]; then
    warn "No profile directory recorded for '$label'. Refusing to build a launcher
    that would open the app's original account instead."
    return 1
  fi

  # Every launch setting is checked here, wherever it came from: the command
  # line, a launcher's own Info.plist, or a restore record someone could edit.
  validate_extras "$extras" "$src_app" "$kind" || return 1

  mkdir -p "$APPS_DIR" 2>/dev/null || { warn "Could not create $APPS_DIR"; return 1; }
  if [ "$kind" != "main" ]; then
    # Owner-only, like the directories the apps create for themselves. Only
    # directories made here are affected; an existing root keeps its mode.
    ( umask 077 && mkdir -p "$data_dir" ) 2>/dev/null \
      || { warn "Could not create $data_dir"; return 1; }
  fi

  BUILD_STAGE=$(mktemp -d "$APPS_DIR/.aidentity-build.XXXXXX" 2>/dev/null) \
    || { BUILD_STAGE=""; warn "Could not write to $APPS_DIR"; return 1; }

  _assemble_launcher "$BUILD_STAGE/$label.app" "$src_app" "$profile" "$data_dir" \
      "$label" "$letter" "$hex" "$kind" "$extras" \
    && _swap_in "$BUILD_STAGE/$label.app" "$dst" "$BUILD_STAGE"
  rc=$?
  _cleanup_stage
  [ "$rc" -eq 0 ] || return 1

  if [ "$kind" != "main" ]; then
    write_restore_record "$data_dir" "$profile" "$src_app" "$letter" "$hex" "$extras" \
      || warn "Could not write the restore record in $data_dir. The launcher works; 'aidentity restore' will not know this profile."
  fi

  # Nudge Launch Services so the icon and name appear immediately.
  local lsreg="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
  [ -x "$lsreg" ] && "$lsreg" -f "$dst" >/dev/null 2>&1
  touch "$dst"
  return 0
}

# A small record inside each profile directory of what its launcher was:
# profile name, target app, badge, colour. The directory outlives the launcher —
# a launcher deleted in Finder, or removed with `rm` without --purge — and with
# this record `aidentity restore` can rebuild the launcher instead of `prune`
# only offering to move a signed-in session to the Trash. Chromium and
# Electron ignore a file they do not know in their data directory. Written to a
# temporary name and moved into place, owner-only like the rest of the
# directory.
RESTORE_RECORD=".aidentity-profile.plist"

write_restore_record() { # data_dir, profile, target app, badge, colour, [extras]
  local dir="$1" tmp bid extras="${6:-}"
  [ -d "$dir" ] || return 1
  bid=$(bundle_id "$3")
  tmp=$(mktemp "$dir/.aidentity-record.XXXXXX" 2>/dev/null) || return 1
  cat > "$tmp" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>$MARKER_KEY</key><string>$(xmlescape "$2")</string>
	<key>AIdentityTargetApp</key><string>$(xmlescape "$3")</string>
	<key>AIdentityTargetBundleID</key><string>$(xmlescape "$bid")</string>
	<key>AIdentityBadge</key><string>$(xmlescape "$4")</string>
	<key>AIdentityColor</key><string>$(xmlescape "$5")</string>
	$(extras_plist_xml "$extras")
	<key>AIdentityVersion</key><string>$AIDENTITY_VERSION</string>
</dict>
</plist>
PLIST
  if plutil -lint "$tmp" >/dev/null 2>&1 && chmod 600 "$tmp" && mv -f "$tmp" "$dir/$RESTORE_RECORD"; then
    return 0
  fi
  rm -f "$tmp"
  return 1
}

record_get() { /usr/libexec/PlistBuddy -c "Print :$2" "$1/$RESTORE_RECORD" 2>/dev/null; }
