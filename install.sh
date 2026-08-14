#!/usr/bin/env bash
#
# aidentity installer
# ===================
#
#   curl -fsSL https://raw.githubusercontent.com/PiniShv/aidentity/main/install.sh | bash
#
# aidentity is a single shell script with no dependencies beyond what ships with
# macOS. Installing it means putting one file on your PATH. That is all this
# script does, and here is the order it does it in:
#
#   1. Refuses to run anywhere but macOS.
#   2. Downloads bin/aidentity from the repository to a temp file. The temp file
#      is deleted on exit, whether this succeeds or fails.
#   3. Checks the download: non-empty, starts with a shebang, carries the
#      version marker every real copy has, parses as shell, and ends on the
#      final line every real copy ends on. A truncated or wrong file never
#      reaches your PATH.
#   4. Installs to /usr/local/bin if you can write there, otherwise to
#      ~/.local/bin. It never calls sudo. If it cannot write anywhere it prints
#      the exact sudo command and stops, so the decision stays yours.
#   5. Prints the installed version, plus the PATH line to add if one is needed.
#      It does not edit your shell files.
#
# Re-running upgrades in place. Nothing else on your Mac is touched: no
# launchers are built, no profile data is read, nothing is removed.
#
# Environment overrides:
#   AIDENTITY_INSTALL_DIR   install here instead of the default search
#   AIDENTITY_REF           branch, tag or commit to install from (default: main)
#
# Uninstall:  https://raw.githubusercontent.com/PiniShv/aidentity/main/uninstall.sh
#
# MIT licensed. https://github.com/PiniShv/aidentity — contact@pinishv.com

set -euo pipefail

REPO_URL="https://github.com/PiniShv/aidentity"
REF="${AIDENTITY_REF:-main}"
SOURCE_URL="https://raw.githubusercontent.com/PiniShv/aidentity/${REF}/bin/aidentity"
INSTALL_URL="https://raw.githubusercontent.com/PiniShv/aidentity/${REF}/install.sh"

BIN_NAME="aidentity"
PRIMARY_DIR="/usr/local/bin"
FALLBACK_DIR="$HOME/.local/bin"

# Smallest plausible copy of the script. Guards against a proxy or captive
# portal handing back a short page that happens to start with "#!".
MIN_BYTES=2000

# The last line of bin/aidentity. Checked because everything else a truncated
# file can still satisfy: it can be over MIN_BYTES, start with "#!", carry the
# version marker near the top, and — since a shell script cut at the wrong point
# is often still valid shell — pass "bash -n" too. Only the tail proves the whole
# file arrived. bin/aidentity must keep ending on this line.
END_MARKER='main "$@"'

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

# --------------------------------------------------------------- cleanup --

# Set before use; the trap tolerates them being empty.
TMP_FILE=""
STAGED_FILE=""

# Filled in as we go. Declared here so 'set -u' has nothing to trip over.
INSTALL_DIR=""
INSTALLED_PATH=""
INSTALLED_VERSION=""
PREVIOUS_VERSION=""

cleanup() {
  [ -n "$TMP_FILE" ] && rm -f "$TMP_FILE"
  [ -n "$STAGED_FILE" ] && rm -f "$STAGED_FILE"
  return 0
}
trap cleanup EXIT

# ---------------------------------------------------------------- guards --

[ "$(uname)" = "Darwin" ] || die "aidentity only runs on macOS (this looks like $(uname)).
    It builds macOS .app launchers, so there is nothing useful to install here."

command -v curl >/dev/null 2>&1 \
  || die "curl is required and was not found on your PATH."

# ------------------------------------------------------------- helpers --

