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
#   bash test/run_tests.sh            # run everything
#   make test                         # same
#   AIDENTITY_TEST_KEEP=1 bash …      # keep the sandbox for inspection
#   AIDENTITY_BIN=/path/to/script …   # test a different copy of the script
#
# Output is TAP-ish: one "ok N - …" or "not ok N - …" line per assertion, a
# plan line, and a final count. Exit status is non-zero if anything failed.

set -uo pipefail

# ------------------------------------------------------------------ setup --

TEST_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(dirname "$TEST_DIR")
AIDENTITY="${AIDENTITY_BIN:-$REPO_DIR/bin/aidentity}"

if [ ! -f "$AIDENTITY" ]; then
  printf '1..0 # SKIP no aidentity script at %s\n' "$AIDENTITY"
  exit 1
fi

if [ "$(uname)" != "Darwin" ]; then
  printf '1..0 # SKIP aidentity is macOS only (this is %s)\n' "$(uname)"
  exit 0
fi

# No colour codes in captured output, so assertions can match plain text.
export NO_COLOR=1
export LC_ALL=C

if [ -t 1 ]; then
  P_GREEN=$'\033[32m'; P_RED=$'\033[31m'; P_DIM=$'\033[2m'; P_OFF=$'\033[0m'
else
  P_GREEN=''; P_RED=''; P_DIM=''; P_OFF=''
fi

TEST_NUM=0
FAIL_COUNT=0
CURRENT_GROUP=''

RUN_OUT=''
RUN_RC=0

# The real locations these tests must never touch.
REAL_APPS="$HOME/Applications"
REAL_DATA="$HOME/Library/Application Support/aidentity"

SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/aidentity-tests.XXXXXX") || {
  printf '1..0 # SKIP could not create a sandbox directory\n'; exit 1
}

# A space in the path on purpose: the launcher embeds these paths in a shell
# script, so quoting bugs surface here rather than on a user's Mac.
SB="$SANDBOX/work space"
APPS="$SB/Applications"
DATA="$SB/profile data"
SRC="$SB/src"
mkdir -p "$APPS" "$DATA" "$SRC"

export AIDENTITY_APPS_DIR="$APPS"
export AIDENTITY_DATA_ROOT="$DATA"

# Reached only through the EXIT/INT/TERM trap installed below, which shellcheck
# cannot see — hence both suppressions. SC2329 is the older spelling, SC2317 the
# newer one; keep both so the lint passes on any shellcheck version.
# shellcheck disable=SC2329,SC2317
cleanup() {
  if [ -n "${AIDENTITY_TEST_KEEP:-}" ]; then
    printf '%s# sandbox kept: %s%s\n' "$P_DIM" "$SANDBOX" "$P_OFF"
    return 0
  fi
  case "$SANDBOX" in
    */aidentity-tests.*)
      chmod -R u+rwX "$SANDBOX" 2>/dev/null
      rm -rf "$SANDBOX"
      ;;
    *) printf '# refusing to remove an unexpected sandbox path: %s\n' "$SANDBOX" >&2 ;;
  esac
}
trap cleanup EXIT INT TERM

# ------------------------------------------------------------- assertions --

group() { CURRENT_GROUP="$1"; printf '%s# --- %s%s\n' "$P_DIM" "$1" "$P_OFF"; }

_pass() {
  TEST_NUM=$((TEST_NUM + 1))
  printf '%sok%s %d - %s\n' "$P_GREEN" "$P_OFF" "$TEST_NUM" "$1"
}

_fail() {
  TEST_NUM=$((TEST_NUM + 1))
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf '%snot ok%s %d - %s\n' "$P_RED" "$P_OFF" "$TEST_NUM" "$1"
  shift
  local line
  for line in "$@"; do printf '#   %s\n' "$line"; done
  [ -n "$CURRENT_GROUP" ] && printf '#   (group: %s)\n' "$CURRENT_GROUP"
  return 0
}

_skip() {
  TEST_NUM=$((TEST_NUM + 1))
  printf 'ok %d - %s # SKIP %s\n' "$TEST_NUM" "$1" "$2"
}

assert_eq() { # desc expected actual
  if [ "$2" = "$3" ]; then _pass "$1"; else _fail "$1" "expected: [$2]" "     got: [$3]"; fi
}

assert_ne() { # desc not_expected actual
  if [ "$2" != "$3" ]; then _pass "$1"; else _fail "$1" "should differ from: [$2]"; fi
}

assert_rc() { # desc expected_rc actual_rc [output]
  if [ "$2" = "$3" ]; then _pass "$1"; else _fail "$1" "expected exit $2, got $3" "output: ${4:-<none>}"; fi
}

assert_rc_nonzero() { # desc actual_rc [output]
  if [ "$2" -ne 0 ]; then _pass "$1"; else _fail "$1" "expected a non-zero exit, got 0" "output: ${3:-<none>}"; fi
}

assert_contains() { # desc haystack needle
  case "$2" in
    *"$3"*) _pass "$1" ;;
    *) _fail "$1" "expected to find: [$3]" "in: [$2]" ;;
  esac
}

assert_not_contains() { # desc haystack needle
  case "$2" in
    *"$3"*) _fail "$1" "should NOT contain: [$3]" "in: [$2]" ;;
    *) _pass "$1" ;;
  esac
}

assert_nonempty() { # desc value
  if [ -n "$2" ]; then _pass "$1"; else _fail "$1" "value was empty"; fi
}

assert_dir()     { if [ -d "$2" ];   then _pass "$1"; else _fail "$1" "no such directory: $2"; fi; }
assert_no_dir()  { if [ ! -d "$2" ]; then _pass "$1"; else _fail "$1" "directory exists but should not: $2"; fi; }
assert_file()    { if [ -f "$2" ];   then _pass "$1"; else _fail "$1" "no such file: $2"; fi; }
assert_no_file() { if [ ! -f "$2" ]; then _pass "$1"; else _fail "$1" "file exists but should not: $2"; fi; }
assert_exec()    { if [ -x "$2" ];   then _pass "$1"; else _fail "$1" "not executable: $2"; fi; }

# ---------------------------------------------------------------- runners --

# Run the CLI. Combines stdout and stderr; stdin is closed so nothing can hang
# on a prompt. Results land in RUN_OUT / RUN_RC.
ai() {
  RUN_OUT=$(bash "$AIDENTITY" "$@" 2>&1 </dev/null)
  RUN_RC=$?
  return 0
}

