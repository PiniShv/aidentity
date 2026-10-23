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
#      the part that loses accounts and local app state, so it prints every
#      path first and then waits for you to type a word. Answer anything else
#      and nothing is deleted.
#
# The safety rule is the same one aidentity itself uses: a bundle is only ever
# deleted if its Info.plist carries the "AIdentityProfile" key, which only
# aidentity writes. A real app that happens to sit in the same folder — or an
# app named after one of your profiles — is never touched. Profile data is only
# deleted from inside the aidentity data root; a path recorded outside it, or one
# that walks back out of it with "..", is reported and left alone.
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

# The word you have to type to lose your profiles.
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
at the prompt. Only bundles carrying the $MARKER_KEY key are eligible.
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
# resolves nowhere near it, and rm -rf does not care about the difference.
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

# Kept deliberately identical to bin/aidentity's version. On macOS `pgrep -a`
# means "include ancestors", NOT "print the command line" as on Linux, so -af
# yields bare PIDs and the match below can never succeed. The list must also be
# captured before matching, or pgrep matches the grep's own argv. This copy had
# both bugs, which made the "don't delete a running profile" guard dead code.
#
# The match runs in the shell, never as `printf … | grep -q`: on the 100 KB
# lists real Electron helpers produce, grep -q's early exit killed printf with
# SIGPIPE, pipefail read that as "no match", and a running profile looked
# stopped. Quoting "$1" inside the pattern keeps [ * ? in a path literal.
running_on_profile() {
  local list rc nl=$'\n'
  [ -n "$1" ] || return 1
  # pgrep exits 1 for "no match" but >=2 for a real failure. Treating those the
  # same made a data-loss guard fail OPEN — a broken pgrep read as "nothing is
  # running" and the delete went ahead. Anything but 0 or 1 is reported as
  # running, so the caller refuses to delete.
  # -a: on macOS pgrep leaves out the caller's own ancestors unless asked.
  list=$(pgrep -afl "user-data-dir=" 2>/dev/null); rc=$?
  if [ "$rc" -gt 1 ]; then
    warn "Could not check which profiles are running (pgrep exited $rc); assuming they are."
    return 0
  fi
  [ "$rc" -eq 0 ] && [ -n "$list" ] || return 1
  case "$list$nl" in
    *"user-data-dir=$1 "*|*"user-data-dir=$1$nl"*) return 0 ;;
  esac
  # The same directory under another spelling — a symlinked root, "//", a
  # trailing slash — is the same profile. Compare each path a process names
  # (up to the next " --" or the end of its line) by directory identity.
  local want line rest path seen="|"
  want=$(/usr/bin/stat -L -f '%d:%i' "$1" 2>/dev/null) || return 1
  while IFS= read -r line; do
    rest=$line
    while :; do
      case "$rest" in *user-data-dir=*) rest=${rest#*user-data-dir=} ;; *) break ;; esac
      path=${rest%% --*}
      case "$seen" in *"|$path|"*) continue ;; esac
      seen="$seen$path|"
      [ "$(/usr/bin/stat -L -f '%d:%i' "$path" 2>/dev/null)" = "$want" ] && return 0
    done
  done <<EOF
$list
EOF
  return 1
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
    Deleting a profile's data while its app is open loses whatever it has not saved."
  fi

  info "Removing them deletes ${C_BOLD}${#LAUNCHERS[@]}${C_RESET} launcher(s) and the profile data listed above."
  info "Every account signed in through that data will have to sign in again."
  dim "  Your real apps — the ones in /Applications — are not touched."
  info ""

  # Ask on the terminal even when stdin is not one (a piped run), and only
  # give up when there is genuinely no terminal. Giving up is not success.
  local reply="" from="/dev/stdin"
  if [ ! -t 0 ]; then
    if ! tty_opens; then
      warn "Not running in a terminal, so there is nobody to confirm with. No launchers or profile data were deleted."
      dim "  Run ./uninstall.sh directly in a terminal to remove them."
      return 2
    fi
    from="/dev/tty"
  fi

  printf 'Type %s%s%s to delete them, or anything else to keep them: ' "$C_BOLD" "$CONFIRM_WORD" "$C_RESET"
  IFS= read -r reply < "$from" || reply="${reply:-}"
  if [ "$reply" != "$CONFIRM_WORD" ]; then
    info ""
    ok "Kept. Nothing was deleted."
    dim "  Your launchers still work; they do not need the aidentity command."
    return 1
  fi
  return 0
}

# Delete one profile directory, with the same checks as aidentity's own purge:
# inside the data root, and not running. The running check is repeated here
# because the confirmation prompt can sit for minutes.
remove_data() {
  local data="$1" name="$2"
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
  if rm -rf "$data" 2>/dev/null && [ ! -e "$data" ]; then
    ok "Deleted data for $name"
  else
    warn "Could not delete the data for $name; it is still at $data"
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

  local d
  for d in ${ORPHANS[@]+"${ORPHANS[@]}"}; do
    remove_data "$d" "$(basename "$d")"
  done

  # Only if it is genuinely empty — rmdir refuses otherwise, which is the point.
  # Finder's .DS_Store is not data; left alone it kept the folder "not empty".
  rm -f "$DATA_ROOT/.DS_Store" 2>/dev/null || true
  rmdir "$DATA_ROOT" 2>/dev/null && dim "  Removed the now-empty $DATA_ROOT" || true
  rmdir "$(dirname "$DATA_ROOT")" 2>/dev/null || true

  info ""
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