# Is this directory a place we can write a file today?
dir_is_writable() {
  local dir="$1" probe parent
  [ -n "$dir" ] || return 1

  if [ -d "$dir" ]; then
    [ -w "$dir" ]
    return $?
  fi

  # Not there yet. Walk up to the nearest directory that does exist and ask
  # whether we could create the rest of the path underneath it.
  probe="$dir"
  while :; do
    parent=$(dirname "$probe")
    [ "$parent" = "$probe" ] && return 1
    if [ -d "$parent" ]; then
      [ -w "$parent" ]
      return $?
    fi
    probe="$parent"
  done
}

on_path() {
  case ":${PATH:-}:" in
    *":$1:"*) return 0 ;;
  esac
  return 1
}

# Print a path with $HOME collapsed, so the line we suggest for an rc file
# stays correct for the user rather than being frozen to one home directory.
portable_path() {
  local p="$1"
  # shellcheck disable=SC2016  # printing the literal characters $HOME is the point
  case "$p" in
    "$HOME"/*) printf '$HOME%s' "${p#"$HOME"}" ;;
    *) printf '%s' "$p" ;;
  esac
}

# Which startup file this user actually loads.
shell_rc_file() {
  case "${SHELL:-}" in
    */zsh)  printf '%s' "$HOME/.zshrc" ;;
    */bash) printf '%s' "$HOME/.bash_profile" ;;
    */fish) printf '%s' "$HOME/.config/fish/config.fish" ;;
    *)      printf '%s' "" ;;
  esac
}

# The line that puts a directory on PATH, in the syntax of the shell the user
# actually runs. 'export PATH=...' is a syntax error in fish, so printing it to a
# fish user is worse than printing nothing.
path_set_line() {
  # shellcheck disable=SC2016  # printing the literal characters $PATH is the point
  case "${SHELL:-}" in
    */fish) printf 'fish_add_path %s' "$1" ;;
    *)      printf 'export PATH="%s:$PATH"' "$1" ;;
  esac
}

# Version of an aidentity script. Read out of the file rather than by running
# it — reporting a version is no reason to execute anything.
read_version() {
  local file="$1" v=""
  v=$(sed -n 's/^AIDENTITY_VERSION="\([^"]*\)".*/\1/p' "$file" 2>/dev/null | head -n 1) || v=""
  [ -n "$v" ] || v="unknown"
  printf '%s' "$v"
}

# ------------------------------------------------------------- download --

download() {
  TMP_FILE=$(mktemp "${TMPDIR:-/tmp}/aidentity-install.XXXXXX") \
    || die "Could not create a temporary file."

  info "Downloading aidentity (${REF}) …"
  dim "  $SOURCE_URL"

  # --proto/--tlsv1.2 pin the transport; -f turns an HTTP error into a failure
  # instead of a downloaded error page. --proto-redir matters as much as --proto:
  # --proto only constrains the first request, and curl's default still permits a
  # redirect to plain http, which would hand the download to anyone on the wire.
  curl --fail --silent --show-error --location \
       --proto '=https' --proto-redir '=https' --tlsv1.2 \
       --connect-timeout 10 --max-time 120 --retry 2 \
       -o "$TMP_FILE" "$SOURCE_URL" \
    || die "Download failed.
    Check your connection, or that '$REF' exists in $REPO_URL"
}

verify() {
  local size first_line last_line

  size=$(wc -c < "$TMP_FILE" | tr -d ' ')
  [ "${size:-0}" -gt 0 ] || die "The downloaded file is empty. Nothing was installed."
  [ "${size:-0}" -ge "$MIN_BYTES" ] || die "The downloaded file is only ${size} bytes, which is far
    too small to be aidentity. Something answered instead of GitHub. Nothing was installed."

  first_line=$(head -n 1 "$TMP_FILE")
  case "$first_line" in
    '#!'*) ;;
    *) die "The downloaded file does not start with a shebang, so it is not a
    script. Nothing was installed." ;;
  esac

  grep -q '^AIDENTITY_VERSION=' "$TMP_FILE" \
    || die "The downloaded file does not look like aidentity (no version marker).
    Nothing was installed."

  bash -n "$TMP_FILE" 2>/dev/null \
    || die "The downloaded file is not valid shell — it is probably truncated.
    Nothing was installed."

  # The check that actually catches truncation. A script cut in half is very
  # often still valid shell, so 'bash -n' alone lets a half file through; the
  # last line is the only thing that proves the transfer finished.
  last_line=$(awk 'NF { line = $0 } END { sub(/[ \t\r]+$/, "", line); print line }' "$TMP_FILE")
  [ "$last_line" = "$END_MARKER" ] \
    || die "The downloaded file is cut off — it does not end where aidentity ends.
    Nothing was installed. Try again; if it keeps happening, download it by hand
    from $REPO_URL"
}

