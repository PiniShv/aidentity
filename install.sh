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
#   2. Downloads bin/aidentity and SHA256SUMS from the same ref to a temp
#      folder. The folder is deleted on exit, whether this succeeds or fails.
#   3. Checks the download against SHA256SUMS. No checksum, a checksum that
#      does not match, or a SHA256SUMS it cannot download, and nothing is
#      installed. For a release tag (vX.Y.Z), the file must also say it is
#      version X.Y.Z. A damaged or wrong file never reaches your PATH.
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
#   AIDENTITY_REF           branch, tag or commit to install from. The default is
#                           the REF= line below: the latest release once one is
#                           tagged (`make release` sets it), main before that.
#
# Uninstall:  https://raw.githubusercontent.com/PiniShv/aidentity/main/uninstall.sh
#
# MIT licensed. https://github.com/PiniShv/aidentity — contact@pinishv.com

set -euo pipefail

REPO_URL="https://github.com/PiniShv/aidentity"
REF="${AIDENTITY_REF:-v1.6.0}"

# REF is interpolated into a raw.githubusercontent.com path, and curl collapses
# dot-segments before sending the request — so a REF containing ".." walked up
# and back down into a DIFFERENT owner and repo, and the installer happily
# fetched and installed whatever that repo served. Validate before use.
case "$REF" in
  ''|*..*|/*|*/|*[!A-Za-z0-9._/-]*)
    printf 'Refusing to use AIDENTITY_REF=%s\n' "$REF" >&2
    printf 'A ref may contain letters, numbers, dot, underscore, hyphen and slash,\n' >&2
    printf 'may not contain "..", and may not start or end with "/".\n' >&2
    exit 1 ;;
esac
SOURCE_URL="https://raw.githubusercontent.com/PiniShv/aidentity/${REF}/bin/aidentity"
SUMS_URL="https://raw.githubusercontent.com/PiniShv/aidentity/${REF}/SHA256SUMS"
INSTALL_URL="https://raw.githubusercontent.com/PiniShv/aidentity/${REF}/install.sh"

BIN_NAME="aidentity"
PRIMARY_DIR="/usr/local/bin"
FALLBACK_DIR="$HOME/.local/bin"

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

# Set before use; the trap tolerates them being empty. The download block
# below sets INSTALL_STAGED (its staged copy) and VERIFIED_SUM.
TMP_DIR=""
INSTALL_STAGED=""
VERIFIED_SUM=""

# Filled in as we go. Declared here so 'set -u' has nothing to trip over.
INSTALL_DIR=""
INSTALLED_PATH=""
INSTALLED_VERSION=""
PREVIOUS_VERSION=""

cleanup() {
  [ -n "$INSTALL_STAGED" ] && rm -f "$INSTALL_STAGED"
  # Only ever a folder this script made with mktemp.
  case "$TMP_DIR" in */aidentity-install.?*) rm -rf "$TMP_DIR" ;; esac
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

# ------------------------------------------------- download and checks --

# >>> download block: identical in bin/aidentity and install.sh
# scripts/guards.sh fails when the two copies differ (see CONTRIBUTING.md).

# x.y.z, each part 1 to 9 digits. The cap keeps a version compare inside
# bash's 64-bit arithmetic, where a longer part wraps round to a small number.
# The case test goes first: it refuses a newline, which a regex might not.
is_version() {
  local re='^[0-9]{1,9}\.[0-9]{1,9}\.[0-9]{1,9}$'
  case "$1" in ''|*[!0-9.]*) return 1 ;; esac
  [[ $1 =~ $re ]]
}

# A release tag: v, then x.y.z, and nothing else. A tag that arrives from the
# network is checked before it goes into a URL or onto the screen: a "/" or
# ".." could steer the download elsewhere, and an escape sequence could
# rewrite the terminal.
is_release_tag() {
  case "$1" in v*) is_version "${1#v}" ;; *) return 1 ;; esac
}

