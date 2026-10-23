#!/usr/bin/env bash
# shellcheck shell=bash
# SC2016: single-quoted scripts are handed to "$BASH_BIN" -c and to generated
# stubs, which expand them later, on purpose. shellcheck only recognises that
# when the interpreter is spelled literally as `bash -c`.
# shellcheck disable=SC2016
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

# ${TMPDIR%/}: macOS sets TMPDIR with a trailing slash, which gave every path
# in the suite a "//". The script now cleans its directories up on paper, so a
# path compared against what it records must be spelled cleanly too.
TMP_BASE="${TMPDIR:-/tmp}"
SANDBOX=$(mktemp -d "${TMP_BASE%/}/aidentity-tests.XXXXXX") || {
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
# Without this the suite scans the real /Applications, which makes `apps`,
# `doctor` and the wizard menu depend on whatever the developer has installed —
# and quietly breaks the isolation this file claims a few lines above.
export AIDENTITY_APP_DIRS="$SRC:$APPS"

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

# The interpreter under test. The script promises the bash 3.2 that macOS ships
# as /bin/bash; running it with whatever `bash` comes first on PATH (often a
# Homebrew 5.x) would hide a 3.2-only bug. AIDENTITY_TEST_BASH tries another.
BASH_BIN="${AIDENTITY_TEST_BASH:-/bin/bash}"

# Run a command with no controlling terminal. Closing stdin is not enough: the
# script's ask() falls back to /dev/tty when stdin runs dry, so in a real
# terminal the "no terminal" tests sat waiting for a key that never came —
# silently, because the prompt went into the captured output. CI has no
# terminal, which is why it never showed there. macOS has no setsid(1); its
# perl does the same, after a fork in case we lead a process group.
detached() {
  if [ -x /usr/bin/perl ]; then
    /usr/bin/perl -MPOSIX -e '
      my $pid = fork; die "fork: $!\n" unless defined $pid;
      if ($pid) { waitpid($pid, 0); exit($? & 127 ? 128 + ($? & 127) : $? >> 8) }
      POSIX::setsid(); exec @ARGV or exit 127' -- "$@"
  else
    "$@"
  fi
}

# Run the CLI. Combines stdout and stderr; stdin is closed and there is no
# terminal, so nothing can hang on a prompt. Results land in RUN_OUT / RUN_RC.
ai() {
  RUN_OUT=$(detached "$BASH_BIN" "$AIDENTITY" "$@" 2>&1 </dev/null)
  RUN_RC=$?
  return 0
}

# Same, but feed a line on stdin (for the rm confirmation prompt).
ai_in() {
  local input="$1"; shift
  RUN_OUT=$(printf '%s\n' "$input" | detached "$BASH_BIN" "$AIDENTITY" "$@" 2>&1)
  RUN_RC=$?
  return 0
}

# Run the CLI on a pseudo-terminal, typing $1 (printf %b escapes) as a user
# would. script(1) gives the child a real terminal, so the walkthrough's
# terminal checks pass and its questions read the typed lines. The pauses keep
# script from signalling end-of-input before the child starts reading. `open`
# is stubbed so a walkthrough can never open a real Finder window.
ai_tty() {
  local input="$1"; shift
  # HOME is sandboxed too: the walkthrough asks extra questions when it finds a
  # real Claude config in the developer's home, which shifted every answer.
  RUN_OUT=$( { { sleep 0.3; printf '%b' "$input"; sleep 1; } \
      | HOME="$SANDBOX/tty-home" PATH="$STUB_BIN:$PATH" \
        script -q /dev/null "$BASH_BIN" "$AIDENTITY" "$@"
      echo "__rc=${PIPESTATUS[1]}"; } 2>&1 | tr -d '\r')
  RUN_RC=${RUN_OUT##*__rc=}
  RUN_OUT=${RUN_OUT%__rc=*}
  return 0
}

# Call one of the script's own functions in a fresh bash, with the dispatch
# line stripped so sourcing does not execute a command.
LIB="$SANDBOX/aidentity-lib.sh"
libcall() {
  RUN_OUT=$(detached "$BASH_BIN" -c '. "$1" >/dev/null 2>&1 || exit 99; shift; "$@"' aidentity-lib "$LIB" "$@" 2>&1)
  RUN_RC=$?
  return 0
}

# Commands that must never reach the real system during a test.
STUB_BIN="$SANDBOX/stub-bin"
mkdir -p "$STUB_BIN"
printf '#!/bin/sh\nprintf "stub open: %%s\\n" "$*"\n' > "$STUB_BIN/open"
chmod +x "$STUB_BIN/open"

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
  RUN_OUT=$(AIDENTITY_APPS_DIR="$RO_APPS" detached "$BASH_BIN" "$AIDENTITY" doctor 2>&1 </dev/null)
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
  quoted=$("$BASH_BIN" -c '. "$1" >/dev/null 2>&1; shquote "$2"' aidentity-lib "$LIB" "$2")
  back=$("$BASH_BIN" -c "printf '%s' $quoted")
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
RUN_OUT=$(HOME="$FAKE_HOME" detached "$BASH_BIN" "$AIDENTITY" add "$ELECTRON_APP" --profile Seeded --seed 2>&1 </dev/null)
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
RUN_OUT=$(AIDENTITY_APPS_DIR="$REG_APPS" detached "$BASH_BIN" "$AIDENTITY" add "$ELECTRON_APP" --profile Blocked 2>&1 </dev/null)
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
  "$BASH_BIN" -c '. "$1" >/dev/null 2>&1 || exit 99; shift; "$@" >/dev/null 2>&1' \
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


group "running check — a real-sized process list"

# A stub pgrep with the profile's main process FIRST, then about 120 KB of
# Electron helper lines for another profile, a size real apps reach. The old
# check piped this into grep -q under pipefail; grep's early exit killed the
# writer with SIGPIPE and the profile read as NOT running.
PGREP_STUB="$SANDBOX/stub-pgrep"
mkdir -p "$PGREP_STUB"
BUSY_DATA="$DATA/fake-busy"
{
  printf '#!/bin/sh\n'
  printf "printf '%%s\\\\n' '101 /Apps/Fake.app/Contents/MacOS/Fake --user-data-dir=%s'\n" "$BUSY_DATA"
  printf 'i=0\nwhile [ "$i" -lt 80 ]; do\n'
  printf "  printf '%%s\\\\n' \"\$((200 + i)) /Apps/Fake.app/Contents/Frameworks/Fake Helper.app/Contents/MacOS/Fake Helper --type=renderer --user-data-dir=%s/other %s\"\n" \
    "$DATA" "$(repeat_char 1400 x)"
  printf '  i=$((i + 1))\ndone\n'
} > "$PGREP_STUB/pgrep"
chmod +x "$PGREP_STUB/pgrep"
STUB_SIZE=$(PATH="$PGREP_STUB:$PATH" pgrep -fl x | wc -c | tr -d ' ')
if [ "$STUB_SIZE" -gt 65536 ]; then _pass "the stub list is bigger than a pipe buffer ($STUB_SIZE bytes)"
else _fail "the stub list is bigger than a pipe buffer" "only $STUB_SIZE bytes"; fi

probe_running() { # data dir -> RUNNING / STOPPED
  PATH="$PGREP_STUB:$PATH" "$BASH_BIN" -c \
    '. "$1" >/dev/null 2>&1; running_on_profile "$2" && echo RUNNING || echo STOPPED' x "$LIB" "$1"
}
assert_eq "a profile listed first in a 120 KB process list reads as running" "RUNNING" "$(probe_running "$BUSY_DATA")"
assert_eq "a prefix of a running profile does not match" "STOPPED" "$(probe_running "$DATA/fake-bus")"
assert_eq "a longer name than a running profile does not match" "STOPPED" "$(probe_running "$BUSY_DATA-2")"
# The same folder under another spelling is the same running profile: a
# symlinked root, a doubled slash, a trailing slash.
mkdir -p "$BUSY_DATA"
ln -sfn "$DATA" "$SB/data-alias"
assert_eq "a running profile reached through a symlinked root reads as running" "RUNNING" \
  "$(probe_running "$SB/data-alias/fake-busy")"
assert_eq "a doubled slash does not hide a running profile" "RUNNING" "$(probe_running "$DATA//fake-busy")"
mkdir -p "$DATA/fake-other"
assert_eq "a different folder through the same symlink does not match" "STOPPED" \
  "$(probe_running "$SB/data-alias/fake-other")"
rm -f "$SB/data-alias"
rmdir "$BUSY_DATA" "$DATA/fake-other" 2>/dev/null

ai add "$ELECTRON_APP" --profile Busy
printf 'session\n' > "$BUSY_DATA/Cookies"
PATH="$PGREP_STUB:$PATH" ai rm "Fake Busy" --purge -y
assert_rc_nonzero "rm --purge refuses a profile that is running" "$RUN_RC" "$RUN_OUT"
assert_file "the running profile's session survives" "$BUSY_DATA/Cookies"
PATH="$PGREP_STUB:$PATH" ai prune -y
assert_file "prune leaves a running, claimed profile alone" "$BUSY_DATA/Cookies"
ai rm "Fake Busy" --purge -y
assert_no_dir "once it stops, --purge deletes it" "$BUSY_DATA"


group "add asks for the account name"

ai add "$ELECTRON_APP"
assert_contains "with no terminal, add says how to give the name" "$RUN_OUT" "--profile"
ai_tty 'Typed\n' add "$ELECTRON_APP"
assert_rc "on a terminal, add asks for a missing name" 0 "$RUN_RC" "$RUN_OUT"
assert_dir "the typed name is used" "$APPS/Fake Typed.app"
ai_tty 'bad/name\nRetyped\n' add "$ELECTRON_APP"
assert_contains "a refused name says why" "$RUN_OUT" "may only contain"
assert_dir "a refused name is asked for again" "$APPS/Fake Retyped.app"
ai rm "Fake Typed" --purge -y
ai rm "Fake Retyped" --purge -y


group "setup survives a typo, and offers a main launcher"

libcall list_compatible_apps
FAKE_IDX=$(printf '%s\n' "$RUN_OUT" | grep -n -x -F "$ELECTRON_APP" | cut -d: -f1)
assert_nonempty "the fake Electron app is in the walkthrough menu" "$FAKE_IDX"

ai_tty "y\nabc\n0\n${FAKE_IDX}\nWizard\nn\nn\nn\n" setup
assert_rc "setup finishes after typos at the menu" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "a typo is answered with a hint" "$RUN_OUT" "Please enter a number"
assert_dir "the account after the typos is created" "$APPS/Fake Wizard.app"
assert_contains "setup reports one profile" "$RUN_OUT" "1 profile(s) created"
assert_no_dir "declining the main launcher builds none" "$APPS/Fake Main.app"

ai_tty "y\n${FAKE_IDX}\nWizard Two\ny\nn\nn\n" setup
assert_dir "accepting the offer builds a main launcher" "$APPS/Fake Main.app"
assert_eq "it is marked as a main launcher" "true" "$(plist_key "$APPS/Fake Main.app" AIdentityMain)"
assert_not_contains "setup never opened a real Finder window" "$RUN_OUT" "Opening"
for p in "Fake Wizard" "Fake Wizard Two"; do ai rm "$p" --purge -y; done
ai rm "Fake Main" -y


group "--main opens the original account"

ai add "$ELECTRON_APP" --main
assert_rc "add --main succeeds" 0 "$RUN_RC" "$RUN_OUT"
MAIN_APP="$APPS/Fake Main.app"
assert_dir "it is named <App> Main" "$MAIN_APP"
assert_eq "it is marked as a main launcher" "true" "$(plist_key "$MAIN_APP" AIdentityMain)"
assert_eq "it records no data directory" "" "$(plist_key "$MAIN_APP" AIdentityDataDir)"
MAIN_SRC=$(cat "$MAIN_APP/Contents/MacOS/launcher")
assert_not_contains "it passes no --user-data-dir" "$MAIN_SRC" "user-data-dir"
assert_contains "it still starts a new instance (-na) of the real app" "$MAIN_SRC" "-na '$ELECTRON_APP'"
assert_no_dir "no profile directory is created for it" "$DATA/fake-main"

ai add "$ELECTRON_APP" --main --profile Second
assert_rc_nonzero "a second main launcher for the same app is refused" "$RUN_RC" "$RUN_OUT"
ai add "$ELECTRON_APP" --profile Main
assert_rc_nonzero "a profile cannot take over the main launcher's name" "$RUN_RC" "$RUN_OUT"
assert_eq "the main launcher is unchanged" "true" "$(plist_key "$MAIN_APP" AIdentityMain)"

ai add "$ELECTRON_APP" --profile Regular
ai add "$ELECTRON_APP" --main --profile Regular
assert_rc_nonzero "a separate profile is never turned into a main launcher" "$RUN_RC" "$RUN_OUT"
assert_eq "the profile keeps its own data directory" \
  "$DATA/fake-regular" "$(plist_key "$APPS/Fake Regular.app" AIdentityDataDir)"
ai rm "Fake Regular" --purge -y

ai list
assert_contains "list says it opens the original account" "$RUN_OUT" "your original account"

ai rename "Fake Main" Original
assert_rc "a main launcher can be renamed" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "it is still a main launcher" "true" "$(plist_key "$APPS/Fake Original.app" AIdentityMain)"
assert_no_dir "renaming creates no profile directory" "$DATA/fake-original"
ai set "Fake Original" --color red
assert_rc "set works on a main launcher" 0 "$RUN_RC" "$RUN_OUT"
ai rebuild "Fake Original"
assert_rc "rebuild works on a main launcher" 0 "$RUN_RC" "$RUN_OUT"
assert_not_contains "rebuild keeps it on the original account" \
  "$(cat "$APPS/Fake Original.app/Contents/MacOS/launcher")" "user-data-dir"
ai rm "Fake Original" --purge -y
assert_rc "rm --purge on a main launcher removes only the launcher" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "and says --purge did nothing" "$RUN_OUT" "does nothing"
assert_no_dir "the main launcher is gone" "$APPS/Fake Original.app"


group "a failed build never loses a launcher"

ai add "$ELECTRON_APP" --profile Safe
printf 'session\n' > "$DATA/fake-safe/Cookies"
SAFE_COLOR=$(plist_key "$APPS/Fake Safe.app" AIdentityColor)
chmod 500 "$APPS"
ai set "Fake Safe" --color red
SET_RC=$RUN_RC; SET_OUT=$RUN_OUT
ai rename "Fake Safe" Moved
REN_RC=$RUN_RC; REN_OUT=$RUN_OUT
chmod 755 "$APPS"
assert_rc_nonzero "set fails when the launcher cannot be rebuilt" "$SET_RC" "$SET_OUT"
assert_rc_nonzero "rename fails when the launcher cannot be rebuilt" "$REN_RC" "$REN_OUT"
assert_dir "the launcher survives both failures" "$APPS/Fake Safe.app"
assert_eq "its colour is unchanged" "$SAFE_COLOR" "$(plist_key "$APPS/Fake Safe.app" AIdentityColor)"
assert_contains "rename says nothing changed" "$REN_OUT" "Nothing was changed"
assert_file "the session was moved back by rename's roll-back" "$DATA/fake-safe/Cookies"
assert_no_dir "no half-renamed data directory is left" "$DATA/fake-moved"
assert_eq "no staging directory is left behind" "0" \
  "$(find "$APPS" -maxdepth 1 -name '.aidentity-build.*' | wc -l | tr -d ' ')"
ai rm "Fake Safe" --purge -y


group "status, permissions and option values"

ai add "$ELECTRON_APP" --profile Used
mkdir -p "$DATA/fake-used/Local Storage"
printf 'x\n' > "$DATA/fake-used/Cookies"
ai list
USED_STATUS=$(printf '%s\n' "$RUN_OUT" | awk '/^Fake Used$/ { f = 1; next } f && /status/ { print; exit }')
assert_contains "an Electron-shaped profile (no Default/) reads as in use" "$USED_STATUS" "in use"
assert_eq "profile directories are owner-only" "700" "$(stat -f '%Lp' "$DATA/fake-used")"
ai rm "Fake Used" --purge -y

ai add "$ELECTRON_APP" --profile --seed
assert_rc_nonzero "an option cannot be swallowed as a profile name" "$RUN_RC" "$RUN_OUT"
assert_contains "and says what is missing" "$RUN_OUT" "needs a value"
assert_no_dir "no launcher named after the option" "$APPS/Fake --seed.app"

ai add "$ELECTRON_APP" --profile Accent --badge "é"
assert_rc "a non-ASCII badge works under LC_ALL=C" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "the whole character is recorded" "é" "$(plist_key "$APPS/Fake Accent.app" AIdentityBadge)"
ai rm "Fake Accent" --purge -y

ai add "$ELECTRON_APP" --profile One
ai add "$ELECTRON_APP" --profile Two
ai rm "Fake One" "Fake Two" -y
assert_rc_nonzero "rm refuses two names instead of removing only the last" "$RUN_RC" "$RUN_OUT"
assert_dir "the first is untouched" "$APPS/Fake One.app"
assert_dir "the second is untouched" "$APPS/Fake Two.app"
ai rm "Fake One" --purge -y
ai rm "Fake Two" --purge -y


group "rm hints, locked launchers and prune"

ai add "$ELECTRON_APP" --profile Hint
printf 'session\n' > "$DATA/fake-hint/Cookies"
ai rm "Fake Hint" -y
assert_contains "rm prints the restore line that reattaches the data" "$RUN_OUT" 'aidentity restore "Fake Hint"'
assert_contains "rm points at prune for deleting it" "$RUN_OUT" "aidentity prune"
assert_not_contains "rm no longer suggests a command that cannot work" "$RUN_OUT" 'rm "Fake Hint" --purge'
ai restore "Fake Hint"
assert_rc "following the hint brings the launcher back" 0 "$RUN_RC" "$RUN_OUT"
assert_file "and the session with it" "$DATA/fake-hint/Cookies"

chflags uchg "$APPS/Fake Hint.app"
ai rm "Fake Hint" --purge -y
LOCK_RC=$RUN_RC; LOCK_OUT=$RUN_OUT
chflags nouchg "$APPS/Fake Hint.app"
assert_rc_nonzero "rm fails on a locked launcher" "$LOCK_RC" "$LOCK_OUT"
assert_not_contains "and does not claim it removed it" "$LOCK_OUT" "Removed launcher"
assert_file "and does not delete the data" "$DATA/fake-hint/Cookies"

# A launcher filed into a folder still claims its data.
mkdir -p "$APPS/Accounts"
mv "$APPS/Fake Hint.app" "$APPS/Accounts/"
ai prune -y
assert_file "prune keeps the data of a launcher moved into a folder" "$DATA/fake-hint/Cookies"
mv "$APPS/Accounts/Fake Hint.app" "$APPS/"
rmdir "$APPS/Accounts"

# The same root spelled through a symlink is the same directory.
ln -s "$DATA" "$SB/data-link"
AIDENTITY_DATA_ROOT="$SB/data-link" ai add "$ELECTRON_APP" --profile Linked
assert_eq "the launcher records the symlinked spelling" \
  "$SB/data-link/fake-linked" "$(plist_key "$APPS/Fake Linked.app" AIdentityDataDir)"
printf 'session\n' > "$DATA/fake-linked/Cookies"
ai prune -y
assert_file "prune matches directories, not spellings" "$DATA/fake-linked/Cookies"
AIDENTITY_DATA_ROOT="$SB/data-link" ai rm "Fake Linked" --purge -y
rm -f "$SB/data-link"
ai rm "Fake Hint" --purge -y


group "rename and rebuild edge cases"

ai add "$ELECTRON_APP" --profile lower
printf 'session\n' > "$DATA/fake-lower/Cookies"
ai rename "Fake lower" Lower
assert_rc "a rename that only changes capitals works" 0 "$RUN_RC" "$RUN_OUT"
ON_DISK=""
for a in "$APPS"/*.app; do
  case "$(basename "$a")" in [Ff][Aa][Kk][Ee]\ [Ll][Oo][Ww][Ee][Rr].app) ON_DISK=$(basename "$a") ;; esac
done
assert_eq "the launcher has the new capitals on disk" "Fake Lower.app" "$ON_DISK"
assert_file "the data stays where it was" "$DATA/fake-lower/Cookies"
ai rm "Fake Lower" --purge -y

ai add "$ELECTRON_APP" --profile Alpha
ai rename "Fake Alpha" Beta
assert_eq "a default badge letter follows the new name" "B" "$(plist_key "$APPS/Fake Beta.app" AIdentityBadge)"
ai rm "Fake Beta" --purge -y
ai add "$ELECTRON_APP" --profile Gamma --badge Z
ai rename "Fake Gamma" Delta
assert_eq "a badge chosen by hand is kept" "Z" "$(plist_key "$APPS/Fake Delta.app" AIdentityBadge)"
ai rm "Fake Delta" --purge -y

# A launcher as aidentity 1.0.0 wrote it: no badge or colour keys at all.
ai add "$ELECTRON_APP" --profile Legacy
/usr/libexec/PlistBuddy -c "Delete :AIdentityBadge" -c "Delete :AIdentityColor" \
  "$APPS/Fake Legacy.app/Contents/Info.plist" >/dev/null 2>&1
ai rebuild "Fake Legacy"
assert_rc "a 1.0.0 launcher rebuilds" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "it gets its default badge back instead of losing it" "L" \
  "$(plist_key "$APPS/Fake Legacy.app" AIdentityBadge)"
assert_contains "and the user is told why" "$RUN_OUT" "1.0.0"
ai rm "Fake Legacy" --purge -y

GONE_APP="$SRC/Gone.app"
make_electron_app "$GONE_APP"
ai add "$GONE_APP" --profile G
rm -rf "$GONE_APP"
ai rebuild "Gone G"
assert_rc_nonzero "rebuild exits non-zero when the app cannot be found" "$RUN_RC" "$RUN_OUT"
assert_not_contains "and prints no success tick" "$RUN_OUT" "Rebuilt 0"
ai rm "Gone G" --purge -y


group "launcher discovery and input edge cases"

# A launcher filed into a folder of a SYMLINKED launcher directory. find without
# -H does not follow the symlinked start, so prune saw no launcher and deleted
# the profile behind it.
mkdir -p "$APPS/Filed"
ln -s "$APPS" "$SB/apps-link"
ai add "$ELECTRON_APP" --profile Linkapps
printf 'session\n' > "$DATA/fake-linkapps/Cookies"
mv "$APPS/Fake Linkapps.app" "$APPS/Filed/"
AIDENTITY_APPS_DIR="$SB/apps-link" ai prune -y
assert_file "prune follows a symlinked launcher directory into its folders" "$DATA/fake-linkapps/Cookies"
mv "$APPS/Filed/Fake Linkapps.app" "$APPS/"
rm -f "$SB/apps-link"

# uninstall.sh must find the same launchers, or it calls their data orphaned
# and deletes it while the launcher stays. Only scan_launchers runs here; the
# removal functions are never called by the suite.
UNINST_LIB="$SANDBOX/uninstall-lib.sh"
grep -v '^main "\$@"$' "$REPO_DIR/uninstall.sh" > "$UNINST_LIB"
mv "$APPS/Fake Linkapps.app" "$APPS/Filed/"
mkdir -p "$DATA/left-behind"
# `set --` first: a sourced file sees the caller's arguments, and uninstall.sh
# reads $1 as an option.
SCAN=$(HOME="$SANDBOX/tty-home" "$BASH_BIN" -c 'lib=$1; set --; . "$lib" >/dev/null 2>&1; scan_launchers
  for a in ${LAUNCHERS[@]+"${LAUNCHERS[@]}"}; do printf "L %s\n" "$a"; done
  for o in ${ORPHANS[@]+"${ORPHANS[@]}"}; do printf "O %s\n" "$o"; done' x "$UNINST_LIB" 2>&1)
assert_contains "uninstall lists a launcher kept in a folder" "$SCAN" "L $APPS/Filed/Fake Linkapps.app"
assert_not_contains "and does not call its data orphaned" "$SCAN" "O $DATA/fake-linkapps"
assert_contains "real orphaned data is still listed" "$SCAN" "O $DATA/left-behind"
# A launcher that is itself a symlink in the launcher folder, pointing outside.
mkdir -p "$SB/apps-elsewhere"
mv "$APPS/Filed/Fake Linkapps.app" "$SB/apps-elsewhere/"
ln -s "$SB/apps-elsewhere/Fake Linkapps.app" "$APPS/Fake Linkapps.app"
SCAN=$(HOME="$SANDBOX/tty-home" "$BASH_BIN" -c 'lib=$1; set --; . "$lib" >/dev/null 2>&1; scan_launchers
  for a in ${LAUNCHERS[@]+"${LAUNCHERS[@]}"}; do printf "L %s\n" "$a"; done
  for o in ${ORPHANS[@]+"${ORPHANS[@]}"}; do printf "O %s\n" "$o"; done' x "$UNINST_LIB" 2>&1)
assert_contains "uninstall lists a launcher that is a symlink" "$SCAN" "L $APPS/Fake Linkapps.app"
assert_not_contains "and does not call its data orphaned" "$SCAN" "O $DATA/fake-linkapps"
rm -f "$APPS/Fake Linkapps.app"
mv "$SB/apps-elsewhere/Fake Linkapps.app" "$APPS/Filed/"
rmdir "$SB/apps-elsewhere"
mv "$APPS/Filed/Fake Linkapps.app" "$APPS/"
rmdir "$APPS/Filed" "$DATA/left-behind"
ai rm "Fake Linkapps" --purge -y

# Folder lists are split on ':' only. A * or ? in a folder name used to be
# expanded against the current directory.
mkdir -p "$SB/glob-cwd/match-a" "$SB/bin-real"
SPLIT=$(cd "$SB/glob-cwd" && "$BASH_BIN" -c 'lib=$1; list=$2; set --; . "$lib" >/dev/null 2>&1
  split_dirs "$list"; printf "[%s]\n" "${DIRS[@]}"
  case $- in *f*) echo "globbing left off" ;; esac' x "$UNINST_LIB" "/one:match-*::/two words" 2>&1)
assert_eq "split_dirs keeps * literal and spaces inside a folder" \
  "$(printf '[/one]\n[match-*]\n[]\n[/two words]')" "$SPLIT"
cp "$REPO_DIR/bin/aidentity" "$SB/bin-real/aidentity"
RUN_OUT=$(AIDENTITY_BIN_DIRS="$SB/bin-*" "$BASH_BIN" -c 'lib=$1; set --; . "$lib" >/dev/null 2>&1
  remove_binary' x "$UNINST_LIB" 2>&1 </dev/null)
assert_contains "a * in AIDENTITY_BIN_DIRS is not expanded to other folders" "$RUN_OUT" "not installed anywhere obvious"
assert_file "and the copy it would have matched stays" "$SB/bin-real/aidentity"
rm -rf "$SB/glob-cwd" "$SB/bin-real"

ai add "$ELECTRON_APP" --profile Latin --badge "$(printf '\351')"
assert_rc "a badge that is not text still builds" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "and says it used the default" "$RUN_OUT" "not a character"
assert_eq "the default badge is used" "L" "$(plist_key "$APPS/Fake Latin.app" AIdentityBadge)"
ai rm "Fake Latin" --purge -y

libcall list_compatible_apps
IDX=$(printf '%s\n' "$RUN_OUT" | grep -n -x -F "$ELECTRON_APP" | cut -d: -f1)
ai_tty "18446744073709551617\n${IDX}\nDigits\n" add
assert_contains "a 20-digit menu answer is refused, not wrapped around" "$RUN_OUT" "Please enter a number"
assert_dir "the next valid answer is used" "$APPS/Fake Digits.app"
ai rm "Fake Digits" --purge -y

ai_tty "y\n${IDX}\nDecl One\nn\ny\n${IDX}\nDecl Two\nn\nn\n" setup
assert_rc "setup with two accounts for one app finishes" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "a declined Main launcher is offered only once" "1" \
  "$(printf '%s\n' "$RUN_OUT" | grep -c "Add a 'Fake Main' launcher")"
assert_dir "both accounts were created" "$APPS/Fake Decl Two.app"
ai rm "Fake Decl One" --purge -y
ai rm "Fake Decl Two" --purge -y


group "interrupts, aliases and symlinks"

# An interrupt while rename builds the new launcher. The data has already
# moved; the old launcher still points at the old path. The handler must move
# the data back. A stub codesign slows the build so the signal lands inside it.
SLOW_STUB="$SANDBOX/stub-slow"
mkdir -p "$SLOW_STUB"
printf '#!/bin/sh\nsleep 4\nexit 0\n' > "$SLOW_STUB/codesign"
# Signing runs only when xcode-select answers, so answer it here too: the
# pause must not depend on the developer's toolchain.
printf '#!/bin/sh\necho /Library/Developer/CommandLineTools\n' > "$SLOW_STUB/xcode-select"
chmod +x "$SLOW_STUB/codesign" "$SLOW_STUB/xcode-select"
ai add "$ELECTRON_APP" --profile Intr
printf 'session\n' > "$DATA/fake-intr/Cookies"
PATH="$SLOW_STUB:$PATH" "$BASH_BIN" "$AIDENTITY" rename "Fake Intr" Gone </dev/null >"$SANDBOX/intr.out" 2>&1 &
INTR_PID=$!
sleep 1.5
kill -TERM "$INTR_PID" 2>/dev/null
wait "$INTR_PID" 2>/dev/null
assert_file "an interrupted rename puts the session back" "$DATA/fake-intr/Cookies"
assert_no_dir "and leaves no moved copy" "$DATA/fake-gone"
assert_dir "the old launcher is still there" "$APPS/Fake Intr.app"
assert_eq "and still points at the session" "$DATA/fake-intr" "$(plist_key "$APPS/Fake Intr.app" AIdentityDataDir)"
assert_no_dir "no half-built launcher is left" "$APPS/Fake Gone.app"
assert_eq "no staging folder is left" "0" "$(find "$APPS" -maxdepth 1 -name '.aidentity-*' | wc -l | tr -d ' ')"
ai rm "Fake Intr" --purge -y

# Stopped between the two moves of a swap: the old launcher is set aside in the
# stage, the new one not yet in place. Cleanup must put the old one back.
mkdir -p "$SANDBOX/swapstage/.previous/Contents"
printf 'old\n' > "$SANDBOX/swapstage/.previous/Contents/marker"
RUN_OUT=$("$BASH_BIN" -c '. "$1" >/dev/null 2>&1
  BUILD_STAGE="$2"; SWAP_PREV="$2/.previous"; SWAP_DST="$3"; _cleanup_stage' x "$LIB" \
  "$SANDBOX/swapstage" "$APPS/Swap Target.app" 2>&1)
assert_file "cleanup puts a set-aside launcher back" "$APPS/Swap Target.app/Contents/marker"
assert_no_dir "and then removes the stage" "$SANDBOX/swapstage"
rm -rf "$APPS/Swap Target.app"

# A symlink to a launcher must not be mistaken for it.
ai add "$ELECTRON_APP" --profile Aliased
ln -s "$APPS/Fake Aliased.app" "$APPS/A Alias.app"
ai set "Fake Aliased" --color red
assert_eq "set acts on the launcher, not on a symlink to it" "E5484D" \
  "$(plist_key "$APPS/Fake Aliased.app" AIdentityColor)"
if [ -L "$APPS/A Alias.app" ]; then _pass "the symlink is left as it was"; else _fail "the symlink is left as it was" "it was replaced"; fi
rm -f "$APPS/A Alias.app"
ai rm "Fake Aliased" --purge -y

# A launcher renamed to "previous" in Finder: its replacement must not end up
# with the old bundle nested inside it.
ai add "$ELECTRON_APP" --profile Prev
mv "$APPS/Fake Prev.app" "$APPS/previous.app"
ai set previous --color teal
assert_rc "a launcher called previous can be rebuilt" 0 "$RUN_RC" "$RUN_OUT"
assert_no_dir "with nothing nested inside it" "$APPS/previous.app/previous.app"
rm -rf "$APPS/previous.app" "$DATA/fake-prev"

# A recorded profile path that is a symlink: its target is claimed, not orphaned.
mkdir -p "$DATA/moved-here"
printf 'session\n' > "$DATA/moved-here/Cookies"
ai add "$ELECTRON_APP" --profile Linked2
rm -rf "$DATA/fake-linked2"
ln -s "$DATA/moved-here" "$DATA/fake-linked2"
ai prune -y
assert_file "prune keeps the folder a profile's symlink points at" "$DATA/moved-here/Cookies"
ai rm "Fake Linked2" -y
rm -f "$DATA/fake-linked2"
rm -rf "$DATA/moved-here"


group "restore records and aidentity restore"

ai add "$ELECTRON_APP" --profile Keep --color teal --badge K
KEEP_DATA="$DATA/fake-keep"
printf 'session\n' > "$KEEP_DATA/Cookies"
assert_file "add writes a restore record into the profile folder" "$KEEP_DATA/.aidentity-profile.plist"
assert_eq "the record is owner-only" "600" "$(stat -f '%Lp' "$KEEP_DATA/.aidentity-profile.plist")"
assert_eq "the record names the profile" "Keep" \
  "$(/usr/libexec/PlistBuddy -c 'Print :AIdentityProfile' "$KEEP_DATA/.aidentity-profile.plist" 2>/dev/null)"

# A launcher deleted in Finder: the folder stays, with its record.
rm -rf "$APPS/Fake Keep.app"
ai restore
assert_contains "restore lists a profile whose launcher is gone" "$RUN_OUT" "Fake Keep"
ai prune
assert_contains "prune says a listed folder can be restored" "$RUN_OUT" 'aidentity restore "Fake Keep"'
assert_file "a cancelled prune deletes nothing" "$KEEP_DATA/Cookies"
ai restore "fake keep"
assert_rc "restore rebuilds it by name, any capitals" 0 "$RUN_RC" "$RUN_OUT"
assert_dir "the launcher is back" "$APPS/Fake Keep.app"
assert_eq "it points at the same folder" "$KEEP_DATA" "$(plist_key "$APPS/Fake Keep.app" AIdentityDataDir)"
assert_eq "with the colour it had" "12A594" "$(plist_key "$APPS/Fake Keep.app" AIdentityColor)"
assert_eq "and the badge it had" "K" "$(plist_key "$APPS/Fake Keep.app" AIdentityBadge)"
assert_file "and the session is untouched" "$KEEP_DATA/Cookies"
ai restore "Fake Keep"
assert_rc_nonzero "restore refuses a profile that already has a launcher" "$RUN_RC" "$RUN_OUT"

# The app moved since: restore finds it by name.
MOVER_DIR="$SB/moved-apps"
mkdir -p "$MOVER_DIR"
make_electron_app "$SRC/Mover.app"
ai add "$SRC/Mover.app" --profile Far
rm -rf "$APPS/Mover Far.app"
mv "$SRC/Mover.app" "$MOVER_DIR/"
RUN_OUT=$(AIDENTITY_APP_DIRS="$SRC:$APPS:$MOVER_DIR" detached "$BASH_BIN" "$AIDENTITY" restore --all 2>&1 </dev/null); RUN_RC=$?
assert_rc "restore --all finds an app that moved" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "and points the launcher at its new place" "$MOVER_DIR/Mover.app" \
  "$(plist_key "$APPS/Mover Far.app" AIdentityTargetApp)"
ai rm "Mover Far" --purge -y
rm -rf "$MOVER_DIR"

# A record cannot smuggle in a bad name.
ai add "$ELECTRON_APP" --profile Bent
rm -rf "$APPS/Fake Bent.app"
/usr/libexec/PlistBuddy -c "Set :AIdentityProfile ../../evil" "$DATA/fake-bent/.aidentity-profile.plist"
ai restore --all
assert_rc_nonzero "a record with an invalid profile name is refused" "$RUN_RC" "$RUN_OUT"
assert_no_dir "and builds nothing" "$APPS/Fake ..app"
rm -rf "$DATA/fake-bent"


group "doctor checks every profile, and --fix repairs"

ai doctor
assert_contains "doctor lists each profile" "$RUN_OUT" "Fake Keep"
assert_rc "doctor reports but exits 0" 0 "$RUN_RC" "$RUN_OUT"

# Simulate drift: an older build, an open folder, no restore record.
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 0.9.0" "$APPS/Fake Keep.app/Contents/Info.plist"
chmod 755 "$KEEP_DATA"
rm -f "$KEEP_DATA/.aidentity-profile.plist"
ai doctor
assert_contains "doctor names an older build" "$RUN_OUT" "built by aidentity 0.9.0"
assert_contains "doctor names a folder others can read" "$RUN_OUT" "mode 755"
assert_contains "doctor names a missing restore record" "$RUN_OUT" "no restore record"
assert_contains "doctor points at --fix" "$RUN_OUT" "doctor --fix"
ai doctor --fix
assert_rc "doctor --fix succeeds" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "the launcher is rebuilt by this version" "$(sed -n 's/^AIDENTITY_VERSION="\(.*\)"$/\1/p' "$AIDENTITY")" \
  "$(plist_key "$APPS/Fake Keep.app" CFBundleShortVersionString)"
assert_eq "the folder is owner-only again" "700" "$(stat -f '%Lp' "$KEEP_DATA")"
assert_file "the restore record is back" "$KEEP_DATA/.aidentity-profile.plist"
assert_file "the session was not touched" "$KEEP_DATA/Cookies"
assert_eq "the colour survived" "12A594" "$(plist_key "$APPS/Fake Keep.app" AIdentityColor)"
ai doctor
assert_not_contains "after --fix, nothing fixable is left for it" "$RUN_OUT" "Fake Keep —"

make_electron_app "$SRC/Vanish.app"
ai add "$SRC/Vanish.app" --profile V
rm -rf "$SRC/Vanish.app"
ai doctor
assert_contains "doctor says when an app is gone" "$RUN_OUT" "its app is gone"
ai rm "Vanish V" --purge -y


group "re-adding keeps the look; relative data roots are cleaned"

ai set "Fake Keep" --color red --badge Q
ai add "$ELECTRON_APP" --profile Keep
assert_rc "re-adding an existing profile succeeds" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "and says Updated, not Created" "$RUN_OUT" "Updated"
assert_eq "it keeps the colour that was set" "E5484D" "$(plist_key "$APPS/Fake Keep.app" AIdentityColor)"
assert_eq "it keeps the badge that was set" "Q" "$(plist_key "$APPS/Fake Keep.app" AIdentityBadge)"
ai add "$ELECTRON_APP" --profile Keep --color blue
assert_eq "a colour given on re-add still wins" "2E7DF6" "$(plist_key "$APPS/Fake Keep.app" AIdentityColor)"
ai rm "Fake Keep" --purge -y

REL_CWD="$SB/cwd/sub"
mkdir -p "$REL_CWD"
RUN_OUT=$(cd "$REL_CWD" && AIDENTITY_DATA_ROOT=../reldata detached "$BASH_BIN" "$AIDENTITY" add "$ELECTRON_APP" --profile Rel 2>&1 </dev/null); RUN_RC=$?
assert_rc "a relative data root works" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "and is recorded without dot segments" "$SB/cwd/reldata/fake-rel" \
  "$(plist_key "$APPS/Fake Rel.app" AIdentityDataDir)"
RUN_OUT=$(cd "$REL_CWD" && AIDENTITY_DATA_ROOT=../reldata detached "$BASH_BIN" "$AIDENTITY" rm "Fake Rel" --purge -y 2>&1 </dev/null); RUN_RC=$?
assert_no_dir "so purge can delete what it made" "$SB/cwd/reldata/fake-rel"


group "doctor and restore vet what they rebuild"

# A damaged launcher that records no app. resolve_app("") returns an app
# folder itself, which doctor --fix used to "repair" the launcher into.
ai add "$ELECTRON_APP" --profile Hollow
/usr/libexec/PlistBuddy -c "Set :AIdentityTargetApp ''" "$APPS/Fake Hollow.app/Contents/Info.plist"
ai doctor
assert_contains "doctor says a launcher records no app" "$RUN_OUT" "records no app"
ai doctor --fix
assert_eq "doctor --fix does not point it at a folder" "" \
  "$(plist_key "$APPS/Fake Hollow.app" AIdentityTargetApp)"
ai rebuild "Fake Hollow"
assert_rc_nonzero "rebuild refuses a launcher with no app" "$RUN_RC" "$RUN_OUT"
ai rm "Fake Hollow" --purge -y

# An app that moved, where only a plain folder of the same name remains.
make_electron_app "$SRC/Shifty.app"
ai add "$SRC/Shifty.app" --profile S
rm -rf "$SRC/Shifty.app"
mkdir -p "$SRC/Shifty"
ai doctor
assert_contains "a folder with the app's name is not taken for the app" "$RUN_OUT" "its app is gone"
rmdir "$SRC/Shifty"
ai rm "Shifty S" --purge -y

# A 1.0.0 launcher: --fix still says its badge and colour went back to defaults.
ai add "$ELECTRON_APP" --profile Oldie
/usr/libexec/PlistBuddy -c "Delete :AIdentityBadge" -c "Delete :AIdentityColor" \
  "$APPS/Fake Oldie.app/Contents/Info.plist" >/dev/null 2>&1
ai doctor --fix
assert_contains "doctor --fix shows the 1.0.0 note" "$RUN_OUT" "1.0.0"
ai rm "Fake Oldie" --purge -y

# Records that are not valid are not offered, and are never printed raw.
ai add "$ELECTRON_APP" --profile Esc
rm -rf "$APPS/Fake Esc.app"
/usr/libexec/PlistBuddy -c "Set :AIdentityProfile $(printf 'Esc\033[2J')" \
  "$DATA/fake-esc/.aidentity-profile.plist"
ai restore
assert_not_contains "a record with control characters is not listed" "$RUN_OUT" "Esc"
rm -rf "$DATA/fake-esc"

ai restore "Something" --all
assert_rc_nonzero "restore refuses a name together with --all" "$RUN_RC" "$RUN_OUT"

# The colour from a record is stored as hex, whatever spelling the record had.
ai add "$ELECTRON_APP" --profile Hue
rm -rf "$APPS/Fake Hue.app"
/usr/libexec/PlistBuddy -c "Set :AIdentityColor blue" "$DATA/fake-hue/.aidentity-profile.plist"
ai restore "Fake Hue"
assert_eq "a colour name in a record is stored as hex" "2E7DF6" "$(plist_key "$APPS/Fake Hue.app" AIdentityColor)"

# Re-adding under a different data root keeps the folder the profile records.
printf 'session\n' > "$DATA/fake-hue/Cookies"
AIDENTITY_DATA_ROOT="$SB/other-root" ai add "$ELECTRON_APP" --profile Hue
assert_eq "re-adding keeps the profile's own folder" "$DATA/fake-hue" \
  "$(plist_key "$APPS/Fake Hue.app" AIdentityDataDir)"
assert_no_dir "and makes no new one under the other root" "$SB/other-root/fake-hue"
ai rm "Fake Hue" --purge -y


group "install.sh end to end, against a stub curl"

# A stub curl that serves this checkout instead of GitHub. It knows the two
# files install.sh fetches; STUB_SUMS picks which checksum file it serves.
CURL_STUB="$SANDBOX/stub-curl"
mkdir -p "$CURL_STUB"
cat > "$CURL_STUB/curl" <<STUB
#!/bin/sh
out="" url=""
while [ \$# -gt 0 ]; do
  case "\$1" in
    -o) out="\$2"; shift 2 ;;
    --proto|--proto-redir|--connect-timeout|--max-time|--retry) shift 2 ;;
    -*) shift ;;
    *) url="\$1"; shift ;;
  esac
done
case "\$url" in
  */bin/aidentity) src='$REPO_DIR/bin/aidentity' ;;
  */SHA256SUMS)
    case "\${STUB_SUMS:-good}" in
      good) src='$REPO_DIR/SHA256SUMS' ;;
      bad) printf '%064d  bin/aidentity\n' 0; exit 0 ;;
      *) exit 22 ;;
    esac ;;
  *) exit 22 ;;