# -------------------------------------------------------------- install --

# Decide where the binary goes. Sets INSTALL_DIR.
choose_install_dir() {
  if [ -n "${AIDENTITY_INSTALL_DIR:-}" ]; then
    INSTALL_DIR="${AIDENTITY_INSTALL_DIR%/}"
    if [ -e "$INSTALL_DIR" ] && [ ! -d "$INSTALL_DIR" ]; then
      die "AIDENTITY_INSTALL_DIR is set to '$INSTALL_DIR', which exists but is not a
    directory. Point it at a directory. Nothing was installed."
    fi
    # The sudo line runs this installer, not a bare curl-to-disk: piping straight
    # into the destination would put an unchecked file on PATH as root.
    dir_is_writable "$INSTALL_DIR" || die "AIDENTITY_INSTALL_DIR is set to '$INSTALL_DIR', which is not writable.
    Either pick a writable directory, or install there yourself with:

      curl -fsSL $INSTALL_URL | sudo AIDENTITY_INSTALL_DIR=$INSTALL_DIR bash"
    return 0
  fi

  if dir_is_writable "$PRIMARY_DIR"; then
    INSTALL_DIR="$PRIMARY_DIR"
    return 0
  fi

  if dir_is_writable "$FALLBACK_DIR"; then
    INSTALL_DIR="$FALLBACK_DIR"
    return 0
  fi

  die "Neither $PRIMARY_DIR nor $FALLBACK_DIR is writable, and this installer
    will not run sudo for you. Two ways forward — pick one:

      1. Install somewhere you own:
           curl -fsSL $INSTALL_URL | AIDENTITY_INSTALL_DIR=\"\$HOME/bin\" bash

      2. Install system-wide yourself, so you type the sudo:
           curl -fsSL $INSTALL_URL | sudo AIDENTITY_INSTALL_DIR=$PRIMARY_DIR bash"
}

install_binary() {
  local dest="$INSTALL_DIR/$BIN_NAME" previous=""

  if [ ! -d "$INSTALL_DIR" ]; then
    mkdir -p "$INSTALL_DIR" || die "Could not create $INSTALL_DIR"
    dim "  Created $INSTALL_DIR"
  fi

  if [ -e "$dest" ]; then
    previous=$(read_version "$dest")
  fi

  # Write beside the target, then move into place. A half-written file is never
  # visible as 'aidentity', and replacing the inode leaves a running copy alone.
  #
  # mktemp, not "$dest.new.$$": /usr/local/bin is group-writable on plenty of
  # Macs, and a predictable staging name is a symlink waiting to happen. Anyone
  # who can write to the directory could plant that name pointing anywhere, and
  # we would faithfully write the script through it, chmod 755 it, and then move
  # the symlink into place as 'aidentity'. mktemp creates the file itself, with
  # an unguessable name and O_EXCL, so there is nothing to pre-empt.
  STAGED_FILE=$(mktemp "$INSTALL_DIR/.aidentity.XXXXXX") \
    || die "Could not write to $INSTALL_DIR"
  cat "$TMP_FILE" > "$STAGED_FILE" || die "Could not write to $INSTALL_DIR"
  chmod 755 "$STAGED_FILE" || die "Could not set permissions on $STAGED_FILE"
  # mv replaces the name; if $dest is itself a symlink it is replaced, not
  # followed, so an existing symlink cannot redirect the install either.
  mv -f "$STAGED_FILE" "$dest" || die "Could not install to $dest"
  STAGED_FILE=""

  INSTALLED_PATH="$dest"
  INSTALLED_VERSION=$(read_version "$dest")
  PREVIOUS_VERSION="$previous"
}