# Same, but feed a line on stdin (for the rm confirmation prompt).
ai_in() {
  local input="$1"; shift
  RUN_OUT=$(printf '%s\n' "$input" | bash "$AIDENTITY" "$@" 2>&1)
  RUN_RC=$?
  return 0
}

# Call one of the script's own functions in a fresh bash, with the dispatch
# line stripped so sourcing does not execute a command.
LIB="$SANDBOX/aidentity-lib.sh"
libcall() {
  RUN_OUT=$(bash -c '. "$1" >/dev/null 2>&1 || exit 99; shift; "$@"' aidentity-lib "$LIB" "$@" 2>&1)
  RUN_RC=$?
  return 0
}

plist_key() { /usr/libexec/PlistBuddy -c "Print :$2" "$1/Contents/Info.plist" 2>/dev/null; }

# Structural fingerprint of a directory tree: proves a bundle was not modified.
fingerprint() {
  [ -d "$1" ] || { printf '<absent>'; return 0; }
  ( cd "$1" && find . -print | LC_ALL=C sort ) | shasum | awk '{print $1}'
}

# Shallow listing, for snapshotting real directories cheaply.
snapshot() {
  if [ -d "$1" ]; then
    ( cd "$1" && find . -mindepth 1 -maxdepth 1 -print | LC_ALL=C sort )
  else
    printf '<absent>'
  fi
}

count_launchers() {
  find "$APPS" -maxdepth 1 -name '*.app' -print 2>/dev/null | wc -l | tr -d ' '
}

repeat_char() { # count char
  local n="$1" c="$2" s=''
  while [ "${#s}" -lt "$n" ]; do s="$s$c"; done
  printf '%s' "$s"
}

# -------------------------------------------------------------- fixtures --

write_min_plist() { # bundle_path bundle_id
  cat > "$1/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleIdentifier</key><string>$2</string>
	<key>CFBundleName</key><string>$(basename "$1" .app)</string>
	<key>CFBundleExecutable</key><string>stub</string>
	<key>CFBundlePackageType</key><string>APPL</string>
</dict>
</plist>
PLIST
}

# An Electron app: detected by the "Electron Framework.framework" directory.
make_electron_app() { # path
  mkdir -p "$1/Contents/MacOS" "$1/Contents/Resources" \
           "$1/Contents/Frameworks/Electron Framework.framework/Versions/A"
  printf '#!/bin/sh\nexit 0\n' > "$1/Contents/MacOS/stub"
  chmod +x "$1/Contents/MacOS/stub"
  write_min_plist "$1" "com.aidentity.test.electron"
}

# A Chromium fork: detected by *.framework/Versions/*/Helpers/*.app.
make_chromium_fork_app() { # path
  mkdir -p "$1/Contents/MacOS" "$1/Contents/Resources" \
           "$1/Contents/Frameworks/Fork Framework.framework/Versions/151/Helpers/Fork Helper.app"
  printf '#!/bin/sh\nexit 0\n' > "$1/Contents/MacOS/stub"
  chmod +x "$1/Contents/MacOS/stub"
  write_min_plist "$1" "com.aidentity.test.fork"
}

# A native AppKit-style app: no --user-data-dir, must be rejected.
make_native_app() { # path
  mkdir -p "$1/Contents/MacOS" "$1/Contents/Resources"
  printf '#!/bin/sh\nexit 0\n' > "$1/Contents/MacOS/stub"
  chmod +x "$1/Contents/MacOS/stub"
  write_min_plist "$1" "com.aidentity.test.native"
}

# A bundle that is NOT ours: a plausible .app with no AIdentityProfile key.
# aidentity must refuse to remove, overwrite or open it.
make_decoy_app() { # path
  mkdir -p "$1/Contents/MacOS" "$1/Contents/Resources"
  printf 'precious user data\n' > "$1/Contents/Resources/important.txt"
  printf '#!/bin/sh\nexit 0\n' > "$1/Contents/MacOS/stub"
  chmod +x "$1/Contents/MacOS/stub"
  write_min_plist "$1" "com.example.decoy"
}

# ================================================================== tests ==

group "sandbox isolation"

REAL_APPS_BEFORE=$(snapshot "$REAL_APPS")
REAL_DATA_BEFORE=$(snapshot "$REAL_DATA")

assert_nonempty "AIDENTITY_APPS_DIR is set" "${AIDENTITY_APPS_DIR:-}"
assert_nonempty "AIDENTITY_DATA_ROOT is set" "${AIDENTITY_DATA_ROOT:-}"
assert_contains "AIDENTITY_APPS_DIR lives inside the sandbox" "$AIDENTITY_APPS_DIR" "$SANDBOX"
assert_contains "AIDENTITY_DATA_ROOT lives inside the sandbox" "$AIDENTITY_DATA_ROOT" "$SANDBOX"
assert_ne "AIDENTITY_APPS_DIR is not the real ~/Applications" "$REAL_APPS" "$AIDENTITY_APPS_DIR"
assert_ne "AIDENTITY_DATA_ROOT is not the real profile directory" \
  "$REAL_DATA/profiles" "$AIDENTITY_DATA_ROOT"
assert_dir "sandbox launcher directory exists" "$APPS"
assert_dir "sandbox data directory exists" "$DATA"
assert_contains "sandbox path contains a space, so quoting is exercised" "$SB" " "

group "fixtures"

ELECTRON_APP="$SRC/Fake.app"
FORK_APP="$SRC/Forky.app"
NATIVE_APP="$SRC/Nativey.app"
make_electron_app "$ELECTRON_APP"
make_chromium_fork_app "$FORK_APP"
make_native_app "$NATIVE_APP"
ELECTRON_FP_BEFORE=$(fingerprint "$ELECTRON_APP")

assert_dir "built a fake Electron app" "$ELECTRON_APP"
assert_dir "built a fake Chromium-fork app" "$FORK_APP"
assert_dir "built a fake native app" "$NATIVE_APP"

# Strip the dispatch line so the script can be sourced for unit tests.
grep -v '^[[:space:]]*main[[:space:]]*"\$@"[[:space:]]*$' "$AIDENTITY" > "$LIB"
assert_file "extracted a sourceable library copy of the script" "$LIB"
libcall slugify "probe"
assert_rc "sourcing the library defines its helper functions" 0 "$RUN_RC" "$RUN_OUT"

group "help, version and exit codes"

