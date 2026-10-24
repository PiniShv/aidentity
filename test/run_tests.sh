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
RUN_ERR=''
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
# VS Code and its forks keep a socket in the profile folder, and aidentity
# refuses a folder whose socket path would pass 103 bytes. "$DATA" is too deep
# for that, so their profiles live in this shorter root.
VSC_DATA="$SANDBOX/v"
mkdir -p "$APPS" "$DATA" "$SRC" "$VSC_DATA"

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

# Same, but stdout and stderr apart: RUN_OUT is stdout only, RUN_ERR is
# stderr. For output another program reads, where one stray line breaks it.
ai_stdout() {
  RUN_OUT=$(detached "$BASH_BIN" "$AIDENTITY" "$@" 2>"$SANDBOX/stderr" </dev/null)
  RUN_RC=$?
  RUN_ERR=$(cat "$SANDBOX/stderr")
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

# Read JSON with the JavaScript engine that ships with macOS, so the check
# needs nothing installed and the script never comes to rely on it. Prints a
# JavaScript expression's value over the parsed text `d`: a string as it is,
# anything else as JSON. In the expression, byName(n) is the object named n
# and arg is the optional third argument. Text that is not valid JSON prints
# the parser's error and exits non-zero.
json_get() { # json, expression, [arg]
  /usr/bin/osascript -l JavaScript - "$1" "$2" "${3:-}" 2>&1 <<'JXA'
function run(argv) {
  var d = JSON.parse(argv[0]);
  function byName(n) { return d.filter(function (o) { return o.name === n; })[0]; }
  var v = new Function("d", "byName", "arg", "return (" + argv[1] + ");")(d, byName, argv[2]);
  return typeof v === "string" ? v : JSON.stringify(v);
}
JXA
}

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
assert_contains "help documents list --json" "$RUN_OUT" "--json"
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
ai_stdout list --json
assert_rc "list --json exits 0 with no profiles" 0 "$RUN_RC" "$RUN_ERR"
assert_eq "list --json prints an empty array when there is nothing yet" "[]" "$RUN_OUT"

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

group "json_str"

libcall json_str "plain"
assert_eq "json_str wraps a plain string in double quotes" '"plain"' "$RUN_OUT"
libcall json_str 'say "hi" \ bye'
assert_eq "json_str escapes quotes and backslashes" '"say \"hi\" \\ bye"' "$RUN_OUT"
libcall json_str $'a\tb\nc\rd'
assert_eq "json_str uses the short forms for tab, newline and return" '"a\tb\nc\rd"' "$RUN_OUT"
libcall json_str $'bell\a esc\033 one\001'
assert_eq "json_str writes other control characters as \\u00XX" '"bell\u0007 esc\u001b one\u0001"' "$RUN_OUT"
libcall json_str 'Ünïcödé — 日本'
assert_eq "json_str passes UTF-8 through unchanged" '"Ünïcödé — 日本"' "$RUN_OUT"
libcall json_str ""
assert_eq "json_str quotes an empty string" '""' "$RUN_OUT"
libcall json_str_or_null ""
assert_eq "an empty value becomes null" "null" "$RUN_OUT"
libcall json_lines $'--lang=de\n\n--disable-gpu'
assert_eq "json_lines makes an array of strings, skipping blank lines" '["--lang=de","--disable-gpu"]' "$RUN_OUT"
libcall json_lines ""
assert_eq "json_lines makes an empty array from nothing" '[]' "$RUN_OUT"

# The property that matters: a JSON parser gives back exactly what went in.
# Both locales, because the loop walks bytes under C and characters under UTF-8.
json_roundtrip() { # description input
  local loc quoted
  for loc in C en_US.UTF-8; do
    quoted=$(LC_ALL=$loc "$BASH_BIN" -c '. "$1" >/dev/null 2>&1; json_str "$2"' aidentity-lib "$LIB" "$2")
    assert_eq "json_str round-trips $1 ($loc)" "true" "$(json_get "$quoted" 'd === arg' "$2")"
  done
}
ALL_ASCII=$(i=1; while [ "$i" -lt 128 ]; do printf '%b' "\\0$(printf '%03o' "$i")"; i=$((i+1)); done)
assert_eq "the test string holds every ASCII character but NUL" "127" "$(printf '%s' "$ALL_ASCII" | wc -c | tr -d ' ')"
json_roundtrip "every ASCII character"        "$ALL_ASCII"
json_roundtrip "a path with quotes and slashes" '/Users/x/My "App" \ 2/a b.app'
json_roundtrip "UTF-8 text"                   'Ünïcödé — 日本 🙂'

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

# The menu reads the list once and asks about every profile against it. The
# answers must be the ones a fresh read gives: same stub, same cases.
probe_listed() { # data dir -> RUNNING / STOPPED
  PATH="$PGREP_STUB:$PATH" "$BASH_BIN" -c \
    '. "$1" >/dev/null 2>&1; l=$(pgrep -afl "user-data-dir="); r=$?; ids=$(proc_dir_ids "$l")
     running_in_list "$2" "$r" "$l" "$ids" && echo RUNNING || echo STOPPED' x "$LIB" "$1"
}
assert_eq "a list read once: the profile listed first reads as running" "RUNNING" "$(probe_listed "$BUSY_DATA")"
assert_eq "a list read once: a prefix does not match" "STOPPED" "$(probe_listed "$DATA/fake-bus")"
assert_eq "a list read once: a longer name does not match" "STOPPED" "$(probe_listed "$BUSY_DATA-2")"
assert_eq "a list read once: a symlinked root reads as running" "RUNNING" "$(probe_listed "$SB/data-alias/fake-busy")"
assert_eq "a list read once: a doubled slash reads as running" "RUNNING" "$(probe_listed "$DATA//fake-busy")"
assert_eq "a list read once: a different folder through the symlink does not match" "STOPPED" \
  "$(probe_listed "$SB/data-alias/fake-other")"
libcall running_in_list "$DATA/fake-busy" 2 "" "|"
assert_rc "a list read once: a pgrep that failed counts as running, as it does for rm" 0 "$RUN_RC" "$RUN_OUT"
libcall running_in_list "$DATA/fake-busy" 1 "" "|"
assert_rc_nonzero "a list read once: no match is not running" "$RUN_RC" "$RUN_OUT"
libcall running_in_list "" 0 "101 x --user-data-dir=/p" "|"
assert_rc_nonzero "a list read once: an empty data dir is never running" "$RUN_RC" "$RUN_OUT"
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


group "launch settings: an allowlist, kept across rename, rebuild and restore"

ai add "$ELECTRON_APP" --profile Flags --arg --lang=de --arg "--proxy-server=socks5://127.0.0.1:1080" \
  --env "HTTPS_PROXY=http://proxy.example:8080"
assert_rc "add accepts allowed switches and variables" 0 "$RUN_RC" "$RUN_OUT"
FL_LAUNCHER="$APPS/Fake Flags.app/Contents/MacOS/launcher"
FL_SRC=$(cat "$FL_LAUNCHER")
assert_contains "the switch reaches the app" "$FL_SRC" "'--lang=de'"
assert_contains "the variable reaches the app" "$FL_SRC" "--env 'HTTPS_PROXY=http://proxy.example:8080'"
if sh -n "$FL_LAUNCHER" 2>/dev/null; then _pass "the launcher is valid sh"; else _fail "the launcher is valid sh" "sh -n failed"; fi
ai list
assert_contains "list shows the switches" "$RUN_OUT" "--lang=de"
assert_contains "list names the variables" "$RUN_OUT" "HTTPS_PROXY (values hidden)"
assert_not_contains "but never shows their values" "$RUN_OUT" "proxy.example"

for bad in --remote-debugging-port=9222 -remote-debugging-port=9222 --inspect --no-sandbox \
           --disable-web-security --js-flags=--x --lang=../x --force-device-scale-factor=9; do
  ai add "$ELECTRON_APP" --profile Denied --arg "$bad"
  assert_rc_nonzero "the switch [$bad] is refused" "$RUN_RC" "$RUN_OUT"
done
for bad in NODE_OPTIONS=--require=/x ELECTRON_RUN_AS_NODE=1 DYLD_INSERT_LIBRARIES=/x FOO=bar HOME=/tmp; do
  ai add "$ELECTRON_APP" --profile Denied --env "$bad"
  assert_rc_nonzero "the variable [$bad] is refused" "$RUN_RC" "$RUN_OUT"
done
assert_no_dir "no launcher is built for a refused setting" "$APPS/Fake Denied.app"

ai set "Fake Flags" --env "HTTPS_PROXY=http://other.example:3128"
assert_eq "set replaces a variable of the same name" "HTTPS_PROXY=http://other.example:3128" \
  "$(/usr/libexec/PlistBuddy -c 'Print :AIdentityEnv:0' "$APPS/Fake Flags.app/Contents/Info.plist" 2>/dev/null)"
ai rename "Fake Flags" Flagged
assert_contains "rename keeps the switches" "$(cat "$APPS/Fake Flagged.app/Contents/MacOS/launcher")" "'--lang=de'"
ai rebuild "Fake Flagged"
assert_contains "rebuild keeps the switches" "$(cat "$APPS/Fake Flagged.app/Contents/MacOS/launcher")" "'--lang=de'"
rm -rf "$APPS/Fake Flagged.app"
ai restore "Fake Flagged"
assert_contains "restore keeps the switches" "$(cat "$APPS/Fake Flagged.app/Contents/MacOS/launcher")" "'--lang=de'"
ai set "Fake Flagged" --clear-args --clear-env
assert_not_contains "set --clear-args removes the switches" "$(cat "$APPS/Fake Flagged.app/Contents/MacOS/launcher")" "--lang"
assert_not_contains "set --clear-env removes the variables" "$(cat "$APPS/Fake Flagged.app/Contents/MacOS/launcher")" "HTTPS_PROXY"

# A restore record is a file anyone with the folder can edit: its settings go
# through the same allowlist.
rm -rf "$APPS/Fake Flagged.app"
/usr/libexec/PlistBuddy -c "Add :AIdentityArgs:0 string --remote-debugging-port=9222" \
  "$DATA/fake-flagged/.aidentity-profile.plist" >/dev/null 2>&1
ai restore "Fake Flagged"
assert_rc "a record carrying a refused switch is still restored" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "the refused switch is dropped, with a note" "$RUN_OUT" "Dropped a stored launch setting"
assert_not_contains "and never reaches the launcher" \
  "$(cat "$APPS/Fake Flagged.app/Contents/MacOS/launcher")" "remote-debugging"
ai rm "Fake Flagged" --purge -y

# Changed values replace old ones by switch name; the newest wins.
ai add "$ELECTRON_APP" --profile Merge --arg --lang=de --arg --lang=de
ai set "Fake Merge" --arg --lang=fr
M_SRC=$(cat "$APPS/Fake Merge.app/Contents/MacOS/launcher")
assert_contains "a new value replaces the old one" "$M_SRC" "'--lang=fr'"
assert_not_contains "the old value is gone" "$M_SRC" "--lang=de"
ai set "Fake Merge" --arg --lang=de
assert_not_contains "setting an earlier value again applies it" \
  "$(cat "$APPS/Fake Merge.app/Contents/MacOS/launcher")" "--lang=fr"
assert_contains "and says when it applies" "$RUN_OUT" "next time"
ai set "Fake Merge" --arg "--proxy-server=socks5://127.0.0.1:1080"
ai set "Fake Merge" --arg --no-proxy-server
assert_not_contains "--no-proxy-server replaces --proxy-server" \
  "$(cat "$APPS/Fake Merge.app/Contents/MacOS/launcher")" "--proxy-server="
assert_eq "a launcher with settings is owner-only" "600" \
  "$(stat -f '%Lp' "$APPS/Fake Merge.app/Contents/Info.plist")"
# A stored setting that is no longer allowed is dropped on rebuild, not fatal.
/usr/libexec/PlistBuddy -c "Add :AIdentityArgs:0 string --inspect" \
  "$APPS/Fake Merge.app/Contents/Info.plist" >/dev/null 2>&1
ai rebuild "Fake Merge"
assert_rc "rebuild drops a stored setting that is not allowed" 0 "$RUN_RC" "$RUN_OUT"
assert_not_contains "and the launcher never carries it" \
  "$(cat "$APPS/Fake Merge.app/Contents/MacOS/launcher")" "--inspect"
ai rm "Fake Merge" --purge -y

for bad in '--locale=ab-CDE$(id)' --force-device-scale-factor=1.0e308 --force-device-scale-factor=4.5 \
           '--proxy-server=http://a --inspect' --lang=d; do
  ai add "$ELECTRON_APP" --profile Shape --arg "$bad"
  assert_rc_nonzero "the value in [$bad] is refused" "$RUN_RC" "$RUN_OUT"
done
for bad in 'TZ=/etc/../x' 'LANG=../x' 'LANG TZ=x' 'HTTPS_PROXY=http://a b'; do
  ai add "$ELECTRON_APP" --profile Shape --env "$bad"
  assert_rc_nonzero "the variable [$bad] is refused" "$RUN_RC" "$RUN_OUT"
done
ai add "$ELECTRON_APP" --profile Shape --arg --lang=pt-BR --arg --force-device-scale-factor=1.25 \
  --env TZ=Europe/Berlin --env LANG=de_DE.UTF-8
assert_rc "well-formed values are accepted" 0 "$RUN_RC" "$RUN_OUT"
ai rm "Fake Shape" --purge -y

ai add "$ELECTRON_APP" --profile Ext --own-extensions
assert_rc_nonzero "--own-extensions is refused for an app that is not VS Code" "$RUN_RC" "$RUN_OUT"
VSC_APP="$SRC/Codish.app"
make_electron_app "$VSC_APP"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.example.codish" "$VSC_APP/Contents/Info.plist"
mkdir -p "$VSC_APP/Contents/Resources/app"
printf '{"darwinBundleIdentifier":"com.example.codish","dataFolderName":".codish"}\n' \
  > "$VSC_APP/Contents/Resources/app/product.json"
AIDENTITY_DATA_ROOT="$VSC_DATA" ai add "$VSC_APP" --profile Iso --own-extensions
assert_rc "a VS Code-style app accepts --own-extensions" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "its launcher gets its own extensions folder" \
  "$(cat "$APPS/Codish Iso.app/Contents/MacOS/launcher")" "--extensions-dir='$VSC_DATA/codish-iso/extensions'"
AIDENTITY_DATA_ROOT="$VSC_DATA" ai rm "Codish Iso" --purge -y
rm -rf "$VSC_APP"


group "VS Code-style apps: the socket path limit"

# VS Code and its forks quit at start when the path of the socket they keep in
# the profile folder, "<first four characters of the version>-main.sock", is
# longer than 103 bytes.
SOCK_APP="$SRC/Codish.app"
make_electron_app "$SOCK_APP"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.example.codish" "$SOCK_APP/Contents/Info.plist"
mkdir -p "$SOCK_APP/Contents/Resources/app"
sock_version() { # version, or nothing for a product.json without one
  printf '{"darwinBundleIdentifier":"com.example.codish","dataFolderName":".codish"%s}\n' \
    "${1:+,\"version\":\"$1\"}" > "$SOCK_APP/Contents/Resources/app/product.json"
}

sock_version 1.142.0
libcall socket_path_bytes "$SOCK_APP" "/p"
assert_eq "the socket is named after the version's first four characters" "17" "$RUN_OUT"
sock_version 1.0
libcall socket_path_bytes "$SOCK_APP" "/p"
assert_eq "a shorter version gives a shorter name" "16" "$RUN_OUT"
sock_version ""
libcall socket_path_bytes "$SOCK_APP" "/p"
assert_eq "with no version, the longest name is assumed" "17" "$RUN_OUT"
sock_version 1.142.0

ai add "$SOCK_APP" --main
assert_rc "a main launcher has no profile folder, so nothing to check" 0 "$RUN_RC" "$RUN_OUT"
ai rm "Codish Main" -y
ai add "$ELECTRON_APP" --profile "$(repeat_char 40 a)"
assert_rc "an app that is not VS Code-style is not checked" 0 "$RUN_RC" "$RUN_OUT"
ai rm "Fake $(repeat_char 40 a)" --purge -y

# The socket path is: root / "codish-" name / "1.14-main.sock", so the longest
# name that fits follows from the root's length in bytes (LC_ALL=C here).
FIT=$((103 - ${#VSC_DATA} - 23))
if [ "$FIT" -lt 2 ] || [ "$FIT" -gt 39 ]; then
  _skip "socket path limit for add, rename, restore and doctor" "the sandbox path is ${#SANDBOX} bytes"
else
  NAME_FIT=$(repeat_char "$FIT" a)
  NAME_OVER=$(repeat_char $((FIT + 1)) a)

  AIDENTITY_DATA_ROOT="$VSC_DATA" ai add "$SOCK_APP" --profile "$NAME_OVER"
  assert_rc_nonzero "add refuses a profile whose socket path would be 104 bytes" "$RUN_RC" "$RUN_OUT"
  assert_contains "and says how long it would be" "$RUN_OUT" "this one would be 104"
  assert_contains "and the limit" "$RUN_OUT" "103 bytes"
  assert_contains "and the longest name that fits" "$RUN_OUT" "Use a profile name of at most $FIT characters, or set AIDENTITY_DATA_ROOT"
  assert_no_dir "it builds no launcher" "$APPS/Codish $NAME_OVER.app"
  assert_no_dir "and makes no profile folder" "$VSC_DATA/codish-$NAME_OVER"

  # é is one character and two bytes. Counted as characters, this path would
  # be 103 and pass.
  U_ROOT="$SANDBOX/é"
  LC_ALL=en_US.UTF-8 AIDENTITY_DATA_ROOT="$U_ROOT" ai add "$SOCK_APP" --profile "$NAME_FIT"
  assert_rc_nonzero "bytes are counted, not characters" "$RUN_RC" "$RUN_OUT"
  assert_contains "so a UTF-8 path is 104 bytes" "$RUN_OUT" "this one would be 104"
  assert_no_dir "and nothing is created" "$U_ROOT"

  # A data folder so deep that a one-character name would be 106 bytes: no
  # name fits, and the folder must be 3 bytes shorter.
  DEEP_ROOT="$VSC_DATA/$(repeat_char $((82 - ${#VSC_DATA} - 1)) d)"
  AIDENTITY_DATA_ROOT="$DEEP_ROOT" ai add "$SOCK_APP" --profile A
  assert_rc_nonzero "a data folder too deep for any name is refused" "$RUN_RC" "$RUN_OUT"
  assert_contains "and says no name fits" "$RUN_OUT" "Even a one-character name is too long in this data folder"
  assert_contains "and how much shorter the folder must be" "$RUN_OUT" \
    "AIDENTITY_DATA_ROOT to a folder whose path is at least 3 bytes shorter"
  assert_no_dir "and nothing is created" "$DEEP_ROOT"

  AIDENTITY_DATA_ROOT="$VSC_DATA" ai add "$SOCK_APP" --profile A
  assert_rc "a short name is fine" 0 "$RUN_RC" "$RUN_OUT"
  printf 'session\n' > "$VSC_DATA/codish-a/Cookies"
  AIDENTITY_DATA_ROOT="$VSC_DATA" ai rename "Codish A" "$NAME_OVER"
  assert_rc_nonzero "rename refuses a name whose socket path would be too long" "$RUN_RC" "$RUN_OUT"
  assert_contains "and asks for a shorter one" "$RUN_OUT" "of at most $FIT characters"
  assert_dir "the launcher is untouched" "$APPS/Codish A.app"
  assert_file "and the profile is not moved" "$VSC_DATA/codish-a/Cookies"
  assert_no_dir "to the new name" "$VSC_DATA/codish-$NAME_OVER"
  AIDENTITY_DATA_ROOT="$VSC_DATA" ai rename "Codish A" "$NAME_FIT"
  assert_rc "rename takes a name of exactly 103 bytes" 0 "$RUN_RC" "$RUN_OUT"
  assert_file "and moves the profile" "$VSC_DATA/codish-$NAME_FIT/Cookies"
  AIDENTITY_DATA_ROOT="$VSC_DATA" ai doctor
  assert_not_contains "doctor finds nothing wrong at exactly 103 bytes" "$RUN_OUT" "cannot open it"

  # A launcher deleted in Finder, and a folder one byte too deep to restore.
  FIT_DATA="$VSC_DATA/codish-$NAME_FIT"
  LONG_DATA="$VSC_DATA/codish-${NAME_FIT}x"
  rm -rf "$APPS/Codish $NAME_FIT.app"
  mv "$FIT_DATA" "$LONG_DATA"
  AIDENTITY_DATA_ROOT="$VSC_DATA" ai restore --all
  assert_rc_nonzero "restore refuses a folder whose socket path is too long" "$RUN_RC" "$RUN_OUT"
  assert_contains "and says to rename the folder" "$RUN_OUT" "Rename this folder to a name of at most $((FIT + 7)) characters"
  assert_no_dir "it builds no launcher" "$APPS/Codish $NAME_FIT.app"
  assert_file "and leaves the profile alone" "$LONG_DATA/Cookies"
  mv "$LONG_DATA" "$FIT_DATA"
  AIDENTITY_DATA_ROOT="$VSC_DATA" ai restore --all
  assert_rc "with a shorter folder name it restores" 0 "$RUN_RC" "$RUN_OUT"
  assert_dir "the launcher is back" "$APPS/Codish $NAME_FIT.app"

  # A profile made before this check, one byte too deep.
  mv "$FIT_DATA" "$LONG_DATA"
  /usr/libexec/PlistBuddy -c "Set :AIdentityDataDir $LONG_DATA" "$APPS/Codish $NAME_FIT.app/Contents/Info.plist"
  AIDENTITY_DATA_ROOT="$VSC_DATA" ai doctor
  assert_rc "doctor reports, it does not fail" 0 "$RUN_RC" "$RUN_OUT"
  assert_contains "doctor reports a profile whose socket path is too long" "$RUN_OUT" \
    "Codish cannot open it: the socket path in its profile folder would be 104 bytes, and macOS allows 103"
  assert_contains "with the rename that fixes it" "$RUN_OUT" \
    "rename it to a name of at most $FIT characters: aidentity rename \"Codish $NAME_FIT\""
  AIDENTITY_DATA_ROOT="$VSC_DATA" ai doctor --fix
  assert_contains "--fix leaves the new name to the user" "$RUN_OUT" "Codish cannot open it"
  assert_eq "and the profile folder stays where it is" "$LONG_DATA" \
    "$(plist_key "$APPS/Codish $NAME_FIT.app" AIdentityDataDir)"
  AIDENTITY_DATA_ROOT="$VSC_DATA" ai add "$SOCK_APP" --profile "$NAME_FIT"
  assert_rc_nonzero "re-adding it is refused too" "$RUN_RC" "$RUN_OUT"
  assert_contains "and points to a rename" "$RUN_OUT" "Rename it to a name of at most $FIT characters:"
  assert_contains "with the command" "$RUN_OUT" "aidentity rename \"Codish $NAME_FIT\""
  AIDENTITY_DATA_ROOT="$VSC_DATA" ai rm "Codish $NAME_FIT" --purge -y
  assert_no_dir "rm --purge still removes it" "$LONG_DATA"
fi
rm -rf "$SOCK_APP"


group "list --json"

JSON_LAUNCHERS_BEFORE=$(count_launchers)
# App names and paths are whatever is on disk. A quote, a backslash, a tab and
# non-ASCII in the app's name reach the name, app and app_path fields.
ODD_APP="$SRC/Wëird \"Q\" \\ Tab	App.app"
ODD="Wëird \"Q\" \\ Tab	App Work"
make_electron_app "$ODD_APP"
ai add "$ODD_APP" --profile Work --badge "é" --color teal --arg --lang=de \
  --env "HTTPS_PROXY=http://secret.example:8080"
assert_rc "add takes an app whose name has quotes, a backslash and a tab" 0 "$RUN_RC" "$RUN_OUT"
ai add "$ELECTRON_APP" --main
ai add "$ELECTRON_APP" --profile Busy --no-badge
printf 'session\n' > "$BUSY_DATA/Cookies"
GONE_APP="$SRC/Gone.app"
make_electron_app "$GONE_APP"
ai add "$GONE_APP" --profile Lost
rm -rf "$GONE_APP"
EXT_APP="$SRC/Codey.app"
make_electron_app "$EXT_APP"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.example.codey" "$EXT_APP/Contents/Info.plist"
mkdir -p "$EXT_APP/Contents/Resources/app"
printf '{"darwinBundleIdentifier":"com.example.codey","dataFolderName":".codey"}\n' \
  > "$EXT_APP/Contents/Resources/app/product.json"
AIDENTITY_DATA_ROOT="$VSC_DATA" ai add "$EXT_APP" --profile Ext --own-extensions

ai_stdout list --json
J=$RUN_OUT
assert_rc "list --json exits 0" 0 "$RUN_RC" "$RUN_ERR"
assert_eq "stdout parses as JSON, one object per launcher" "5" "$(json_get "$J" 'd.length')"
assert_eq "every object has the same keys, in the same order" "true" \
  "$(json_get "$J" 'd.every(function (o) { return Object.keys(o).join() === arg; })' \
     "name,app,app_path,profile,data_dir,main,status,badge,color,built_by,args,env,own_extensions")"
assert_eq "name survives quotes, a backslash, a tab and UTF-8" "true" \
  "$(json_get "$J" 'byName(arg) !== undefined' "$ODD")"
assert_eq "app is the app's name" "Wëird \"Q\" \\ Tab	App" "$(json_get "$J" 'byName(arg).app' "$ODD")"
assert_eq "app_path is the app's path" "$ODD_APP" "$(json_get "$J" 'byName(arg).app_path' "$ODD")"
assert_eq "profile is the profile name" "Work" "$(json_get "$J" 'byName(arg).profile' "$ODD")"
assert_eq "data_dir is the profile folder" "$(plist_key "$APPS/$ODD.app" AIdentityDataDir)" \
  "$(json_get "$J" 'byName(arg).data_dir' "$ODD")"
assert_eq "main is false for a profile" "false" "$(json_get "$J" 'byName(arg).main' "$ODD")"
assert_eq "a fresh profile is signed out / new" "signed out / new" "$(json_get "$J" 'byName(arg).status' "$ODD")"
assert_eq "badge keeps a non-ASCII character" "é" "$(json_get "$J" 'byName(arg).badge' "$ODD")"
assert_eq "color is the hex value" "12A594" "$(json_get "$J" 'byName(arg).color' "$ODD")"
assert_eq "built_by is the version that built it" "${VERSION_LINE#aidentity }" \
  "$(json_get "$J" 'byName(arg).built_by' "$ODD")"
assert_eq "args lists the switches" '["--lang=de"]' "$(json_get "$J" 'byName(arg).args' "$ODD")"
assert_eq "env lists variable names" '["HTTPS_PROXY"]' "$(json_get "$J" 'byName(arg).env' "$ODD")"
assert_not_contains "and never their values" "$J" "secret.example"
assert_eq "own_extensions is false by default" "false" "$(json_get "$J" 'byName(arg).own_extensions' "$ODD")"
assert_eq "own_extensions is true when asked for" "true" "$(json_get "$J" 'byName("Codey Ext").own_extensions')"

assert_eq "a main launcher has no data_dir" "null" "$(json_get "$J" 'byName("Fake Main").data_dir')"
assert_eq "a main launcher is marked main" "true" "$(json_get "$J" 'byName("Fake Main").main')"
assert_eq "a main launcher that is not running says so" "not running" "$(json_get "$J" 'byName("Fake Main").status')"
assert_eq "a used profile is in use" "in use" "$(json_get "$J" 'byName("Fake Busy").status')"
assert_eq "no badge is null" "null" "$(json_get "$J" 'byName("Fake Busy").badge')"
assert_eq "a launcher whose app is gone says app missing" "app missing" "$(json_get "$J" 'byName("Gone Lost").status')"

PATH="$PGREP_STUB:$PATH" ai_stdout list --json
assert_eq "a running profile is running" "running" "$(json_get "$RUN_OUT" 'byName("Fake Busy").status')"
PATH="$PGREP_STUB:$PATH" ai list
BUSY_STATUS=$(printf '%s\n' "$RUN_OUT" | awk '/^Fake Busy$/ { f = 1; next } f && /status/ { print; exit }')
assert_contains "the plain list agrees" "$BUSY_STATUS" "running"
assert_contains "the plain list still says how to fix a missing app" "$RUN_OUT" \
  'app missing — run: aidentity rebuild "Gone Lost"'

# Warnings go to stderr, so stdout still parses when the running check fails.
FAIL_PGREP="$SANDBOX/stub-pgrep-fails"
mkdir -p "$FAIL_PGREP"
printf '#!/bin/sh\nexit 3\n' > "$FAIL_PGREP/pgrep"
chmod +x "$FAIL_PGREP/pgrep"
PATH="$FAIL_PGREP:$PATH" ai_stdout list --json
assert_eq "stdout parses even when a warning is printed" "5" "$(json_get "$RUN_OUT" 'd.length')"
assert_contains "the warning goes to stderr" "$RUN_ERR" "Could not check which profiles are running"

ai_tty '' list --json
assert_not_contains "no colour codes, even on a terminal" "$RUN_OUT" $'\033'
# A slow run outlasts ai_tty's input, and the terminal then echoes the end of
# input as "^D" and two backspaces into the output. That echo is the
# terminal's, not the script's, so it is removed before parsing.
assert_eq "and it still parses" "5" "$(json_get "${RUN_OUT//^D$'\b\b'/}" 'd.length')"

ai_stdout ls --json
assert_eq "ls --json works too" "5" "$(json_get "$RUN_OUT" 'd.length')"
ai list --jsn
assert_rc_nonzero "list refuses an option it does not know" "$RUN_RC" "$RUN_OUT"
assert_contains "and names it" "$RUN_OUT" "--jsn"
ai list extra
assert_rc_nonzero "list refuses an extra argument" "$RUN_RC" "$RUN_OUT"

for l in "$ODD" "Fake Busy" "Gone Lost"; do ai rm "$l" --purge -y; done
AIDENTITY_DATA_ROOT="$VSC_DATA" ai rm "Codey Ext" --purge -y
ai rm "Fake Main" -y
rm -rf "$ODD_APP" "$EXT_APP"
assert_eq "every launcher this group made is gone" "$JSON_LAUNCHERS_BEFORE" "$(count_launchers)"


group "aidentity ui"

# The menu is driven on a real pseudo-terminal, so these tests see what a person
# sees: the escape sequences it writes, and the terminal's settings before and
# after. The terminal's input stays open until the run is over (the wrapper
# below drops a marker file when it is), because `script` ends its input with
# a stray end-of-input byte the moment the pipe closes, which the menu would
# read as a quit. Every run types its own `q`, and a timer ends one that hangs.
#
# Nothing here waits for a fixed time. The run's output is also written to
# UI_LOG as it comes (through tee: script holds its own file back), and keys are
# typed when the menu has shown that it is ready for them. This suite is run on
# busy machines, where a fixed pause is too short sooner or later.
UI_DONE="$SANDBOX/ui-done"
UI_LOG="$SANDBOX/ui-log"
export UI_DONE UI_LOG
ESC=$'\033'
FRAME_HOME="${ESC}[1;1H"

# Wait until text $1 is in the output written after byte $2 (about 40 s at most).
ui_wait_log() { # text, [offset]
  local i=0
  while [ "$i" -lt 800 ]; do
    tail -c +$((${2:-0} + 1)) "$UI_LOG" 2>/dev/null | grep -q -F -- "$1" && return 0
    sleep 0.05; i=$((i + 1))
  done
  return 1
}

# Keys are printf %b text, typed once the menu has entered the alternate screen
# (UI_READY=none: after a short pause, for a run that never does). A ";" ends a
# chunk. A chunk that starts with <text> waits until the output after the
# previous chunk has shown that text; one that starts with + creates that file
# (a flag the stubs read) instead of typing; one that starts with ! runs that
# shell command instead (a launcher added from outside while the menu is open).
ui_feed() { # keys
  local chunks chunk want off=0
  if [ "${UI_READY:-?1049h}" = none ]; then sleep 0.4; else ui_wait_log "${UI_READY:-?1049h}"; fi
  if [ -n "$1" ]; then
    IFS=';' read -r -a chunks <<<"$1"
    for chunk in "${chunks[@]}"; do
      case "$chunk" in
        '<'*) want=${chunk#<}; want=${want%%>*}; chunk=${chunk#*>}; ui_wait_log "$want" "$off" ;;
      esac
      # The offset is taken before the chunk is typed, so an answer that comes
      # at once (a shell's prompt after Ctrl-Z) is still seen by the next wait.
      off=$(wc -c < "$UI_LOG" 2>/dev/null | tr -d ' ')
      case "$chunk" in
        '!'*) eval "${chunk#!}" ;;
        +*)   : > "${chunk#+}" ;;
        *)    printf '%b' "$chunk" ;;
      esac
    done
  fi
  # Hold the input open until the run is over; 900 x 0.1 s is a safety limit.
  off=0
  while [ ! -e "$UI_DONE" ] && [ "$off" -lt 900 ]; do sleep 0.1; off=$((off + 1)); done
}

# What runs on the terminal: the window size is set, then the terminal's
# settings are noted before and after the command, and the command's own exit
# status is returned. `trap : INT` keeps a Ctrl-C from ending this wrapper too.
UI_WRAP='
flags() { stty -a | tr " " "\n" | grep -E "^-?(echo|icanon|isig|icrnl|opost|onlcr)\$"; }
stty rows "$1" cols "$2"; shift 2
before=$(flags)
trap : INT
"$@"; rc=$?
after=$(flags)
if [ "$before" = "$after" ]; then f=same; else f=differ; fi
printf "\n__flags=%s\n" "$f"
: > "$UI_DONE"
exit "$rc"'

# Run a command on a terminal rows x cols in size, typing $3 at it. RUN_OUT is
# everything it wrote, RUN_RC its exit status, RUN_FLAGS "same" when the
# terminal's echo and line settings are back as they were.
ui_pty() { # rows, cols, keys, command…
  local rows="$1" cols="$2" keys="$3" f; shift 3
  rm -f "$UI_DONE"; : > "$UI_LOG"
  RUN_OUT=$( { ui_feed "$keys" \
      | HOME="$SANDBOX/tty-home" PATH="$STUB_BIN:$PATH" TERM="${UI_TERM:-xterm-256color}" \
        /usr/bin/perl -e 'alarm 90; exec @ARGV' script -q /dev/null /bin/sh -c "$UI_WRAP" ui "$rows" "$cols" "$@"
      echo "__rc=${PIPESTATUS[1]}"; } 2>&1 | tee "$UI_LOG" | tr -d '\r')
  RUN_RC=${RUN_OUT##*__rc=}
  RUN_OUT=${RUN_OUT%__rc=*}
  f=${RUN_OUT##*__flags=}
  RUN_FLAGS=${f%%$'\n'*}
  RUN_OUT=${RUN_OUT%__flags=*}
  return 0
}

ui_run_menu() { ui_pty "$1" "$2" "$3" "$BASH_BIN" "$AIDENTITY" ui; } # rows, cols, keys

# The last screen the menu drew: every frame starts at the top left.
ui_frame() { printf '%s' "${RUN_OUT##*"$FRAME_HOME"}"; }

# Whether any colour or style escape (SGR) is in RUN_OUT.
ui_has_sgr() { printf '%s' "$RUN_OUT" | perl -e 'local $/; exit((<STDIN> =~ /\e\[[0-9;]*m/) ? 0 : 1)'; }

assert_eq "no launcher is left from an earlier group" "0" "$(count_launchers)"
UI_BASE=$(count_launchers)

ai add "$ELECTRON_APP" --profile Alpha --color blue --badge A
ai add "$ELECTRON_APP" --profile Beta --color teal
ai add "$ELECTRON_APP" --main
assert_eq "three launchers to look at" "3" "$(count_launchers)"
ALPHA="$APPS/Fake Alpha.app"; BETA="$APPS/Fake Beta.app"; MAINL="$APPS/Fake Main.app"

# --- what it refuses, and what the plain command still does

ai ui
assert_rc_nonzero "ui refuses without a terminal" "$RUN_RC" "$RUN_OUT"
assert_contains "and says it needs one" "$RUN_OUT" "needs a terminal"
assert_not_contains "and writes no screen codes" "$RUN_OUT" "${ESC}[?1049h"

UI_READY=none ui_pty 24 80 '' "$BASH_BIN" -c '"$1" "$2" ui | cat; exit "${PIPESTATUS[0]}"' x "$BASH_BIN" "$AIDENTITY"
assert_rc_nonzero "ui refuses when only the input is a terminal" "$RUN_RC" "$RUN_OUT"
assert_contains "and says so" "$RUN_OUT" "needs a terminal"
assert_not_contains "and takes over no screen" "$RUN_OUT" "${ESC}[?1049h"

UI_READY=none ui_pty 24 80 '' "$BASH_BIN" -c '"$1" "$2" ui </dev/null; exit $?' x "$BASH_BIN" "$AIDENTITY"
assert_rc_nonzero "ui refuses when only the output is a terminal" "$RUN_RC" "$RUN_OUT"
assert_contains "and says so" "$RUN_OUT" "needs a terminal"
assert_not_contains "and takes over no screen" "$RUN_OUT" "${ESC}[?1049h"

UI_READY=none UI_TERM=dumb ui_run_menu 24 80 'q'
assert_rc_nonzero "ui refuses a terminal that cannot move the cursor" "$RUN_RC" "$RUN_OUT"
assert_contains "and names the TERM" "$RUN_OUT" "'dumb'"

ai ui extra
assert_rc_nonzero "ui takes no arguments" "$RUN_RC" "$RUN_OUT"
assert_contains "and names the one it was given" "$RUN_OUT" "extra"

ai help
assert_contains "help documents ui" "$RUN_OUT" "Full-screen menu"
assert_contains "help's examples show it" "$RUN_OUT" "aidentity ui"
ai
assert_contains "no arguments still print the help" "$RUN_OUT" "USAGE"

# --- it opens, and q leaves with the terminal as it was

ui_run_menu 24 80 'q'
assert_rc "q quits with status 0" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "the terminal's echo and line settings are back" "same" "$RUN_FLAGS"
assert_contains "it uses the alternate screen" "$RUN_OUT" "${ESC}[?1049h"
assert_contains "it says it is reading before the first screen is drawn" "${RUN_OUT%%"$FRAME_HOME"*}" "Reading the profiles"
assert_contains "it hides the cursor" "$RUN_OUT" "${ESC}[?25l"
LEAVING=${RUN_OUT##*"${ESC}[?1049h"}
assert_contains "it leaves the alternate screen" "$LEAVING" "${ESC}[?1049l"
assert_contains "it shows the cursor again" "$LEAVING" "${ESC}[?25h"
FRAME=$(ui_frame)
assert_contains "the header names the version" "$FRAME" "aidentity $(sed -n 's/^AIDENTITY_VERSION="\(.*\)"$/\1/p' "$AIDENTITY")"
assert_contains "and counts the profiles and what runs" "$FRAME" "3 profiles · 0 running"
assert_contains "a row for each launcher" "$FRAME" "Fake Alpha"
assert_contains "the badge is shown" "$FRAME" "[A]"
assert_contains "a main launcher says original" "$FRAME" "original"
assert_contains "a stopped profile has a hollow dot" "$FRAME" "○ Fake Beta"
assert_contains "the first row is selected" "$FRAME" "▸ ○ Fake Alpha"
assert_contains "a main launcher is not running" "$FRAME" "not running"
assert_contains "a profile with no data is new" "$FRAME" "signed out / new"
assert_contains "the footer lists the keys" "$FRAME" "q quit"
assert_contains "the footer lists the remove key" "$FRAME" "d remove"
assert_not_contains "no foreground colour under NO_COLOR" "$RUN_OUT" "${ESC}[38;5"
assert_not_contains "no background colour under NO_COLOR" "$RUN_OUT" "${ESC}[48;5"
if ui_has_sgr; then _fail "NO_COLOR output has no style escapes at all"; else _pass "NO_COLOR output has no style escapes at all"; fi

NO_COLOR='' ui_run_menu 24 80 'q'
assert_contains "with colour on, the badge is drawn in its colour" "$RUN_OUT" "${ESC}[48;5;69m"
assert_contains "the selected row is highlighted" "$RUN_OUT" "${ESC}[7m"
assert_eq "the terminal is restored with colour on too" "same" "$RUN_FLAGS"

# ai_tty gives the menu a terminal that reports no size (0 by 0): it falls back
# to 24 rows by 80 columns.
TERM=xterm-256color ai_tty 'q' ui
assert_rc "a terminal that reports no size still works" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "it lists the launchers" "$RUN_OUT" "Fake Alpha"
assert_contains "and draws 24 rows" "$RUN_OUT" "${ESC}[24;1H"

UI_FLAG="$SANDBOX/ui-running-flag"
UI_PGREP="$SANDBOX/ui-pgrep"
mkdir -p "$UI_PGREP"
printf '#!/bin/sh\nif [ -e "%s" ]; then printf "%%s\\n" "101 /x/Fake.app/Contents/MacOS/stub --user-data-dir=%s"; exit 0; fi\nexit 1\n' \
  "$UI_FLAG" "$DATA/fake-beta" > "$UI_PGREP/pgrep"
chmod +x "$UI_PGREP/pgrep"

touch "$UI_FLAG"
NO_COLOR='' PATH="$UI_PGREP:$PATH" ui_run_menu 24 80 'q'
assert_contains "a running profile has a green dot" "$RUN_OUT" "${ESC}[32m"
rm -f "$UI_FLAG"

# --- moving

ui_run_menu 24 80 '\033[B\033[Bq'
assert_contains "the arrow keys move down" "$(ui_frame)" "▸ ○ Fake Main"
ui_run_menu 24 80 'jq'
assert_contains "j moves down" "$(ui_frame)" "▸ ○ Fake Beta"
ui_run_menu 24 80 'jjkq'
assert_contains "k moves up" "$(ui_frame)" "▸ ○ Fake Beta"
ui_run_menu 24 80 'jjjjjjq'
assert_contains "it stops at the last row" "$(ui_frame)" "▸ ○ Fake Main"
ui_run_menu 24 80 'jj\033[Aq'
assert_contains "the up arrow moves up" "$(ui_frame)" "▸ ○ Fake Beta"
ui_run_menu 24 80 'kkq'
assert_contains "it stops at the first row" "$(ui_frame)" "▸ ○ Fake Alpha"
ui_run_menu 24 80 '\033[B\033'
assert_rc "Esc quits" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "and gives the terminal back" "same" "$RUN_FLAGS"
ui_run_menu 24 80 '\004'
assert_rc "Ctrl-D quits" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "and gives the terminal back too" "same" "$RUN_FLAGS"

# --- Enter opens the profile and shows the result in the footer

ui_run_menu 24 200 '\nq'
assert_rc "Enter then q exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "Enter opens the selected launcher" "$RUN_OUT" "stub open: $ALPHA"
assert_contains "and its message is in the footer" "$(ui_frame)" "Opening Fake Alpha"

# An `open` that fails is put ahead of the stub on the PATH inside the run.
UI_FAILOPEN="$SANDBOX/ui-failopen"
mkdir -p "$UI_FAILOPEN"
printf '#!/bin/sh\nexit 1\n' > "$UI_FAILOPEN/open"
chmod +x "$UI_FAILOPEN/open"
ui_pty 24 200 '\nq' /bin/sh -c 'PATH="$1:$PATH"; exec "$2" "$3" ui' x "$UI_FAILOPEN" "$BASH_BIN" "$AIDENTITY"
assert_rc "an open that fails leaves the menu running, and q quits it" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "the footer says what failed" "$(ui_frame)" "Could not open 'Fake Alpha'"
assert_not_contains "and does not claim it opened" "$(ui_frame)" "Opening Fake Alpha"
assert_eq "and the terminal is intact" "same" "$RUN_FLAGS"

# --- narrow windows, long lists

ui_run_menu 20 40 'q'
FRAME=$(ui_frame)
assert_contains "a narrow window still shows the version" "$FRAME" "aidentity "
assert_contains "and the counts, on a line of their own" "$FRAME" "3 profiles · 0 running"
assert_contains "and every launcher" "$FRAME" "Fake Beta"
assert_not_contains "but leaves out the badge column" "$FRAME" "[A]"
assert_contains "and keeps the main keys" "$FRAME" "q quit"
assert_not_contains "and leaves the rest to the help screen" "$FRAME" "d remove"

ui_run_menu 7 80 'q'
FRAME=$(ui_frame)
assert_contains "a short window shows the first rows" "$FRAME" "Fake Alpha"
assert_not_contains "and not the rest" "$FRAME" "Fake Main"
assert_contains "and says how many are out of view" "$FRAME" "1 more below"
ui_run_menu 7 80 'jjq'
FRAME=$(ui_frame)
assert_contains "scrolling brings the selected row into view" "$FRAME" "▸ ○ Fake Main"
assert_contains "and says what is above" "$FRAME" "1 more above"
assert_not_contains "and the first row has gone" "$FRAME" "Fake Alpha"

ui_run_menu 3 80 'q'
assert_rc "a window far too small still quits cleanly" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "and says it is too small" "$RUN_OUT" "too small"

ui_run_menu 24 80 '?aq'
assert_rc "the help screen returns to the menu" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "the help screen lists the keys" "$RUN_OUT" "this help"
assert_contains "and how to remove" "$RUN_OUT" "k keeps the data"

# --- rename

ui_run_menu 24 100 'rRenamed\n qq'
assert_rc "r renames through the prompt" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "the prompt leaves the menu screen" "$RUN_OUT" "New account name"
assert_contains "rename's own message is shown" "$RUN_OUT" "Renamed Fake Alpha to Fake Renamed"
assert_contains "then it waits for a key" "$RUN_OUT" "Press any key to return"
assert_dir "the launcher has the new name" "$APPS/Fake Renamed.app"
assert_no_dir "and the old one is gone" "$ALPHA"
assert_dir "the profile folder moved with it" "$DATA/fake-renamed"
assert_contains "the menu comes back with the new name selected" "$(ui_frame)" "▸ ○ Fake Renamed"
ai rename "Fake Renamed" Alpha

ui_run_menu 24 100 'r\nq'
assert_rc "an empty name cancels the rename" 0 "$RUN_RC" "$RUN_OUT"
assert_dir "and nothing changed" "$ALPHA"
assert_not_contains "and there is nothing to read, so no pause" "$RUN_OUT" "Press any key"

ui_run_menu 24 100 'rbad/name\nOk2\n qq'
assert_contains "a name that is not allowed is refused for its reason" "$RUN_OUT" "may only contain"
assert_dir "and the next try is used" "$APPS/Fake Ok2.app"
ai rename "Fake Ok2" Alpha

ui_run_menu 24 100 'r;<New account name>\003;<?1049h>q'
assert_rc "Ctrl-C at a prompt only cancels the prompt" 0 "$RUN_RC" "$RUN_OUT"
assert_dir "so nothing was renamed" "$ALPHA"
assert_eq "and the menu came back" "same" "$RUN_FLAGS"
ENTERED=${RUN_OUT//"${ESC}[?1049h"/$'\001'}; ENTERED=${ENTERED//[!$'\001']/}
assert_eq "it left the screen for the prompt and came back" "2" "${#ENTERED}"

# --- badge and colour

ui_run_menu 24 100 'bX\n qq'
assert_eq "b sets the badge" "X" "$(plist_key "$ALPHA" AIdentityBadge)"
assert_contains "through set's own message" "$RUN_OUT" "Updated Fake Alpha"
ui_run_menu 24 100 'b\nq'
assert_eq "an empty answer leaves the badge" "X" "$(plist_key "$ALPHA" AIdentityBadge)"

ui_run_menu 24 100 'c\033[C\n qq'
assert_eq "c, right, Enter picks the next colour (blue to green)" "2FB344" "$(plist_key "$ALPHA" AIdentityColor)"
ui_run_menu 24 100 'c\033[D\n qq'
assert_eq "left goes back" "2E7DF6" "$(plist_key "$ALPHA" AIdentityColor)"
ui_run_menu 24 100 'c\033[C\033q'
assert_rc "Esc cancels the picker and q quits" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "so the colour is unchanged" "2E7DF6" "$(plist_key "$ALPHA" AIdentityColor)"
assert_contains "the picker names the colour it shows" "$RUN_OUT" "Colour  < green >"
if ui_has_sgr; then _fail "the colour picker has no style escapes under NO_COLOR"; else _pass "the colour picker has no style escapes under NO_COLOR"; fi
ui_run_menu 24 100 'c'"$(printf '\\033[C%.0s' 1 2 3 4 5 6 7 8 9 10)"'\n qq'
assert_eq "the picker wraps around after ten colours" "2E7DF6" "$(plist_key "$ALPHA" AIdentityColor)"

# --- remove

ALPHA_FP=$(fingerprint "$ALPHA")
ui_run_menu 24 100 'dXq'
assert_eq "any other key after d cancels" "$ALPHA_FP" "$(fingerprint "$ALPHA")"
assert_contains "d asks what to remove" "$RUN_OUT" "k  keep the data"
if ui_has_sgr; then _fail "the remove question has no style escapes under NO_COLOR"; else _pass "the remove question has no style escapes under NO_COLOR"; fi
ui_run_menu 24 100 'jd\033kq'
assert_contains "a key typed right after Esc is kept: Esc cancels d, then k moves up" "$(ui_frame)" "▸ ○ Fake Alpha"

mkdir -p "$DATA/fake-beta"; printf 'session\n' > "$DATA/fake-beta/Cookies"
ui_run_menu 24 100 'jdk q'
assert_rc "d then k removes the launcher" 0 "$RUN_RC" "$RUN_OUT"
assert_no_dir "the launcher is gone" "$BETA"
assert_file "its data is kept" "$DATA/fake-beta/Cookies"
assert_contains "rm's own message is shown" "$RUN_OUT" "Removed launcher 'Fake Beta'"
assert_contains "and how to get it back" "$RUN_OUT" "aidentity restore"
assert_not_contains "the menu no longer lists it" "$(ui_frame)" "Fake Beta"
ai restore "Fake Beta"
assert_dir "the account comes back through restore" "$BETA"

ui_run_menu 24 100 'jdpno\n qq'
assert_dir "d then p asks for yes, and no keeps the launcher" "$BETA"
assert_file "and the data" "$DATA/fake-beta/Cookies"
assert_contains "it asks like rm does" "$RUN_OUT" "Type yes to confirm"

ui_run_menu 24 100 'jdpyes\n qq'
assert_no_dir "typing yes removes the launcher" "$BETA"
assert_no_dir "and deletes its data" "$DATA/fake-beta"
ai add "$ELECTRON_APP" --profile Beta --color teal
printf 'session\n' > "$DATA/fake-beta/Cookies"

touch "$UI_FLAG"
PATH="$UI_PGREP:$PATH" ui_run_menu 24 100 'jdk q'
assert_contains "a running profile is shown as running" "$RUN_OUT" "● Fake Beta"
assert_contains "and counted" "$RUN_OUT" "1 running"
assert_contains "d then k refuses it, as rm does" "$RUN_OUT" "running right now"
assert_dir "so the launcher stays" "$BETA"
assert_rc "and the menu is still there to quit from" 0 "$RUN_RC" "$RUN_OUT"
REFUSED_MENU=${RUN_OUT//"${ESC}[?1049h"/$'\001'}; REFUSED_MENU=${REFUSED_MENU//[!$'\001']/}
assert_eq "it left the screen for the refusal and came back" "2" "${#REFUSED_MENU}"
PATH="$UI_PGREP:$PATH" ui_run_menu 24 100 'jdp q'
assert_contains "d then p refuses it too" "$RUN_OUT" "running right now"
assert_not_contains "before asking for yes" "$RUN_OUT" "Type yes"
assert_rc "and the menu is still there to quit from" 0 "$RUN_RC" "$RUN_OUT"
assert_file "so the session survives" "$DATA/fake-beta/Cookies"
rm -f "$UI_FLAG"

DATA_BEFORE=$(snapshot "$DATA")
ui_run_menu 24 100 'jjdXq'
assert_contains "a main launcher offers only k" "$RUN_OUT" "remove the launcher only"
assert_not_contains "and not p" "$RUN_OUT" "delete the data too"
ui_run_menu 24 100 'jjdpq'
assert_dir "p on a main launcher removes nothing" "$MAINL"
assert_contains "and says the app's data is never deleted" "$(ui_frame)" "never deletes the app's data"
ui_run_menu 24 100 'jjdk q'
assert_no_dir "k removes the main launcher" "$MAINL"
assert_eq "no profile folder is touched" "$DATA_BEFORE" "$(snapshot "$DATA")"
ai add "$ELECTRON_APP" --main

# --- doctor, add

ui_run_menu 24 100 'xf q'
assert_rc "x shows the doctor's report" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "it is doctor's own report" "$RUN_OUT" "aidentity doctor"
assert_contains "and offers the repair" "$RUN_OUT" "Press f to repair"
assert_contains "f runs it again as doctor --fix, and waits for a key" "${RUN_OUT##*Press f to repair}" "Press any key to return"
assert_eq "and the terminal is intact" "same" "$RUN_FLAGS"

libcall list_compatible_apps
UI_IDX=$(printf '%s\n' "$RUN_OUT" | grep -n -x -F "$ELECTRON_APP" | cut -d: -f1)
assert_nonempty "the fake app is in the add list" "$UI_IDX"
ui_run_menu 24 100 "a${UI_IDX}\\nWizzy\\n q"
assert_rc "a runs the add walkthrough" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "it lists the apps the way add does" "$RUN_OUT" "Which app needs another account?"
assert_dir "and creates the launcher" "$APPS/Fake Wizzy.app"
assert_contains "the new launcher is selected" "$(ui_frame)" "▸ ○ Fake Wizzy"
ai rm "Fake Wizzy" --purge -y

# --- statuses refresh by themselves

rm -f "$UI_FLAG"
PATH="$UI_PGREP:$PATH" ui_run_menu 24 100 "<0 running>+$UI_FLAG;<1 running>q"
assert_contains "it starts with nothing running" "$RUN_OUT" "0 running"
assert_contains "a profile that starts shows up without a key press" "$RUN_OUT" "1 running"
rm -f "$UI_FLAG"

# A launcher made or removed while the menu is open shows up on the next
# refresh, and the selected row stays on the same launcher.
# shellcheck disable=SC2329,SC2317  # run by name from ui_feed (a ! chunk)
ui_outside_add() { ai add "$ELECTRON_APP" --profile Outside; }
# shellcheck disable=SC2329,SC2317  # run by name from ui_feed (a ! chunk)
ui_outside_rm() { ai rm "Fake Outside" --purge -y; }
ui_run_menu 24 100 '<3 profiles>!ui_outside_add;<4 profiles>j;!ui_outside_rm;<3 profiles>q'
assert_contains "a launcher added from outside is counted without a key press" "$RUN_OUT" "4 profiles · 0 running"
assert_contains "and listed" "$RUN_OUT" "Fake Outside"
assert_contains "the one removed from outside goes again" "$(ui_frame)" "3 profiles · 0 running"
assert_not_contains "and is no longer listed" "$(ui_frame)" "Fake Outside"
assert_contains "the selection stays on the launcher it was on" "$(ui_frame)" "▸ ○ Fake Beta"
assert_no_dir "nothing of it is left" "$APPS/Fake Outside.app"

# --- one look at the processes per refresh, and the same words as list

UI_COUNT_BIN="$SANDBOX/ui-count-bin"
UI_COUNT="$SANDBOX/ui-count"
mkdir -p "$UI_COUNT_BIN"
printf '#!/bin/sh\necho x >> "%s"\nprintf "%%s\\n" "101 /x/Fake.app/Contents/MacOS/stub --user-data-dir=%s"\nexit 0\n' \
  "$UI_COUNT" "$DATA/fake-beta" > "$UI_COUNT_BIN/pgrep"
chmod +x "$UI_COUNT_BIN/pgrep"
rm -f "$UI_COUNT"
RUN_OUT=$(PATH="$UI_COUNT_BIN:$PATH" "$BASH_BIN" -c '. "$1" >/dev/null 2>&1; ui_load; echo "N=$UI_N RUNNING=$UI_RUNNING"
  i=0; while [ "$i" -lt "$UI_N" ]; do echo "S $i ${UI_L_STATUS[$i]}"; i=$((i + 1)); done
  echo "CALLS=$(wc -l < "$2" | tr -d " ")"
  i=0; while [ "$i" -lt "$UI_N" ]; do
    echo "L $i $(launcher_status "${UI_L_APP[$i]}" "${UI_L_TARGET[$i]}" "${UI_L_DATA[$i]}")"; i=$((i + 1)); done' x "$LIB" "$UI_COUNT" 2>&1)
assert_contains "the menu counts what runs" "$RUN_OUT" "N=3 RUNNING=1"
assert_contains "pgrep was called once for three rows" "$RUN_OUT" "CALLS=1"
for i in 0 1 2; do
  assert_eq "row $i reads as list reads it" "$(printf '%s\n' "$RUN_OUT" | sed -n "s/^L $i //p")" "$(printf '%s\n' "$RUN_OUT" | sed -n "s/^S $i //p")"
done
assert_contains "the one with a process is running" "$RUN_OUT" "S 1 running"

# --- signals, and a crash: the terminal always comes back

# The menu runs in the background so a signal can be sent to it; <&0 keeps the
# terminal as its input. Each step waits for what the one before it caused.
UI_BG='
flags() { stty -a | tr " " "\n" | grep -E "^-?(echo|icanon|isig|icrnl|opost|onlcr)\$"; }
size() { wc -c < "$UI_LOG" | tr -d " "; }
waitfor() {
  i=0
  while [ "$i" -lt 800 ]; do
    tail -c +$(($2 + 1)) "$UI_LOG" 2>/dev/null | grep -q -F -- "$1" && return 0
    sleep 0.05; i=$((i + 1))
  done
  return 1
}
stty rows 20 cols 100
before=$(flags)
"$1" "$2" ui <&0 & p=$!
waitfor "?1049h" 0
case "$3" in
  WINCH) o=$(size); stty rows 12 cols 40 </dev/tty; waitfor "3 profiles" "$o"; kill -TERM $p ;;
  TSTP)  o=$(size); kill -TSTP $p; waitfor "?1049l" "$o"; o=$(size); kill -CONT $p; waitfor "?1049h" "$o"; kill -TERM $p ;;
  *)     kill -"$3" $p ;;
esac
wait $p; rc=$?
after=$(flags)
if [ "$before" = "$after" ]; then f=same; else f=differ; fi
printf "\n__flags=%s\n" "$f"
exit "$rc"'

ui_signal() { # signal
  ui_pty 20 100 '' /bin/sh -c "$UI_BG" ui "$BASH_BIN" "$AIDENTITY" "$1"
}

ui_signal TERM
assert_rc "SIGTERM ends the menu with 143" 143 "$RUN_RC" "$RUN_OUT"
assert_eq "and gives the terminal back" "same" "$RUN_FLAGS"
assert_contains "after leaving the alternate screen" "${RUN_OUT##*"${ESC}[?1049h"}" "${ESC}[?1049l"

ui_signal HUP
assert_rc "SIGHUP ends the menu with 129" 129 "$RUN_RC" "$RUN_OUT"
assert_eq "and gives the terminal back" "same" "$RUN_FLAGS"
assert_contains "after leaving the alternate screen" "${RUN_OUT##*"${ESC}[?1049h"}" "${ESC}[?1049l"

ui_run_menu 20 100 '\003'
assert_rc "Ctrl-C ends the menu with 130" 130 "$RUN_RC" "$RUN_OUT"
assert_eq "and gives the terminal back" "same" "$RUN_FLAGS"
assert_contains "after leaving the alternate screen" "${RUN_OUT##*"${ESC}[?1049h"}" "${ESC}[?1049l"

ui_signal WINCH
UI_AFTER_RESIZE=${RUN_OUT##*"${ESC}[2;1H "}
assert_contains "a resize redraws the menu at once, in the narrow layout" "$UI_AFTER_RESIZE" "3 profiles · 0 running"
assert_not_contains "without the badge column" "$UI_AFTER_RESIZE" "[A]"
assert_eq "and the terminal comes back" "same" "$RUN_FLAGS"

ui_signal TSTP
STOPS=${RUN_OUT//"${ESC}[?1049l"/$'\001'}; STOPS=${STOPS//[!$'\001']/}
assert_eq "Ctrl-Z leaves the screen, and fg takes it again, then it leaves once more" "2" "${#STOPS}"
assert_eq "and the terminal comes back" "same" "$RUN_FLAGS"

# Ctrl-Z typed at the terminal, the way a person does it. The menu is started
# from an interactive shell as a job, and Ctrl-Z goes to the whole job. (A
# kill -TSTP of one process, as above, cannot show what the shell sees: the
# questions are asked in subshells, and a stop that reaches only some of them
# leaves the others waiting for ever.) The shell's prompt is "JOB: ", and the
# job's command line contains UIJOB=1, which the shell prints again on fg.
export UI_JOB_BASH="$BASH_BIN" UI_JOB_SCRIPT="$AIDENTITY"
UI_JOB_CMD='UIJOB=1 "$UI_JOB_BASH" "$UI_JOB_SCRIPT" ui\n'
UI_JOB_RC="$SANDBOX/ui-job-rc"
printf "PS1='JOB: '\n" > "$UI_JOB_RC"
ui_job() { # keys, typed once the shell shows its prompt
  BASH_SILENCE_DEPRECATION_WARNING=1 HISTFILE=/dev/null UI_READY='JOB: ' \
    ui_pty 24 100 "$1" "$BASH_BIN" --noprofile --rcfile "$UI_JOB_RC" -i
}
# After fg the shell prints the job's line, then gives the job its terminal
# settings back, then continues it. Keys typed before that are lost. So wait
# until no process of the menu is stopped any more. (grep -c, not -q: an early
# exit would end the pipe under pipefail and read as "none stopped".)
# shellcheck disable=SC2329,SC2317  # run by name from ui_feed (a ! chunk)
ui_wait_continued() {
  local i=0 n
  while [ "$i" -lt 400 ]; do
    n=$(/bin/ps -axww -o stat=,command= | grep -a -F -- "$UI_JOB_SCRIPT ui" | grep -a -c '^T')
    [ "$n" -gt 0 ] || return 0
    sleep 0.05; i=$((i + 1))
  done
}

ui_job "$UI_JOB_CMD;<?1049h>b;<One character for the icon badge>\032;<JOB: >fg\n;<UIJOB=1>;!ui_wait_continued;Z\n;<Press any key to return> ;<?1049h>q;<JOB: >exit\n"
assert_rc "the shell runs the menu and ends" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "Ctrl-Z at the badge question stops the job, and the shell has its prompt back" "$RUN_OUT" "Stopped"
assert_eq "fg goes on with the question: the badge is set" "Z" "$(plist_key "$ALPHA" AIdentityBadge)"
assert_contains "and the command's own message is shown" "$RUN_OUT" "Updated Fake Alpha"
assert_eq "the terminal is as it was" "same" "$RUN_FLAGS"
ai set "Fake Alpha" --badge X

ui_job "$UI_JOB_CMD;<?1049h>r;<New account name>\032;<JOB: >fg\n;<UIJOB=1>;!ui_wait_continued;\n;<?1049h>q;<JOB: >exit\n"
assert_contains "Ctrl-Z at the rename question stops the job too" "$RUN_OUT" "Stopped"
assert_dir "and fg goes on: an empty answer cancels, nothing is renamed" "$ALPHA"
ENTERED=${RUN_OUT//"${ESC}[?1049h"/$'\001'}; ENTERED=${ENTERED//[!$'\001']/}
assert_eq "and the menu came back" "2" "${#ENTERED}"

# Ctrl-Z while a command's own output is on screen, then Ctrl-Z in the menu:
# the menu must still hand the screen back afterwards.
ui_job "$UI_JOB_CMD;<?1049h>bW\n;<Press any key to return>\032;<JOB: >fg\n;<UIJOB=1>;!ui_wait_continued; ;<?1049h>\032;<JOB: >fg\n;<?1049h>q;<JOB: >exit\n"
STOPS=${RUN_OUT//Stopped/$'\001'}; STOPS=${STOPS//[!$'\001']/}
assert_eq "Ctrl-Z at the pause and again in the menu stop the job twice" "2" "${#STOPS}"
LAST_STOP=${RUN_OUT%Stopped*}
assert_contains "the second stop gave the screen back first" "${LAST_STOP##*"${ESC}[?1049h"}" "${ESC}[?1049l"
assert_eq "the terminal is as it was" "same" "$RUN_FLAGS"
ai set "Fake Alpha" --badge X

# Enter opens a profile, which takes a moment in subshells over the menu. A
# Ctrl-Z typed in that moment waits in the input and stops the menu as soon as
# the open is done. (A stop signal sent to those subshells would stop them
# alone, and the menu would wait for them for ever.)
UI_SLOW="$SANDBOX/ui-slowopen"; UI_OPENING="$SANDBOX/ui-opening"
export UI_SLOW UI_OPENING
mkdir -p "$UI_SLOW"
printf '#!/bin/sh\n: > "$UI_OPENING"\nsleep 2\nexit 0\n' > "$UI_SLOW/open"
chmod +x "$UI_SLOW/open"
# shellcheck disable=SC2329,SC2317  # run by name from ui_feed (a ! chunk)
ui_wait_opening() { local i=0; while [ ! -e "$UI_OPENING" ] && [ "$i" -lt 400 ]; do sleep 0.05; i=$((i + 1)); done; }
rm -f "$UI_OPENING"
ui_job 'UIJOB=1 PATH="$UI_SLOW:$PATH" "$UI_JOB_BASH" "$UI_JOB_SCRIPT" ui\n;<?1049h>\n;!ui_wait_opening;\032;<JOB: >fg\n;<?1049h>q;<JOB: >exit\n'
assert_rc "Ctrl-Z while a profile opens does not freeze the menu" 0 "$RUN_RC" "$RUN_OUT"
STOPS=${RUN_OUT//Stopped/$'\001'}; STOPS=${STOPS//[!$'\001']/}
assert_eq "it stops the job once the open is done" "1" "${#STOPS}"
LAST_STOP=${RUN_OUT%Stopped*}
assert_contains "the open finished and said so first" "$LAST_STOP" "Opening Fake Alpha"
assert_contains "then the screen was given back" "${LAST_STOP##*"${ESC}[?1049h"}" "${ESC}[?1049l"
assert_eq "the terminal is as it was" "same" "$RUN_FLAGS"

# A failure inside the menu, not a signal: the exit trap gives the terminal back.
ui_pty 20 100 '' "$BASH_BIN" -c '. "$1"; ui_draw() { : "${UI_TEST_UNSET:?boom}"; }; cmd_ui' x "$LIB"
assert_rc_nonzero "a crash exits non-zero" "$RUN_RC" "$RUN_OUT"
assert_eq "and still gives the terminal back" "same" "$RUN_FLAGS"
assert_contains "after leaving the alternate screen" "${RUN_OUT##*"${ESC}[?1049h"}" "${ESC}[?1049l"

# --- cleanup

ai rm "Fake Alpha" --purge -y
ai rm "Fake Beta" --purge -y
ai rm "Fake Main" -y
assert_eq "every launcher this group made is gone" "$UI_BASE" "$(count_launchers)"


group "the generated launcher: sign-in guard and a clean environment"

# The launcher is run here with pgrep, osascript and open swapped for stubs,
# so nothing real is launched and no dialog is shown.
GUARD_STUB="$SANDBOX/stub-guard"
mkdir -p "$GUARD_STUB"
printf '#!/bin/sh\nexit "${STUB_PGREP:-0}"\n' > "$GUARD_STUB/pgrep"
printf '#!/bin/sh\necho "${STUB_ANSWER:-open}"\n' > "$GUARD_STUB/osascript"
printf '#!/bin/sh\n{ echo "ARGS $*"; env; } > "%s/opened"\n' "$SANDBOX" > "$GUARD_STUB/open"
chmod +x "$GUARD_STUB/pgrep" "$GUARD_STUB/osascript" "$GUARD_STUB/open"
ai add "$ELECTRON_APP" --profile Guard
G_DATA="$DATA/fake-guard"
sed -e "s|/usr/bin/pgrep|$GUARD_STUB/pgrep|; s|/usr/bin/osascript|$GUARD_STUB/osascript|; s|/usr/bin/open|$GUARD_STUB/open|" \
  "$APPS/Fake Guard.app/Contents/MacOS/launcher" > "$SANDBOX/guard-launcher.sh"
run_guard() { rm -f "$SANDBOX/opened"; env "$@" /bin/sh "$SANDBOX/guard-launcher.sh"; }

run_guard STUB_ANSWER=cancel
assert_no_file "Cancel in the first-open dialog opens nothing" "$SANDBOX/opened"
run_guard STUB_ANSWER=open
assert_file "Open Anyway opens the profile" "$SANDBOX/opened"
run_guard STUB_PGREP=1 STUB_ANSWER=cancel
assert_file "with no other copy running there is no dialog" "$SANDBOX/opened"
printf '{}' > "$G_DATA/Local State"
run_guard STUB_ANSWER=cancel
assert_file "a profile that was opened before has no dialog" "$SANDBOX/opened"
run_guard "AA_BYTES=$(printf 'caf\351')" LC_ALL=en_US.UTF-8 \
  NODE_OPTIONS=--require=/x VSCODE_PID=1 ELECTRON_RUN_AS_NODE=1 LANG=de_DE.UTF-8
OPENED=$(cat "$SANDBOX/opened")
assert_not_contains "NODE_OPTIONS never reaches the app, even beside a value that is not UTF-8" "$OPENED" "NODE_OPTIONS="
assert_not_contains "VSCODE_* from the caller never reaches the app" "$OPENED" "VSCODE_PID="
assert_not_contains "ELECTRON_* from the caller never reaches the app" "$OPENED" "ELECTRON_RUN_AS_NODE="
assert_contains "ordinary variables still do" "$OPENED" "LANG=de_DE.UTF-8"
assert_contains "and the profile directory is passed" "$OPENED" "--user-data-dir=$G_DATA"
ai rm "Fake Guard" --purge -y


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


group "release notes, from the changelog"

# scripts/release-notes.sh builds the text of a GitHub release: an install
# header, then the version's CHANGELOG section. stdout and stderr stay apart,
# because the release workflow writes stdout into the release.
RELNOTES="$REPO_DIR/scripts/release-notes.sh"
relnotes() { # version, optional changelog path
  RUN_OUT=$(detached "$BASH_BIN" "$RELNOTES" "$@" 2>"$SANDBOX/stderr" </dev/null)
  RUN_RC=$?
  RUN_ERR=$(cat "$SANDBOX/stderr")
  return 0
}

# The 1.3.0 section, cut from the real changelog a different way (sed between
# the two headings, blank edges trimmed). The release is old, so it is frozen.
want_130=$(sed -n '/^## \[1\.3\.0\]/,/^## \[1\.2\.0\]/p' "$REPO_DIR/CHANGELOG.md" | sed '1d;$d' | sed '/./,$!d')
relnotes 1.3.0
assert_rc "the 1.3.0 notes are produced" 0 "$RUN_RC" "$RUN_ERR"
assert_eq "nothing goes to stderr on success" "" "$RUN_ERR"
want_lines=$(printf '%s\n' "$want_130" | wc -l | tr -d ' ')
assert_eq "the 1.3.0 section is extracted exactly, to its last line" "$want_130" \
  "$(printf '%s\n' "$RUN_OUT" | tail -n "$want_lines")"
assert_eq "it starts with the section's first line, after a blank line" "" \
  "$(printf '%s\n' "$RUN_OUT" | tail -n "$((want_lines + 1))" | head -n 1)"
assert_contains "the header has the install line for this tag" "$RUN_OUT" \
  "curl -fsSL https://raw.githubusercontent.com/PiniShv/aidentity/v1.3.0/install.sh | bash"
assert_contains "and the Homebrew line" "$RUN_OUT" "brew install pinishv/tap/aidentity"
# GitHub lists its own "Source code" archives under the notes. They are not
# signed, so the header must name the four files that are, not say "each file".
assert_contains "the header names the four signed files" "$RUN_OUT" \
  '`aidentity`, `install.sh`, `uninstall.sh` and `SHA256SUMS`, have signed build provenance'
assert_contains "and says the Source code archives are not signed" "$RUN_OUT" \
  'The "Source code" archives that GitHub adds to every release are not signed.'
assert_not_contains "it does not claim every file on the page is signed" "$RUN_OUT" "Each file below"
assert_eq "the header comes first" "**Install or upgrade**" "$(printf '%s\n' "$RUN_OUT" | head -n 1)"
assert_not_contains "the heading line is left out" "$RUN_OUT" "## [1.3.0]"
assert_not_contains "the next version's section is not included" "$RUN_OUT" "## [1.2.0]"
assert_not_contains "nor is its text" "$RUN_OUT" "aidentity add APP --main"
assert_not_contains "the link list at the bottom is not included" "$RUN_OUT" "[1.3.0]: https://"

# A tiny changelog for the edges: the first, last and empty sections, a blank
# line inside a section, and a version that only starts the same.
CL_FIX="$SB/fixture-changelog.md"
cat > "$CL_FIX" <<'CL'
# Changelog

## [Unreleased]

## [2.0.0] - 2030-01-02


### Added

- First.

  Still the first.

### Fixed

- Second.


## [1.5.0] - 2029-06-01

## [1.0.0] - 2028-01-01

Only text, then the link list.

[Unreleased]: https://example.invalid/compare/v2.0.0...HEAD
[2.0.0]: https://example.invalid/compare/v1.0.0...v2.0.0
[1.0.0]: https://example.invalid/releases/tag/v1.0.0
CL
relnotes 2.0.0 "$CL_FIX"
want_fix=$(printf '### Added\n\n- First.\n\n  Still the first.\n\n### Fixed\n\n- Second.')
assert_eq "a section keeps its inner blank lines and loses the ones at its edges" "$want_fix" \
  "$(printf '%s\n' "$RUN_OUT" | tail -n 9)"
assert_not_contains "and stops at the next heading" "$RUN_OUT" "1.5.0"
relnotes 1.0.0 "$CL_FIX"
assert_eq "the last section ends where the link list starts" "Only text, then the link list." \
  "$(printf '%s\n' "$RUN_OUT" | tail -n 1)"
assert_not_contains "no link line from the bottom is included" "$RUN_OUT" "example.invalid"
relnotes 1.5.0 "$CL_FIX"
assert_rc "a section with nothing in it is an error" 1 "$RUN_RC" "$RUN_OUT"
assert_contains "that says which version" "$RUN_ERR" "No notes for 1.5.0"
assert_eq "and prints no notes" "" "$RUN_OUT"
relnotes 2.0 "$CL_FIX"
assert_rc "a version that is not x.y.z is refused" 2 "$RUN_RC" "$RUN_ERR"

# An unknown version must fail, so a release is never published with blank notes.
relnotes 9.9.9
assert_rc "an unknown version fails" 1 "$RUN_RC" "$RUN_OUT"
assert_contains "and names the version" "$RUN_ERR" "No notes for 9.9.9"
assert_eq "and prints nothing on stdout" "" "$RUN_OUT"
relnotes 1.3
assert_rc "x.y is not a version" 2 "$RUN_RC" "$RUN_ERR"
relnotes v1.3.0
assert_rc "a leading v is refused" 2 "$RUN_RC" "$RUN_ERR"
assert_contains "with the usage line" "$RUN_ERR" "Usage: scripts/release-notes.sh x.y.z"
relnotes "1.3.0; touch $SB/pwned"
assert_rc "text after a version is refused" 2 "$RUN_RC" "$RUN_ERR"
assert_no_file "and runs nothing it was handed" "$SB/pwned"
relnotes ""
assert_rc "no version is refused" 2 "$RUN_RC" "$RUN_ERR"
relnotes 1.3.0 "$SB/no-such-changelog.md"
assert_rc "a changelog that cannot be read is an error" 1 "$RUN_RC" "$RUN_ERR"
assert_contains "that names the file" "$RUN_ERR" "no-such-changelog.md"

# The release workflow calls this with the version in bin/aidentity. If a
# release is prepared without a changelog section, the tag run would fail.
cur_version=$(sed -n 's/^AIDENTITY_VERSION="\(.*\)"$/\1/p' "$AIDENTITY")
relnotes "$cur_version"
assert_rc "the changelog has notes for the version in the script ($cur_version)" 0 "$RUN_RC" "$RUN_ERR"


group "release check, before anything is signed"

# scripts/release-check.sh is the release workflow's first step. It runs on a
# copy of the tree, from another directory, so it is also shown to find the
# repository by its own path. The copy is made release-ready first: install.sh
# pointing at this version's tag, as `make release` leaves it.
RC_DIR="$SB/release-check-repo"
rc_version=$(sed -n 's/^AIDENTITY_VERSION="\(.*\)"$/\1/p' "$REPO_DIR/bin/aidentity")
rc_fresh() {
  rm -rf "$RC_DIR"
  mkdir -p "$RC_DIR/bin" "$RC_DIR/scripts" "$RC_DIR/test"
  cp "$REPO_DIR/bin/aidentity" "$RC_DIR/bin/"
  cp "$REPO_DIR/uninstall.sh" "$REPO_DIR/SHA256SUMS" "$REPO_DIR/CHANGELOG.md" "$RC_DIR/"
  cp "$REPO_DIR/scripts/"*.sh "$RC_DIR/scripts/"
  cp "$REPO_DIR/test/run_tests.sh" "$RC_DIR/test/"
  sed "s|^REF=.*|REF=\"\${AIDENTITY_REF:-v$rc_version}\"|" "$REPO_DIR/install.sh" > "$RC_DIR/install.sh"
}
rc_sed() { # file, sed script: edit one file of the copy
  sed "$2" "$RC_DIR/$1" > "$RC_DIR/$1.new" && mv "$RC_DIR/$1.new" "$RC_DIR/$1"
}
rc_run() { # tag
  RUN_OUT=$(cd "$SB" && detached "$BASH_BIN" "$RC_DIR/scripts/release-check.sh" "$@" 2>"$SANDBOX/stderr" </dev/null)
  RUN_RC=$?
  RUN_ERR=$(cat "$SANDBOX/stderr")
  return 0
}
rc_tree() { (cd "$RC_DIR" && find . -type f -exec shasum {} + | sort); }

rc_fresh
rc_before=$(rc_tree)
rc_run "v$rc_version"
assert_rc "a release-ready tree passes with its own tag (v$rc_version)" 0 "$RUN_RC" "$RUN_OUT$RUN_ERR"
assert_contains "and says so" "$RUN_OUT" "Tag v$rc_version matches version $rc_version."
assert_contains "after the source guards ran" "$RUN_OUT" "SHA256SUMS matches bin/aidentity"
assert_eq "nothing goes to stderr on success" "" "$RUN_ERR"
assert_eq "it changes no file" "$rc_before" "$(rc_tree)"

rc_run
assert_rc "no tag is a usage error" 2 "$RUN_RC" "$RUN_OUT$RUN_ERR"
assert_contains "that shows the usage" "$RUN_ERR" "Usage: scripts/release-check.sh vX.Y.Z"

# The tag must be v + the script's version. A pushed tag that is not (a tag on
# the wrong commit, a pre-release name, a missing v) is not released.
for bad_tag in v9.9.9 "$rc_version" "v$rc_version-rc1" "V$rc_version" "v$rc_version.0"; do
  rc_run "$bad_tag"
  assert_rc "tag '$bad_tag' is refused" 1 "$RUN_RC" "$RUN_OUT$RUN_ERR"
  assert_contains "with both versions named" "$RUN_ERR" "The tag is $bad_tag but bin/aidentity is version $rc_version"
done

# SHA256SUMS: stale, in shasum's binary-mode spelling, and missing.
rc_fresh
printf '%064d  bin/aidentity\n' 0 > "$RC_DIR/SHA256SUMS"
rc_run "v$rc_version"
assert_rc "stale sums are refused" 1 "$RUN_RC" "$RUN_OUT$RUN_ERR"
assert_contains "with the reason" "$RUN_ERR" "SHA256SUMS does not match bin/aidentity"
assert_contains "and the fix" "$RUN_ERR" "make checksums"
(cd "$RC_DIR" && shasum -a 256 -b bin/aidentity) > "$RC_DIR/SHA256SUMS"
assert_contains "(the sums line really is '*bin/aidentity')" "$(cat "$RC_DIR/SHA256SUMS")" " *bin/aidentity"
rc_run "v$rc_version"
assert_rc "a '*bin/aidentity' sums line is refused, as the installer would not read it" 1 "$RUN_RC" "$RUN_OUT$RUN_ERR"
assert_contains "as having no usable line" "$RUN_ERR" "expected nothing"
rm -f "$RC_DIR/SHA256SUMS"
rc_run "v$rc_version"
assert_rc "a missing SHA256SUMS is refused" 1 "$RUN_RC" "$RUN_OUT$RUN_ERR"

# A version that is not x.y.z is refused before it is compared or printed.
for odd in 1.4 1.4.0-rc1 1.2.3.4 1..0 .1.0 1.0. ""; do
  rc_fresh
  rc_sed bin/aidentity "s/^AIDENTITY_VERSION=.*/AIDENTITY_VERSION=\"$odd\"/"
  rc_run "v$odd"
  assert_rc "version '$odd' is refused" 1 "$RUN_RC" "$RUN_OUT$RUN_ERR"
  assert_contains "as not a version" "$RUN_ERR" "Could not read a version (x.y.z)"
done
rc_fresh
rc_sed bin/aidentity '/^AIDENTITY_VERSION=/d'
rc_run "v$rc_version"
assert_rc "a script with no version line is refused" 1 "$RUN_RC" "$RUN_OUT$RUN_ERR"
rc_fresh
rc_sed bin/aidentity 's|^AIDENTITY_VERSION=.*|AIDENTITY_VERSION="1.0.0$(touch pwned)"|'
rc_run 'v1.0.0$(touch pwned)'
assert_rc "a version with a command in it is refused" 1 "$RUN_RC" "$RUN_OUT$RUN_ERR"
assert_no_file "and the command never runs" "$RC_DIR/pwned"
assert_no_file "wherever it would have landed" "$SB/pwned"

# install.sh must install this tag. scripts/guards.sh accepts main there, so
# without this check a hand-made release would ship an installer for main.
rc_fresh
rc_sed install.sh 's|^REF=.*|REF="${AIDENTITY_REF:-main}"|'
rc_run "v$rc_version"
assert_rc "an installer that installs main is refused" 1 "$RUN_RC" "$RUN_OUT$RUN_ERR"
assert_contains "with what it installs" "$RUN_ERR" "installs 'main' by default"
assert_contains "and what it must install" "$RUN_ERR" "must install v$rc_version"
rc_fresh
rc_sed install.sh 's|^REF=.*|REF="${AIDENTITY_REF:-v0.0.1}"|'
rc_run "v$rc_version"
assert_rc "an installer for another tag is refused" 1 "$RUN_RC" "$RUN_OUT$RUN_ERR"
rc_fresh
rc_sed install.sh '/^REF=/d'
rc_run "v$rc_version"
assert_rc "an installer with no REF line is refused" 1 "$RUN_RC" "$RUN_OUT$RUN_ERR"
assert_contains "that says there is none" "$RUN_ERR" "installs 'nothing' by default"

# The changelog must have notes for the version.
rc_fresh
rc_sed CHANGELOG.md "s/^## \[$rc_version\]/## [0.0.1]/"
rc_run "v$rc_version"
assert_rc "a changelog without the version is refused" 1 "$RUN_RC" "$RUN_OUT$RUN_ERR"
assert_contains "naming the version" "$RUN_ERR" "No notes for $rc_version"
assert_contains "and the release" "$RUN_ERR" "has no notes for $rc_version"
assert_not_contains "and it does not say the tag matches" "$RUN_OUT" "matches version"

# The source guards run too, and their failure stops the release.
rc_fresh
rc_sed uninstall.sh 's/^running_on_profile() {/running_on_profile() { :;/'
rc_run "v$rc_version"
assert_rc "a failing source guard is refused" 1 "$RUN_RC" "$RUN_OUT$RUN_ERR"
assert_contains "with the guard's own message" "$RUN_ERR" "running_on_profile differs between bin/aidentity and uninstall.sh"
assert_contains "and the release check's" "$RUN_ERR" "scripts/guards.sh failed"
assert_not_contains "and it does not say the tag matches" "$RUN_OUT" "matches version"


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


group "help for one command"

# Every name main() takes, each with the command it stands for.
HELP_PAIRS="setup:setup init:setup wizard:setup add:add rename:rename mv:rename
set:set modify:set edit:set prune:prune restore:restore rebuild:rebuild
repair:rebuild list:list ls:list open:open rm:rm remove:rm delete:rm apps:apps
doctor:doctor update:update ui:ui completion:completion version:version --version:version -v:version
help:help"
for pair in $HELP_PAIRS; do
  w=${pair%%:*}; c=${pair#*:}
  ai "$w" --help
  assert_rc "$w --help exits 0" 0 "$RUN_RC" "$RUN_OUT"
  assert_contains "$w --help names its command" "$RUN_OUT" "aidentity $c"
  assert_contains "$w --help has a usage section" "$RUN_OUT" "USAGE"
  assert_contains "$w --help has an example" "$RUN_OUT" "EXAMPLES"
  HELP_LONG="$RUN_OUT"
  ai "$w" -h
  assert_eq "$w -h prints the same as $w --help" "$HELP_LONG" "$RUN_OUT"
  ai help "$w"
  assert_eq "help $w prints the same as $w --help" "$HELP_LONG" "$RUN_OUT"
done

# Every alias is named in the help of the command it stands for.
for pair in $HELP_PAIRS; do
  w=${pair%%:*}; c=${pair#*:}
  [ "$w" = "$c" ] && continue
  ai "$c" --help
  assert_contains "help for $c mentions its alias $w" "$RUN_OUT" "$w"
done

# Every option the completion offers is in that command's help, so the two
# cannot drift apart unseen.
for c in add set list rm prune restore rebuild doctor update; do
  libcall command_options "$c"
  OPTS_OF_C="$RUN_OUT"
  assert_nonempty "$c has options for completion" "$OPTS_OF_C"
  ai "$c" --help
  for o in $OPTS_OF_C; do
    assert_contains "help for $c documents $o" "$RUN_OUT" "$o"
  done
done

ai help
HELP_ALL="$RUN_OUT"
assert_rc "help exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "the overview points to per-command help" "$HELP_ALL" "aidentity help <command>"
assert_contains "the overview lists completion" "$HELP_ALL" "completion SHELL"
ai
assert_eq "no arguments print the overview, as before" "$HELP_ALL" "$RUN_OUT"
ai --help
assert_eq "--help prints the overview" "$HELP_ALL" "$RUN_OUT"
ai -h rm
assert_rc "-h before a command is still the overview" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "and ignores what follows, as before" "$HELP_ALL" "$RUN_OUT"
ai help help
assert_contains "the help for help says -h on its own shows the overview" "$RUN_OUT" "aidentity -h and aidentity --help show the same overview"
assert_contains "and that what follows it is ignored" "$RUN_OUT" "ignore what comes after them"

ai_stdout help definitely-not-a-command
assert_rc_nonzero "help for an unknown command fails" "$RUN_RC" "$RUN_OUT"
assert_eq "and prints nothing on stdout" "" "$RUN_OUT"
assert_contains "and says which name has no help" "$RUN_ERR" "definitely-not-a-command"
ai help --bogus
assert_rc_nonzero "help for an unknown option fails" "$RUN_RC" "$RUN_OUT"
ai help __complete
assert_rc_nonzero "the hidden command has no help" "$RUN_RC" "$RUN_OUT"
ai help rm add
assert_rc_nonzero "help takes one command" "$RUN_RC" "$RUN_OUT"
ai definitely-not-a-command --help
assert_rc_nonzero "an unknown command with --help still fails" "$RUN_RC" "$RUN_OUT"

group "--help never runs the command"

# A launcher and two folders (one stray, one with a restore record) for
# the commands to act on if --help ever failed to stop them.
ai add "$ELECTRON_APP" --profile Safe
ai add "$ELECTRON_APP" --profile Gone
ai rm "Fake Gone" -y
STRAY_DIR="$DATA/stray-profile"
mkdir -p "$STRAY_DIR"
printf 'session\n' > "$STRAY_DIR/Cookies"
printf 'session\n' > "$DATA/fake-safe/Cookies"
assert_dir "the launcher to protect exists" "$APPS/Fake Safe.app"
assert_no_dir "the removed launcher is gone" "$APPS/Fake Gone.app"

tree_state() { # directory: names and contents of everything below it
  fingerprint "$1"
  ( cd "$1" && find . -type f -exec shasum {} + 2>/dev/null | LC_ALL=C sort | shasum | awk '{print $1}' )
}

no_action() { # description, then the command line
  local desc="$1" before after; shift
  before="$(tree_state "$APPS")|$(tree_state "$DATA")"
  PATH="$STUB_BIN:$PATH" ai "$@"
  after="$(tree_state "$APPS")|$(tree_state "$DATA")"
  assert_rc "$desc exits 0" 0 "$RUN_RC" "$RUN_OUT"
  assert_contains "$desc shows the help" "$RUN_OUT" "USAGE"
  assert_not_contains "$desc opens nothing" "$RUN_OUT" "stub open"
  assert_eq "$desc changes nothing" "$before" "$after"
}

no_action "rm NAME --help" rm "Fake Safe" --help
no_action "rm --help first, with --purge and -y" rm --help "Fake Safe" --purge -y
no_action "rm NAME --purge --yes -h" rm "Fake Safe" --purge --yes -h
no_action "remove NAME --purge -y --help" remove "Fake Safe" --purge -y --help
no_action "delete NAME --help" delete "Fake Safe" --help
no_action "add APP --profile NAME --help" add "$ELECTRON_APP" --profile Other --help
no_action "add with --help where a value goes" add "$ELECTRON_APP" --profile --help
no_action "add --main --help" add "$ELECTRON_APP" --main --help
no_action "rename OLD NEW --help" rename "Fake Safe" Renamed --help
no_action "mv OLD NEW -h" mv "Fake Safe" Renamed -h
no_action "set NAME --color red -h" set "Fake Safe" --color red -h
no_action "set NAME --clear-args --help" set "Fake Safe" --clear-args --help
no_action "rebuild --all --help" rebuild --all --help
no_action "rebuild NAME --help" rebuild "Fake Safe" --help
no_action "prune --yes --help" prune --yes --help
no_action "restore --all --help" restore --all --help
no_action "restore NAME --help" restore "Fake Gone" --help
no_action "doctor --fix --help" doctor --fix --help
no_action "open NAME --help" open "Fake Safe" --help
no_action "list --json --help" list --json --help
no_action "setup --help" setup --help
no_action "apps --help" apps --help
no_action "completion bash --help" completion bash --help

ai completion bash --help
assert_not_contains "completion bash --help prints help, not the script" "$RUN_OUT" "complete -F"

assert_dir "the launcher is still there" "$APPS/Fake Safe.app"
assert_file "its data is still there" "$DATA/fake-safe/Cookies"
assert_file "the stray folder is still there" "$STRAY_DIR/Cookies"
assert_no_dir "restore did not rebuild the removed launcher" "$APPS/Fake Gone.app"
assert_no_dir "nothing was created by add --help" "$APPS/Fake Other.app"
assert_no_dir "nothing was renamed" "$APPS/Fake Renamed.app"
ai rm "Fake Safe" --purge -y
rm -rf "$STRAY_DIR" "$DATA/fake-gone"

group "shell completion scripts"

for sh in bash zsh fish; do
  ai_stdout completion "$sh"
  assert_rc "completion $sh exits 0" 0 "$RUN_RC" "$RUN_ERR"
  assert_nonempty "completion $sh prints a script" "$RUN_OUT"
  assert_eq "completion $sh prints nothing on stderr" "" "$RUN_ERR"
  assert_contains "completion $sh asks aidentity for names" "$RUN_OUT" "aidentity __complete"
  printf '%s\n' "$RUN_OUT" > "$SANDBOX/completion.$sh"
  for w in setup init wizard add rename mv set modify edit prune restore rebuild \
           repair list ls open rm remove delete apps doctor completion version help; do
    case "$RUN_OUT" in
      *"$w"*) ;;
      *) _fail "completion $sh knows the command $w" "no $w in the script" ;;
    esac
  done
  for o in --purge --json --own-extensions --shared-extensions --clear-args --fix --all; do
    case "$RUN_OUT" in
      *"${o#--}"*) ;;
      *) _fail "completion $sh knows the option $o" "no ${o#--} in the script" ;;
    esac
  done
  assert_contains "completion $sh offers colour names" "$RUN_OUT" "graphite"
done

if "$BASH_BIN" -n "$SANDBOX/completion.bash" 2>/dev/null; then
  _pass "the bash script is valid bash"
else
  _fail "the bash script is valid bash" "$("$BASH_BIN" -n "$SANDBOX/completion.bash" 2>&1)"
fi
if command -v bash >/dev/null 2>&1 && bash -n "$SANDBOX/completion.bash" 2>/dev/null; then
  _pass "and valid for the first bash on PATH"
else
  _fail "and valid for the first bash on PATH" "bash -n failed"
fi

ZSH_BIN=$(command -v zsh 2>/dev/null || true)
if [ -n "$ZSH_BIN" ]; then
  if "$ZSH_BIN" -n "$SANDBOX/completion.zsh" 2>/dev/null; then
    _pass "the zsh script is valid zsh"
  else
    _fail "the zsh script is valid zsh" "$("$ZSH_BIN" -n "$SANDBOX/completion.zsh" 2>&1)"
  fi
  # Loaded the way the README says, it registers itself for aidentity.
  ZSH_REG=$(HOME="$SANDBOX/tty-home" "$ZSH_BIN" -f -c '
    autoload -Uz compinit; compinit -u -d "$1/zcompdump" >/dev/null 2>&1
    eval "$(cat "$2")"; print -r -- "${_comps[aidentity]}"' zsh "$SANDBOX" "$SANDBOX/completion.zsh" 2>&1)
  assert_eq "zsh registers the completion function for aidentity" "_aidentity" "$ZSH_REG"
else
  _skip "the zsh script is valid zsh" "zsh is not installed"
  _skip "zsh registers the completion function for aidentity" "zsh is not installed"
fi

FISH_BIN=$(command -v fish 2>/dev/null || true)
if [ -n "$FISH_BIN" ]; then
  if "$FISH_BIN" --no-execute "$SANDBOX/completion.fish" 2>/dev/null; then
    _pass "the fish script is valid fish"
  else
    _fail "the fish script is valid fish" "$("$FISH_BIN" --no-execute "$SANDBOX/completion.fish" 2>&1)"
  fi
else
  _skip "the fish script is valid fish" "fish is not installed; the fish script was not syntax-checked"
fi

ai_stdout completion tcsh
assert_rc_nonzero "an unknown shell exits non-zero" "$RUN_RC" "$RUN_ERR"
assert_eq "and prints no script" "" "$RUN_OUT"
assert_contains "and names the shell" "$RUN_ERR" "tcsh"
assert_contains "and says what is supported" "$RUN_ERR" "bash, zsh or fish"
ai_stdout completion
assert_rc_nonzero "no shell exits non-zero" "$RUN_RC" "$RUN_ERR"
assert_contains "and shows the usage" "$RUN_ERR" "Usage: aidentity completion"
ai completion bash zsh
assert_rc_nonzero "two shells are refused" "$RUN_RC" "$RUN_OUT"
ai completion --bogus
assert_rc_nonzero "an unknown option is refused" "$RUN_RC" "$RUN_OUT"

# The names the scripts complete are the names main() takes.
libcall eval 'printf "%s\n" $COMMAND_WORDS'
WORDS_LISTED=$(printf '%s\n' "$RUN_OUT" | LC_ALL=C sort)
WORDS_DISPATCHED=$(sed -n '/^canonical_command() {/,/^}/p' "$AIDENTITY" \
  | sed -n 's/^    \([a-z|-]*\)) .*/\1/p' | tr '|' '\n' | grep -v '^-' | LC_ALL=C sort)
assert_nonempty "the command table can be read from the script" "$WORDS_DISPATCHED"
assert_eq "COMMAND_WORDS lists exactly the names the dispatch accepts" "$WORDS_DISPATCHED" "$WORDS_LISTED"
for w in $WORDS_LISTED; do
  libcall canonical_command "$w"
  assert_rc "canonical_command accepts $w" 0 "$RUN_RC" "$RUN_OUT"
done

# Homebrew's default shells are bash, zsh and fish. Naming them is refused by
# brew audit --strict, so the line must not list them.
if grep -qxF '    generate_completions_from_executable(bin/"aidentity", "completion")' "$REPO_DIR/Formula/aidentity.rb"; then
  _pass "the Homebrew formula installs bash, zsh and fish completions"
else
  _fail "the Homebrew formula installs bash, zsh and fish completions" "no generate_completions_from_executable line with the default shells"
fi

group "completion candidates (__complete)"

ai add "$ELECTRON_APP" --profile "Home Office"
ai add "$ELECTRON_APP" --profile Work
ai add "$ELECTRON_APP" --profile Gone
ai rm "Fake Gone" -y
make_decoy_app "$APPS/Decoy.app"

has_line() { # description, text, line: the line is there whole, spaces and all
  if printf '%s\n' "$2" | grep -Fxq -- "$3"; then _pass "$1"; else _fail "$1" "no line [$3]" "in: [$2]"; fi
}
lacks_line() {
  if printf '%s\n' "$2" | grep -Fxq -- "$3"; then _fail "$1" "unexpected line [$3]" "in: [$2]"; else _pass "$1"; fi
}

ai_stdout __complete launchers
assert_rc "__complete launchers exits 0" 0 "$RUN_RC" "$RUN_ERR"
assert_eq "and prints nothing on stderr" "" "$RUN_ERR"
has_line "it lists a profile name" "$RUN_OUT" "Fake Work"
has_line "it lists a profile name with a space in the profile" "$RUN_OUT" "Fake Home Office"
lacks_line "it leaves out an app that is not a launcher" "$RUN_OUT" "Decoy"
lacks_line "and a profile whose launcher is gone" "$RUN_OUT" "Fake Gone"
assert_not_contains "and prints no colour codes or paths" "$RUN_OUT" "/"

make_electron_app "$SRC/Space Case.app"
ai_stdout __complete apps
assert_rc "__complete apps exits 0" 0 "$RUN_RC" "$RUN_ERR"
has_line "it lists an Electron app" "$RUN_OUT" "Fake"
has_line "and an app whose name has a space" "$RUN_OUT" "Space Case"
has_line "it lists a Chromium fork" "$RUN_OUT" "Forky"
lacks_line "it leaves out a native app" "$RUN_OUT" "Nativey"
lacks_line "and the launchers" "$RUN_OUT" "Fake Work"

# A folder name is not trusted: an escape sequence in one must not reach the
# terminal through the list Tab prints.
ESC=$(printf '\033')
make_electron_app "$SRC/Evil${ESC}[31mApp.app"
cp -R "$APPS/Fake Work.app" "$APPS/Fake ${ESC}[31mRed.app"
ai_stdout __complete apps
assert_not_contains "an app name with an escape character is left out" "$RUN_OUT" "Evil"
assert_not_contains "and no escape character is printed" "$RUN_OUT" "$ESC"
ai_stdout __complete launchers
assert_not_contains "a launcher name with an escape character is left out" "$RUN_OUT" "Red"
assert_not_contains "and no escape character is printed for launchers" "$RUN_OUT" "$ESC"
has_line "the other launchers are still listed" "$RUN_OUT" "Fake Work"
rm -rf "$SRC/Evil${ESC}[31mApp.app" "$APPS/Fake ${ESC}[31mRed.app"

ai_stdout __complete restorable
assert_rc "__complete restorable exits 0" 0 "$RUN_RC" "$RUN_ERR"
has_line "it lists a profile whose launcher was removed" "$RUN_OUT" "Fake Gone"
lacks_line "and not one that still has a launcher" "$RUN_OUT" "Fake Work"

for what in bogus ""; do
  ai_stdout __complete "$what"
  assert_rc "__complete [$what] exits 0" 0 "$RUN_RC" "$RUN_ERR"
  assert_eq "__complete [$what] prints nothing" "" "$RUN_OUT"
  assert_eq "__complete [$what] says nothing on stderr" "" "$RUN_ERR"
done
ai_stdout __complete
assert_rc "__complete with no argument exits 0" 0 "$RUN_RC" "$RUN_ERR"
assert_eq "and prints nothing" "$RUN_OUT$RUN_ERR" ""

for what in launchers restorable apps; do
  RUN_OUT=$(AIDENTITY_APPS_DIR="$SB/no/such/folder" AIDENTITY_DATA_ROOT="$SB/no/such/data" \
    AIDENTITY_APP_DIRS="$SB/no/such/apps" detached "$BASH_BIN" "$AIDENTITY" __complete "$what" 2>"$SANDBOX/stderr" </dev/null)
  RUN_RC=$?
  assert_rc "__complete $what over folders that do not exist exits 0" 0 "$RUN_RC" "$RUN_OUT"
  assert_eq "and prints nothing" "" "$RUN_OUT$(cat "$SANDBOX/stderr")"
done

group "bash completion behaviour"

COMP_BIN="$SANDBOX/comp-bin"
mkdir -p "$COMP_BIN"
printf '#!/bin/sh\nexec "%s" "%s" "$@"\n' "$BASH_BIN" "$AIDENTITY" > "$COMP_BIN/aidentity"
chmod +x "$COMP_BIN/aidentity"

# Run the generated function as bash would, with the words typed so far; the
# last one is the word under the cursor. RUN_OUT holds what COMPREPLY ends up
# with, one entry per line.
bash_complete() {
  RUN_OUT=$(PATH="$COMP_BIN:$PATH" "$BASH_BIN" -c '
    . "$1"; shift
    COMP_WORDS=("$@"); COMP_CWORD=$(( $# - 1 ))
    _aidentity
    for r in "${COMPREPLY[@]}"; do printf "%s\n" "$r"; done' aidentity-comp "$SANDBOX/completion.bash" "$@" 2>&1)
  RUN_RC=$?
}

bash_complete aidentity ""
assert_rc "completing the command works" 0 "$RUN_RC" "$RUN_OUT"
has_line "an empty word offers commands: add" "$RUN_OUT" "add"
has_line "and aliases: ls" "$RUN_OUT" "ls"
has_line "and completion itself" "$RUN_OUT" "completion"
lacks_line "but not options" "$RUN_OUT" "--help"
bash_complete aidentity re
assert_eq "a prefix narrows the commands" "rename
restore
rebuild
repair
remove" "$RUN_OUT"
bash_complete aidentity -
assert_eq "a dash offers the global options" "-h
--help
-v
--version" "$RUN_OUT"
bash_complete aidentity rm --p
assert_eq "an option prefix completes the option" "--purge" "$RUN_OUT"
bash_complete aidentity delete --pu
assert_eq "an alias gets its command's options" "--purge" "$RUN_OUT"
bash_complete aidentity ls --
assert_eq "list offers --json and --help" "--json
--help" "$RUN_OUT"
bash_complete aidentity add --
has_line "add offers --profile" "$RUN_OUT" "--profile"
has_line "add offers --own-extensions" "$RUN_OUT" "--own-extensions"
bash_complete aidentity add Fake --profile Work --se
assert_eq "options are still offered after other arguments" "--seed" "$RUN_OUT"

bash_complete aidentity rm ""
has_line "rm offers a profile name, escaped for the shell" "$RUN_OUT" 'Fake\ Work'
has_line "and one whose profile name has a space" "$RUN_OUT" 'Fake\ Home\ Office'
lacks_line "and not an app that is not a launcher" "$RUN_OUT" "Decoy"
bash_complete aidentity open 'Fake\ H'
assert_eq "a name already escaped by hand completes" 'Fake\ Home\ Office' "$RUN_OUT"
bash_complete aidentity open '"Fake H'
assert_eq "a name inside double quotes completes unescaped" 'Fake Home Office' "$RUN_OUT"
bash_complete aidentity open "'Fake W"
assert_eq "a name inside single quotes completes unescaped" 'Fake Work' "$RUN_OUT"
bash_complete aidentity rm "Fake Work" ""
assert_eq "rm takes one name, so nothing more is offered" "" "$RUN_OUT"
bash_complete aidentity rename "Fake Work" ""
assert_eq "the new name for rename is not completed" "" "$RUN_OUT"
for c in open set rebuild rename; do
  bash_complete aidentity "$c" "Fake\\ W"
  assert_eq "$c completes a profile name" 'Fake\ Work' "$RUN_OUT"
done
bash_complete aidentity restore ""
assert_eq "restore offers only profiles that can be restored" 'Fake\ Gone' "$RUN_OUT"
bash_complete aidentity add ""
has_line "add offers an app name" "$RUN_OUT" "Fake"
has_line "and an app whose name has a space is escaped" "$RUN_OUT" 'Space\ Case'
lacks_line "and not a launcher" "$RUN_OUT" 'Fake\ Work'
bash_complete aidentity add Fo
assert_eq "an app prefix narrows the apps" "Forky" "$RUN_OUT"
bash_complete aidentity add Spa
assert_eq "a spaced app name completes with its space escaped" 'Space\ Case' "$RUN_OUT"
bash_complete aidentity add --color ""
has_line "--color offers colours" "$RUN_OUT" "blue"
has_line "including the neutrals" "$RUN_OUT" "graphite"
bash_complete aidentity set "Fake Work" -c pu
assert_eq "-c completes a colour too" "purple" "$RUN_OUT"
bash_complete aidentity set "Fake Work" --colour te
assert_eq "--colour completes a colour as well" "teal" "$RUN_OUT"
bash_complete aidentity add --profile ""
assert_eq "a value that has no list offers nothing" "" "$RUN_OUT"
bash_complete aidentity completion ""
assert_eq "completion offers the three shells" "bash
zsh
fish" "$RUN_OUT"
bash_complete aidentity help rest
assert_eq "help completes a command name" "restore" "$RUN_OUT"
bash_complete aidentity definitely-not-a-command ""
assert_eq "an unknown command offers nothing" "" "$RUN_OUT"

# A folder name is not trusted. After an opening quote the name is escaped for
# that quote, so a $, a backtick or a quote mark in it is never run as code.
EVAL_DIR="$SANDBOX/comp-eval"
mkdir -p "$EVAL_DIR"
HOSTILE_NAMES=(
  'Fake Dollar $HOME Work'
  'Fake Sub $(touch pwned-marker) Work'
  'Fake Tick `touch pwned-marker` Work'
  "Fake It's Work"
  'Fake Quote"d Work'
  'Fake Slash\ed Work'
  'Fake Bang! Work'
)
for n in "${HOSTILE_NAMES[@]}"; do cp -R "$APPS/Fake Work.app" "$APPS/$n.app"; done

shell_reads() { # description, quote mark ("" for none), what is typed, the name it must be
  local desc="$1" q="$2" typed="$3" want="$4" got
  bash_complete aidentity open "$q$typed"
  case "$RUN_OUT" in
    ""|*$'\n'*) _fail "$desc" "expected exactly one reply" "got: [$RUN_OUT]"; return ;;
  esac
  rm -f "$EVAL_DIR/pwned-marker"
  got=$(cd "$EVAL_DIR" && "$BASH_BIN" -c "printf '%s' $q$RUN_OUT$q" 2>&1)
  assert_eq "$desc: the shell reads the name back whole" "$want" "$got"
  assert_no_file "$desc: and runs nothing" "$EVAL_DIR/pwned-marker"
}

for q in '"' "'" ""; do
  case "$q" in '"') qn="in double quotes" ;; "'") qn="in single quotes" ;; *) qn="without quotes" ;; esac
  shell_reads "$qn, a dollar sign"      "$q" "Fake Dollar" 'Fake Dollar $HOME Work'
  shell_reads "$qn, a command in \$()"  "$q" "Fake Sub"    'Fake Sub $(touch pwned-marker) Work'
  shell_reads "$qn, a backtick"         "$q" "Fake Tick"   'Fake Tick `touch pwned-marker` Work'
  shell_reads "$qn, an apostrophe"      "$q" "Fake It"     "Fake It's Work"
  shell_reads "$qn, a double quote"     "$q" "Fake Quote"  'Fake Quote"d Work'
  shell_reads "$qn, a backslash"        "$q" "Fake Slash"  'Fake Slash\ed Work'
done
shell_reads "in single quotes, an exclamation mark" "'" "Fake Bang" 'Fake Bang! Work'
shell_reads "without quotes, an exclamation mark" "" "Fake Bang" 'Fake Bang! Work'

bash_complete aidentity open '"Fake Dollar'
assert_eq 'in double quotes a $ gets a backslash' 'Fake Dollar \$HOME Work' "$RUN_OUT"
bash_complete aidentity open '"Fake Quote'
assert_eq 'and a double quote' 'Fake Quote\"d Work' "$RUN_OUT"
bash_complete aidentity open '"Fake Tick'
assert_eq 'and a backtick' 'Fake Tick \`touch pwned-marker\` Work' "$RUN_OUT"
bash_complete aidentity open '"Fake Slash'
assert_eq 'and a backslash' 'Fake Slash\\ed Work' "$RUN_OUT"
bash_complete aidentity open "'Fake It"
assert_eq "in single quotes an apostrophe closes, escapes and reopens" "Fake It'\\''s Work" "$RUN_OUT"
bash_complete aidentity open "'Fake Dollar"
assert_eq "in single quotes a \$ needs nothing" 'Fake Dollar $HOME Work' "$RUN_OUT"
bash_complete aidentity open '"Fake Bang'
assert_eq "a name with ! is left out inside double quotes, where it cannot be escaped" "" "$RUN_OUT"
bash_complete aidentity open 'Fake\ Bang'
assert_eq "and is escaped without quotes" 'Fake\ Bang\!\ Work' "$RUN_OUT"

# What is typed already is read back through the same escapes.
bash_complete aidentity open '"Fake Dollar \$H'
assert_eq "an escaped \$ already typed still matches" 'Fake Dollar \$HOME Work' "$RUN_OUT"
bash_complete aidentity open "\"Fake Dollar \\"
assert_eq "so does a backslash with nothing after it yet" 'Fake Dollar \$HOME Work' "$RUN_OUT"
bash_complete aidentity open '"Fake Quote\"'
assert_eq "an escaped double quote already typed still matches" 'Fake Quote\"d Work' "$RUN_OUT"
bash_complete aidentity open "\"Fake Slash\\\\"
assert_eq "an escaped backslash already typed still matches" 'Fake Slash\\ed Work' "$RUN_OUT"
bash_complete aidentity open "'Fake It'\\''s"
assert_eq "an escaped apostrophe already typed still matches" "Fake It'\\''s Work" "$RUN_OUT"

group "zsh completion behaviour"

if [ -n "$ZSH_BIN" ]; then
# The generated function runs under zsh -f. compadd and _describe, which only
# exist inside zsh's completion system, are replaced by stand-ins that print the
# candidates starting with the word under the cursor. zsh's own compadd does the
# quoting of names, so these tests cover what the function decides: which words
# count as arguments, which list it asks for and which options it offers.
ZSH_DRIVER="$SANDBOX/zsh-driver.zsh"
cat > "$ZSH_DRIVER" <<'ZSH_DRIVER_END'
compdef() { :; }
compadd() {
  local arr=0 c
  while [[ $1 == -* && $1 != -- ]]; do [[ $1 == -a ]] && arr=1; shift; done
  [[ $1 == -- ]] && shift
  if (( arr )); then set -- "${(@P)1}"; fi
  for c in "$@"; do [[ $c == "$words[CURRENT]"* ]] && print -r -- "$c"; done
  return 0
}
_describe() {
  local c
  for c in "${(@P)argv[-1]}"; do c=${c%%:*}; [[ $c == "$words[CURRENT]"* ]] && print -r -- "$c"; done
  return 0
}
. "$1"; shift
words=("$@"); CURRENT=$#
_aidentity
ZSH_DRIVER_END

# Like bash_complete: the words typed so far, the last one under the cursor.
# The output is sorted, since zsh lists its own order.
zsh_complete() {
  RUN_OUT=$(cd "$EVAL_DIR" && PATH="$COMP_BIN:$PATH" HOME="$SANDBOX/tty-home" "$ZSH_BIN" -f "$ZSH_DRIVER" "$SANDBOX/completion.zsh" "$@" 2>&1)
  RUN_RC=$?
  RUN_OUT=$(printf '%s\n' "$RUN_OUT" | LC_ALL=C sort)
}

zsh_complete aidentity ""
assert_rc "zsh: completing the command works" 0 "$RUN_RC" "$RUN_OUT"
has_line "zsh: an empty word offers commands: add" "$RUN_OUT" "add"
has_line "zsh: and aliases: ls" "$RUN_OUT" "ls"
has_line "zsh: and completion itself" "$RUN_OUT" "completion"
lacks_line "zsh: but not options" "$RUN_OUT" "--help"
zsh_complete aidentity re
assert_eq "zsh: a prefix narrows the commands" "rebuild
remove
rename
repair
restore" "$RUN_OUT"
zsh_complete aidentity -
assert_eq "zsh: a dash offers the global options" "--help
--version
-h
-v" "$RUN_OUT"
zsh_complete aidentity rm --p
assert_eq "zsh: an option prefix completes the option" "--purge" "$RUN_OUT"
zsh_complete aidentity delete --pu
assert_eq "zsh: an alias gets its command's options" "--purge" "$RUN_OUT"
zsh_complete aidentity ls --
assert_eq "zsh: list offers --json and --help" "--help
--json" "$RUN_OUT"
zsh_complete aidentity add --
has_line "zsh: add offers --profile" "$RUN_OUT" "--profile"
has_line "zsh: add offers --own-extensions" "$RUN_OUT" "--own-extensions"
zsh_complete aidentity add Fake --profile Work --se
assert_eq "zsh: options are still offered after other arguments" "--seed" "$RUN_OUT"

zsh_complete aidentity rm ""
has_line "zsh: rm offers a profile name" "$RUN_OUT" "Fake Work"
has_line "zsh: and one whose profile name has a space" "$RUN_OUT" "Fake Home Office"
lacks_line "zsh: and not an app that is not a launcher" "$RUN_OUT" "Decoy"
lacks_line "zsh: and not a profile that can only be restored" "$RUN_OUT" "Fake Gone"
zsh_complete aidentity open "Fake H"
assert_eq "zsh: a name with a space completes" "Fake Home Office" "$RUN_OUT"
zsh_complete aidentity rm "Fake Work" ""
assert_eq "zsh: rm takes one name, so nothing more is offered" "" "$RUN_OUT"
zsh_complete aidentity rename "Fake Work" ""
assert_eq "zsh: the new name for rename is not completed" "" "$RUN_OUT"
zsh_complete aidentity rm --purge ""
has_line "zsh: an option before the name does not count as the name" "$RUN_OUT" "Fake Work"
for c in open set rebuild rename; do
  zsh_complete aidentity "$c" "Fake W"
  assert_eq "zsh: $c completes a profile name" "Fake Work" "$RUN_OUT"
done
zsh_complete aidentity restore ""
assert_eq "zsh: restore offers only profiles that can be restored" "Fake Gone" "$RUN_OUT"
zsh_complete aidentity add ""
has_line "zsh: add offers an app name" "$RUN_OUT" "Fake"
has_line "zsh: and an app whose name has a space" "$RUN_OUT" "Space Case"
lacks_line "zsh: and not a launcher" "$RUN_OUT" "Fake Work"
zsh_complete aidentity add Fo
assert_eq "zsh: an app prefix narrows the apps" "Forky" "$RUN_OUT"
zsh_complete aidentity add --color ""
has_line "zsh: --color offers colours" "$RUN_OUT" "blue"
has_line "zsh: including the neutrals" "$RUN_OUT" "graphite"
zsh_complete aidentity set "Fake Work" -c pu
assert_eq "zsh: -c completes a colour too" "purple" "$RUN_OUT"
zsh_complete aidentity set "Fake Work" --colour te
assert_eq "zsh: --colour completes a colour as well" "teal" "$RUN_OUT"
zsh_complete aidentity add --profile ""
assert_eq "zsh: a value that has no list offers nothing" "" "$RUN_OUT"
zsh_complete aidentity completion ""
assert_eq "zsh: completion offers the three shells" "bash
fish
zsh" "$RUN_OUT"
zsh_complete aidentity help rest
assert_eq "zsh: help completes a command name" "restore" "$RUN_OUT"
zsh_complete aidentity definitely-not-a-command ""
assert_eq "zsh: an unknown command offers nothing" "" "$RUN_OUT"

# Folder names are handed to zsh as they are. zsh quotes them itself, and
# nothing in the function reads them as code.
for want in 'Fake Dollar $HOME Work' 'Fake Sub $(touch pwned-marker) Work' 'Fake Tick `touch pwned-marker` Work' \
            "Fake It's Work" 'Fake Quote"d Work' 'Fake Slash\ed Work' 'Fake Bang! Work'; do
  zsh_complete aidentity open "${want% Work}"
  has_line "zsh: the name [$want] is offered as it is" "$RUN_OUT" "$want"
done
assert_no_file "zsh: and no folder name ran as code" "$EVAL_DIR/pwned-marker"
else
  _skip "zsh completion behaviour" "zsh is not installed"
fi

for n in "${HOSTILE_NAMES[@]}"; do rm -rf "$APPS/$n.app"; done
rm -rf "$EVAL_DIR"

ai rm "Fake Home Office" --purge -y
ai rm "Fake Work" --purge -y
rm -rf "$DATA/fake-gone" "$APPS/Decoy.app" "$SRC/Space Case.app"
group "update — version and tag checks"

for t in v1.4.0 v10.0.123 v0.0.1; do
  libcall is_release_tag "$t"
  assert_rc "accepts the tag $t" 0 "$RUN_RC" "$RUN_OUT"
done
for t in 1.4.0 v1.4 v1.4.0-rc1 V1.4.0 "v1.4.0 " "v1.4.0/../../x" "v1.4.0
v" v1234567890.0.0 ""; do
  libcall is_release_tag "$t"
  assert_rc_nonzero "rejects the tag [$t]" "$RUN_RC" "$RUN_OUT"
done

newer() { # a b expected-rc description
  libcall version_newer "$1" "$2"
  assert_rc "$4" "$3" "$RUN_RC" "$RUN_OUT"
}
newer 1.10.0 1.9.0 0 "1.10.0 is newer than 1.9.0 (numbers, not text)"
newer 2.0.0 1.99.99 0 "2.0.0 is newer than 1.99.99"
newer 1.4.0 1.4.0 1 "a version is not newer than itself"
newer 1.3.9 1.4.0 1 "1.3.9 is not newer than 1.4.0"
newer 1.08.0 1.7.0 0 "a leading zero is not read as octal"

UPD_JSON="$SANDBOX/release.json"
printf '{"url":"x","tag_name":"v1.4.0","body":"see \\"tag_name\\":\\"v9.9.9\\""}' > "$UPD_JSON"
libcall latest_tag "$UPD_JSON"
assert_eq "the tag is read from one-line JSON, not from the notes" "v1.4.0" "$RUN_OUT"
printf '{\n  "tag_name" : "v2.10.3",\n  "name": "x"\n}\n' > "$UPD_JSON"
libcall latest_tag "$UPD_JSON"
assert_eq "and from indented JSON" "v2.10.3" "$RUN_OUT"
printf '{"message":"Not Found"}' > "$UPD_JSON"
libcall latest_tag "$UPD_JSON"
assert_rc_nonzero "an answer with no tag is refused" "$RUN_RC" "$RUN_OUT"


group "update end to end, against a stub curl"

# A stub curl that plays GitHub. It serves files from UPD_SRV by the part of
# the URL after the repository name, so the real URLs work unchanged, and it
# logs every call. UPD_NET=down makes it fail the way a dead network does.
UPD_STUB="$SANDBOX/stub-curl-update"
UPD_SRV="$SANDBOX/update-server"
UPD_LOG="$SANDBOX/update-curl.log"
UPD_TMP="$SANDBOX/update-tmp"
mkdir -p "$UPD_STUB" "$UPD_SRV/releases" "$UPD_TMP"
cat > "$UPD_STUB/curl" <<STUB
#!/bin/sh
out="" url=""
printf '%s\n' "\$*" >> '$UPD_LOG'
if [ "\${UPD_NET:-up}" = down ]; then
  echo "curl: (6) Could not resolve host: api.github.com" >&2; exit 6
fi
while [ \$# -gt 0 ]; do
  case "\$1" in
    -o) out="\$2"; shift 2 ;;
    --proto|--proto-redir|--connect-timeout|--max-time|--retry|--max-filesize|-H) shift 2 ;;
    -*) shift ;;
    *) url="\$1"; shift ;;
  esac
done
case "\$url" in
  https://upd.test/r/*) rest="\${url#https://upd.test/r/}" ;;
  https://*/PiniShv/aidentity/*) rest="\${url#https://*/PiniShv/aidentity/}" ;;
  *) rest="" ;;
esac
case "\$rest" in
  ''|*..*|/*) echo "curl: (22) The requested URL returned error: 404" >&2; exit 22 ;;
esac
if [ ! -f '$UPD_SRV'/"\$rest" ]; then
  echo "curl: (22) The requested URL returned error: 404" >&2; exit 22
fi
cat '$UPD_SRV'/"\$rest" > "\$out"
STUB
chmod +x "$UPD_STUB/curl"
# update must never run sudo. If it ever does, this stub leaves a trace.
UPD_SUDO_LOG="$SANDBOX/upd-sudo.log"
cat > "$UPD_STUB/sudo" <<STUB
#!/bin/sh
printf '%s\n' "\$*" >> '$UPD_SUDO_LOG'
exit 1
STUB
chmod +x "$UPD_STUB/sudo"

# A copy of the script at path $1 that says it is version $2.
upd_copy() { # path, version
  mkdir -p "$(dirname "$1")"
  sed "s/^AIDENTITY_VERSION=.*/AIDENTITY_VERSION=\"$2\"/" "$AIDENTITY" > "$1"
  chmod 755 "$1"
}
# Publish a release on the stub server: its tag, and the version its script
# says (the tag's own by default). The checksum file matches what is served.
upd_release() { # tag, [version in the file]
  upd_copy "$UPD_SRV/$1/bin/aidentity" "${2:-${1#v}}"
  ( cd "$UPD_SRV/$1" && shasum -a 256 bin/aidentity > SHA256SUMS )
}
# What the API names as the latest release: any text at all. The notes carry
# a look-alike key, which must never be read as the tag.
upd_latest() { # tag
  printf '{\n  "url": "https://api.github.com/repos/PiniShv/aidentity/releases/1",\n  "tag_name": "%s",\n  "body": "Notes: \\"tag_name\\": \\"v99.0.0\\""\n}\n' \
    "$1" > "$UPD_SRV/releases/latest"
}
# Run `update` from the copy at $1, with the stub curl first on PATH, TMPDIR
# inside the sandbox and no Homebrew variables from the developer's shell.
# VAR=value arguments after the path are set for the run; the rest go to
# update itself.
upd() { # script, [VAR=value …], [update's arguments]
  local script="$1" envs=()
  shift
  while [ $# -gt 0 ]; do
    case "$1" in [A-Z]*=*) envs+=("$1"); shift ;; *) break ;; esac
  done
  : > "$UPD_LOG"
  RUN_OUT=$(env -u HOMEBREW_PREFIX -u HOMEBREW_CELLAR -u AIDENTITY_UPDATE_URL \
      HOME="$SANDBOX/upd-home" TMPDIR="$UPD_TMP" PATH="$UPD_STUB:/usr/bin:/bin:/usr/sbin:/sbin" \
      ${envs[@]+"${envs[@]}"} /usr/bin/perl -MPOSIX -e '
      my $pid = fork; die "fork: $!\n" unless defined $pid;
      if ($pid) { waitpid($pid, 0); exit($? & 127 ? 128 + ($? & 127) : $? >> 8) }
      POSIX::setsid(); exec @ARGV or exit 127' -- "$BASH_BIN" "$script" update "$@" 2>&1 </dev/null)
  RUN_RC=$?
  return 0
}
calls() { grep -c . "$UPD_LOG" | tr -d ' '; }
same_file() { # description, file, saved copy
  if cmp -s "$2" "$3"; then _pass "$1"; else _fail "$1" "$2 changed"; fi
}
only_script_in() { # folder: nothing but the script is left there
  assert_eq "no staged file is left in the folder" "aidentity" "$(ls -A "$1")"
  assert_eq "no download folder is left behind" "" "$(ls -A "$UPD_TMP")"
}

ai help
assert_contains "help documents update" "$RUN_OUT" "update"
assert_contains "help documents update --check" "$RUN_OUT" "Only say whether a newer release is out"
assert_contains "help documents AIDENTITY_UPDATE_URL" "$RUN_OUT" "AIDENTITY_UPDATE_URL"

U_DIR="$SB/upd bin"
U="$U_DIR/aidentity"
U_SAVED="$SANDBOX/upd-saved"
upd_copy "$U" 1.0.0
cp "$U" "$U_SAVED"

upd_release v1.0.0
upd_latest v1.0.0
upd "$U" --check
assert_rc "--check exits 0 when up to date" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "and says so" "$RUN_OUT" "1.0.0 is up to date"
upd "$U"
assert_rc "update exits 0 when up to date" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "and downloads nothing beyond the release info" "1" "$(calls)"
same_file "and leaves the file alone" "$U" "$U_SAVED"

upd_release v2.0.0
upd_latest v2.0.0
upd "$U" --check
assert_rc "--check exits 0 when a new release is out" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "and names both versions" "$RUN_OUT" "1.0.0 → 2.0.0 is available"
assert_contains "and how to update" "$RUN_OUT" "aidentity update"
assert_eq "--check downloads nothing beyond the release info" "1" "$(calls)"
same_file "--check installs nothing" "$U" "$U_SAVED"
UPD_CALLS=$(cat "$UPD_LOG")
assert_contains "curl is held to HTTPS" "$UPD_CALLS" "--proto =https"
assert_contains "redirects too" "$UPD_CALLS" "--proto-redir =https"
assert_contains "with TLS 1.2 or later" "$UPD_CALLS" "--tlsv1.2"
assert_contains "and a time limit" "$UPD_CALLS" "--max-time"
assert_contains "the release info comes from the GitHub API" "$UPD_CALLS" \
  "https://api.github.com/repos/PiniShv/aidentity/releases/latest"

upd "$U"
assert_rc "update installs a new release and exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "it says what it updated" "$RUN_OUT" "Updated 1.0.0 → 2.0.0"
assert_contains "it says the checksum was verified" "$RUN_OUT" "checksum verified"
assert_contains "it suggests rebuilding the launchers" "$RUN_OUT" "aidentity doctor --fix"
assert_contains "the script comes from the release tag" "$(cat "$UPD_LOG")" \
  "https://raw.githubusercontent.com/PiniShv/aidentity/v2.0.0/bin/aidentity"
assert_eq "an update makes three downloads" "3" "$(calls)"
# -q works only as curl's first argument. Anywhere else, curl still reads the
# user's .curlrc, where "insecure" would turn off certificate checks.
assert_eq "every curl call starts with -q, so ~/.curlrc is never read" "0" \
  "$(grep -vc '^-q ' "$UPD_LOG")"
same_file "the file is now the release's script" "$U" "$UPD_SRV/v2.0.0/bin/aidentity"
assert_exec "and stays executable" "$U"
assert_eq "with mode 755" "755" "$(/usr/bin/stat -f %Lp "$U")"
only_script_in "$U_DIR"
RUN_OUT=$("$BASH_BIN" "$U" version 2>&1)
assert_eq "the new copy runs" "aidentity 2.0.0" "$RUN_OUT"

# Through a symlink, the real file is replaced and the link stays a link.
upd_copy "$SB/upd real/aidentity" 1.0.0
mkdir -p "$SB/upd link"
ln -s "$SB/upd real/aidentity" "$SB/upd link/aidentity"
upd "$SB/upd link/aidentity"
assert_rc "update through a symlink exits 0" 0 "$RUN_RC" "$RUN_OUT"
same_file "the file the link points at is replaced" "$SB/upd real/aidentity" "$UPD_SRV/v2.0.0/bin/aidentity"
if [ -L "$SB/upd link/aidentity" ]; then _pass "the link is still a link"
else _fail "the link is still a link" "it was replaced by a file"; fi

# The file found must carry this copy's exact version line, or update cannot
# be sure it found itself. Here the line has a comment added by hand.
upd_copy "$SB/upd odd/aidentity" 1.0.0
/usr/bin/sed -i '' 's/^AIDENTITY_VERSION="1.0.0"$/AIDENTITY_VERSION="1.0.0"  # edited/' "$SB/upd odd/aidentity"
cp "$SB/upd odd/aidentity" "$SANDBOX/upd-saved-odd"
upd "$SB/upd odd/aidentity"
assert_rc_nonzero "a file without this copy's exact version line is refused" "$RUN_RC" "$RUN_OUT"
assert_contains "as a file it cannot find" "$RUN_OUT" "Could not find the file"
assert_eq "before any network call" "0" "$(calls)"
same_file "and the file is kept" "$SB/upd odd/aidentity" "$SANDBOX/upd-saved-odd"

# Every refusal below must leave the old file exactly as it was.
upd_copy "$U" 1.0.0
printf '%064d  bin/aidentity\n' 0 > "$UPD_SRV/v2.0.0/SHA256SUMS"
upd "$U"
assert_rc_nonzero "a checksum mismatch refuses" "$RUN_RC" "$RUN_OUT"
assert_contains "and says why" "$RUN_OUT" "Checksum mismatch"
assert_contains "and that nothing changed" "$RUN_OUT" "Nothing was changed"
same_file "the old file is kept byte for byte" "$U" "$U_SAVED"
only_script_in "$U_DIR"

rm -f "$UPD_SRV/v2.0.0/SHA256SUMS"
upd "$U"
assert_rc_nonzero "a missing checksum file refuses" "$RUN_RC" "$RUN_OUT"
assert_contains "and says the download cannot be checked" "$RUN_OUT" "cannot be checked"
same_file "the old file is kept" "$U" "$U_SAVED"

printf 'abc123  install.sh\n' > "$UPD_SRV/v2.0.0/SHA256SUMS"
upd "$U"
assert_rc_nonzero "a checksum file with no line for the script refuses" "$RUN_RC" "$RUN_OUT"
same_file "the old file is kept" "$U" "$U_SAVED"

# A script whose checksum matches but which says it is another version.
upd_release v2.0.0 2.0.1
upd "$U"
assert_rc_nonzero "a version line that does not match the tag refuses" "$RUN_RC" "$RUN_OUT"
assert_contains "and says so" "$RUN_OUT" "does not say it is version 2.0.0"
same_file "the old file is kept" "$U" "$U_SAVED"

# Cut short, with a checksum made for the short file: the checksum passes, so
# only the structural checks can stop it.
upd_release v2.0.0
head -n 200 "$UPD_SRV/v2.0.0/bin/aidentity" > "$SANDBOX/upd-short"
mv "$SANDBOX/upd-short" "$UPD_SRV/v2.0.0/bin/aidentity"
( cd "$UPD_SRV/v2.0.0" && shasum -a 256 bin/aidentity > SHA256SUMS )
upd "$U"
assert_rc_nonzero "a script cut short refuses, even with its own checksum" "$RUN_RC" "$RUN_OUT"
same_file "the old file is kept" "$U" "$U_SAVED"
printf 'AIDENTITY_VERSION="2.0.0"\nmain "$@"\n' > "$UPD_SRV/v2.0.0/bin/aidentity"
( cd "$UPD_SRV/v2.0.0" && shasum -a 256 bin/aidentity > SHA256SUMS )
upd "$U"
assert_rc_nonzero "a download that is not a script refuses" "$RUN_RC" "$RUN_OUT"
assert_contains "and says so" "$RUN_OUT" "not a script"
same_file "the old file is kept" "$U" "$U_SAVED"
# Each structural check on its own: every other check passes in each file.
printf '#!/bin/bash\nAIDENTITY_VERSION="2.0.0"\nif then fi\nmain "$@"\n' > "$UPD_SRV/v2.0.0/bin/aidentity"
( cd "$UPD_SRV/v2.0.0" && shasum -a 256 bin/aidentity > SHA256SUMS )
upd "$U"
assert_rc_nonzero "a download that is not valid shell refuses" "$RUN_RC" "$RUN_OUT"
assert_contains "and says so" "$RUN_OUT" "not valid shell"
same_file "the old file is kept" "$U" "$U_SAVED"
printf '#!/bin/bash\nAIDENTITY_VERSION="2.0.0"\necho first half\n' > "$UPD_SRV/v2.0.0/bin/aidentity"
( cd "$UPD_SRV/v2.0.0" && shasum -a 256 bin/aidentity > SHA256SUMS )
upd "$U"
assert_rc_nonzero "valid shell that does not end on aidentity's last line refuses" "$RUN_RC" "$RUN_OUT"
assert_contains "and says it may be cut off" "$RUN_OUT" "may be cut off"
same_file "the old file is kept" "$U" "$U_SAVED"
only_script_in "$U_DIR"
upd_release v2.0.0

for t in 2.0.0 v2.0 v2.0.0-rc1 "v2.0.0/../../../evil/repo/v9.9.9" "v2.0.0\$(touch $SANDBOX/pwned)"; do
  upd_latest "$t"
  upd "$U"
  assert_rc_nonzero "a malformed tag is refused: $t" "$RUN_RC" "$RUN_OUT"
  assert_eq "and nothing is downloaded for it" "1" "$(calls)"
  case "$t" in
    *evil*) assert_not_contains "and the tag is never echoed" "$RUN_OUT" "evil" ;;
  esac
done
upd "$U" --check
assert_rc_nonzero "--check refuses a malformed tag too" "$RUN_RC" "$RUN_OUT"
assert_contains "and says the answer was not a valid release" "$RUN_OUT" "valid release"
same_file "the old file is kept" "$U" "$U_SAVED"
assert_no_file "and nothing in the tag ran" "$SANDBOX/pwned"
upd_latest v2.0.0

# Never a downgrade: a copy newer than the latest release stays as it is.
upd_copy "$U" 3.0.0
cp "$U" "$SANDBOX/upd-saved-3"
upd "$U"
assert_rc "a copy newer than the latest release exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "and says it is newer" "$RUN_OUT" "newer than the latest release (2.0.0)"
assert_eq "and downloads nothing" "1" "$(calls)"
same_file "it is never downgraded" "$U" "$SANDBOX/upd-saved-3"
upd_copy "$U" 1.0.0

upd "$U" UPD_NET=down --check
assert_rc_nonzero "--check with no network exits non-zero" "$RUN_RC" "$RUN_OUT"
assert_contains "with a clear error" "$RUN_OUT" "Could not get the latest release"
upd "$U" UPD_NET=down
assert_rc_nonzero "update with no network exits non-zero" "$RUN_RC" "$RUN_OUT"
same_file "the old file is kept" "$U" "$U_SAVED"

# Homebrew's copy belongs to brew. Refused before any network call.
upd_copy "$SB/brew/Cellar/aidentity/1.0.0/bin/aidentity" 1.0.0
mkdir -p "$SB/brew/bin"
ln -s ../Cellar/aidentity/1.0.0/bin/aidentity "$SB/brew/bin/aidentity"
upd "$SB/brew/bin/aidentity"
assert_rc_nonzero "a Homebrew copy is refused" "$RUN_RC" "$RUN_OUT"
assert_contains "with the brew command" "$RUN_OUT" "brew upgrade aidentity"
assert_eq "before any network call" "0" "$(calls)"
same_file "the Homebrew file is kept" "$SB/brew/Cellar/aidentity/1.0.0/bin/aidentity" "$U_SAVED"
upd "$SB/brew/bin/aidentity" --check
assert_rc "--check still works for a Homebrew copy" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "and points at brew" "$RUN_OUT" "To update:    brew upgrade aidentity"
upd_copy "$SB/hb prefix/bin/aidentity" 1.0.0
upd "$SB/hb prefix/bin/aidentity" "HOMEBREW_PREFIX=$SB/hb prefix"
assert_rc_nonzero "a copy inside HOMEBREW_PREFIX is refused" "$RUN_RC" "$RUN_OUT"
assert_contains "with the brew command" "$RUN_OUT" "brew upgrade aidentity"
upd_copy "$SB/hb store/aidentity/1.0.0/bin/aidentity" 1.0.0
upd "$SB/hb store/aidentity/1.0.0/bin/aidentity" "HOMEBREW_CELLAR=$SB/hb store"
assert_rc_nonzero "a copy inside HOMEBREW_CELLAR is refused" "$RUN_RC" "$RUN_OUT"
assert_contains "with the brew command" "$RUN_OUT" "brew upgrade aidentity"
assert_eq "before any network call" "0" "$(calls)"
same_file "and the file is kept" "$SB/hb store/aidentity/1.0.0/bin/aidentity" "$U_SAVED"

# A source checkout is updated with git, not by replacing its file.
U_CO="$SB/checkout"
upd_copy "$U_CO/bin/aidentity" 1.0.0
touch "$U_CO/install.sh" "$U_CO/uninstall.sh" "$U_CO/LICENSE"
mkdir -p "$U_CO/.git"
upd "$U_CO/bin/aidentity"
assert_rc_nonzero "a copy in a git checkout is refused" "$RUN_RC" "$RUN_OUT"
# The script names folders by their real path: /var is /private/var on macOS.
assert_contains "with git pull for that folder" "$RUN_OUT" "git -C '$(cd -P "$U_CO" && pwd -P)' pull"
assert_eq "before any network call" "0" "$(calls)"
same_file "the checkout's file is kept" "$U_CO/bin/aidentity" "$U_SAVED"
upd "$U_CO/bin/aidentity" --check
assert_rc "--check works in a git checkout" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "and points at git pull" "$RUN_OUT" "To update:    git -C '$(cd -P "$U_CO" && pwd -P)' pull"
# Unpacked source code with no .git: there is nothing to pull from.
rm -rf "$U_CO/.git"
upd "$U_CO/bin/aidentity"
assert_rc_nonzero "a copy in unpacked source code is refused" "$RUN_RC" "$RUN_OUT"
assert_contains "and says to download the new release" "$RUN_OUT" \
  "Update the source code instead: download the new release from https://github.com/PiniShv/aidentity"
assert_not_contains "and does not suggest git" "$RUN_OUT" "git -C"
assert_eq "before any network call" "0" "$(calls)"
same_file "the file is kept" "$U_CO/bin/aidentity" "$U_SAVED"
upd "$U_CO/bin/aidentity" --check
assert_rc "--check works in unpacked source code" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "and points at the release page" "$RUN_OUT" \
  "To update:    download the new release from https://github.com/PiniShv/aidentity"

if [ "$(id -u)" = "0" ]; then
  _skip "a folder the user cannot write to is refused" "running as root, every folder is writable"
else
  U_RO="$SB/upd ro"
  upd_copy "$U_RO/aidentity" 1.0.0
  chmod 555 "$U_RO"
  upd "$U_RO/aidentity"
  chmod 755 "$U_RO"
  assert_rc_nonzero "a folder the user cannot write to is refused" "$RUN_RC" "$RUN_OUT"
  assert_contains "with the exact command to run" "$RUN_OUT" "sudo '$(cd -P "$U_RO" && pwd -P)/aidentity' update"
  assert_eq "before anything is downloaded" "1" "$(calls)"
  same_file "the file is kept" "$U_RO/aidentity" "$U_SAVED"
fi

# A sticky folder (like /tmp): anyone may write there, but only the owner of
# a file, or of the folder, may replace it.
U_ST="$SB/upd sticky"
upd_copy "$U_ST/aidentity" 1.0.0
chmod 1777 "$U_ST"
libcall can_replace "$U_ST/aidentity"
assert_rc "in a sticky folder, your own file can be replaced" 0 "$RUN_RC" "$RUN_OUT"
upd "$U_ST/aidentity"
assert_rc "and update replaces it there" 0 "$RUN_RC" "$RUN_OUT"
same_file "with the release's script" "$U_ST/aidentity" "$UPD_SRV/v2.0.0/bin/aidentity"
only_script_in "$U_ST"
chmod 755 "$U_ST"
# /private/tmp is sticky, writable by all and owned by root. A file there that
# is not yours (here: one that does not exist) cannot be replaced. Only looked
# at, never written.
if [ -k /private/tmp ] && [ -w /private/tmp ] && [ ! -O /private/tmp ]; then
  libcall can_replace "/private/tmp/aidentity-not-yours.$$"
  assert_rc_nonzero "in a sticky folder that is not yours, a file that is not yours cannot be replaced" "$RUN_RC" "$RUN_OUT"
else
  _skip "in a sticky folder that is not yours, a file that is not yours cannot be replaced" \
    "/private/tmp is not a sticky folder owned by someone else here"
fi

# The script read from stdin has no file to replace. $0 is then the shell,
# which must never be taken for the script.
: > "$UPD_LOG"
RUN_OUT=$(env -u HOMEBREW_PREFIX -u HOMEBREW_CELLAR HOME="$SANDBOX/upd-home" TMPDIR="$UPD_TMP" \
  PATH="$UPD_STUB:/usr/bin:/bin:/usr/sbin:/sbin" "$BASH_BIN" -s update < "$U" 2>&1); RUN_RC=$?
assert_rc_nonzero "a script read from stdin refuses to update" "$RUN_RC" "$RUN_OUT"
assert_contains "and says it cannot find its file" "$RUN_OUT" "Could not find the file"
assert_eq "before any network call" "0" "$(calls)"

upd "$U" AIDENTITY_UPDATE_URL=http://upd.test/r --check
assert_rc_nonzero "AIDENTITY_UPDATE_URL must be https" "$RUN_RC" "$RUN_OUT"
assert_eq "and a plain-http one is never contacted" "0" "$(calls)"
upd "$U" AIDENTITY_UPDATE_URL=https://upd.test/r/ --check
assert_rc "AIDENTITY_UPDATE_URL replaces GitHub" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "and says so on every run" "$RUN_OUT" "Using AIDENTITY_UPDATE_URL"
assert_contains "the release info comes from it" "$(cat "$UPD_LOG")" "https://upd.test/r/releases/latest"
assert_not_contains "and not from GitHub" "$(cat "$UPD_LOG")" "api.github.com"
upd "$U" AIDENTITY_UPDATE_URL=https://upd.test/r
assert_rc "AIDENTITY_UPDATE_URL is used for a full update too" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "the script comes from it" "$(cat "$UPD_LOG")" "https://upd.test/r/v2.0.0/bin/aidentity"
assert_contains "and the checksum file" "$(cat "$UPD_LOG")" "https://upd.test/r/v2.0.0/SHA256SUMS"
assert_not_contains "and nothing from GitHub" "$(cat "$UPD_LOG")" "githubusercontent"
same_file "the file is the release's script" "$U" "$UPD_SRV/v2.0.0/bin/aidentity"
upd_copy "$U" 1.0.0

# No curl on PATH: a clear message, and nothing else happens. uname stays,
# because the script checks it is on macOS before anything else.
mkdir -p "$SANDBOX/upd-no-curl"
ln -sf /usr/bin/uname "$SANDBOX/upd-no-curl/uname"
upd "$U" "PATH=$SANDBOX/upd-no-curl"
assert_rc_nonzero "update without curl exits non-zero" "$RUN_RC" "$RUN_OUT"
assert_contains "and says it needs curl" "$RUN_OUT" "needs curl"
assert_eq "and nothing is downloaded" "0" "$(calls)"
same_file "and the file is kept" "$U" "$U_SAVED"

# Stopped part way: the download folder and the staged copy are both removed.
# update runs in its own process group with a slow stub; once the stub says it
# is busy, the signal goes to that group: update and the stub it waits on,
# all started here. A job started with & ignores SIGINT, and a shell cannot
# trap a signal ignored when it starts, so the wrapper restores it first, as
# a terminal's Ctrl-C would find it.
UPD_READY="$SANDBOX/upd-ready"
UPD_SLOW_NET="$SANDBOX/stub-upd-slow-net"
UPD_SLOW_SUM="$SANDBOX/stub-upd-slow-sum"
mkdir -p "$UPD_SLOW_NET" "$UPD_SLOW_SUM"
cat > "$UPD_SLOW_NET/curl" <<STUB
#!/bin/sh
ps -o pgid= -p \$\$ | tr -d ' ' > '$UPD_READY'
sleep 20
exit 28
STUB
# Slow only when it checks the staged copy, the moment it sits beside the
# old file.
cat > "$UPD_SLOW_SUM/shasum" <<STUB
#!/bin/sh
for a in "\$@"; do
  case "\$a" in
    */.aidentity-update.*) ps -o pgid= -p \$\$ | tr -d ' ' > '$UPD_READY'; sleep 20 ;;
  esac
done
exec /usr/bin/shasum "\$@"
STUB
chmod +x "$UPD_SLOW_NET/curl" "$UPD_SLOW_SUM/shasum"
upd_signal() { # signal, stub folder, script
  local pid pg="" i=0
  rm -f "$UPD_READY"
  env -u HOMEBREW_PREFIX -u HOMEBREW_CELLAR -u AIDENTITY_UPDATE_URL \
      HOME="$SANDBOX/upd-home" TMPDIR="$UPD_TMP" PATH="$2:$UPD_STUB:/usr/bin:/bin:/usr/sbin:/sbin" \
      /usr/bin/perl -MPOSIX -e '
      my $pid = fork; die "fork: $!\n" unless defined $pid;
      if ($pid) { waitpid($pid, 0); exit($? & 127 ? 128 + ($? & 127) : $? >> 8) }
      $SIG{INT} = "DEFAULT"; POSIX::setsid(); exec @ARGV or exit 127' -- "$BASH_BIN" "$3" update \
      >"$SANDBOX/upd-signal.out" 2>&1 </dev/null &
  pid=$!
  while [ ! -s "$UPD_READY" ] && [ "$i" -lt 100 ]; do sleep 0.1; i=$((i+1)); done
  pg=$(cat "$UPD_READY" 2>/dev/null)
  UPD_BUSY_DIR=$(ls -A "$(dirname "$3")")
  UPD_BUSY_TMP=$(ls -A "$UPD_TMP")
  case "$pg" in ''|*[!0-9]*) ;; *) kill -"$1" -- "-$pg" 2>/dev/null ;; esac
  wait "$pid"; RUN_RC=$?
  RUN_OUT=$(cat "$SANDBOX/upd-signal.out")
  return 0
}
upd_signal TERM "$UPD_SLOW_NET" "$U"
assert_ne "a download folder existed while curl ran" "" "$UPD_BUSY_TMP"
assert_rc "TERM during the download exits 143" 143 "$RUN_RC" "$RUN_OUT"
same_file "and the old file is kept" "$U" "$U_SAVED"
only_script_in "$U_DIR"
upd_signal INT "$UPD_SLOW_SUM" "$U"
assert_contains "a staged copy sat beside the old file" "$UPD_BUSY_DIR" ".aidentity-update."
assert_rc "Ctrl-C while the new copy is staged exits 130" 130 "$RUN_RC" "$RUN_OUT"
same_file "and the old file is kept" "$U" "$U_SAVED"
only_script_in "$U_DIR"

upd "$U" --no-such-flag
assert_rc_nonzero "an unknown option for update exits non-zero" "$RUN_RC" "$RUN_OUT"
upd "$U" now
assert_rc_nonzero "an extra argument for update exits non-zero" "$RUN_RC" "$RUN_OUT"
same_file "and neither touches the file" "$U" "$U_SAVED"
only_script_in "$U_DIR"
assert_no_file "update never ran sudo, in any run above" "$UPD_SUDO_LOG"


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