# ---------------------------------------------------------------- report --

report() {
  info ""
  if [ -n "$PREVIOUS_VERSION" ] && [ "$PREVIOUS_VERSION" != "$INSTALLED_VERSION" ]; then
    ok "Upgraded ${C_BOLD}aidentity $PREVIOUS_VERSION → $INSTALLED_VERSION${C_RESET}"
  elif [ -n "$PREVIOUS_VERSION" ]; then
    ok "Reinstalled ${C_BOLD}aidentity $INSTALLED_VERSION${C_RESET}"
  else
    ok "Installed ${C_BOLD}aidentity $INSTALLED_VERSION${C_RESET}"
  fi
  printf '   %s\n' "$INSTALLED_PATH"

  local rc portable line
  if ! on_path "$INSTALL_DIR"; then
    rc=$(shell_rc_file)
    portable=$(portable_path "$INSTALL_DIR")
    line=$(path_set_line "$portable")
    info ""
    warn "$INSTALL_DIR is not on your PATH, so typing 'aidentity' will not find it yet."
    if [ -n "$rc" ]; then
      info ""
      printf '  1. Add this line to %s%s%s:\n' "$C_BOLD" "$rc" "$C_RESET"
      info ""
      printf '       %s\n' "$line"
      info ""
      printf '  2. Then reload it:  source %s\n' "$rc"
    else
      info ""
      printf '  Add this to your shell startup file, in your shell'"'"'s own syntax:\n'
      info ""
      printf '       %s\n' "$line"
    fi
    info ""
    dim "  Until then, run it by full path: $INSTALLED_PATH"
  else
    # On PATH, but is it *this* copy that wins? An older one earlier in PATH
    # would silently keep running.
    local found
    found=$(command -v "$BIN_NAME" 2>/dev/null) || found=""
    if [ -n "$found" ] && [ "$found" != "$INSTALLED_PATH" ]; then
      info ""
      warn "Another aidentity comes first on your PATH and will be used instead:"
      dim "    $found"
      dim "  Remove it, or move $INSTALL_DIR earlier in PATH."
    fi
  fi

  info ""
  info "${C_BOLD}Next:${C_RESET}"
  printf '  aidentity setup      guided walkthrough — start here\n'
  printf '  aidentity apps       list apps that can take a second account\n'
  printf '  aidentity doctor     check the setup\n'
  info ""
  dim "  $REPO_URL"
}

# Offer the walkthrough straight away, so the common path is one command total.
#
# stdin is the installer script itself when this arrives via `curl … | bash`, so
# both the question and the walkthrough have to be wired to the terminal
# explicitly. With no terminal (CI, a provisioning script) we simply skip it.
offer_setup() {
  [ -r /dev/tty ] || return 0
  [ -x "$INSTALLED_PATH" ] || return 0

  local reply=""
  info ""
  printf 'Set up your first extra account now? [Y/n] ' > /dev/tty
  IFS= read -r reply < /dev/tty 2>/dev/null || return 0
  case "$(printf '%s' "$reply" | tr '[:upper:]' '[:lower:]')" in
    ''|y|yes) ;;
    *) info ""; dim "  No problem — run 'aidentity setup' whenever you like."; return 0 ;;
  esac

  info ""
  "$INSTALLED_PATH" setup < /dev/tty || true
}

# ----------------------------------------------------------------- main --

main() {
  info "${C_BOLD}aidentity${C_RESET} — run several accounts of the same Mac app at the same time."
  info ""
  download
  verify
  choose_install_dir
  install_binary
  report
  offer_setup
}

main "$@"