ai help
assert_rc "help exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "help documents add" "$RUN_OUT" "add"
assert_contains "help documents list" "$RUN_OUT" "list"
assert_contains "help documents open" "$RUN_OUT" "open"
assert_contains "help documents rm" "$RUN_OUT" "rm"
assert_contains "help documents apps" "$RUN_OUT" "apps"
assert_contains "help documents doctor" "$RUN_OUT" "doctor"
assert_contains "help documents --purge" "$RUN_OUT" "--purge"
assert_contains "help explains the single-instance-lock mechanism" "$RUN_OUT" "single-instance lock"

ai --help
assert_rc "--help exits 0" 0 "$RUN_RC" "$RUN_OUT"
ai -h
assert_rc "-h exits 0" 0 "$RUN_RC" "$RUN_OUT"

ai
assert_rc "no arguments falls back to help and exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "no arguments prints the usage block" "$RUN_OUT" "USAGE"

ai version
assert_rc "version exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "version names the tool" "$RUN_OUT" "aidentity "
VERSION_LINE="$RUN_OUT"
ai --version
assert_eq "--version matches version" "$VERSION_LINE" "$RUN_OUT"
ai -v
assert_eq "-v matches version" "$VERSION_LINE" "$RUN_OUT"

ai definitely-not-a-command
assert_rc_nonzero "an unknown command exits non-zero" "$RUN_RC" "$RUN_OUT"
assert_contains "an unknown command says which one" "$RUN_OUT" "definitely-not-a-command"

ai add --no-such-flag
assert_rc_nonzero "an unknown option for add exits non-zero" "$RUN_RC" "$RUN_OUT"
ai rm --no-such-flag
assert_rc_nonzero "an unknown option for rm exits non-zero" "$RUN_RC" "$RUN_OUT"

ai add
assert_rc_nonzero "add with no app and no terminal exits non-zero" "$RUN_RC" "$RUN_OUT"
ai add "$ELECTRON_APP"
assert_rc_nonzero "add with no profile and no terminal exits non-zero" "$RUN_RC" "$RUN_OUT"

ai open
assert_rc_nonzero "open with no argument exits non-zero" "$RUN_RC" "$RUN_OUT"
ai rm
assert_rc_nonzero "rm with no argument exits non-zero" "$RUN_RC" "$RUN_OUT"

group "apps and doctor"

ai apps
assert_rc "apps exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_nonempty "apps produces output" "$RUN_OUT"

ai doctor
assert_rc "doctor exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_nonempty "doctor produces output" "$RUN_OUT"
assert_contains "doctor reports the sandbox launcher directory" "$RUN_OUT" "$APPS"
assert_contains "doctor reports a macOS version" "$RUN_OUT" "macOS"
assert_contains "doctor reports the bash version" "$RUN_OUT" "bash"

if [ "$(id -u)" = "0" ]; then
  _skip "doctor flags a launcher directory it cannot write to" "running as root, every directory is writable"
else
  RO_APPS="$SB/read only apps"
  mkdir -p "$RO_APPS"
  chmod 500 "$RO_APPS"
  RUN_OUT=$(AIDENTITY_APPS_DIR="$RO_APPS" bash "$AIDENTITY" doctor 2>&1 </dev/null)
  chmod 700 "$RO_APPS"
  assert_contains "doctor flags a launcher directory it cannot write to" "$RUN_OUT" "NOT WRITABLE"
fi

ai list
assert_rc "list exits 0 with no profiles" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "list says so when there is nothing yet" "$RUN_OUT" "No profiles yet."

group "profile name validation — rejected"

reject_name() { # description name
  libcall validate_profile_name "$2"
  assert_rc_nonzero "rejects $1" "$RUN_RC" "$RUN_OUT"
}

reject_name "an empty name"                    ""
# The single quotes below are deliberate: these strings must reach the script
# with their metacharacters intact, which is the whole point of the test.
# shellcheck disable=SC2016
reject_name "command substitution \$(...)"     'Work$(whoami)'
# shellcheck disable=SC2016
reject_name "a bare dollar sign"               'Work$HOME'
# shellcheck disable=SC2016
reject_name "backticks"                        'Work`id`'
reject_name "a double quote"                   'Work"x'
reject_name "a single quote"                   "Work'x"
reject_name "a forward slash"                  'Work/Personal'
reject_name "a leading slash"                  '/etc'
reject_name "a semicolon"                      'Work; rm -rf ~'
reject_name "an ampersand"                     'Work & Play'
reject_name "a pipe"                           'Work|Play'
reject_name "a glob star"                      'Work*'
reject_name "a redirect character"             'Work>out'
reject_name "a newline"                        "$(printf 'Work\nPersonal')"
reject_name "a tab"                            "$(printf 'Work\tX')"
reject_name "a leading space"                  ' Work'
reject_name "a trailing space"                 'Work '
reject_name "a leading dot"                    '.hidden'
reject_name "a parent-directory name"          '..'
reject_name "an XML-breaking character"        'Work<Personal'
reject_name "a colon"                          'Work:Personal'
reject_name "a backslash"                      'Work\Personal'
reject_name "a name longer than 40 characters" "$(repeat_char 41 a)"

group "profile name validation — accepted"

accept_name() { # description name
  libcall validate_profile_name "$2"
  assert_rc "accepts $1" 0 "$RUN_RC" "$RUN_OUT"
}

accept_name "a plain word"                    'Work'
accept_name "lowercase"                       'personal'
accept_name "a single letter"                 'W'
accept_name "a digit"                         '2'
accept_name "an internal space"               'My Client'
accept_name "a hyphen"                        'Client-2'
accept_name "an underscore"                   'Client_2'
accept_name "letters, digits, space, hyphen and underscore together" 'Acme Corp_2-b'
accept_name "exactly 40 characters"           "$(repeat_char 40 a)"

group "slugify and shquote"

libcall slugify "Fake Work"
assert_eq "slugify lowercases and hyphenates spaces" "fake-work" "$RUN_OUT"
libcall slugify "My_Client 3"
assert_eq "slugify turns underscores into hyphens" "my-client-3" "$RUN_OUT"
libcall slugify "Claude WORK"
assert_eq "slugify lowercases uppercase input" "claude-work" "$RUN_OUT"
libcall slugify "Client-2"
assert_eq "slugify keeps existing hyphens" "client-2" "$RUN_OUT"
libcall slugify "A"
assert_eq "slugify handles a single character" "a" "$RUN_OUT"
# The slug becomes a directory name and part of a bundle identifier, and it is
# built from the *app* name too — which nothing validates. The charset filter is
# what keeps it safe, so pin it directly rather than trusting name validation.
libcall slugify 'Ev&il<x> Work'
assert_eq "slugify drops every character outside a-z0-9-" "evilx-work" "$RUN_OUT"

