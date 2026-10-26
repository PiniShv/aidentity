# shellcheck shell=bash
# SC2016: single-quoted scripts are handed to "$BASH_BIN" -c and to generated
# stubs, which expand them later, on purpose. shellcheck only recognises that
# when the interpreter is spelled literally as `bash -c`.
# shellcheck disable=SC2016
#
# Area "ui": aidentity ui, the full-screen menu, driven on a pseudo-terminal.
# Sourced by test/run_tests.sh after test/lib.sh. Run it alone with:
#   bash test/run_tests.sh ui

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
# terminal's echo and line settings are back as they were. The perl wrapper
# puts SIGINT and SIGHUP back to their defaults first: a suite started with
# either ignored (by nohup, or as a background job) would pass that on, the
# menu could not trap it, and each Ctrl-C test would wait out the alarm.
ui_pty() { # rows, cols, keys, command…
  local rows="$1" cols="$2" keys="$3" f; shift 3
  rm -f "$UI_DONE"; : > "$UI_LOG"
  RUN_OUT=$( { ui_feed "$keys" \
      | HOME="$SANDBOX/tty-home" PATH="$STUB_BIN:$PATH" TERM="${UI_TERM:-xterm-256color}" \
        /usr/bin/perl -e '$SIG{INT} = $SIG{HUP} = "DEFAULT"; alarm 90; exec @ARGV' script -q /dev/null /bin/sh -c "$UI_WRAP" ui "$rows" "$cols" "$@"
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
assert_contains "and the stop key" "$FRAME" "s stop"
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

# Success and failure differ only in colour, so these run with colour on.
NO_COLOR='' ui_pty 24 200 '\nq' /bin/sh -c 'PATH="$1:$PATH"; exec "$2" "$3" ui' x "$UI_FAILOPEN" "$BASH_BIN" "$AIDENTITY"
assert_contains "with colour on, an open that fails is shown in red" "$(ui_frame)" "${ESC}[31m✗ Could not open 'Fake Alpha'"
assert_not_contains "not in the green of a success" "$(ui_frame)" "${ESC}[32m✗ Could not open"
NO_COLOR='' ui_run_menu 24 200 '\nq'
# The stub open prints a line of its own first; the footer joins the lines.
assert_contains "and an open that works is shown in green" "$(ui_frame)" "${ESC}[32mstub open: $ALPHA ✓ Opening Fake Alpha"

# --- s quits the selected profile

ui_run_menu 24 200 'sq'
assert_contains "s on a profile that is not running says so" "$(ui_frame)" "'Fake Alpha' is not running."
assert_contains "after saying what it was doing" "$RUN_OUT" "Quitting Fake Alpha"
assert_eq "and the terminal is intact" "same" "$RUN_FLAGS"

# A profile that really runs: its app's executable is a symlink to /bin/bash
# (macOS stops a copy of a system binary as it starts), run as a launcher
# starts it. It is started from a subshell that ends at once, so launchd reaps
# it the moment it ends. It waits on a FIFO for at most 60 seconds.
UI_QAPP="$SRC/Quitty.app"
make_electron_app "$UI_QAPP"
rm -f "$UI_QAPP/Contents/MacOS/stub"
ln -s /bin/bash "$UI_QAPP/Contents/MacOS/stub"
ai add "$UI_QAPP" --profile Work
UI_QEXE="$(plist_key "$APPS/Quitty Work.app" AIdentityTargetApp)/Contents/MacOS/stub"
UI_QFIFO="$SANDBOX/ui-quit-fifo"
rm -f "$UI_QFIFO"
mkfifo "$UI_QFIFO"
UI_QPID=$("$UI_QEXE" -c 'read -t 60 x <> "$0"' "$UI_QFIFO" \
  "--user-data-dir=$(plist_key "$APPS/Quitty Work.app" AIdentityDataDir)" </dev/null >/dev/null 2>&1 & echo $!)
# Ended by its PID, and only while its command line still names the FIFO.
ui_quit_kill() {
  case "$(/bin/ps -ww -o command= -p "$UI_QPID" 2>/dev/null)" in
    *"$UI_QFIFO"*) kill -KILL "$UI_QPID" 2>/dev/null ;;
  esac
}
trap 'ui_quit_kill; cleanup' EXIT INT TERM
i=0
while [ "$i" -lt 100 ]; do
  case "$(/bin/ps -ww -o command= -p "$UI_QPID" 2>/dev/null)" in "$UI_QEXE "*) break ;; esac
  sleep 0.05; i=$((i + 1))
done
# Ctrl-C while quit waits for an app that does not quit. The osascript stub
# says the request was sent and does nothing, as an app asking about unsaved
# work; it notes the PID last, so Ctrl-C is typed only once quit is waiting.
# The footer must not claim the profile was quit: it still runs.
UI_QDEAF="$SANDBOX/ui-quit-deaf"
UI_QASKED="$SANDBOX/ui-quit-asked"
mkdir -p "$UI_QDEAF"
printf '#!/bin/sh\ncat >/dev/null\necho sent\nfor a; do p=$a; done\nprintf "%%s\\n" "$p" >> "%s"\n' \
  "$UI_QASKED" > "$UI_QDEAF/osascript"
chmod +x "$UI_QDEAF/osascript"
ui_quit_asked() {
  local i=0
  while [ ! -s "$UI_QASKED" ] && [ "$i" -lt 800 ]; do sleep 0.05; i=$((i + 1)); done
}
rm -f "$UI_QASKED"
NO_COLOR='' ui_pty 24 200 '<4 profiles · 1 running>jjjs;!ui_quit_asked;\003;<Did not finish>q' \
  /bin/sh -c 'PATH="$1:$PATH"; exec "$2" "$3" ui' x "$UI_QDEAF" "$BASH_BIN" "$AIDENTITY"
assert_rc "Ctrl-C while s waits only stops the quit, and q quits the menu" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "the quit event went to the profile's process" "$UI_QPID" "$(cat "$UI_QASKED" 2>/dev/null)"
assert_contains "the footer says the quit did not finish, in red" "$(ui_frame)" \
  "${ESC}[31mDid not finish quitting Quitty Work."
assert_not_contains "and no frame claims it quit" "$RUN_OUT" "Quit Quitty Work."
assert_contains "the row still counts as running" "$(ui_frame)" "4 profiles · 1 running"
if kill -0 "$UI_QPID" 2>/dev/null; then _pass "the profile's process still runs"; else _fail "the profile's process still runs"; fi
assert_eq "and the terminal is intact" "same" "$RUN_FLAGS"

# An app still running after the wait. At 80 columns the footer shows the
# whole line, down to what the app may be doing. The sleep stub ends each step
# of the wait at once, so this run does not take 10 seconds.
UI_QSTILL="$SANDBOX/ui-quit-still"
mkdir -p "$UI_QSTILL"
printf '#!/bin/sh\ncat >/dev/null\necho sent\n' > "$UI_QSTILL/osascript"
printf '#!/bin/sh\nexit 0\n' > "$UI_QSTILL/sleep"
chmod +x "$UI_QSTILL/osascript" "$UI_QSTILL/sleep"
NO_COLOR='' ui_pty 24 80 '<4 profiles · 1 running>jjjs;<asking you>q' \
  /bin/sh -c 'PATH="$1:$PATH"; exec "$2" "$3" ui' x "$UI_QSTILL" "$BASH_BIN" "$AIDENTITY"
assert_rc "s on an app that does not quit, then q, exits 0" 0 "$RUN_RC" "$RUN_OUT"
UI_STILL=$(ui_frame | tr '\033' '\n' | grep -F 'still running')
assert_contains "at 80 columns the footer shows the whole line, in red" "$UI_STILL" \
  "[31m! Quitty Work is still running; it may be asking you something."
assert_not_contains "and cuts none of it" "$UI_STILL" "…"
if kill -0 "$UI_QPID" 2>/dev/null; then _pass "and the process still runs"; else _fail "and the process still runs"; fi

# An osascript that finds no app for the PID: the process is not an app, so
# quit sends it nothing, and the footer says so in red, never as a success.
UI_QNOAPP="$SANDBOX/ui-quit-no-app"
mkdir -p "$UI_QNOAPP"
printf '#!/bin/sh\ncat >/dev/null\necho none\n' > "$UI_QNOAPP/osascript"
chmod +x "$UI_QNOAPP/osascript"
NO_COLOR='' ui_pty 24 200 '<4 profiles · 1 running>jjjs;<Nothing was quit>q' \
  /bin/sh -c 'PATH="$1:$PATH"; exec "$2" "$3" ui' x "$UI_QNOAPP" "$BASH_BIN" "$AIDENTITY"
assert_rc "s on a profile with no app open, then q, exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "the footer says what still runs, in red" "$(ui_frame)" \
  "${ESC}[31m! 'Quitty Work' has no app open, but these still use its profile folder:"
assert_not_contains "and no frame claims it quit" "$RUN_OUT" "Quit Quitty Work."
assert_contains "the row still counts as running" "$(ui_frame)" "4 profiles · 1 running"
if kill -0 "$UI_QPID" 2>/dev/null; then _pass "the process is sent nothing"; else _fail "the process is sent nothing"; fi

# An osascript that finds an app that would not take the quit event, so quit
# sends SIGTERM.
UI_QREFUSED="$SANDBOX/ui-quit-refused"
mkdir -p "$UI_QREFUSED"
printf '#!/bin/sh\ncat >/dev/null\necho refused\n' > "$UI_QREFUSED/osascript"
chmod +x "$UI_QREFUSED/osascript"

NO_COLOR='' ui_pty 24 200 '<4 profiles · 1 running>jjjs;<Quit Quitty Work.>q' \
  /bin/sh -c 'PATH="$1:$PATH"; exec "$2" "$3" ui' x "$UI_QREFUSED" "$BASH_BIN" "$AIDENTITY"
assert_rc "s on a running profile, then q, exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "the footer says it is quitting first" "$RUN_OUT" "Quitting Quitty Work"
assert_contains "then shows quit's own message, in green" "$(ui_frame)" "${ESC}[32m✓ Quit Quitty Work."
assert_contains "and the row's status is read again" "$(ui_frame)" "4 profiles · 0 running"
if kill -0 "$UI_QPID" 2>/dev/null; then _fail "the profile's process is gone"; else _pass "the profile's process is gone"; fi
assert_eq "and the terminal is intact" "same" "$RUN_FLAGS"

UI_QBADPS="$SANDBOX/ui-quit-bad-ps"
mkdir -p "$UI_QBADPS"
printf '#!/bin/sh\nexit 1\n' > "$UI_QBADPS/ps"
chmod +x "$UI_QBADPS/ps"
NO_COLOR='' ui_pty 24 200 'jjjs;<Could not list>q' \
  /bin/sh -c 'PATH="$1:$PATH"; exec "$2" "$3" ui' x "$UI_QBADPS" "$BASH_BIN" "$AIDENTITY"
assert_contains "a quit that fails is shown in red" "$(ui_frame)" "${ESC}[31m✗ Could not list the running processes"
assert_rc "and the menu is still there to quit from" 0 "$RUN_RC" "$RUN_OUT"

ui_quit_kill
trap cleanup EXIT INT TERM
ai rm "Quitty Work" --purge -y
rm -f "$UI_QFIFO"
assert_eq "the quit group's launcher is gone" "3" "$(count_launchers)"

# --- narrow windows, long lists

ui_run_menu 20 40 'q'
FRAME=$(ui_frame)
assert_contains "a narrow window still shows the version" "$FRAME" "aidentity "
assert_contains "and the counts, on a line of their own" "$FRAME" "3 profiles · 0 running"
assert_contains "and every launcher" "$FRAME" "Fake Beta"
assert_not_contains "but leaves out the badge column" "$FRAME" "[A]"
assert_contains "and keeps the main keys" "$FRAME" "q quit"
assert_not_contains "and leaves the rest to the help screen" "$FRAME" "d remove"
assert_not_contains "stop among them" "$FRAME" "s stop"

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

# 68 columns: the longest key line still fits whole.
ui_run_menu 24 68 '?aq'
assert_rc "the help screen returns to the menu" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "the help screen lists the keys" "$RUN_OUT" "this help"
assert_contains "and how to remove" "$RUN_OUT" "k keeps the data"
assert_contains "p moves the data to the Trash, as the remove question says" "$RUN_OUT" "remove: k keeps the data, p moves it to the Trash"
assert_not_contains "and nothing says it deletes" "$RUN_OUT" "delete"
assert_contains "and that s quits one profile" "$RUN_OUT" "stop: quit the profile; other copies keep running"

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
assert_contains "p says the data goes to the Trash" "$RUN_OUT" "p  move data to Trash"
ui_run_menu 24 80 'dXq'
assert_contains "the whole question fits 80 columns" "$RUN_OUT" "Remove Fake Alpha?   k  keep the data   p  move data to Trash   Esc  cancel"
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
assert_no_dir "and takes its data away" "$DATA/fake-beta"
assert_contains "to the Trash, through rm's own message" "$RUN_OUT" "Moved the profile data to the Trash."
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
assert_not_contains "and not p" "$RUN_OUT" "move data to Trash"
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
  proc_snapshot; i=0; while [ "$i" -lt "$UI_N" ]; do
    launcher_status "${UI_L_TARGET[$i]}" "${UI_L_DATA[$i]}" "${UI_L_MAIN[$i]}"; echo "L $i $STATUS"; i=$((i + 1)); done' x "$LIB" "$UI_COUNT" 2>&1)
assert_contains "the menu counts what runs" "$RUN_OUT" "N=3 RUNNING=1"
assert_contains "pgrep was called once for three rows" "$RUN_OUT" "CALLS=1"
for i in 0 1 2; do
  assert_eq "row $i reads as list reads it" "$(printf '%s\n' "$RUN_OUT" | sed -n "s/^L $i //p")" "$(printf '%s\n' "$RUN_OUT" | sed -n "s/^S $i //p")"
done
assert_contains "the one with a process is running" "$RUN_OUT" "S 1 running"

# --- signals, and a crash: the terminal always comes back

# The menu runs in the background so a signal can be sent to it; <&0 keeps the
# terminal as its input, and perl gives it SIGINT back (a background job of a
# script starts with it ignored, and could not trap it). Each step waits for
# what the one before it caused.
# TERM and HUP are sent once the first screen is drawn and the menu waits for a
# key: a signal during that read once left the terminal with echo off. The
# resize waits for the narrow layout's own header line, not for any redraw.
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
/usr/bin/perl -e "\$SIG{INT} = q(DEFAULT); exec @ARGV" "$1" "$2" ui <&0 & p=$!
waitfor "?1049h" 0
case "$3" in
  WINCH) o=$(size); stty rows 12 cols 40 </dev/tty; waitfor "[2;1H 3 profiles" "$o"; kill -TERM $p ;;
  TSTP)  o=$(size); kill -TSTP $p; waitfor "?1049l" "$o"; o=$(size); kill -CONT $p; waitfor "?1049h" "$o"; kill -TERM $p ;;
  INT2)  waitfor "quit" 0; sleep 1.7; kill -INT $p
         # A menu that lost the signal is killed, so none is left running.
         /usr/bin/perl -e "sleep 10; kill 9, $p" </dev/null >/dev/null 2>&1 & w=$! ;;
  *)     waitfor "quit" 0; sleep 0.5; kill -"$3" $p ;;
