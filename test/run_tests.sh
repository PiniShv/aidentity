#!/usr/bin/env bash
# shellcheck shell=bash
#
# aidentity test suite — self-contained, no frameworks, no dependencies.
#
# Everything runs against temporary directories. AIDENTITY_APPS_DIR and
# AIDENTITY_DATA_ROOT are pointed at a sandbox before the first command runs,
# and a test of its own proves the real ~/Applications and the real profile
# directory are never written to.
#
# The suite builds its own fake .app bundles, so it passes on a CI runner with
# no Chromium or Electron app installed.
#
# The suite is split by area. test/lib.sh holds what every area shares: the
# sandbox, the assertions, the runners and the fixtures. Each test/t_<area>.sh
# holds the groups of one area. This file is the entry point: it runs the first
# and last groups itself and sources the areas between them.
#
#   bash test/run_tests.sh                 # run everything
#   bash test/run_tests.sh ui completion   # only those areas
#   bash test/run_tests.sh --list          # print the area names
#   make test                              # run everything
#   make test AREA=ui                      # one area (several: AREA="ui help")
#   AIDENTITY_TEST_KEEP=1 bash …           # keep the sandbox for inspection
#   AIDENTITY_BIN=/path/to/script …        # test a different copy of the script
#
# Areas run in the order of TEST_AREAS below, whatever order they are named in.
# Each starts from an empty work space (see area_reset in lib.sh), so it gives
# the same results alone as in a full run, and is checked after it ends for a
# launcher or profile data left behind. Every file is parsed with the running
# bash before anything runs. The "sandbox isolation" and "fixtures" groups run
# first, and the final isolation check last, whichever areas are chosen. With
# AIDENTITY_TEST_KEEP=1 the files of earlier areas are gone at the end; run one
# area to look at its files.
#
# Output is TAP-ish: one "ok N - …" or "not ok N - …" line per assertion, a
# plan line, and a final count. Exit status is non-zero if anything failed.
# An area name that does not exist exits with status 2.

set -uo pipefail

TEST_DIR=$(cd "$(dirname "$0")" && pwd)

# The areas, in the order they run. Each one is the file test/t_<area>.sh. A
# new file has to be added here, or the suite stops and says so.
TEST_AREAS="basics lifecycle running quit accounts maintenance restore settings json transfer ui launcher install release uninstall help completion update"

print_areas() {
  local area_name
  for area_name in $TEST_AREAS; do printf '%s\n' "$area_name"; done
}

# Every area is a file, and every file is an area. A file that is not in the
# list would never run, and nothing would say so. bash reads a sourced file one
# command at a time: a line this bash cannot parse (bash 4 syntax under the 3.2
# that macOS ships, say) would end that file there, and the tests after it would
# never run, without a failure. So every file is parsed whole first. All of this
# runs before the areas are chosen, so a new file's mistake is named first.
parses() { # file
  "$BASH" -n "$1" || { printf 'test/%s does not parse under %s\n' "${1##*/}" "$BASH" >&2; exit 1; }
}
for area_name in $TEST_AREAS; do
  [ -f "$TEST_DIR/t_$area_name.sh" ] || {
    printf 'The test area %s has no file: test/t_%s.sh\n' "$area_name" "$area_name" >&2; exit 1; }
  parses "$TEST_DIR/t_$area_name.sh"
done
for area_file in "$TEST_DIR"/t_*.sh; do
  [ -e "$area_file" ] || continue
  area_name=${area_file##*/t_}; area_name=${area_name%.sh}
  case " $TEST_AREAS " in
    *" $area_name "*) ;;
    *) printf 'test/t_%s.sh is not listed in TEST_AREAS in test/run_tests.sh\n' "$area_name" >&2; exit 1 ;;
  esac
done
parses "$TEST_DIR/lib.sh"

# ---------------------------------------------------------- choose the areas --

# Before the sandbox is made, so --list and a wrong name work on any machine.
WANT_AREAS=""
for area_arg in "$@"; do
  if [ "$area_arg" = --list ]; then print_areas; exit 0; fi
  is_area=no
  for area_name in $TEST_AREAS; do
    [ "$area_name" = "$area_arg" ] && is_area=yes
  done
  if [ "$is_area" = no ]; then
    printf 'Unknown test area: %s\nThe areas are:\n' "$area_arg" >&2
    print_areas >&2
    exit 2
  fi
  WANT_AREAS="$WANT_AREAS $area_arg"