libcall shquote "plain"
assert_eq "shquote wraps a plain string in single quotes" "'plain'" "$RUN_OUT"
libcall shquote "/a b/c"
assert_eq "shquote keeps spaces inside the quotes" "'/a b/c'" "$RUN_OUT"
libcall shquote "it's"
assert_eq "shquote escapes an embedded single quote" "'it'\\''s'" "$RUN_OUT"

# The property that matters: whatever goes in comes back out of a shell verbatim.
shquote_roundtrip() { # description input
  local quoted back
  quoted=$(bash -c '. "$1" >/dev/null 2>&1; shquote "$2"' aidentity-lib "$LIB" "$2")
  back=$(bash -c "printf '%s' $quoted")
  assert_eq "shquote round-trips $1" "$2" "$back"
}
shquote_roundtrip "a path with spaces"       "/Users/x/Application Support/y"
shquote_roundtrip "an apostrophe"            "Bob's Mac"
# shellcheck disable=SC2016  # the literal $ and backticks are the payload
shquote_roundtrip "a dollar sign"            'a $HOME b'
# shellcheck disable=SC2016
shquote_roundtrip "backticks and semicolons" 'a `id`; b'
shquote_roundtrip "a double quote"           'say "hi"'

group "colour handling"

libcall color_hex blue
assert_eq "a named colour resolves to hex" "2E7DF6" "$RUN_OUT"
libcall color_hex BLUE
assert_eq "colour names are case-insensitive" "2E7DF6" "$RUN_OUT"
libcall color_hex 2E7DF6
assert_eq "a raw hex value passes through" "2E7DF6" "$RUN_OUT"
libcall color_hex nosuchcolour
assert_rc_nonzero "an unknown colour is rejected" "$RUN_RC" "$RUN_OUT"
libcall auto_color "Fake Work"
assert_nonempty "auto_color returns a colour for a profile" "$RUN_OUT"
AUTO_ONCE="$RUN_OUT"
libcall auto_color "Fake Work"
assert_eq "auto_color is stable for the same profile" "$AUTO_ONCE" "$RUN_OUT"

group "app detection"

libcall is_chromium_app "$ELECTRON_APP"
assert_rc "an Electron bundle is detected" 0 "$RUN_RC" "$RUN_OUT"
libcall is_chromium_app "$FORK_APP"
assert_rc "a Chromium-fork bundle is detected" 0 "$RUN_RC" "$RUN_OUT"
libcall is_chromium_app "$NATIVE_APP"
assert_rc_nonzero "a native bundle is not detected" "$RUN_RC" "$RUN_OUT"
libcall is_chromium_app_deep "$NATIVE_APP"
assert_rc_nonzero "the deep check also rejects a native bundle" "$RUN_RC" "$RUN_OUT"

ai add "$NATIVE_APP" --profile Work
assert_rc_nonzero "add refuses a native app" "$RUN_RC" "$RUN_OUT"
assert_contains "add explains why a native app cannot work" "$RUN_OUT" "Chromium"
assert_no_dir "add left no launcher behind for a native app" "$APPS/Nativey Work.app"

ai add "$SRC/Nope.app" --profile Work
assert_rc_nonzero "add refuses an app that does not exist" "$RUN_RC" "$RUN_OUT"

group "marker-key safety rule"

DECOY="$APPS/Decoy.app"
make_decoy_app "$DECOY"
DECOY_FP=$(fingerprint "$DECOY")

libcall is_our_launcher "$DECOY"
assert_rc_nonzero "a bundle without the marker key is not ours" "$RUN_RC" "$RUN_OUT"

ai rm Decoy -y
assert_rc_nonzero "rm refuses a bundle aidentity did not create" "$RUN_RC" "$RUN_OUT"
assert_contains "rm says why it refused" "$RUN_OUT" "not created by aidentity"
assert_dir "the decoy still exists after rm" "$DECOY"
assert_file "the decoy's contents are untouched" "$DECOY/Contents/Resources/important.txt"
assert_eq "the decoy tree is unchanged" "$DECOY_FP" "$(fingerprint "$DECOY")"

ai rm Decoy --purge -y
assert_rc_nonzero "rm --purge also refuses a bundle aidentity did not create" "$RUN_RC" "$RUN_OUT"
assert_dir "the decoy still exists after rm --purge" "$DECOY"

ai open Decoy
assert_rc_nonzero "open refuses a bundle aidentity did not create" "$RUN_RC" "$RUN_OUT"

# add builds "<App> <Profile>.app", so a decoy at that exact name is a collision.
GUARD="$APPS/Fake Guard.app"
make_decoy_app "$GUARD"
GUARD_FP=$(fingerprint "$GUARD")
ai add "$ELECTRON_APP" --profile Guard
assert_rc_nonzero "add refuses to overwrite a bundle it did not create" "$RUN_RC" "$RUN_OUT"
assert_contains "add says it will not overwrite" "$RUN_OUT" "Refusing to overwrite"
assert_dir "the colliding bundle survives" "$GUARD"
assert_eq "the colliding bundle is unchanged" "$GUARD_FP" "$(fingerprint "$GUARD")"
assert_no_dir "no profile data was created for the refused add" "$DATA/fake-guard"

ai list
assert_not_contains "list ignores bundles without the marker key" "$RUN_OUT" "Decoy"

rm -rf "$DECOY" "$GUARD"

group "add → list → rm lifecycle"

ai add "$ELECTRON_APP" --profile Work
assert_rc "add succeeds against a fake Electron app" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "add reports what it created" "$RUN_OUT" "Fake Work"

LAUNCHER="$APPS/Fake Work.app"
PROFILE_DATA="$DATA/fake-work"

assert_dir "the launcher lands in AIDENTITY_APPS_DIR" "$LAUNCHER"
assert_dir "the profile data directory is created" "$PROFILE_DATA"
assert_no_dir "nothing was written to the real ~/Applications" "$REAL_APPS/Fake Work.app"

