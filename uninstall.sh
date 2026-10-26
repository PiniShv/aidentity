#!/usr/bin/env bash
#
# aidentity uninstaller
# =====================
#
#   ./uninstall.sh
#
# Two separate things can be removed, and this script treats them separately:
#
#   1. The aidentity command itself. Removed without asking — that is what you
#      ran this for. Deleting it does not affect any launcher you already built;
#      each launcher is a standalone .app that holds no reference to the tool.
#
#   2. Your launchers and their profile data. Offered, never assumed. This is
#      the part that signs accounts out and takes local app state away, so it
#      prints every path first and then waits for you to type a word. Answer
#      anything else and nothing is removed. Launchers are deleted; profile
#      data is moved to the Trash, so it can still be put back.
#
# The safety rule is the same one aidentity itself uses: a bundle is only ever
# deleted if its Info.plist carries the "AIdentityProfile" key, which only
# aidentity writes. A real app that happens to sit in the same folder — or an
# app named after one of your profiles — is never touched. Profile data is only
# moved to the Trash from inside the aidentity data root; a path recorded outside
# it, or one that walks back out of it with "..", is reported and left alone.
#
# The command file gets the same treatment: a file called "aidentity" is only
# removed once it has been read and found to be aidentity. Your own script of
# that name, a Homebrew-managed copy, and a repository checkout are all left for
# you to deal with.
#
# Nothing here uses sudo. If the command lives somewhere you cannot write, the
# exact sudo line is printed for you to run yourself.
#
# Environment overrides (match the ones aidentity uses):
#   AIDENTITY_INSTALL_DIR   where the command was installed
#   AIDENTITY_BIN_DIRS      colon-separated folders to look in for the command,
#                           INSTEAD of the default folders and your PATH (the
#                           test suite uses it so it can never find a real copy)
#   AIDENTITY_APPS_DIR      where launchers live (default: ~/Applications)
#   AIDENTITY_APP_DIRS      colon-separated app folders also searched for
#                           launchers (default: /Applications:~/Applications)
#   AIDENTITY_DATA_ROOT     where profile data lives
#
# MIT licensed. https://github.com/PiniShv/aidentity — contact@pinishv.com

set -euo pipefail

MARKER_KEY="AIdentityProfile"
BIN_NAME="aidentity"

APPS_DIR="${AIDENTITY_APPS_DIR:-$HOME/Applications}"
DATA_ROOT="${AIDENTITY_DATA_ROOT:-$HOME/Library/Application Support/aidentity/profiles}"

# The word you have to type to remove your launchers and profiles.
CONFIRM_WORD="delete"

# ---------------------------------------------------------------- output --

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_RESET=$'\033[0m'; C_DIM=$'\033[2m'; C_BOLD=$'\033[1m'
  C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
else
  C_RESET=''; C_DIM=''; C_BOLD=''; C_RED=''; C_GREEN=''; C_YELLOW=''
fi