# One HTTPS download into a file. -q must stay the FIRST argument: it stops
# curl from reading the user's .curlrc, where a line like "insecure" would turn
# off certificate checks and "output" would send the file somewhere else.
# --proto and --proto-redir hold every transfer, redirects included, to HTTPS.
# --max-filesize stops an answer far bigger than the file asked for. Into a
# file, never a pipe, so curl's own exit status is what gets checked.
https_fetch() { # url, output file, max bytes, [extra curl options]
  local url="$1" out="$2" max="$3"
  shift 3
  curl -q -fsSL --proto '=https' --proto-redir '=https' --tlsv1.2 \
       --connect-timeout 10 --max-time 60 --retry 2 --max-filesize "$max" \
       "$@" -o "$out" "$url"
}

# The version a copy of the script says it is: its first AIDENTITY_VERSION
# line, read from the file and never by running it. Empty when there is none.
file_version() { # file
  sed -n '/^AIDENTITY_VERSION="\([^"]*\)"$/{s//\1/p;q;}' "$1" 2>/dev/null || true
}

# Check a download against the SHA256SUMS published beside it, or say why not
# and return 1: a line for bin/aidentity with 64 hex digits (no checksum, no
# install), a matching SHA-256 and, unless the version is "-", the file's own
# version line. Sets VERIFIED_SUM, which install_atomic installs against.
verify_release_file() { # file, checksum file, version (x.y.z, or - for none)
  local LC_ALL=C want got
  VERIFIED_SUM=""
  [ -n "${3:-}" ] || { warn "No version was given to check the download against."; return 1; }
  want=$(awk '$2 == "bin/aidentity" { print $1; exit }' "$2" 2>/dev/null) || want=""
  case "$want" in *[!0-9a-f]*) want="" ;; esac
  if [ "${#want}" -ne 64 ]; then
    warn "The checksum file has no valid line for bin/aidentity, so the download cannot be checked."
    return 1
  fi
  got=$(shasum -a 256 "$1" 2>/dev/null | awk '{print $1}') || got=""
  if [ "$got" != "$want" ]; then
    warn "Checksum mismatch: the download is not the published file.
    expected ${want}
    got      ${got:-(none)}"
    return 1
  fi
  if [ "$3" != - ] && [ "$(file_version "$1")" != "$3" ]; then
    warn "The download does not say it is version $3."
    return 1
  fi
  VERIFIED_SUM="$want"
}

# Put a checked file in place of the destination in one step: write it beside
# the destination, check it against the verified checksum, then mv it over. A
# half-written file is never seen under the real name, and a copy running now
# keeps reading its old file. mktemp, not a fixed name: in a folder others can
# write to, as /usr/local/bin often is, a fixed name can be planted as a
# symlink and the file written through it. Any failure dies; the EXIT trap
# removes INSTALL_STAGED.
install_atomic() { # checked file, destination, its VERIFIED_SUM
  local src="$1" dest="$2" sum="$3" dir
  dir=$(dirname "$dest")
  [ "${#sum}" -eq 64 ] || die "The download was not checked. Nothing was changed."
  INSTALL_STAGED=$(mktemp "$dir/.aidentity.XXXXXX" 2>/dev/null) \
    || { INSTALL_STAGED=""; die "Could not write to $dir. Nothing was changed."; }
  cat "$src" > "$INSTALL_STAGED" && chmod 755 "$INSTALL_STAGED" \
    || die "Could not write the new copy to $dir. Nothing was changed."
  [ "$(shasum -a 256 "$INSTALL_STAGED" 2>/dev/null | awk '{print $1}')" = "$sum" ] \
    || die "The copy written to $dir does not match the download. Nothing was changed."
  # -h replaces a link at the destination instead of following it into a
  # folder. /bin/mv: -h is BSD-only, and a GNU mv first on PATH rejects it.
  /bin/mv -fh "$INSTALL_STAGED" "$dest" \
    || die "Could not replace $dest. Nothing was changed."
  INSTALL_STAGED=""
  [ -f "$dest" ] && [ ! -L "$dest" ] \
    && [ "$(shasum -a 256 "$dest" 2>/dev/null | awk '{print $1}')" = "$sum" ] \
    || die "Installing did not leave the new copy at $dest.
    Check what is at that path, then run the installer again."
}