done
set --

# shellcheck source=/dev/null  # shellcheck reads each file on its own
. "$TEST_DIR/lib.sh"

# ====================================================== always run, first ==

group "sandbox isolation"

REAL_APPS_BEFORE=$(snapshot "$REAL_APPS")
REAL_DATA_BEFORE=$(snapshot "$REAL_DATA")
REAL_TRASH_BEFORE=$(trash_names "$REAL_TRASH")

assert_nonempty "AIDENTITY_APPS_DIR is set" "${AIDENTITY_APPS_DIR:-}"
assert_nonempty "AIDENTITY_DATA_ROOT is set" "${AIDENTITY_DATA_ROOT:-}"
assert_contains "AIDENTITY_APPS_DIR lives inside the sandbox" "$AIDENTITY_APPS_DIR" "$SANDBOX"
assert_contains "AIDENTITY_DATA_ROOT lives inside the sandbox" "$AIDENTITY_DATA_ROOT" "$SANDBOX"
assert_contains "HOME lives inside the sandbox, so its Trash does too" "$HOME" "$SANDBOX"
assert_ne "AIDENTITY_APPS_DIR is not the real ~/Applications" "$REAL_APPS" "$AIDENTITY_APPS_DIR"
assert_ne "AIDENTITY_DATA_ROOT is not the real profile directory" \
  "$REAL_DATA/profiles" "$AIDENTITY_DATA_ROOT"
assert_dir "sandbox launcher directory exists" "$APPS"
assert_dir "sandbox data directory exists" "$DATA"
assert_contains "sandbox path contains a space, so quoting is exercised" "$SB" " "

group "fixtures"

build_fixture_apps

assert_dir "built a fake Electron app" "$ELECTRON_APP"
assert_dir "built a fake Chromium-fork app" "$FORK_APP"
assert_dir "built a fake native app" "$NATIVE_APP"

make_lib_copies
assert_file "extracted a sourceable library copy of the script" "$LIB"
libcall slugify "probe"
assert_rc "sourcing the library defines its helper functions" 0 "$RUN_RC" "$RUN_OUT"

# ============================================================== the areas ==

for area_name in $TEST_AREAS; do
  if [ -n "$WANT_AREAS" ]; then
    case " $WANT_AREAS " in *" $area_name "*) ;; *) continue ;; esac
  fi
  area_reset || exit 1
  # shellcheck source=/dev/null  # one file for each area, listed in the lint
  . "$TEST_DIR/t_$area_name.sh"
  # The next area starts from an empty work space, so a launcher or profile
  # left behind would go unnoticed there. Each area cleans up after itself.
  assert_eq "area $area_name left no launcher behind" 0 "$(count_launchers)"
  assert_eq "and no profile data" "" "$(ls -A "$DATA" 2>/dev/null)"
  assert_eq "and no VS Code-style profile data" "" "$(ls -A "$VSC_DATA" 2>/dev/null)"
done

# ======================================================= always run, last ==

group "sandbox isolation — final check"

assert_eq "the real ~/Applications is unchanged" "$REAL_APPS_BEFORE" "$(snapshot "$REAL_APPS")"
assert_eq "the real aidentity data directory is unchanged" "$REAL_DATA_BEFORE" "$(snapshot "$REAL_DATA")"
assert_no_dir "no launcher leaked into the real ~/Applications" "$REAL_APPS/Fake Work.app"
assert_no_dir "no profile leaked into the real data directory" "$REAL_DATA/profiles/fake-work"
assert_eq "no profile data went to the real Trash" "$REAL_TRASH_BEFORE" "$(trash_names "$REAL_TRASH")"
assert_dir "everything the suite created is inside the sandbox" "$SANDBOX"

# ================================================================== report ==

[ -z "$WANT_AREAS" ] || printf '# only these areas ran:%s\n' "$WANT_AREAS"
printf '1..%d\n' "$TEST_NUM"
if [ "$FAIL_COUNT" -eq 0 ]; then
  printf '%s# %d tests, 0 failed%s\n' "$P_GREEN" "$TEST_NUM" "$P_OFF"
  exit 0
fi
printf '%s# %d tests, %d failed%s\n' "$P_RED" "$TEST_NUM" "$FAIL_COUNT" "$P_OFF"
exit 1