info() { printf '%s\n' "$*"; }
ok()   { printf '%s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '%s!%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
dim()  { printf '%s%s%s\n' "$C_DIM" "$*" "$C_RESET"; }
die()  { printf '%s✗%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; exit 1; }

usage() {
  cat <<EOF
${C_BOLD}aidentity uninstaller${C_RESET}

  ./uninstall.sh          Remove the aidentity command, then offer to remove
                          every launcher and all profile data.
  ./uninstall.sh --help   This text.

Launchers and profile data are never removed without you typing '$CONFIRM_WORD'
at the prompt. Only bundles carrying the $MARKER_KEY key are eligible. Profile
data is moved to the Trash, not deleted.
EOF
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  "") ;;
  *) die "Unknown option: $1  (try --help)" ;;
esac

# ---------------------------------------------------------------- guards --

[ "$(uname)" = "Darwin" ] || die "aidentity only runs on macOS, so there is nothing here to uninstall."

# ------------------------------------------------------------- helpers --

# Only bundles that aidentity built carry this key. Everything destructive in
# this script goes through here first.
is_our_launcher() {
  [ -d "$1" ] || return 1
  /usr/libexec/PlistBuddy -c "Print :$MARKER_KEY" "$1/Contents/Info.plist" >/dev/null 2>&1
}

# A missing key is normal, not fatal: PlistBuddy exits non-zero and 'set -e'
# would take the whole script down mid-scan, silently, before anything is even
# listed. Absent reads as empty.
plist_get() {
  /usr/libexec/PlistBuddy -c "Print :$2" "$1/Contents/Info.plist" 2>/dev/null || true
}

# Is this recorded data directory genuinely inside our data root? A plain prefix
# test is not enough — "$DATA_ROOT/../../Pictures" is prefixed by $DATA_ROOT and
# resolves nowhere near it, and a move to the Trash does not care about the
# difference.
# Kept deliberately identical to bin/aidentity's version. A string prefix test
# is not enough: "$DATA_ROOT//" matches "$DATA_ROOT"/?* yet IS the root, and a
# symlink inside the root escapes it entirely. Resolve both sides instead.
data_is_ours() {
  local d="$1" real root head tail
  [ -n "$d" ] || return 1

  # Absolute only: a relative path made the walk-up loop below spin forever.
  case "$d" in /*) ;; *) return 1 ;; esac
  # No dot segments — the tail is re-attached lexically and never resolved.
  case "$d" in
    *"/../"*|*"/.."|*"/./"*|*"/."|*"/") return 1 ;;
  esac

  root=$(command cd -P "$DATA_ROOT" 2>/dev/null && pwd -P) || return 1
  [ -n "$root" ] || return 1

  head="$d"; tail=""
  while [ ! -d "$head" ]; do
    tail="${head##*/}${tail:+/$tail}"
    head="${head%/*}"
    [ -z "$head" ] && head="/"
  done
  real=$(command cd -P "$head" 2>/dev/null && pwd -P) || return 1
  [ -n "$tail" ] && real="${real%/}/$tail"

  [ "$real" = "$root" ] && return 1
  case "$real" in
    "$root"/?*) return 0 ;;
    *) return 1 ;;
  esac
}


# Read the file before deleting it. "aidentity" is a plausible name for
# something the user wrote themselves, and $(command -v) will happily hand us
# whatever answers to that name.
looks_like_aidentity() {
  [ -f "$1" ] || return 1
  grep -q '^AIDENTITY_VERSION=' "$1" 2>/dev/null
}

