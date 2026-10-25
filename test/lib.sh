# shellcheck shell=bash
# SC2016: single-quoted scripts are handed to "$BASH_BIN" -c and to generated
# stubs, which expand them later, on purpose. shellcheck only recognises that
# when the interpreter is spelled literally as `bash -c`.
# shellcheck disable=SC2016
# SC2329, SC2317: the helpers below are called from test/run_tests.sh and the
# area files, which shellcheck does not read together with this one.
# shellcheck disable=SC2329,SC2317
# SC2034: the variables set here are read in test/run_tests.sh and the area
# files, which shellcheck does not read together with this one.
# shellcheck disable=SC2034
#
# aidentity test suite, the shared part: the sandbox, the assertions, the
# runners and the fixtures. test/run_tests.sh sources this file and then the
# area files (test/t_*.sh); it is never run on its own.

# ------------------------------------------------------------------ setup --

TEST_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
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

# rm --purge, prune and uninstall.sh move profile data to the Trash in the home
# folder. So every command here runs with a home folder in the sandbox, and
# that is where the data lands. The real Trash is checked at the end, like the
# real folders above. The sandbox is on the same volume as this home folder,
# so the Trash used is always this one.
REAL_TRASH="$HOME/.Trash"
export HOME="$SANDBOX/home"
SB_TRASH="$HOME/.Trash"
# tty-home is the home folder of the runs on a terminal (ai_tty, the menu,
# uninstall.sh). It must exist too: a Trash is only made in a home folder that
# is there.
mkdir -p "$HOME" "$SANDBOX/tty-home"

# The names in a Trash that start with "fake-", the prefix of every profile
# folder the suite makes. Only those: other changes to a user's Trash while
# the suite runs are not the suite's. A Trash that cannot be listed (macOS
# keeps the real one private from some programs) reads as that, both times,
# so there the final check of the real Trash is only advisory: it cannot see a
# change. The HOME override above is the real guard.
trash_names() { # trash folder
  local list
  list=$(ls -A "$1" 2>/dev/null) || { printf '<unreadable>'; return 0; }
  printf '%s\n' "$list" | grep '^fake-' | LC_ALL=C sort
  return 0
}

# Empty the sandbox's two Trash folders, so a test knows the names it finds
# there. Only ever these two, inside this run's sandbox.
trash_reset() {
  case "$SB_TRASH" in
    "$SANDBOX"/?*) ;;
    *) printf '# refusing to empty a Trash outside the sandbox: %s\n' "$SB_TRASH" >&2; return 1 ;;
  esac
  chmod -R u+rwX "$SB_TRASH" "$SANDBOX/tty-home/.Trash" 2>/dev/null
  rm -rf "$SB_TRASH" "$SANDBOX/tty-home/.Trash"
}

# A small disk image attached as a second volume, hidden from Finder, at a
# mount point in the sandbox. VOL_MNT is set before the attach, so cleanup
# detaches it however the run ends. Returns non-zero when hdiutil cannot do
# it here.
VOL_MNT=""
vol_attach() { # mount point inside the sandbox
  local img="$SANDBOX/volume.dmg"
  rm -f "$img"
  mkdir -p "$1" || return 1
  hdiutil create -size 8m -fs HFS+ -volname aidentity-test -layout NONE "$img" >/dev/null 2>&1 || return 1
  VOL_MNT="$1"
  if ! hdiutil attach -nobrowse -noverify -noautoopen -mountpoint "$1" "$img" >/dev/null 2>&1; then
    vol_detach; return 1
  fi
  [ "$(/usr/bin/stat -f %d "$1")" != "$(/usr/bin/stat -f %d "$SANDBOX")" ] || { vol_detach; return 1; }
}

vol_detach() {
  [ -n "${VOL_MNT:-}" ] || return 0
  hdiutil detach "$VOL_MNT" >/dev/null 2>&1 || hdiutil detach -force "$VOL_MNT" >/dev/null 2>&1
  VOL_MNT=""
  rm -f "$SANDBOX/volume.dmg"
  return 0
}

export AIDENTITY_APPS_DIR="$APPS"
export AIDENTITY_DATA_ROOT="$DATA"
# Without this the suite scans the real /Applications, which makes `apps`,
# `doctor` and the wizard menu depend on whatever the developer has installed —
# and quietly breaks the isolation this file claims a few lines above.
export AIDENTITY_APP_DIRS="$SRC:$APPS"

# Reached only through the EXIT/INT/TERM trap installed below.
cleanup() {
  # A disk image attached as a second volume is detached first, kept sandbox
  # or not: a mounted volume would outlive the run.
  vol_detach
  if [ -n "${AIDENTITY_TEST_KEEP:-}" ]; then
    printf '%s# sandbox kept: %s%s\n' "$P_DIM" "$SANDBOX" "$P_OFF"
    return 0
  fi
  case "$SANDBOX" in
    */aidentity-tests.*)
      chmod -R u+rwX "$SANDBOX" 2>/dev/null
      # The install tests lock a file with chflags; one stopped half way
      # would otherwise stay locked.
      chflags -R nouchg "$SANDBOX" 2>/dev/null
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

# The three fake apps every area starts from. The "fixtures" group in
# run_tests.sh builds them, and area_reset builds them again.
ELECTRON_APP="$SRC/Fake.app"
FORK_APP="$SRC/Forky.app"
NATIVE_APP="$SRC/Nativey.app"
build_fixture_apps() {
  make_electron_app "$ELECTRON_APP"
  make_chromium_fork_app "$FORK_APP"
  make_native_app "$NATIVE_APP"
}