assert_eq "the launcher carries the marker key" "Work" "$(plist_key "$LAUNCHER" AIdentityProfile)"
assert_eq "the launcher records its target app" "$ELECTRON_APP" "$(plist_key "$LAUNCHER" AIdentityTargetApp)"
assert_eq "the launcher records its data directory" "$PROFILE_DATA" "$(plist_key "$LAUNCHER" AIdentityDataDir)"
assert_eq "the launcher is a background agent (LSUIElement)" "true" "$(plist_key "$LAUNCHER" LSUIElement)"
assert_contains "the launcher gets its own bundle identifier" \
  "$(plist_key "$LAUNCHER" CFBundleIdentifier)" "com.aidentity."

if plutil -lint "$LAUNCHER/Contents/Info.plist" >/dev/null 2>&1; then
  _pass "the generated Info.plist is valid"
else
  _fail "the generated Info.plist is valid" "plutil -lint rejected it"
fi

assert_file "the launcher has a launcher script" "$LAUNCHER/Contents/MacOS/launcher"
assert_exec "the launcher script is executable" "$LAUNCHER/Contents/MacOS/launcher"
LAUNCH_SRC=$(cat "$LAUNCHER/Contents/MacOS/launcher")
assert_contains "the launcher is a plain sh script" "$LAUNCH_SRC" "#!/bin/sh"
assert_contains "the launcher passes --user-data-dir" "$LAUNCH_SRC" "--user-data-dir='$PROFILE_DATA'"
assert_contains "the launcher opens the real app by path" "$LAUNCH_SRC" "'$ELECTRON_APP'"
assert_contains "the launcher asks for a new instance (-na)" "$LAUNCH_SRC" "-na"

# The whole design rests on this: the real app is never copied or touched.
assert_no_dir "the launcher does not embed a copy of the app" "$LAUNCHER/Contents/Frameworks"
assert_eq "the source app is not modified" "$ELECTRON_FP_BEFORE" "$(fingerprint "$ELECTRON_APP")"

if command -v codesign >/dev/null 2>&1 && xcode-select -p >/dev/null 2>&1; then
  if codesign --verify "$LAUNCHER" >/dev/null 2>&1; then
    _pass "the generated launcher passes codesign --verify"
  else
    _fail "the generated launcher passes codesign --verify" "codesign rejected $LAUNCHER"
  fi
else
  _skip "the generated launcher passes codesign --verify" "no codesign toolchain on this machine"
fi

ai list
assert_rc "list exits 0 with a profile present" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "list shows the launcher name" "$RUN_OUT" "Fake Work"
assert_contains "list shows the profile name" "$RUN_OUT" "Work"
assert_contains "list shows where the data lives" "$RUN_OUT" "$PROFILE_DATA"
assert_contains "a fresh profile is reported as signed out" "$RUN_OUT" "signed out"

ai doctor
assert_contains "doctor counts profiles" "$RUN_OUT" "profiles"

ai add "$ELECTRON_APP" --profile Work
assert_rc "adding the same profile again is idempotent" 0 "$RUN_RC" "$RUN_OUT"
assert_dir "the launcher still exists after a re-add" "$LAUNCHER"
assert_eq "a re-add does not create a second launcher" "1" "$(count_launchers)"

ai add "$ELECTRON_APP" --profile Personal --color teal --badge P
assert_rc "add accepts --color and --badge" 0 "$RUN_RC" "$RUN_OUT"
assert_dir "the second launcher exists" "$APPS/Fake Personal.app"
ai list
assert_contains "list shows the first profile" "$RUN_OUT" "Fake Work"
assert_contains "list shows the second profile" "$RUN_OUT" "Fake Personal"
assert_ne "the two profiles get different data directories" \
  "$(plist_key "$APPS/Fake Work.app" AIdentityDataDir)" \
  "$(plist_key "$APPS/Fake Personal.app" AIdentityDataDir)"

ai add "$ELECTRON_APP" --profile Bad --color chartreuse
assert_rc_nonzero "add rejects an unknown colour" "$RUN_RC" "$RUN_OUT"
assert_no_dir "no launcher is built when the colour is rejected" "$APPS/Fake Bad.app"

ai add "$FORK_APP" --profile Work
assert_rc "add works against a Chromium-fork bundle too" 0 "$RUN_RC" "$RUN_OUT"
assert_dir "the fork launcher exists" "$APPS/Forky Work.app"
ai rm "Forky Work" -y
assert_rc "rm removes the fork launcher" 0 "$RUN_RC" "$RUN_OUT"

ai add "$APPS/Fake Work.app" --profile Nested
assert_rc_nonzero "add refuses to profile one of its own launchers" "$RUN_RC" "$RUN_OUT"

ai_in "no" rm "Fake Personal"
assert_rc_nonzero "rm without --yes cancels when the answer is not 'yes'" "$RUN_RC" "$RUN_OUT"
assert_contains "a cancelled rm says so" "$RUN_OUT" "Cancelled"
assert_dir "a cancelled rm leaves the launcher in place" "$APPS/Fake Personal.app"

ai_in "yes" rm "Fake Personal"
assert_rc "rm proceeds when the answer is 'yes'" 0 "$RUN_RC" "$RUN_OUT"
assert_no_dir "the confirmed launcher is gone" "$APPS/Fake Personal.app"
assert_dir "rm without --purge keeps the profile data" "$DATA/fake-personal"

ai rm "No Such Profile" -y
assert_rc_nonzero "rm of an unknown profile exits non-zero" "$RUN_RC" "$RUN_OUT"

ai rm "Fake Work" -y
assert_rc "rm --yes removes without prompting" 0 "$RUN_RC" "$RUN_OUT"
assert_no_dir "the launcher is gone" "$LAUNCHER"
assert_dir "the data survives a plain rm" "$PROFILE_DATA"

ai list
assert_contains "list is empty again after removing every profile" "$RUN_OUT" "No profiles yet."

group "--purge stays inside the data root"

ai add "$ELECTRON_APP" --profile Purgeable
assert_rc "add a profile to purge" 0 "$RUN_RC" "$RUN_OUT"
touch "$DATA/fake-purgeable/marker"
assert_file "the profile data has a marker file" "$DATA/fake-purgeable/marker"
ai rm "Fake Purgeable" --purge -y
assert_rc "rm --purge exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_no_dir "rm --purge deletes data inside the data root" "$DATA/fake-purgeable"
assert_dir "rm --purge leaves the data root itself alone" "$DATA"

