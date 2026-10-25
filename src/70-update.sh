# ---------------------------------------------------------------- update --
#
# `aidentity update` is the only code in this script that uses the network.
# It asks GitHub which release is the latest and, unless --check was given,
# downloads that release's bin/aidentity and SHA256SUMS and puts the new script
# in place of this one. Every check below must pass first; any failure leaves
# the old file exactly as it was. It never runs sudo and never downgrades.

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


version_newer() { # a, b (both x.y.z) -> true when a is newer than b
  local a b i
  IFS=. read -r -a a <<<"$1"
  IFS=. read -r -a b <<<"$2"
  # 10#: a part like "08" is not octal.
  for i in 0 1 2; do
    [ "$((10#${a[i]}))" -gt "$((10#${b[i]}))" ] && return 0
    [ "$((10#${a[i]}))" -lt "$((10#${b[i]}))" ] && return 1
  done
  return 1
}

# Where releases come from: the GitHub API for the latest tag, raw files for
# the download. Fixed: no setting can point update anywhere else.
#
# Copies already installed check every later release with their own fixed
# code, so each release must keep what they expect: the files at
# <tag>/bin/aidentity and <tag>/SHA256SUMS, a "<64 hex>  bin/aidentity" line in
# SHA256SUMS, and one AIDENTITY_VERSION="x.y.z" line. Copies of 1.4.0 also
# want #! on the first line, a file that passes bash -n, and main "$@" as the
# last line. A release that breaks any of these can never be installed by
# their `aidentity update`. scripts/guards.sh checks all of them.
UPDATE_API="https://api.github.com/repos/PiniShv/aidentity"
UPDATE_RAW="https://raw.githubusercontent.com/PiniShv/aidentity"

# The tag of the latest release, from the API's JSON. grep, because jq is not
# on a stock Mac. Text in the release notes cannot pose as this key: a quote
# inside a JSON string is always escaped, so it never matches '"tag_name"'.
latest_tag() { # json file
  local tag
  tag=$(grep -o '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' "$1" 2>/dev/null | head -n 1 \
        | sed 's/.*"\([^"]*\)"$/\1/')
  is_release_tag "$tag" || return 1
  printf '%s' "$tag"
}