esac
wait $p; rc=$?
[ -z "${w:-}" ] || kill $w 2>/dev/null
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

# Ctrl-C while the rows are read. They are read in `while read … done <<EOF`
# loops, and a trap that runs there has the here-document as its input: the
# terminal's settings, put back through it, never reached the terminal. A long
# process list keeps the menu in such a loop (the main launcher's status reads
# it line by line); the stub drops a file once it has written the list.
UI_LONGPS="$SANDBOX/ui-longps"; UI_PS_DONE="$SANDBOX/ui-ps-done"
export UI_PS_DONE
mkdir -p "$UI_LONGPS"
printf '#!/bin/sh\nyes "x other process" | head -n 150000\n: > "$UI_PS_DONE"\nexit 0\n' > "$UI_LONGPS/ps"
chmod +x "$UI_LONGPS/ps"
# shellcheck disable=SC2329,SC2317  # run by name from ui_feed (a ! chunk)
ui_wait_ps() { local i=0; while [ ! -e "$UI_PS_DONE" ] && [ "$i" -lt 800 ]; do sleep 0.05; i=$((i + 1)); done; }
rm -f "$UI_PS_DONE"
PATH="$UI_LONGPS:$PATH" ui_run_menu 20 100 '!ui_wait_ps;\003'
assert_rc "Ctrl-C while the rows are read ends the menu with 130" 130 "$RUN_RC" "$RUN_OUT"
assert_eq "and gives the terminal back" "same" "$RUN_FLAGS"
assert_not_contains "without waiting for the rows" "$RUN_OUT" "profiles ·"