# A launcher whose recorded data directory points outside the data root must not
# be able to talk aidentity into deleting that path.
purge_guard_case() { # description outside_path
  local desc="$1" outside="$2"
  mkdir -p "$outside"
  printf 'do not delete me\n' > "$outside/precious.txt"
  ai add "$ELECTRON_APP" --profile Escape
  if [ "$RUN_RC" -ne 0 ]; then _fail "$desc (setup)" "add failed: $RUN_OUT"; return 0; fi
  /usr/libexec/PlistBuddy -c "Set :AIdentityDataDir $outside" \
    "$APPS/Fake Escape.app/Contents/Info.plist" >/dev/null 2>&1
  ai rm "Fake Escape" --purge -y
  assert_rc "$desc — rm still exits 0" 0 "$RUN_RC" "$RUN_OUT"
  assert_contains "$desc — rm warns the data is outside the data root" "$RUN_OUT" "outside"
  assert_file "$desc — the outside data is left in place" "$outside/precious.txt"
  assert_no_dir "$desc — the launcher itself is removed" "$APPS/Fake Escape.app"
  rm -rf "$outside"
}

purge_guard_case "an unrelated directory" "$SB/somewhere else"
purge_guard_case "a sibling that merely shares the data-root prefix" "${DATA}-evil"

# The data root itself is not "inside" the data root, so it must survive too.
mkdir -p "$DATA/keep-me"
ai add "$ELECTRON_APP" --profile Root
/usr/libexec/PlistBuddy -c "Set :AIdentityDataDir $DATA" \
  "$APPS/Fake Root.app/Contents/Info.plist" >/dev/null 2>&1
ai rm "Fake Root" --purge -y
assert_rc "rm --purge pointed at the data root exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_dir "rm --purge never deletes the data root itself" "$DATA"
assert_dir "unrelated profile data survives" "$DATA/keep-me"
rm -rf "$DATA/keep-me"

group "--seed copies an existing Claude config"

FAKE_HOME="$SB/fake home"
mkdir -p "$FAKE_HOME/Library/Application Support/Claude"
printf '{"mcpServers":{"probe":{}}}\n' > "$FAKE_HOME/Library/Application Support/Claude/claude_desktop_config.json"
# --seed is gated on the target being Claude Desktop, so the fixture has to
# claim Claude's bundle id. Seeding any other app was a real bug.
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.anthropic.claudefordesktop" \
  "$ELECTRON_APP/Contents/Info.plist" >/dev/null 2>&1 || true
RUN_OUT=$(HOME="$FAKE_HOME" bash "$AIDENTITY" add "$ELECTRON_APP" --profile Seeded --seed 2>&1 </dev/null)
RUN_RC=$?
assert_rc "add --seed exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_file "add --seed copies the MCP config into the new profile" \
  "$DATA/fake-seeded/claude_desktop_config.json"
ai rm "Fake Seeded" --purge -y
assert_rc "the seeded profile is removed cleanly" 0 "$RUN_RC" "$RUN_OUT"

group "icon handling"

SYSTEM_ICNS="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns"
if [ -f "$SYSTEM_ICNS" ]; then
  ICON_APP="$SRC/Icony.app"
  make_electron_app "$ICON_APP"
  cp "$SYSTEM_ICNS" "$ICON_APP/Contents/Resources/app.icns"
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string app" \
    "$ICON_APP/Contents/Info.plist" >/dev/null 2>&1
  ai add "$ICON_APP" --profile Iconed --color purple --badge I
  assert_rc "add succeeds for an app that has an icon" 0 "$RUN_RC" "$RUN_OUT"
  # Either the badge was drawn or the app's own icon was copied. Both are fine;
  # what must never happen is a hard failure or a launcher with no icon at all.
  assert_file "the launcher ends up with an icon" \
    "$APPS/Icony Iconed.app/Contents/Resources/icon.icns"
  ai rm "Icony Iconed" --purge -y
  assert_rc "the icon profile is removed cleanly" 0 "$RUN_RC" "$RUN_OUT"
else
  _skip "add succeeds for an app that has an icon" "no system .icns available"
  _skip "the launcher ends up with an icon" "no system .icns available"
  _skip "the icon profile is removed cleanly" "no system .icns available"
fi

# A missing icon must not be fatal.
ai add "$ELECTRON_APP" --profile Noicon
assert_rc "an app with no icon still produces a launcher" 0 "$RUN_RC" "$RUN_OUT"
assert_dir "the icon-less launcher exists" "$APPS/Fake Noicon.app"
ai rm "Fake Noicon" --purge -y
assert_rc "the icon-less profile is removed cleanly" 0 "$RUN_RC" "$RUN_OUT"

group "injection attempts through the CLI"

assert_eq "no launchers left over before the injection cases" "0" "$(count_launchers)"

inject_case() { # name
  ai add "$ELECTRON_APP" --profile "$1"
  assert_rc_nonzero "add rejects the profile name [$1]" "$RUN_RC" "$RUN_OUT"
}
# shellcheck disable=SC2016  # unexpanded $( ) and backticks are the payload
inject_case 'Work$(touch '"$SB"'/pwned)'
inject_case 'Work`touch '"$SB"'/pwned`'
inject_case 'Work; touch '"$SB"'/pwned'
inject_case '../../../../etc/pwned'
inject_case 'Work" /><key>x</key><string>y</string><!--'

assert_no_file "no injected command ever ran" "$SB/pwned"
assert_eq "no launcher was created by any injection attempt" "0" "$(count_launchers)"

group "refusals happen for the stated reason"

# Several refusals exit non-zero for more than one possible reason. Checking only
# the exit code lets the real guard be deleted while the test still passes, so
# these pin the reason as well.

# A launcher is not a Chromium app either, so an exit code alone cannot tell
# "this is my own launcher" apart from "this is not an Electron app".
ai add "$ELECTRON_APP" --profile Selfref
assert_rc "built a launcher to aim add at" 0 "$RUN_RC" "$RUN_OUT"
ai add "$APPS/Fake Selfref.app" --profile Nested
assert_rc_nonzero "add refuses one of its own launchers as the source app" "$RUN_RC" "$RUN_OUT"
assert_contains "add refuses it for being a launcher, not for failing the Chromium check" \
  "$RUN_OUT" "is an aidentity launcher"
assert_no_dir "no launcher-of-a-launcher was created" "$APPS/Fake Selfref Nested.app"
ai rm "Fake Selfref" --purge -y
assert_rc "removed the helper launcher" 0 "$RUN_RC" "$RUN_OUT"