# Start an area from a clean work space: no launchers, no profile data, and
# nothing in $SRC but the three fixture apps. run_tests.sh calls it before each
# area, so an area behaves the same alone as in a full run. With
# AIDENTITY_TEST_KEEP=1 only the last area's files are kept; run one area to
# look at its files.
area_reset() {
  local p
  case "$SANDBOX" in
    */aidentity-tests.*) ;;
    *) printf '# refusing to reset an unexpected sandbox: %s\n' "$SANDBOX" >&2; return 1 ;;
  esac
  # Both paths are deleted whole, so both must sit inside this run's sandbox.
  for p in "$SB" "$VSC_DATA"; do
    case "$p" in
      "$SANDBOX"/?*) ;;
      *) printf '# refusing to reset a path outside the sandbox: %s\n' "$p" >&2; return 1 ;;
    esac
  done
  chmod -R u+rwX "$SB" "$VSC_DATA" 2>/dev/null
  chflags -R nouchg "$SB" "$VSC_DATA" 2>/dev/null
  rm -rf "$SB" "$VSC_DATA"
  mkdir -p "$APPS" "$DATA" "$SRC" "$VSC_DATA"
  build_fixture_apps
}

# ---------------------------------------------- shared by more than one area --

# uninstall.sh with its dispatch line stripped, so a test can source it the way
# it sources LIB.
UNINST_LIB="$SANDBOX/uninstall-lib.sh"

# Strip the dispatch line of each script, so it can be sourced for unit tests.
# The "fixtures" group calls this once, for every area.
make_lib_copies() {
  grep -v '^[[:space:]]*main[[:space:]]*"\$@"[[:space:]]*$' "$AIDENTITY" > "$LIB"
  grep -v '^main "\$@"$' "$REPO_DIR/uninstall.sh" > "$UNINST_LIB"
}

# The command table, a row per command, in CMD_ROWS. The help and completion
# areas both walk it, so a new command is tested by both. The caller can check
# RUN_RC and RUN_OUT, which hold what reading the table said.
read_command_table() {
  local row
  libcall eval 'printf "%s\n" "$COMMANDS"'
  CMD_ROWS=()
  while IFS= read -r row; do [ -n "$row" ] && CMD_ROWS+=("$row"); done <<EOF_ROWS
$RUN_OUT
EOF_ROWS
}

# A stub pgrep with the profile's main process FIRST, then about 120 KB of
# Electron helper lines for another profile, a size real apps reach. The old
# check piped this into grep -q under pipefail; grep's early exit killed the
# writer with SIGPIPE and the profile read as NOT running. The running-check
# area is about that; list --json uses the same stub for a running profile.
# The second stub is a pgrep that fails, which is not "nothing is running".
PGREP_STUB="$SANDBOX/stub-pgrep"
FAIL_PGREP="$SANDBOX/stub-pgrep-fails"
BUSY_DATA="$DATA/fake-busy"
make_pgrep_stubs() {
  mkdir -p "$PGREP_STUB" "$FAIL_PGREP"
  {
    printf '#!/bin/sh\n'
    printf "printf '%%s\\\\n' '101 /Apps/Fake.app/Contents/MacOS/Fake --user-data-dir=%s'\n" "$BUSY_DATA"
    printf 'i=0\nwhile [ "$i" -lt 80 ]; do\n'
    printf "  printf '%%s\\\\n' \"\$((200 + i)) /Apps/Fake.app/Contents/Frameworks/Fake Helper.app/Contents/MacOS/Fake Helper --type=renderer --user-data-dir=%s/other %s\"\n" \
      "$DATA" "$(repeat_char 1400 x)"
    printf '  i=$((i + 1))\ndone\n'
  } > "$PGREP_STUB/pgrep"
  chmod +x "$PGREP_STUB/pgrep"
  printf '#!/bin/sh\nexit 3\n' > "$FAIL_PGREP/pgrep"
  chmod +x "$FAIL_PGREP/pgrep"
}

# install.sh, run with a stub curl first on PATH. The install area builds the
# one in CURL_STUB. The update area passes a PATH of its own, with its own stub
# curl, which wins over this one.
CURL_STUB="$SANDBOX/stub-curl"
# --piped runs it as `curl … | bash` does: the script arrives on stdin.
inst() { # [--piped] install dir, then optional VAR=value settings for install.sh
  local args=("$REPO_DIR/install.sh") input=/dev/null dir
  if [ "$1" = --piped ]; then args=(-s); input="$REPO_DIR/install.sh"; shift; fi
  dir="$1"; shift
  RUN_OUT=$(env HOME="$SANDBOX/inst-home" PATH="$CURL_STUB:/usr/bin:/bin:/usr/sbin:/sbin" \
    AIDENTITY_INSTALL_DIR="$dir" "$@" /usr/bin/perl -MPOSIX -e '
      my $pid = fork; die "fork: $!\n" unless defined $pid;
      if ($pid) { waitpid($pid, 0); exit($? & 127 ? 128 + ($? & 127) : $? >> 8) }
      POSIX::setsid(); exec @ARGV or exit 127' -- "$BASH_BIN" "${args[@]}" 2>&1 <"$input")
  RUN_RC=$?
  return 0
}
