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
#   AIDENTITY_APPS_DIR      where launchers live (default: ~/Applications)
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
running_on_profile() {
  local list
  [ -n "$1" ] || return 1
  # pgrep exits 1 for "no match" but >=2 for a real failure. Treating those the
  # same made a data-loss guard fail OPEN — a broken pgrep read as "nothing is
  # running" and the delete went ahead. Anything but 0 or 1 is reported as
  # running, so the caller refuses to delete.
  local rc
  list=$(pgrep -fl "user-data-dir=" 2>/dev/null); rc=$?
  if [ "$rc" -gt 1 ]; then
    warn "Could not check which profiles are running (pgrep exited $rc); assuming they are."
    return 0
  fi
  [ "$rc" -eq 0 ] && [ -n "$list" ] || return 1
  printf '%s\n' "$list" | grep -qF -- "user-data-dir=$1 " ||
  printf '%s\n' "$list" | grep -q -- "user-data-dir=$(printf '%s' "$1" | sed 's/[][\.*^$\/]/\\&/g')\$"
}

human_size() {
  [ -d "$1" ] || { printf 'empty'; return 0; }
  du -sh "$1" 2>/dev/null | awk '{print $1}' || printf '?'
}

# ------------------------------------------------- 1. the command itself --

remove_binary() {
  local candidates="" dir found removed=0 blocked=0 p

  # Everywhere it could plausibly be, plus wherever the shell currently finds it.
  for dir in "${AIDENTITY_INSTALL_DIR:-}" /usr/local/bin "$HOME/.local/bin" "$HOME/bin" /opt/homebrew/bin; do
    [ -n "$dir" ] || continue
    [ -f "${dir%/}/$BIN_NAME" ] || continue
    candidates="$candidates
${dir%/}/$BIN_NAME"
  done

  found=$(command -v "$BIN_NAME" 2>/dev/null) || found=""
  # Only an absolute path is a file we can reason about. A bare name or a
  # relative hit means PATH holds something like '.', and rm would be aimed at
  # the current directory.
  case "$found" in
    /*) candidates="$candidates
$found" ;;
  esac

  # Deduplicate, keeping order.
  candidates=$(printf '%s\n' "$candidates" | awk 'NF && !seen[$0]++')

  if [ -z "$candidates" ]; then
    info "The aidentity command is not installed anywhere obvious."
    dim "  Looked in: /usr/local/bin, ~/.local/bin, ~/bin, /opt/homebrew/bin, and your PATH."
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
  info ""
}

# ------------------------------------------- 2. launchers + profile data --

# Fills LAUNCHERS / LABELS / PROFILES / DATA_DIRS, parallel arrays.
LAUNCHERS=(); LABELS=(); PROFILES=(); DATA_DIRS=()

scan_launchers() {
  local app label
  [ -d "$APPS_DIR" ] || return 0
  for app in "$APPS_DIR"/*.app; do
    [ -d "$app" ] || continue
    is_our_launcher "$app" || continue
    label=$(basename "$app" .app)
    LAUNCHERS+=("$app")
    LABELS+=("$label")
    PROFILES+=("$(plist_get "$app" "$MARKER_KEY")")
    DATA_DIRS+=("$(plist_get "$app" "AIdentityDataDir")")
  done
}

# Show exactly what would go, then ask. Returns 1 if the user declines.
confirm_removal() {
  local i data running=0

  info "${C_BOLD}These launchers were built by aidentity:${C_RESET}"
  info ""
  i=0
  while [ "$i" -lt "${#LAUNCHERS[@]}" ]; do
    data="${DATA_DIRS[$i]}"
    printf '  %s%s%s\n' "$C_BOLD" "${LABELS[$i]}" "$C_RESET"
    printf '    launcher  %s\n' "${LAUNCHERS[$i]}"
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

  if [ "$running" -gt 0 ]; then
    die "$running profile(s) are running right now. Quit them, then re-run this script.
    Deleting a profile's data while its app is open loses whatever it has not saved."
  fi

  info "Removing them deletes ${C_BOLD}${#LAUNCHERS[@]}${C_RESET} launcher(s) and the profile data listed above."
  info "Every account signed in through those launchers will have to sign in again."
  dim "  Your real apps — the ones in /Applications — are not touched."
  info ""

  if [ ! -t 0 ]; then
    warn "Not running in a terminal, so there is nobody to confirm with. Nothing was deleted."
    dim "  Run ./uninstall.sh directly in a terminal to remove them."
    return 1
  fi

  printf 'Type %s%s%s to delete them, or anything else to keep them: ' "$C_BOLD" "$CONFIRM_WORD" "$C_RESET"
  local reply=""
  read -r reply || reply=""
  if [ "$reply" != "$CONFIRM_WORD" ]; then
    info ""
    ok "Kept. Nothing was deleted."
    dim "  Your launchers still work; they do not need the aidentity command."
    return 1
  fi
  return 0
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
      if rm -rf "$app"; then
        ok "Removed ${LABELS[$i]}.app"
      else
        warn "Could not remove $app — it is still there."
      fi
    else
      warn "Skipped $app — it no longer carries the $MARKER_KEY key."
    fi

    if [ -n "$data" ]; then
      if data_is_ours "$data"; then
        if [ -d "$data" ]; then
          if rm -rf "$data"; then
            ok "Deleted data for ${LABELS[$i]}"
          else
            warn "Could not delete the data for ${LABELS[$i]}; it is still at $data"
          fi
        fi
      else
        warn "Left profile data in place (outside the aidentity data directory):"
        dim "    $data"
      fi
    fi
    i=$((i + 1))
  done

  # Only if it is genuinely empty — rmdir refuses otherwise, which is the point.
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

  if [ "${#LAUNCHERS[@]}" -eq 0 ]; then
    info "No aidentity launchers found in $APPS_DIR — nothing else to remove."
    info ""
    ok "Done."
    return 0
  fi

  if confirm_removal; then
    info ""
    remove_launchers
    info ""
    ok "Done. aidentity is gone from this Mac."
  else
    info ""
    dim "  Reinstall any time: curl -fsSL https://raw.githubusercontent.com/PiniShv/aidentity/main/install.sh | bash"
  fi
}

main "$@"
