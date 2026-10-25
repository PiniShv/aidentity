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

# The test files are the runner, the shared part and one file for each area.
# The pattern stays as it is when no area file exists, and then it is reported
# as missing, like any other file.
FILES="bin/aidentity install.sh uninstall.sh test/run_tests.sh test/lib.sh test/t_*.sh"
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
# shellcheck disable=SC2086  # FILES is a fixed list of known names, and a glob
hits=$(perl -ne 'print "$ARGV:$.: $&\n" if /(?<!\{)\$[A-Za-z_][A-Za-z0-9_]*[^\x00-\x7F]/; close ARGV if eof' $FILES)
if [ -n "$hits" ]; then
  bad "Use \${var} when a non-ASCII character follows the name:"
  printf '%s\n' "$hits" >&2
else
  pass "braces before multi-byte characters"
fi

# 2. Installed copies check a download by its checksum alone, which proves it
#    is the published file but not that the file works. So the file is
#    checked here, before every release: it must parse as shell. On a Mac,
#    /bin/bash is the 3.2 that installed copies run. CI and the release gate
#    run this on Linux, where it is bash 5; there the 3.2 check is the macOS
#    test job, which runs the whole suite under /bin/bash. A script cut short
#    is often still valid shell; check 7 pins the last line for that.
if err=$(/bin/bash -n bin/aidentity 2>&1); then
  pass "bin/aidentity passes bash -n"
else
  bad "bin/aidentity is not valid shell (bash -n):"
  printf '%s\n' "$err" >&2
fi

# 3. Code is pasted into the scripts that cannot source bin/aidentity, and it
#    MUST stay in step: a drifted copy of running_on_profile once shipped a
#    dead guard. uninstall.sh carries the safety helpers (the running check is
#    four functions, so all four are compared), compared as code without
#    comments. install.sh carries the download block, compared byte for byte.
#    Either copy missing fails.
for fn in proc_snapshot running_on_profile running_in_snapshot proc_dir_ids data_is_ours is_our_launcher; do
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
block() { sed -n '/^# >>> download block/,/^# <<< download block/p' "$1"; }
a=$(block bin/aidentity); b=$(block install.sh)
# Each function once, inside the block: a second definition elsewhere in the
# file would quietly replace the shared one. Any way of writing one counts:
# name() {, name () { and function name {.
for fn in is_version is_release_tag https_fetch file_version verify_release_file install_atomic; do
  def="^[[:space:]]*(function[[:space:]]+${fn}([[:space:]]|\(|$)|${fn}[[:space:]]*\(\))"
  if ! printf '%s\n' "$a" | grep -q "^$fn() {" \
     || [ "$(grep -cE "$def" bin/aidentity)" != 1 ] || [ "$(grep -cE "$def" install.sh)" != 1 ]; then
    bad "$fn must be defined once, inside the download block, in bin/aidentity and install.sh"
  fi
done
if [ -z "$a" ] || [ -z "$b" ]; then
  bad "the download block is missing from bin/aidentity or install.sh"
elif [ "$a" != "$b" ]; then
  bad "the download block differs between bin/aidentity and install.sh"
  diff <(printf '%s\n' "$a") <(printf '%s\n' "$b") >&2 || true
else
  pass "the download block is the same in bin/aidentity and install.sh"
fi

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

# 6. The scripts run curl in one place, https_fetch, which holds it to HTTPS
#    and keeps the user's .curlrc out. Another call would use the network
#    without those settings, and SECURITY.md would no longer be true.
#    install.sh also prints lines that start "curl -fsSL $INSTALL_URL |" for
#    the user to run: those are text, not calls.
for f in bin/aidentity install.sh; do
  hits=$(perl -ne '
    $in = 1 if /^https_fetch\(\) \{/;
    print(($in ? "in" : "out"), " $.: $_")
      if !/^\s*#/ && !/^\s*curl -fsSL \$INSTALL_URL \| / && /(?<![\w.-])curl\s+(?:-|["\x27\$]|https?:)/;
    $in = 0 if $in && /^\}/;
  ' "$f")
  outside=$(printf '%s\n' "$hits" | grep '^out ' || true)
  inside=$(printf '%s\n' "$hits" | grep -c '^in ' || true)
  if [ -n "$outside" ]; then
    bad "curl may run only in https_fetch in $f:"
    printf '%s\n' "$outside" >&2
  elif [ "$inside" != "1" ]; then
    bad "https_fetch in $f should run curl once (found $inside); update this check if it moved"
  else
    pass "curl runs only in https_fetch in $f"
  fi
done

# 7. Every installed copy's `aidentity update` checks a release with its own
#    fixed code. Copies of 1.4.0 check the first line, the last line, the
#    version line and the SHA256SUMS line format (and bash -n, check 2). Later
#    copies check only the last two, but 1.4.0 copies stay installed. If one
#    of these changes, those copies can never update again.
case "$(head -n 1 bin/aidentity)" in
  '#!'*) pass "bin/aidentity starts with #!, which installed copies check" ;;
  *) bad "bin/aidentity must start with #!; installed copies of update check that" ;;
esac
last=$(awk 'NF {l=$0} END {sub(/[ \t\r]+$/,"",l); print l}' bin/aidentity)
# shellcheck disable=SC2016  # the literal text of the last line
if [ "$last" = 'main "$@"' ]; then
  pass "bin/aidentity ends on main \"\$@\", the line installed copies check"
else
  bad "bin/aidentity must end on [main \"\$@\"]; installed copies of update check that line. It ends on [$last]"
fi
n=$(grep -cE '^AIDENTITY_VERSION="[0-9]+\.[0-9]+\.[0-9]+"$' bin/aidentity)
if [ "$n" = "1" ]; then
  pass "bin/aidentity has one AIDENTITY_VERSION=\"x.y.z\" line"
else
  bad "bin/aidentity needs exactly one AIDENTITY_VERSION=\"x.y.z\" line (found $n); installed copies of update read it"
fi
if grep -qE '^[0-9a-f]{64}  bin/aidentity$' SHA256SUMS; then
  pass "SHA256SUMS has a '<sha256>  bin/aidentity' line"
else
  bad "SHA256SUMS needs a '<64 hex>  bin/aidentity' line; installed copies of update read that format. Run: make checksums"
fi

# 8. bin/aidentity is built from src/ by scripts/build.sh, and both are
#    committed. A change made in bin/aidentity alone would be lost at the next
#    build; one made in src/ alone would never ship.
if err=$(bash scripts/build.sh --check 2>&1); then
  pass "bin/aidentity is the build of src/"
else
  bad "bin/aidentity is not the build of src/. Edit src/*.sh, then run: make build"
  printf '%s\n' "$err" >&2
fi

exit "$fail"
