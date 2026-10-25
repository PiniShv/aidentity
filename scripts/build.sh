#!/usr/bin/env bash
#
# Builds bin/aidentity from the files in src/. The tool ships as that one file:
# install.sh, `aidentity update` and the Homebrew formula all fetch it alone.
# src/ is where it is written, split by subject so each part can be read on
# its own. The build joins the files in name order with one blank line between
# them, and adds nothing else.
#
#   bash scripts/build.sh               # write bin/aidentity (make build)
#   bash scripts/build.sh --check       # fail if bin/aidentity is not the build
#   bash scripts/build.sh --where 2345  # which src/ line is line 2345 of bin/aidentity
#
# --where is for messages that name a line of bin/aidentity, from bash or
# from shellcheck. Edit the src/ line it prints.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

# The glob below sorts by locale; C keeps it to byte order.
LC_ALL=C

OUT=bin/aidentity

die() { printf '%s\n' "$1" >&2; exit 1; }

# Each file is "NN-name.sh"; NN sets its place. Anything else in src/ is a
# mistake that would otherwise be left out of the build without a word.
sources() {
  local f found=0
  for f in src/*; do
    [ -e "$f" ] || continue
    case "${f#src/}" in
      [0-9][0-9]-*.sh) found=1 ;;
      *) die "src/ holds only NN-name.sh files, which the build joins in order. Rename or move: $f" ;;
    esac
  done
  [ "$found" = 1 ] || die "No src/NN-name.sh files to build from. Run this from a full checkout."
  for f in src/[0-9][0-9]-*.sh; do
    # A last line without a newline would be glued to the next file's first.
    # An empty file would still get a blank line before it, which --where
    # cannot count, so every line after it would map to the wrong place.
    [ -s "$f" ] || die "$f is empty. Add its code, or delete it."
    [ -z "$(tail -c 1 "$f")" ] || die "$f must end with a newline."
  done
}

build() {
  local f first=1
  for f in src/[0-9][0-9]-*.sh; do
    [ "$first" = 1 ] || printf '\n'
    cat "$f" || return 1
    first=0
  done
}

case "${1:-}" in
  '')
    sources
    tmp=$(mktemp "bin/.aidentity.XXXXXX") || die "Could not create a file in bin/."
    # Removed on any exit, Ctrl-C included. After the move it is already gone.
    trap 'rm -f "$tmp"' EXIT
    if build > "$tmp" && chmod 755 "$tmp" && mv -f "$tmp" "$OUT"; then
      parts=(src/[0-9][0-9]-*.sh)
      printf 'Built %s from %s files in src/.\n' "$OUT" "${#parts[@]}"
    else
      die "Could not build $OUT."
    fi
    ;;
  --check)
    sources
    if ! cmp -s <(build) "$OUT"; then
      printf '%s is not the build of src/. Make changes in src/*.sh, not in %s, then run: make build\n' "$OUT" "$OUT" >&2
      diff -u -L 'the build of src/' -L "$OUT" <(build) "$OUT" | head -n 20 >&2
      exit 1
    fi
    ;;
  --where)
    case "${2:-}" in ''|*[!0-9]*|0*) die "Usage: scripts/build.sh --where LINE  (a line number of $OUT)" ;; esac
    sources
    # Line by line through the same join the build does: one blank line
    # before every file but the first.
    awk -v want="$2" '
      FNR == 1 && NR > 1 { if (++n == want) { print "the blank line between " prev " and " FILENAME; found = 1; exit } }
      { if (++n == want) { print FILENAME ":" FNR; found = 1; exit } prev = FILENAME }
      END { if (!found) { print "'"$OUT"' has only " n " lines" > "/dev/stderr"; exit 1 } }
    ' src/[0-9][0-9]-*.sh
    ;;
  *)
    die "Usage: scripts/build.sh [--check | --where LINE]"
    ;;
esac
