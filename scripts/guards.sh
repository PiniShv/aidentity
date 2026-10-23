#!/usr/bin/env bash
#
# The source checks CI runs beyond lint and the test suite, in one place so
# `make check` runs exactly what CI runs. Exit status is non-zero if any fails.
#
#   bash scripts/guards.sh
#
# Each check exists because its absence once shipped a bug; the reason is
# written next to it.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

FILES="bin/aidentity install.sh uninstall.sh test/run_tests.sh"
fail=0
pass() { printf 'ok    %s\n' "$1"; }
bad()  { printf '::error::%s\n' "$1" >&2; fail=1; }

# A missing file must fail, not shrink the checks below to nothing.
for f in $FILES SHA256SUMS; do
  [ -f "$f" ] || bad "missing: $f"
done

# 1. "$var…" expands as ${var…} in bash and dies under `set -u`. perl, not
#    `grep -P`: BSD grep rejects -P, which once made this check pass
#    unconditionally on macOS.
# shellcheck disable=SC2086  # FILES is a fixed list of known names
hits=$(perl -ne 'print "$ARGV:$.: $&\n" if /(?<!\{)\$[A-Za-z_][A-Za-z0-9_]*[^\x00-\x7F]/; close ARGV if eof' $FILES)
if [ -n "$hits" ]; then
  bad "Use \${var} when a non-ASCII character follows the name:"
  printf '%s\n' "$hits" >&2
else
  pass "braces before multi-byte characters"
fi

# 2. install.sh verifies a download by matching this exact final line.
marker=$(sed -n "s/^END_MARKER='\(.*\)'$/\1/p" install.sh)
last=$(awk 'NF {l=$0} END {sub(/[ \t\r]+$/,"",l); print l}' bin/aidentity)
if [ -n "$marker" ] && [ "$last" = "$marker" ]; then
  pass "bin/aidentity ends on install.sh's END_MARKER"
else
  bad "bin/aidentity must end on [$marker] but ends on [$last]"
fi

# 3. Safety helpers are copied into uninstall.sh and MUST stay in step: a
#    drifted copy of running_on_profile once shipped a dead guard. Compare
#    code, not comments, and fail when either copy is missing.
for fn in running_on_profile data_is_ours is_our_launcher; do
  a=$(sed -n "/^$fn() {/,/^}/p" bin/aidentity | grep -v '^[[:space:]]*#' | grep -v '^[[:space:]]*$' || true)
  b=$(sed -n "/^$fn() {/,/^}/p" uninstall.sh  | grep -v '^[[:space:]]*#' | grep -v '^[[:space:]]*$' || true)
  if [ -z "$a" ] || [ -z "$b" ]; then
    bad "$fn is missing from bin/aidentity or uninstall.sh"
  elif [ "$a" != "$b" ]; then
    bad "$fn differs between bin/aidentity and uninstall.sh"
    diff <(printf '%s\n' "$a") <(printf '%s\n' "$b") >&2 || true
  else
    pass "$fn is the same in both scripts"
  fi
done

# 4. A changed bin/aidentity without a new SHA256SUMS fails every piped install.
want=$(awk '$2 == "bin/aidentity" { print $1; exit }' SHA256SUMS)
got=$(shasum -a 256 bin/aidentity | awk '{print $1}')
if [ -n "$want" ] && [ "$want" = "$got" ]; then
  pass "SHA256SUMS matches bin/aidentity"
else
  bad "SHA256SUMS is stale (expected $want, got $got). Run: make checksums"
fi

# 5. The installer's default ref is either main or this exact release, so the
#    script and its checksum always come from the same version.
version=$(sed -n 's/^AIDENTITY_VERSION="\(.*\)"$/\1/p' bin/aidentity)
# shellcheck disable=SC2016  # the $ is part of the text matched, not expanded
ref=$(sed -n 's/^REF="\${AIDENTITY_REF:-\(.*\)}"$/\1/p' install.sh)
if [ "$ref" = "main" ] || [ "$ref" = "v$version" ]; then
  pass "install.sh installs '$ref' (version $version)"
else
  bad "install.sh's default ref is '$ref'; it must be main or v$version. Run: make release VERSION=$version"
fi

exit "$fail"