# Ctrl-C while the menu waits for a key: in bash 5, a `read -s` that the trap
# cuts into puts back the mode it saved when it began (echo off) after the trap.
ui_run_menu 20 100 '<quit>\003'
assert_rc "Ctrl-C while the menu waits for a key ends it with 130" 130 "$RUN_RC" "$RUN_OUT"
assert_eq "and gives the terminal back" "same" "$RUN_FLAGS"

# And just before that wait runs out: bash 3.2 runs the trap inside the read,
# and the read's 2-second timer jumped back into it, so Ctrl-C was lost. A slow
# stty when the settings are put back stands in for a busy machine.
UI_SLOWSTTY="$SANDBOX/ui-slowstty"
mkdir -p "$UI_SLOWSTTY"
printf '#!/bin/sh\ncase "$1" in gfmt1:*) sleep 0.5 ;; esac\nexec /bin/stty "$@"\n' > "$UI_SLOWSTTY/stty"
chmod +x "$UI_SLOWSTTY/stty"
PATH="$UI_SLOWSTTY:$PATH" ui_signal INT2
assert_rc "Ctrl-C as the wait for a key runs out ends the menu with 130" 130 "$RUN_RC" "$RUN_OUT"
assert_eq "and gives the terminal back" "same" "$RUN_FLAGS"

# Ctrl-C at a wait for a key on the normal screen, here the doctor's: bash 3.2
# never undoes the mode the read set there.
ui_run_menu 20 100 'x;<Any other key returns>\003'
assert_rc "Ctrl-C at a key wait after a command ends the menu with 130" 130 "$RUN_RC" "$RUN_OUT"
assert_eq "and gives the terminal back" "same" "$RUN_FLAGS"

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