# Without the marker check, `open` would hand the bundle to macOS and still exit
# non-zero when macOS declined it — passing the old exit-code-only assertion.
OPEN_DECOY="$APPS/OpenDecoy.app"
make_decoy_app "$OPEN_DECOY"
ai open OpenDecoy
assert_rc_nonzero "open refuses a bundle aidentity did not create" "$RUN_RC" "$RUN_OUT"
assert_contains "open refuses on the marker key, not because macOS declined to launch it" \
  "$RUN_OUT" "not created by aidentity"
assert_dir "the decoy survives an attempted open" "$OPEN_DECOY"
rm -rf "$OPEN_DECOY"

group "a plain file at the launcher path is not collateral"

# add's collision guard uses -d, so a regular *file* at that path slips past it.
# The only thing standing between that file and `rm -rf` is build_launcher's own
# ownership check. Nothing exercised it before.
FILE_AT_PATH="$APPS/Fake Filed.app"
printf 'precious\n' > "$FILE_AT_PATH"
ai add "$ELECTRON_APP" --profile Filed
assert_file "a plain file sitting at the launcher path is never deleted" "$FILE_AT_PATH"
assert_eq "that file's contents are intact" "precious" "$(cat "$FILE_AT_PATH" 2>/dev/null)"
# Caught by create_profile's -e collision guard now, before build_launcher is
# reached at all — earlier and with a clearer message than the old -d test,
# which let a plain file slip through to assert_ours.
assert_contains "add refuses to touch it" "$RUN_OUT" "aidentity did not create"
rm -f "$FILE_AT_PATH"
rm -rf "$DATA/fake-filed"

group "a malformed Info.plist is caught, not shipped"

# Profile names are validated; app bundle names are not, and both go into the
# generated plist. An app whose name carries XML metacharacters is the reachable
# path to a broken plist, which is what the plutil -lint backstop is for.
# An app name carrying XML metacharacters must be ESCAPED into the plist, not
# left to corrupt it. "Barnes & Noble.app" is the real-world case.
XML_APP="$SRC/Ev&il<x>.app"
make_electron_app "$XML_APP"
ai add "$XML_APP" --profile Work
assert_rc "an app name with XML metacharacters is handled, not rejected" 0 "$RUN_RC" "$RUN_OUT"
assert_dir "the launcher for an XML-metacharacter app exists" "$APPS/Ev&il<x> Work.app"
if plutil -lint "$APPS/Ev&il<x> Work.app/Contents/Info.plist" >/dev/null 2>&1; then
  _pass "the generated plist is well formed despite & and <"
else
  _fail "the generated plist is well formed despite & and <" "plutil rejected it"
fi
assert_eq "the app name round-trips through the plist unescaped" \
  "$(plist_key "$APPS/Ev&il<x> Work.app" CFBundleName)" "Ev&il<x> Work"
ai rm "Ev&il<x> Work" --purge -y
assert_rc "the XML-metacharacter launcher is removable by the tool" 0 "$RUN_RC" "$RUN_OUT"
assert_no_dir "no XML-metacharacter debris is left behind" "$APPS/Ev&il<x> Work.app"

group "regressions — bugs found in review, each must stay fixed"

# A failed build must NOT report success. build_launcher used to run inside
# $(…), so its die() exited only that subshell and add printed "✓ Created".
REG_APPS="$SB/ro apps"
mkdir -p "$REG_APPS"
chmod 500 "$REG_APPS"
RUN_OUT=$(AIDENTITY_APPS_DIR="$REG_APPS" bash "$AIDENTITY" add "$ELECTRON_APP" --profile Blocked 2>&1 </dev/null)
RUN_RC=$?
chmod 700 "$REG_APPS"
assert_rc_nonzero "a build that cannot write exits non-zero" "$RUN_RC" "$RUN_OUT"
assert_not_contains "a failed build never claims success" "$RUN_OUT" "Created"

# data_is_ours must reject the root however it is spelled, and must not follow
# a symlink out of the root.
libcall data_is_ours "$DATA//"
assert_rc_nonzero "purge guard rejects the data root spelled with a double slash" "$RUN_RC"
libcall data_is_ours "$DATA"
assert_rc_nonzero "purge guard rejects the bare data root" "$RUN_RC"
mkdir -p "$SB/outside/keep"
ln -sfn "$SB/outside" "$DATA/escape"
libcall data_is_ours "$DATA/escape/keep"
assert_rc_nonzero "purge guard does not follow a symlink out of the root" "$RUN_RC"
rm -f "$DATA/escape"
libcall data_is_ours "$DATA/a-real-profile"
assert_rc "purge guard still accepts a genuine profile path" 0 "$RUN_RC"

# Distinct names that slugify to one directory must be refused, not merged.
ai add "$ELECTRON_APP" --profile "Coll A"
assert_rc "the first of two colliding names is created" 0 "$RUN_RC" "$RUN_OUT"
ai add "$ELECTRON_APP" --profile "Coll_A"
assert_rc_nonzero "a name colliding on slug is refused" "$RUN_RC" "$RUN_OUT"
assert_contains "the collision is explained" "$RUN_OUT" "share its profile directory"
assert_no_dir "no launcher is built for the colliding name" "$APPS/Fake Coll_A.app"
ai rm "Fake Coll A" --purge -y

# data_is_ours must never hang. A relative path made its walk-up loop spin
# forever while the tail string grew without bound — and in `rm --purge` the
# launcher is deleted BEFORE that call, so the user was left wedged.
# Run it with a hard deadline; a hang is a failure, not a stalled suite.
bounded_libcall() { # seconds, fn, args...
  local secs="$1"; shift
  local rcfile="$SANDBOX/bounded.$$"
  rm -f "$rcfile"
  # Spawn the worker DIRECTLY so we hold its real pid. Going through libcall
  # gave us the pid of a wrapper subshell; killing that left the inner bash
  # spinning, so a hang in the code under test hung the suite instead of
  # failing it.
  bash -c '. "$1" >/dev/null 2>&1 || exit 99; shift; "$@" >/dev/null 2>&1' \
       aidentity-lib "$LIB" "$@" &
  local pid=$!
  ( sleep "$secs"; kill -9 "$pid" 2>/dev/null ) &
  local watchdog=$!
  if wait "$pid" 2>/dev/null; then BOUNDED_RC=0; else BOUNDED_RC=$?; fi
  kill "$watchdog" 2>/dev/null
  wait "$watchdog" 2>/dev/null
  # kill -9 surfaces as 137; report it as a timeout rather than a plain failure.
  [ "$BOUNDED_RC" = "137" ] && BOUNDED_RC="TIMEOUT"
  rm -f "$rcfile"
  return 0
}