# <<< download block


# Download the script and its checksum file from the same ref.
download() {
  local tmp="${TMPDIR:-/tmp}"
  TMP_DIR=$(mktemp -d "${tmp%/}/aidentity-install.XXXXXX") \
    || die "Could not create a temporary folder."

  info "Downloading aidentity (${REF}) …"
  dim "  $SOURCE_URL"
  https_fetch "$SOURCE_URL" "$TMP_DIR/aidentity" 4194304 \
    || die "Could not download aidentity from AIDENTITY_REF=$REF (curl's reason is above).
    Check your internet connection, or that '$REF' exists in $REPO_URL
    A proxy or CA certificate set in ~/.curlrc is not used here: set
    https_proxy or CURL_CA_BUNDLE instead.
    Nothing was installed."
  https_fetch "$SUMS_URL" "$TMP_DIR/SHA256SUMS" 65536 \
    || die "Could not download SHA256SUMS for AIDENTITY_REF=$REF, so the download cannot be checked.
    Nothing was installed."
}

# The checksum is required: no line for bin/aidentity, or a mismatch, and
# nothing is installed. For a release tag the file must also say it is that
# version, so a tag cannot hand out another version's file. A branch or a
# commit names no version, so its checksum alone decides.
#
# Be honest about what this buys: it catches corruption, truncation, a proxy
# swapping the body, and a partial CDN object. It does NOT defend against a
# compromise of the repository itself, because the checksum is served from the
# same origin as the file. Homebrew is the stronger channel — its formula pins
# a sha256 reviewed at release time.
verify() {
  local version=-
  is_release_tag "$REF" && version="${REF#v}"
  verify_release_file "$TMP_DIR/aidentity" "$TMP_DIR/SHA256SUMS" "$version" \
    || die "Refusing to install aidentity from AIDENTITY_REF=$REF. Nothing was installed."
  dim "  checksum verified"
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

  # A real directory here (a checkout at ~/bin/aidentity, say) would swallow the
  # file: mv moves INTO a directory instead of replacing it.
  if [ -d "$dest" ] && [ ! -L "$dest" ]; then
    die "$dest is a directory, not a file. Move it aside, then run this again.
    Nothing was installed."
  fi
  if [ -e "$dest" ]; then
    previous=$(file_version "$dest")
    [ -n "$previous" ] || previous="unknown"
  fi

  install_atomic "$TMP_DIR/aidentity" "$dest" "$VERIFIED_SUM"

  INSTALLED_PATH="$dest"
  INSTALLED_VERSION=$(file_version "$dest")
  [ -n "$INSTALLED_VERSION" ] || INSTALLED_VERSION="unknown"
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
#
# The terminal test opens /dev/tty rather than reading its mode bits: those say
# "readable" on every Mac, terminal or not, so a CI or MDM install that had
# just succeeded died on the redirection below and exited 1.
offer_setup() {
  ( : < /dev/tty ) 2>/dev/null || return 0
  [ -x "$INSTALLED_PATH" ] || return 0
  # Under the sudo line printed above, setup would build launchers and profile
  # directories owned by root, in root's home. Leave it to the user.
  if [ "$(id -u)" -eq 0 ]; then
    info ""
    dim "  Run 'aidentity setup' as yourself (not with sudo) to set up an account."
    return 0
  fi

  local reply=""
  info ""
  printf 'Set up your first extra account now? [Y/n] ' 2>/dev/null > /dev/tty || return 0
  IFS= read -r reply 2>/dev/null < /dev/tty || return 0
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
