#!/usr/bin/env bash
#
# aidentity — run several accounts of the same Mac app at the same time.
#
# Builds a small launcher app per profile. The launcher opens the app you already
# have installed, pointed at its own data directory, so every account stays signed
# in simultaneously. The original app is never copied, patched or re-signed.
#
#   aidentity add                 # interactive
#   aidentity add Claude --profile Work
#   aidentity list
#   aidentity ui                  # full-screen menu
#   aidentity rm "Claude Work" --purge
#   aidentity update --check
#
# Environment (all optional):
#   AIDENTITY_APPS_DIR    where launchers are written (default: ~/Applications)
#   AIDENTITY_DATA_ROOT   where profile data lives
#                         (default: ~/Library/Application Support/aidentity/profiles)
#   AIDENTITY_APP_DIRS    colon-separated folders searched for apps
#                         (default: /Applications:~/Applications)
#
# The network is used by one command only: `aidentity update`, which asks
# GitHub for the latest release over HTTPS. Nothing else connects anywhere.
#
# https://github.com/PiniShv/aidentity
#
# Apache-2.0 licensed. Requires macOS. No dependencies beyond what ships with the OS.
#
# This file is built from the src/ folder of the repository by
# scripts/build.sh. To change it, edit those files and run `make build`.

set -uo pipefail

AIDENTITY_VERSION="1.6.1"

# Every launcher we build carries this key in its Info.plist. It is the ONLY way
# we recognise our own bundles, and nothing is ever deleted without it. That makes
# `rm` safe even if a profile is named after an app you already have installed.
MARKER_KEY="AIdentityProfile"

APPS_DIR="${AIDENTITY_APPS_DIR:-$HOME/Applications}"
DATA_ROOT="${AIDENTITY_DATA_ROOT:-$HOME/Library/Application Support/aidentity/profiles}"

# Make a path absolute and drop ".", "..", "//" and a trailing "/", on paper
# only — nothing on disk is read. Both directories below are overridable, and a
# relative value was recorded verbatim in a launcher's Info.plist, where it
# later resolved against whatever directory the tool ran from. Anchoring alone
# was not enough: "../profiles" became ".../sub/../profiles", which the purge
# guard rightly refuses (no dot segments), so purge, rename and prune refused
# every profile made with it.
normpath() {
  local p="$1" out="" seg oldifs="$IFS"
  case "$p" in /*) ;; *) p="$PWD/$p" ;; esac
  IFS='/'; set -f
  for seg in $p; do
    case "$seg" in
      ''|.) ;;
      ..) out="${out%/*}" ;;
      *) out="$out/$seg" ;;
    esac
  done
  set +f; IFS="$oldifs"
  printf '%s' "${out:-/}"
}

APPS_DIR=$(normpath "$APPS_DIR")
DATA_ROOT=$(normpath "$DATA_ROOT")

# This file, as it was started, made absolute on paper. `update` replaces it.
# BASH_SOURCE, not $0: when the script arrives on stdin (`curl … | bash`), $0
# is "bash", and following that would aim the update at the shell itself.
# BASH_SOURCE is empty then, and update refuses.
SELF_PATH="${BASH_SOURCE[0]:-}"
case "$SELF_PATH" in ''|/*) ;; *) SELF_PATH="$PWD/$SELF_PATH" ;; esac