bounded_libcall 5 data_is_ours "reldata/some-profile"
assert_ne "a relative data dir does not hang the purge guard" "TIMEOUT" "$BOUNDED_RC"
assert_ne "a relative data dir is not accepted" "0" "$BOUNDED_RC"

bounded_libcall 5 data_is_ours "nope/a/b/c"
assert_ne "a deep relative path does not hang the purge guard" "TIMEOUT" "$BOUNDED_RC"

libcall data_is_ours "$DATA/../$(basename "$DATA")/x"
assert_rc_nonzero "purge guard rejects a path containing .. even if it would land inside" "$RUN_RC"

# The running check must be anchored, and must never match on an empty path.
libcall running_on_profile ""
assert_rc_nonzero "an empty data dir never reports as running" "$RUN_RC"


group "rename, set, prune and rebuild"

ai add "$ELECTRON_APP" --profile Renameable
assert_rc "a profile to rename is created" 0 "$RUN_RC" "$RUN_OUT"
RN_DATA="$DATA/fake-renameable"
assert_dir "its data directory exists" "$RN_DATA"
printf 'signed-in\n' > "$RN_DATA/session.marker"

ai rename "Fake Renameable" "Renamed"
assert_rc "rename succeeds" 0 "$RUN_RC" "$RUN_OUT"
assert_dir "the renamed launcher exists" "$APPS/Fake Renamed.app"
assert_no_dir "the old launcher is gone" "$APPS/Fake Renameable.app"
assert_file "the signed-in session moved with it" "$DATA/fake-renamed/session.marker"
assert_no_dir "the old data directory is gone" "$RN_DATA"
assert_eq "the launcher records the new data dir" \
  "$DATA/fake-renamed" "$(plist_key "$APPS/Fake Renamed.app" AIdentityDataDir)"

ai rename "Fake Renamed" "../evil"
assert_rc_nonzero "rename rejects an invalid new name" "$RUN_RC" "$RUN_OUT"
assert_dir "a rejected rename leaves the launcher alone" "$APPS/Fake Renamed.app"
ai rename "No Such Profile" "Whatever"
assert_rc_nonzero "rename refuses an unknown profile" "$RUN_RC" "$RUN_OUT"

ai set "Fake Renamed" --color purple
assert_rc "set changes a colour" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "the new colour is recorded" "8E4EC6" "$(plist_key "$APPS/Fake Renamed.app" AIdentityColor)"
assert_file "set does not disturb the session" "$DATA/fake-renamed/session.marker"
ai set "Fake Renamed" --color nosuchcolour
assert_rc_nonzero "set rejects an unknown colour" "$RUN_RC" "$RUN_OUT"
ai set "Fake Renamed"
assert_rc_nonzero "set with nothing to change is refused" "$RUN_RC" "$RUN_OUT"
ai set "Fake Renamed" --no-badge
assert_rc "set --no-badge succeeds" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "the badge is cleared" "" "$(plist_key "$APPS/Fake Renamed.app" AIdentityBadge)"

mkdir -p "$DATA/an-orphan"
printf 'x\n' > "$DATA/an-orphan/data"
ai prune -y
assert_rc "prune succeeds" 0 "$RUN_RC" "$RUN_OUT"
assert_no_dir "an orphaned profile directory is removed" "$DATA/an-orphan"
assert_dir "a claimed profile directory survives prune" "$DATA/fake-renamed"
assert_file "prune never touches a live session" "$DATA/fake-renamed/session.marker"
ai prune -y
assert_contains "a second prune reports nothing to do" "$RUN_OUT" "No orphaned profile data"

ai rebuild "Fake Renamed"
assert_rc "rebuild of one profile succeeds" 0 "$RUN_RC" "$RUN_OUT"
assert_dir "the rebuilt launcher is still there" "$APPS/Fake Renamed.app"
assert_file "rebuild does not touch profile data" "$DATA/fake-renamed/session.marker"
assert_eq "rebuild preserves the recorded data dir" \
  "$DATA/fake-renamed" "$(plist_key "$APPS/Fake Renamed.app" AIdentityDataDir)"
ai rebuild --all
assert_rc "rebuild --all succeeds" 0 "$RUN_RC" "$RUN_OUT"
ai rebuild "No Such Profile"
assert_rc_nonzero "rebuild refuses an unknown profile" "$RUN_RC" "$RUN_OUT"

# None of these may act on a bundle aidentity did not create.
DECOY4="$APPS/Decoy Four.app"
mkdir -p "$DECOY4/Contents"
write_min_plist "$DECOY4" "com.example.decoyfour"
for sub in rename set rebuild; do
  case "$sub" in
    rename) ai rename "Decoy Four" "Hijacked" ;;
    set)    ai set "Decoy Four" --color red ;;
    rebuild) ai rebuild "Decoy Four" ;;
  esac
  assert_rc_nonzero "$sub refuses a bundle aidentity did not create" "$RUN_RC" "$RUN_OUT"
done
assert_dir "the decoy survives all three" "$DECOY4"
rm -rf "$DECOY4"

ai rm "Fake Renamed" --purge -y
assert_rc "the renamed profile is removed cleanly" 0 "$RUN_RC" "$RUN_OUT"


group "sandbox isolation — final check"

assert_eq "the real ~/Applications is unchanged" "$REAL_APPS_BEFORE" "$(snapshot "$REAL_APPS")"
assert_eq "the real aidentity data directory is unchanged" "$REAL_DATA_BEFORE" "$(snapshot "$REAL_DATA")"
assert_no_dir "no launcher leaked into the real ~/Applications" "$REAL_APPS/Fake Work.app"
assert_no_dir "no profile leaked into the real data directory" "$REAL_DATA/profiles/fake-work"
assert_dir "everything the suite created is inside the sandbox" "$SANDBOX"

# ================================================================== report ==

printf '1..%d\n' "$TEST_NUM"
if [ "$FAIL_COUNT" -eq 0 ]; then
  printf '%s# %d tests, 0 failed%s\n' "$P_GREEN" "$TEST_NUM" "$P_OFF"
  exit 0
fi
printf '%s# %d tests, %d failed%s\n' "$P_RED" "$TEST_NUM" "$FAIL_COUNT" "$P_OFF"
exit 1