# The real file behind this running copy: symlinks followed (a Homebrew link
# points into its Cellar) and its folder resolved with cd -P. Fails when there
# is no file — the script came in on stdin — or when the file found does not
# carry this copy's version line, so update never replaces anything else.
self_real_path() {
  local p="$SELF_PATH" link d n=0
  [ -n "$p" ] && [ -e "$p" ] || return 1
  while [ -L "$p" ]; do
    n=$((n+1)); [ "$n" -le 40 ] || return 1
    link=$(readlink "$p") || return 1
    case "$link" in /*) p="$link" ;; *) p="$(dirname "$p")/$link" ;; esac
  done
  [ -f "$p" ] || return 1
  d=$(command cd -P "$(dirname "$p")" 2>/dev/null && pwd -P) || return 1
  p="${d%/}/$(basename "$p")"
  [ -f "$p" ] && [ ! -L "$p" ] || return 1
  grep -qxF "AIDENTITY_VERSION=\"$AIDENTITY_VERSION\"" "$p" 2>/dev/null || return 1
  printf '%s' "$p"
}

# Homebrew keeps its own record of what it installed. Replacing its file
# behind its back makes that record wrong, so brew must do the update. Its
# files live in a Cellar, and everything under /opt/homebrew is brew's.
# /usr/local is skipped as a prefix: the installer puts copies there too, and
# brew's own files there are in /usr/local/Cellar, which the first test sees.
brew_owns() { # real path, path as started
  local p pre
  for p in "$1" "$2"; do
    case "$p" in */Cellar/*|/opt/homebrew/*) return 0 ;; esac
    for pre in "${HOMEBREW_PREFIX:-}" "${HOMEBREW_CELLAR:-}"; do
      pre="${pre%/}"
      case "$pre" in ''|/usr/local) continue ;; esac
      case "$p" in "$pre"/*) return 0 ;; esac
    done
  done
  return 1
}

# A copy inside the source code (bin/aidentity beside install.sh) belongs to
# git or to whoever unpacked it, not to this command. Prints the folder.
source_root() { # real path
  local bin root
  bin=$(dirname "$1"); root=$(dirname "$bin")
  [ "$(basename "$bin")" = "bin" ] && [ -f "$root/install.sh" ] \
    && [ -f "$root/uninstall.sh" ] && [ -f "$root/LICENSE" ] || return 1
  printf '%s' "$root"
}

# A path as the user should type it: quoted only when it has to be.
typed_path() {
  local LC_ALL=C
  case "$1" in *[!A-Za-z0-9/._+-]*) shquote "$1" ;; *) printf '%s' "$1" ;; esac
}

# Whether this user can replace the file: write access to its folder, and in a
# sticky folder (like /tmp) the file or the folder must be theirs too.
can_replace() { # file
  local dir; dir=$(dirname "$1")
  [ -w "$dir" ] || return 1
  [ ! -k "$dir" ] || [ -O "$1" ] || [ -O "$dir" ]
}

cmd_update() {
  local check=0 real="" how="" root="" hint tag new tmp
  while [ $# -gt 0 ]; do
    case "$1" in
      --check) check=1; shift ;;
      -*) die "Unknown option for update: $1" ;;
      *) die "Unexpected argument: $1" ;;
    esac
  done

  command -v curl >/dev/null 2>&1 || die "aidentity update needs curl, and it was not found."
  is_version "$AIDENTITY_VERSION" || die "This copy has no usable version number, so it cannot compare versions."

  # Who should update this copy. Settled before any network call, so a copy
  # that is not ours to replace is refused without contacting anything.
  real=$(self_real_path) || real=""
  if [ -n "$real" ] && brew_owns "$real" "$SELF_PATH"; then
    how="brew"; hint="brew upgrade aidentity"
  elif [ -n "$real" ] && root=$(source_root "$real"); then
    how="source"
    if [ -e "$root/.git" ]; then hint="git -C $(typed_path "$root") pull"
    else hint="download the new release from https://github.com/PiniShv/aidentity"; fi
  else
    hint="aidentity update"
  fi

  if [ "$check" -eq 0 ]; then
    case "$how" in
      brew) die "This copy of aidentity is managed by Homebrew, so Homebrew must update it:
    brew upgrade aidentity" ;;
      source) die "This copy runs from the aidentity source code in $root.
    Update the source code instead: $hint" ;;
    esac
    [ -n "$real" ] || die "Could not find the file this aidentity runs from, so there is nothing to replace.
    Run it by its full path, for example: /usr/local/bin/aidentity update"
  fi

  tmp="${TMPDIR:-/tmp}"
  UPDATE_TMP=$(mktemp -d "${tmp%/}/aidentity-update.XXXXXX" 2>/dev/null) \
    || { UPDATE_TMP=""; die "Could not create a temporary folder."; }

  info "Checking for the latest release of aidentity …"
  https_fetch "$UPDATE_API/releases/latest" "$UPDATE_TMP/release.json" 1048576 \
      -H 'Accept: application/vnd.github+json' \
    || die "Could not get the latest release from GitHub (curl's reason is above).
    Check your internet connection, or try again later. Nothing was changed."
  tag=$(latest_tag "$UPDATE_TMP/release.json") \
    || die "GitHub's answer did not name a valid release (a tag like v1.4.0). Nothing was changed."
  new="${tag#v}"

  if ! version_newer "$new" "$AIDENTITY_VERSION"; then
    if version_newer "$AIDENTITY_VERSION" "$new"; then
      # Never a downgrade: a build newer than the release stays as it is.
      ok "aidentity $AIDENTITY_VERSION is newer than the latest release ($new). Nothing to update."
    else
      ok "aidentity $AIDENTITY_VERSION is up to date."
    fi
    return 0
  fi

  if [ "$check" -eq 1 ]; then
    info "$AIDENTITY_VERSION → $new is available."
    dim "  What changed: https://github.com/PiniShv/aidentity/releases/tag/$tag"
    dim "  To update:    $hint"
    return 0
  fi

  # No sudo here, ever. Say what to run, and let the user decide.
  if ! can_replace "$real"; then
    die "$AIDENTITY_VERSION → $new is available, but you cannot replace $real.
    aidentity does not use sudo. To update, run this yourself:
      sudo $(typed_path "$real") update"
  fi

  info "Downloading aidentity $new …"
  https_fetch "$UPDATE_RAW/$tag/bin/aidentity" "$UPDATE_TMP/aidentity" 4194304 \
    || die "Could not download aidentity $new. Nothing was changed."
  https_fetch "$UPDATE_RAW/$tag/SHA256SUMS" "$UPDATE_TMP/SHA256SUMS" 65536 \
    || die "Could not download the checksum file for $new, so the download cannot be checked.
    Nothing was changed."
  verify_release_file "$UPDATE_TMP/aidentity" "$UPDATE_TMP/SHA256SUMS" "$new" \
    || die "Refusing to install it. Nothing was changed."
  dim "  checksum verified"

  info "Installing to $real …"
  install_atomic "$UPDATE_TMP/aidentity" "$real" "$VERIFIED_SUM"

  ok "Updated $AIDENTITY_VERSION → $new"
  printf '   %s\n' "$real"
  info ""
  info "Your launchers keep working. To rebuild them with the new version, run:"
  info "  aidentity doctor --fix"
  return 0
}