esac
if [ -n "\$out" ]; then cat "\$src" > "\$out"; else cat "\$src"; fi
STUB
chmod +x "$CURL_STUB/curl"

inst() { # install dir, then optional VAR=value settings for install.sh
  local dir="$1"; shift
  RUN_OUT=$(env HOME="$SANDBOX/inst-home" PATH="$CURL_STUB:/usr/bin:/bin:/usr/sbin:/sbin" \
    AIDENTITY_INSTALL_DIR="$dir" "$@" /usr/bin/perl -MPOSIX -e '
      my $pid = fork; die "fork: $!\n" unless defined $pid;
      if ($pid) { waitpid($pid, 0); exit($? & 127 ? 128 + ($? & 127) : $? >> 8) }
      POSIX::setsid(); exec @ARGV or exit 127' -- "$BASH_BIN" "$REPO_DIR/install.sh" 2>&1 </dev/null)
  RUN_RC=$?
  return 0
}

INST_A="$SB/inst a"
inst "$INST_A"
assert_rc "install.sh installs with no terminal and exits 0" 0 "$RUN_RC" "$RUN_OUT"
if cmp -s "$INST_A/aidentity" "$REPO_DIR/bin/aidentity"; then _pass "the installed file is this checkout's script"
else _fail "the installed file is this checkout's script" "differs or missing"; fi
assert_exec "it is executable" "$INST_A/aidentity"
assert_contains "the checksum was verified" "$RUN_OUT" "checksum verified"
assert_not_contains "no walkthrough is offered without a terminal" "$RUN_OUT" "Set up your first"
inst "$INST_A"
assert_contains "a second run reports a reinstall" "$RUN_OUT" "Reinstalled"

inst "$SB/inst b" STUB_SUMS=bad
assert_rc_nonzero "a checksum mismatch refuses to install" "$RUN_RC" "$RUN_OUT"
assert_no_file "and writes nothing" "$SB/inst b/aidentity"
inst "$SB/inst c" STUB_SUMS=missing
assert_rc "a missing checksum file warns and installs" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "and says so" "$RUN_OUT" "No published checksum"
inst "$SB/inst d" "AIDENTITY_REF=../../evil/repo/main"
assert_rc_nonzero "a ref that walks out of the repository is refused" "$RUN_RC" "$RUN_OUT"
mkdir -p "$SB/inst e/aidentity"
inst "$SB/inst e"
assert_rc_nonzero "a directory at the target is refused" "$RUN_RC" "$RUN_OUT"
mkdir -p "$SB/inst f" "$SB/elsewhere"
ln -s "$SB/elsewhere" "$SB/inst f/aidentity"
inst "$SB/inst f"
assert_rc "a symlink at the target is replaced" 0 "$RUN_RC" "$RUN_OUT"
if [ -f "$SB/inst f/aidentity" ] && [ ! -L "$SB/inst f/aidentity" ]; then _pass "by a real file"
else _fail "by a real file" "still a link or missing"; fi
assert_eq "nothing was dropped into the link's target" "" "$(ls -A "$SB/elsewhere")"

# GNU coreutils first on PATH (common with Homebrew): its mv has no -h. The
# installer must not depend on whichever mv comes first.
printf '#!/bin/sh\ncase " $* " in *" -h"*|*" -fh "*) echo "mv: invalid option -- h" >&2; exit 1 ;; esac\nexec /bin/mv "$@"\n' \
  > "$CURL_STUB/mv"
chmod +x "$CURL_STUB/mv"
inst "$SB/inst g"
assert_rc "an mv without -h first on PATH does not break the install" 0 "$RUN_RC" "$RUN_OUT"
assert_file "the file is installed" "$SB/inst g/aidentity"
rm -f "$CURL_STUB/mv"

# make formula against a tag that cannot be downloaded must change nothing.
# It used to hash the empty download and write that checksum into the formula.
FORMULA_SB="$SB/formula-copy"
mkdir -p "$FORMULA_SB/Formula"
cp "$REPO_DIR/Makefile" "$FORMULA_SB/"
cp "$REPO_DIR/Formula/aidentity.rb" "$FORMULA_SB/Formula/"
mkdir -p "$SANDBOX/stub-curl-404"
printf '#!/bin/sh\necho "curl: (22) The requested URL returned error: 404" >&2\nexit 22\n' > "$SANDBOX/stub-curl-404/curl"
chmod +x "$SANDBOX/stub-curl-404/curl"
RUN_OUT=$(cd "$FORMULA_SB" && PATH="$SANDBOX/stub-curl-404:$PATH" make -s formula VERSION=9.9.9 2>&1); RUN_RC=$?
assert_rc_nonzero "make formula fails when the tag cannot be downloaded" "$RUN_RC" "$RUN_OUT"
if cmp -s "$FORMULA_SB/Formula/aidentity.rb" "$REPO_DIR/Formula/aidentity.rb"; then
  _pass "and leaves the formula untouched"
else
  _fail "and leaves the formula untouched" "the formula changed"
fi
RUN_OUT=$(cd "$FORMULA_SB" && make -s release VERSION='1.0.0"; touch pwned; "' 2>&1); RUN_RC=$?
assert_rc_nonzero "make release refuses a version that is not x.y.z" "$RUN_RC" "$RUN_OUT"
assert_no_file "and runs nothing it was handed" "$FORMULA_SB/pwned"
# A valid first line used to carry a second one past a line-by-line check.
for target in release formula; do
  RUN_OUT=$(cd "$FORMULA_SB" && PATH="$SANDBOX/stub-curl-404:$PATH" \
    make -s "$target" VERSION="1.2.3
touch pwned" 2>&1); RUN_RC=$?
  assert_rc_nonzero "make $target refuses a version with a second line" "$RUN_RC" "$RUN_OUT"
  assert_contains "with the usage line, before anything else runs" "$RUN_OUT" "Usage: make $target"
done
assert_no_file "and the second line never runs" "$FORMULA_SB/pwned"


group "uninstall.sh end to end, every search path in the sandbox"

# AIDENTITY_BIN_DIRS keeps it from finding a real installed copy; HOME and
# AIDENTITY_APP_DIRS keep its launcher search inside the sandbox.
UN_BIN="$SB/un-bin"
mkdir -p "$UN_BIN"
un_prepare() {
  cp "$REPO_DIR/bin/aidentity" "$UN_BIN/aidentity"
  ai add "$ELECTRON_APP" --profile Bye
  printf 'session\n' > "$DATA/fake-bye/Cookies"
}
un_tty() { # typed input
  RUN_OUT=$( { { sleep 0.3; printf '%b' "$1"; sleep 1; } \
      | HOME="$SANDBOX/tty-home" AIDENTITY_BIN_DIRS="$UN_BIN" PATH="$STUB_BIN:$PATH" \
        script -q /dev/null "$BASH_BIN" "$REPO_DIR/uninstall.sh"
      echo "__rc=${PIPESTATUS[1]}"; } 2>&1 | tr -d '\r')
  RUN_RC=${RUN_OUT##*__rc=}
  RUN_OUT=${RUN_OUT%__rc=*}
  return 0
}

un_prepare
un_tty 'no\n'
assert_rc "declining exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "and says nothing was deleted" "$RUN_OUT" "Kept"
assert_dir "the launcher stays" "$APPS/Fake Bye.app"
assert_file "the data stays" "$DATA/fake-bye/Cookies"

cp "$REPO_DIR/bin/aidentity" "$UN_BIN/aidentity"
RUN_OUT=$(HOME="$SANDBOX/tty-home" AIDENTITY_BIN_DIRS="$UN_BIN" detached "$BASH_BIN" "$REPO_DIR/uninstall.sh" 2>&1 </dev/null); RUN_RC=$?
assert_rc_nonzero "with no terminal to confirm on, it exits non-zero" "$RUN_RC" "$RUN_OUT"
assert_dir "and deletes no launcher" "$APPS/Fake Bye.app"

un_prepare
mkdir -p "$DATA/stray-profile"
un_tty 'delete\n'
assert_rc "typing delete removes everything" 0 "$RUN_RC" "$RUN_OUT"
assert_no_file "the command" "$UN_BIN/aidentity"
assert_no_dir "the launcher" "$APPS/Fake Bye.app"
assert_no_dir "its data" "$DATA/fake-bye"
assert_no_dir "data no launcher pointed at" "$DATA/stray-profile"
assert_contains "and only then says aidentity is gone" "$RUN_OUT" "aidentity is gone"
assert_file "it never touched this checkout" "$REPO_DIR/bin/aidentity"
mkdir -p "$DATA"

# A Homebrew-managed copy is left for brew, so "gone" would be false.
mkdir -p "$SB/Cellar/aidentity/1.1.0/bin"
cp "$REPO_DIR/bin/aidentity" "$SB/Cellar/aidentity/1.1.0/bin/aidentity"
ln -sfn "$SB/Cellar/aidentity/1.1.0/bin/aidentity" "$UN_BIN/aidentity"
ai add "$ELECTRON_APP" --profile Bye
un_tty 'delete\n'
assert_contains "a Homebrew copy is left for brew" "$RUN_OUT" "managed by Homebrew"
assert_not_contains "and the end does not claim it is all gone" "$RUN_OUT" "aidentity is gone"
assert_no_dir "the launcher is still removed" "$APPS/Fake Bye.app"
rm -f "$UN_BIN/aidentity"
mkdir -p "$DATA"


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