# Homebrew links its binaries out of the Cellar. Deleting the link leaves brew
# convinced the formula is still installed, which is a worse state than before.
brew_managed() {
  local target
  [ -L "$1" ] || return 1
  target=$(readlink "$1" 2>/dev/null) || return 1
  case "$target" in
    */Cellar/*) return 0 ;;
  esac
  return 1
}

# A repository checkout is a working copy, not an installation. Recognise it by
# what sits two levels up from bin/aidentity.
in_repo_checkout() {
  local root
  root=$(dirname "$(dirname "$1")")
  [ -f "$root/install.sh" ] && [ -f "$root/uninstall.sh" ] && [ -f "$root/LICENSE" ]
}

# proc_snapshot, running_on_profile, running_in_snapshot and proc_dir_ids are
# kept identical to bin/aidentity's; scripts/guards.sh compares them. On macOS
# `pgrep -a` means "include ancestors", NOT "print the command line" as on
# Linux, so -af yields bare PIDs and the match below can never succeed. The
# list must also be captured before matching, or pgrep matches the grep's own
# argv. This copy had both bugs, which made the "don't delete a running
# profile" guard dead code.
proc_snapshot() {
  # -a: on macOS pgrep leaves out the caller's own ancestors unless asked.
  PS_RC=0; PS_LIST=$(pgrep -afl "user-data-dir=" 2>/dev/null) || PS_RC=$?
  PS_IDS=""; PS_ALL=""
  [ "$PS_RC" -le 1 ] || warn "Could not check which profiles are running (pgrep exited $PS_RC); assuming they are."
}

# Every check looks afresh: remove_data asks again after its prompt.
running_on_profile() {
  [ -n "$1" ] || return 1
  local PS_RC="" PS_LIST="" PS_IDS="" PS_ALL=""
  proc_snapshot
  running_in_snapshot "$1"
}

# The match runs in the shell, never as `printf … | grep -q`: on the 100 KB
# lists real Electron helpers produce, grep -q's early exit killed printf with
# SIGPIPE, pipefail read that as "no match", and a running profile looked
# stopped. Quoting "$1" inside the pattern keeps [ * ? in a path literal.
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

# trash_path is kept identical to bin/aidentity's; scripts/guards.sh compares
# them. It moves a folder into the Trash of its own volume with a plain mv (a
# rename, so it happens whole or not at all) and prints where it went. If it
# cannot, it says why, and the folder stays where it was.
trash_path() { # path -> prints where it went
  local src="$1" base parent dev uid trash mount up dest n id err moved
  base=${src##*/}
  case "$src" in /?*) ;; *) base="" ;; esac
  if [ -z "$base" ] || [ "$base" = "." ] || [ "$base" = ".." ]; then
    warn "Could not move '$src' to the Trash: it is not a full path to a folder. Nothing was deleted."
    return 1
  fi
  if [ ! -e "$src" ] && [ ! -L "$src" ]; then
    warn "Could not move $src to the Trash: it does not exist."
    return 1
  fi
  # A symlink would move on its own and leave the data it points to where it
  # is, while the caller says the data is in the Trash.
  if [ -L "$src" ]; then
    warn "Could not move $src to the Trash: it is a symbolic link, and the data it points to would stay where it is. Nothing was deleted."
    return 1
  fi
  parent=${src%/*}; [ -n "$parent" ] || parent="/"
  # Without -L: the device of the entry itself, which is what mv renames.
  dev=$(/usr/bin/stat -f %d "$src" 2>/dev/null) || dev=""
  if [ -z "$dev" ]; then
    warn "Could not move $src to the Trash: it cannot be read. Nothing was deleted."
    return 1
  fi

  if [ -n "${HOME:-}" ] && [ "$(/usr/bin/stat -L -f %d "$HOME" 2>/dev/null)" = "$dev" ]; then
    trash="$HOME/.Trash"
    if [ ! -d "$trash" ] && ! mkdir -m 700 "$trash" 2>/dev/null; then
      warn "Could not move $src to the Trash: $trash is missing and could not be created. Nothing was deleted."
      return 1
    fi
  else
    # Another volume. Its top folder is where the device changes, walking up
    # from the folder PATH is in. A PATH that is itself a volume (its folder
    # is on another device) cannot be moved anywhere.
    up=$(command cd -P "$parent" 2>/dev/null && pwd -P) || up=""
    if [ -z "$up" ] || [ "$(/usr/bin/stat -f %d "$up" 2>/dev/null)" != "$dev" ]; then
      warn "Could not move $src to the Trash: it is a volume of its own, or its folder cannot be read. Nothing was deleted."
      return 1
    fi
    mount=$up
    while [ "$mount" != "/" ]; do
      up=${mount%/*}; [ -n "$up" ] || up="/"
      [ "$(/usr/bin/stat -f %d "$up" 2>/dev/null)" = "$dev" ] || break
      mount=$up
    done
    # Finder makes .Trashes on a volume it has put things in the Trash on. A
    # volume without one may not want one (a backup disk, a network share), so
    # it is not made here.
    if [ ! -d "$mount/.Trashes" ]; then
      warn "Could not move $src to the Trash: its volume, $mount, has no Trash folder (.Trashes). Nothing was deleted."
      return 1
    fi
    uid=$(id -u 2>/dev/null) || uid=""
    trash="$mount/.Trashes/$uid"
    if [ -z "$uid" ] || { [ ! -d "$trash" ] && ! mkdir -m 700 "$trash" 2>/dev/null; }; then
      warn "Could not move $src to the Trash: $trash is missing and could not be created. Nothing was deleted."
      return 1
    fi
  fi
  # A symlinked Trash could lead to another volume, and then mv would copy.
  if [ "$(/usr/bin/stat -L -f %d "$trash" 2>/dev/null)" != "$dev" ]; then
    warn "Could not move $src to the Trash: $trash is on another volume. Nothing was deleted."
    return 1
  fi

  # mv onto a folder that exists moves INTO it, so the name must be free:
  # "name", then "name 2", "name 3", and so on, as Finder names them.
  dest="$trash/$base"; n=2
  while [ -e "$dest" ] || [ -L "$dest" ]; do
    if [ "$n" -gt 9999 ]; then
      warn "Could not move $src to the Trash: too many items named '$base' there already. Nothing was deleted."
      return 1
    fi
    dest="$trash/$base $n"; n=$((n + 1))
  done
  id=$(/usr/bin/stat -f %d:%i "$src" 2>/dev/null) || id=""
  # -n: never replace an item that took the name since the check above.
  err=$(mv -n "$src" "$dest" 2>&1) || err=${err:-mv failed}
  err=${err#mv: }
  if [ -e "$src" ] || [ -L "$src" ]; then
    warn "Could not move $src to the Trash: ${err:-$dest was taken just before the move}. Nothing was deleted."
    return 1
  fi
  # Gone from where it was, so a rename put it in the Trash, whole. The return
  # status says only that: whether PATH is still where it was.
  moved=$dest
  if [ -n "$id" ] && [ "$(/usr/bin/stat -f %d:%i "$dest" 2>/dev/null)" != "$id" ] \
     && [ "$(/usr/bin/stat -f %d:%i "$dest/$base" 2>/dev/null)" = "$id" ]; then
    # A folder made at that name in the moment before the move holds it.
    moved="$dest/$base"
  elif [ -n "$err" ] || { [ ! -e "$dest" ] && [ ! -L "$dest" ]; }; then
    # The system may keep a Trash private even from its owner's programs.
    warn "Moved $src to the Trash, but could not check it there${err:+ ($err)}. Look in: $trash"
  fi
  printf '%s\n' "$moved"
}

# Whether /dev/tty can really be opened. Its mode bits say yes on every Mac,
# terminal or not.
tty_opens() { ( : < /dev/tty ) 2>/dev/null; }

# A directory's identity, so two spellings of one directory compare equal.
dir_id() { [ -d "$1" ] && /usr/bin/stat -L -f '%d:%i' "$1" 2>/dev/null; }

# Splits a colon-separated folder list into DIRS. Globbing is off while it
# splits, so a folder name with * or ? in it stays one literal entry instead of
# turning into whatever it happens to match.
split_dirs() {
  local IFS=':'
  set -f
  # shellcheck disable=SC2206 # splitting on ':' is the point; globbing is off
  DIRS=($1)
  set +f
}

human_size() {
  [ -d "$1" ] || { printf 'empty'; return 0; }
  du -sh "$1" 2>/dev/null | awk '{print $1}' || printf '?'
}

# ------------------------------------------------- 1. the command itself --

remove_binary() {
  local candidates="" dir found removed=0 blocked=0 p
  local DIRS=()

  # AIDENTITY_INSTALL_DIR is one folder, taken as it is, never split.
  DIRS=("${AIDENTITY_INSTALL_DIR:-}" /usr/local/bin "$HOME/.local/bin" "$HOME/bin" /opt/homebrew/bin)
  local use_path=1
  # AIDENTITY_BIN_DIRS replaces the whole search, the PATH lookup included.
  # Without it, running this script in a sandbox could still find a real copy
  # in /usr/local/bin and delete it.
  if [ -n "${AIDENTITY_BIN_DIRS:-}" ]; then
    split_dirs "$AIDENTITY_BIN_DIRS"
    use_path=0
  fi

  # Everywhere it could plausibly be, plus wherever the shell currently finds it.
  for dir in ${DIRS[@]+"${DIRS[@]}"}; do
    [ -n "$dir" ] || continue
    [ -f "${dir%/}/$BIN_NAME" ] || continue
    candidates="$candidates
${dir%/}/$BIN_NAME"
  done

  if [ "$use_path" -eq 1 ]; then
    found=$(command -v "$BIN_NAME" 2>/dev/null) || found=""
    # Only an absolute path is a file we can reason about. A bare name or a
    # relative hit means PATH holds something like '.', and rm would be aimed
    # at the current directory.
    case "$found" in
      /*) candidates="$candidates
$found" ;;
    esac
  fi

  # Deduplicate, keeping order.
  candidates=$(printf '%s\n' "$candidates" | awk 'NF && !seen[$0]++')

  if [ -z "$candidates" ]; then
    info "The aidentity command is not installed anywhere obvious."
    if [ "$use_path" -eq 1 ]; then
      dim "  Looked in: /usr/local/bin, ~/.local/bin, ~/bin, /opt/homebrew/bin, and your PATH."
    else
      dim "  Looked in: $AIDENTITY_BIN_DIRS"
    fi
    info ""
    return 0
  fi

  while IFS= read -r p; do
    [ -n "$p" ] || continue

    if in_repo_checkout "$p"; then
      blocked=$((blocked + 1))
      warn "Left $p alone — that is a repository checkout, not an installation."
      continue
    fi

    if brew_managed "$p"; then
      blocked=$((blocked + 1))
      warn "Left $p alone — it is managed by Homebrew."
      dim "  Remove it with:  brew uninstall aidentity"
      continue
    fi

    if ! looks_like_aidentity "$p"; then
      blocked=$((blocked + 1))
      warn "Left $p alone — it does not look like aidentity."
      dim "  Nothing this script did not install is deleted. Remove it yourself if you want it gone."
      continue
    fi

    if [ -w "$(dirname "$p")" ]; then
      if rm -f "$p"; then
        ok "Removed $p"
        removed=$((removed + 1))
      else
        blocked=$((blocked + 1))
        warn "Could not remove $p."
      fi
    else
      blocked=$((blocked + 1))
      warn "Cannot remove $p — you do not have write access to $(dirname "$p")."
      dim "  Run this yourself if you want it gone:  sudo rm -f $p"
    fi
  done <<EOF
$candidates
EOF

  [ "$removed" -gt 0 ] || [ "$blocked" -gt 0 ] || info "Nothing to remove."
  LEFT_BEHIND=$((LEFT_BEHIND + blocked))
  info ""
}

# ------------------------------------------- 2. launchers + profile data --

# Fills LAUNCHERS / LABELS / PROFILES / DATA_DIRS, parallel arrays, and ORPHANS:
# profile directories in the data root that no launcher points at. Those hold
# signed-in sessions too — left by a launcher deleted in Finder, or by
# `aidentity rm` without --purge — and leaving them behind while saying
# "aidentity is gone" was not true.
LAUNCHERS=(); LABELS=(); PROFILES=(); DATA_DIRS=(); ORPHANS=()

# Things kept on purpose or by failure (a Homebrew copy, a locked launcher,
# data outside the root or in use). "aidentity is gone" is said only at zero.
LEFT_BEHIND=0

# Profile folders moved to the Trash, for the note on how to put one back.
MOVED_DATA=0

# Every aidentity launcher worth removing, one path per line: the launcher
# directory and folders inside it (followed with -H when it is a symlink), the
# app folders (AIDENTITY_APP_DIRS, as aidentity itself searches them), and what
# Spotlight knows inside those places or your home folder. Looking only at the
# top of the launcher directory listed a filed-away launcher's data as "no
# launcher points at" and deleted it while the launcher stayed. Our own hidden
# .aidentity-* folders and the Trash are skipped. Every hit is still checked
# for the marker key before it is listed.
discover_launchers() {
  local app dir DIRS=()
  split_dirs "${AIDENTITY_APP_DIRS:-/Applications:$HOME/Applications}"
  {
    # The top level by glob as well: find's -type d skips a launcher that is
    # itself a symlink, and its data would then look orphaned.
    for app in "$APPS_DIR"/*.app; do
      if [ -d "$app" ]; then printf '%s\n' "$app"; fi
    done
    find -H "$APPS_DIR" -maxdepth 3 -type d -name '.aidentity-*' -prune \
      -o -type d -name '*.app' -print -prune 2>/dev/null || true
    for dir in ${DIRS[@]+"${DIRS[@]}"}; do
      [ -n "$dir" ] && [ -d "$dir" ] || continue
      find -H "$dir" -maxdepth 2 -type d -name '.aidentity-*' -prune \
        -o -type d -name '*.app' -print -prune 2>/dev/null || true
    done
    if command -v mdfind >/dev/null 2>&1; then
      mdfind "kMDItemCFBundleIdentifier == 'com.aidentity.*'" 2>/dev/null || true
    fi
  } | awk 'NF && !seen[$0]++' | while IFS= read -r app; do
    case "$app" in */.aidentity-*|*/.Trash/*|*/.Trashes/*) continue ;; esac
    inside=0
    case "$app" in "$APPS_DIR"/*|"$HOME"/*) inside=1 ;; esac
    for dir in ${DIRS[@]+"${DIRS[@]}"}; do
      # "/" as an app folder would make every Spotlight hit "inside" it.
      [ -n "${dir%/}" ] || continue
      case "$app" in "${dir%/}"/*) inside=1 ;; esac
    done
    [ "$inside" -eq 1 ] || continue
    is_our_launcher "$app" && printf '%s\n' "$app"
  done
  return 0
}

scan_launchers() {
  local app label d id claimed=" " found
  found=$(discover_launchers) || found=""
  while IFS= read -r app; do
    [ -n "$app" ] || continue
    label=$(basename "$app" .app)
    LAUNCHERS+=("$app")
    LABELS+=("$label")
    PROFILES+=("$(plist_get "$app" "$MARKER_KEY")")
    d=$(plist_get "$app" "AIdentityDataDir")
    DATA_DIRS+=("$d")
    if id=$(dir_id "$d"); then claimed="$claimed$id "; fi
  done <<EOF
$found
EOF
  [ -d "$DATA_ROOT" ] || return 0
  for d in "$DATA_ROOT"/*; do
    [ -d "$d" ] || continue
    id=$(dir_id "$d") || continue
    case "$claimed" in *" $id "*) continue ;; esac
    data_is_ours "$d" || continue
    ORPHANS+=("$d")
  done
  return 0
}

# The identities of the folders that the launchers found right now record, as
# " id id ". Asked again after the question, as prune does: the scan is as old
# as the question, and a launcher may have been made for one of those folders
# since, by 'aidentity restore' for example.
claimed_now() {
  local app d id ids=" " found
  found=$(discover_launchers) || found=""
  while IFS= read -r app; do
    [ -n "$app" ] || continue
    d=$(plist_get "$app" "AIdentityDataDir")
    if id=$(dir_id "$d"); then ids="$ids$id "; fi
  done <<EOF
$found
EOF
  printf '%s' "$ids"
}

# Show exactly what would go, then ask. Returns 1 if the user declines, and 2
# if there is no terminal to ask on.
confirm_removal() {
  local i data running=0 d

  if [ "${#LAUNCHERS[@]}" -gt 0 ]; then
    info "${C_BOLD}These launchers were built by aidentity:${C_RESET}"
    info ""
  fi
  i=0
  while [ "$i" -lt "${#LAUNCHERS[@]}" ]; do
    data="${DATA_DIRS[$i]}"
    printf '  %s%s%s\n' "$C_BOLD" "${LABELS[$i]}" "$C_RESET"
    printf '    launcher  %s\n' "${LAUNCHERS[$i]}"
    if [ "$(plist_get "${LAUNCHERS[$i]}" AIdentityMain)" = "true" ]; then
      printf '    data      the app'"'"'s own — your original account, kept\n'
    fi
    if [ -n "$data" ]; then
      if data_is_ours "$data"; then
        printf '    data      %s  (%s)\n' "$data" "$(human_size "$data")"
      else
        printf '    data      %s\n' "$data"
        printf '              %soutside the aidentity data directory — will be KEPT%s\n' "$C_YELLOW" "$C_RESET"
      fi
    fi
    if [ -n "$data" ] && running_on_profile "$data"; then
      printf '    status    %sRUNNING%s\n' "$C_YELLOW" "$C_RESET"
      running=$((running + 1))
    fi
    info ""
    i=$((i + 1))
  done

  if [ "${#ORPHANS[@]}" -gt 0 ]; then
    info "${C_BOLD}Profile data no launcher points at${C_RESET} (left by a launcher deleted in"
    info "Finder, or by 'aidentity rm' without --purge):"
    info ""
    for d in "${ORPHANS[@]}"; do
      printf '    data      %s  (%s)\n' "$d" "$(human_size "$d")"
      if running_on_profile "$d"; then
        printf '    status    %sRUNNING%s\n' "$C_YELLOW" "$C_RESET"
        running=$((running + 1))
      fi
    done
    info ""
  fi

  if [ "$running" -gt 0 ]; then
    die "$running profile(s) are running right now. Quit them, then re-run this script.
    Moving a profile's data while its app is open loses whatever it has not saved."
  fi

  info "Removing them deletes ${C_BOLD}${#LAUNCHERS[@]}${C_RESET} launcher(s) and moves the profile data listed above to the Trash."
  info "Every account signed in through that data is signed out, until its folder is moved back."
  dim "  Your real apps — the ones in /Applications — are not touched."
  info ""

  # Ask on the terminal even when stdin is not one (a piped run), and only
  # give up when there is genuinely no terminal. Giving up is not success.
  local reply="" from="/dev/stdin"
  if [ ! -t 0 ]; then
    if ! tty_opens; then
      warn "Not running in a terminal, so there is nobody to confirm with. No launchers or profile data were removed."
      dim "  Run ./uninstall.sh directly in a terminal to remove them."
      return 2
    fi
    from="/dev/tty"
  fi

  printf 'Type %s%s%s to remove them, or anything else to keep them: ' "$C_BOLD" "$CONFIRM_WORD" "$C_RESET"
  IFS= read -r reply < "$from" || reply="${reply:-}"
  if [ "$reply" != "$CONFIRM_WORD" ]; then
    info ""
    ok "Kept. Nothing was removed."
    dim "  Your launchers still work; they do not need the aidentity command."
    return 1
  fi
  return 0
}

# Move one profile directory to the Trash, with the same checks as aidentity's
# own purge: inside the data root, and not running. The running check is
# repeated here because the confirmation prompt can sit for minutes.
remove_data() {
  local data="$1" name="$2" moved
  if ! data_is_ours "$data"; then
    warn "Left profile data in place (outside the aidentity data directory):"
    dim "    $data"
    LEFT_BEHIND=$((LEFT_BEHIND + 1))
    return 0
  fi
  [ -d "$data" ] || return 0
  if running_on_profile "$data"; then
    warn "Kept the data for $name — it was opened while waiting for confirmation."
    LEFT_BEHIND=$((LEFT_BEHIND + 1))
    return 0
  fi
  # trash_path says why when it cannot; the data then stays where it is.
  if moved=$(trash_path "$data"); then
    ok "Moved the data for $name to the Trash"
    dim "    $moved"
    MOVED_DATA=$((MOVED_DATA + 1))
  else
    dim "    The data for $name is still at: $data"
    LEFT_BEHIND=$((LEFT_BEHIND + 1))
  fi
}

remove_launchers() {
  local i app data

  i=0
  while [ "$i" -lt "${#LAUNCHERS[@]}" ]; do
    app="${LAUNCHERS[$i]}"
    data="${DATA_DIRS[$i]}"

    # Checked once at scan time and again here: the list could be minutes old,
    # and nothing without the marker is ever removed.
    if is_our_launcher "$app"; then
      if rm -rf "$app" 2>/dev/null && [ ! -e "$app" ]; then
        ok "Removed ${LABELS[$i]}.app"
      else
        warn "Could not remove $app — it is still there."
        LEFT_BEHIND=$((LEFT_BEHIND + 1))
      fi
    else
      warn "Skipped $app — it no longer carries the $MARKER_KEY key."
      LEFT_BEHIND=$((LEFT_BEHIND + 1))
    fi

    if [ -n "$data" ]; then
      remove_data "$data" "${LABELS[$i]}"
    fi
    i=$((i + 1))
  done

  # Looked for again only now, after the launchers above are gone, so every
  # launcher still there counts. Moving a folder one of them uses would open
  # that account signed out.
  local d id claimed=" "
  if [ "${#ORPHANS[@]}" -gt 0 ]; then claimed=$(claimed_now); fi
  for d in ${ORPHANS[@]+"${ORPHANS[@]}"}; do
    if id=$(dir_id "$d"); then
      case "$claimed" in
        *" $id "*)
          warn "Kept $(basename "$d") — a launcher uses it now."
          LEFT_BEHIND=$((LEFT_BEHIND + 1))
          continue ;;
      esac
    fi
    remove_data "$d" "$(basename "$d")"
  done

  # Only if it is genuinely empty — rmdir refuses otherwise, which is the point.
  # Finder's .DS_Store is not data; left alone it kept the folder "not empty".
  rm -f "$DATA_ROOT/.DS_Store" 2>/dev/null || true
  rmdir "$DATA_ROOT" 2>/dev/null && dim "  Removed the now-empty $DATA_ROOT" || true
  rmdir "$(dirname "$DATA_ROOT")" 2>/dev/null || true

  info ""
  # The data root may be gone by now (rmdir above), so the hint says to create
  # it first. A folder with no restore record comes back through add instead.
  if [ "$MOVED_DATA" -gt 0 ]; then
    dim "  To get an account back, install aidentity again and create the data folder:"
    dim "    mkdir -p \"$DATA_ROOT\""
    dim "  Then move the profile's folder from the Trash into it, and run:"
    dim "    aidentity restore"
    dim "  If restore does not list it, add the profile again with the same app and"
    dim "  profile name, and it uses the folder."
  fi
  dim "  If a launcher was pinned to your Dock, drag the tile out — macOS keeps it"
  dim "  until you do, even though the app is gone."
}

# ----------------------------------------------------------------- main --

main() {
  info "${C_BOLD}aidentity uninstaller${C_RESET}"
  info ""

  remove_binary

  scan_launchers

  if [ "${#LAUNCHERS[@]}" -eq 0 ] && [ "${#ORPHANS[@]}" -eq 0 ]; then
    info "No aidentity launchers or profile data found — nothing else to remove."
    info ""
    ok "Done."
    return 0
  fi

  local rc=0
  confirm_removal || rc=$?
  if [ "$rc" -eq 0 ]; then
    info ""
    remove_launchers
    info ""
    # Say "gone" only when it is. A Homebrew copy, a locked launcher, data
    # outside the root or data in use is kept on purpose — and then this must
    # not claim otherwise.
    if [ "$LEFT_BEHIND" -eq 0 ] && [ ! -d "$DATA_ROOT" ]; then
      ok "Done. aidentity is gone from this Mac."
    else
      warn "Done, but some things were left in place — see the messages above."
      [ -d "$DATA_ROOT" ] && dim "    Still there: $DATA_ROOT"
    fi
  else
    info ""
    dim "  Reinstall any time: curl -fsSL https://raw.githubusercontent.com/PiniShv/aidentity/main/install.sh | bash"
    # No terminal to confirm on is not success: a script calling this must not
    # read "exit 0" as "everything was removed". Declining is a fine answer.
    if [ "$rc" -eq 2 ]; then exit 1; fi
  fi
  return 0
}

main "$@"
