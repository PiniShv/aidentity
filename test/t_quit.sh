# shellcheck shell=bash
# SC2016: single-quoted scripts are handed to the fake app's shell and to
# generated stubs, which expand them later, on purpose. shellcheck only
# recognises that when the interpreter is spelled literally as `bash -c`.
# shellcheck disable=SC2016
# SC2153: DATA is set in lib.sh, which shellcheck does not read together with
# this file; it takes it for a misspelling of QDATA.
# shellcheck disable=SC2153
#
# Area "quit": aidentity quit, against real processes.
# Sourced by test/run_tests.sh after test/lib.sh. Run it alone with:
#   bash test/run_tests.sh quit

group "quit — one copy of the app, found and asked to quit"

# The fake app's executable is a symlink to /bin/bash. macOS stops a copy of a
# system binary as it starts; a link runs, and ps shows the link's path, as it
# shows a real app's executable. Each process waits on a FIFO for at most 60
# seconds and starts no child, so nothing is left behind for long even if this
# area is stopped half way. A helper sits inside the app's Frameworks folder,
# where Electron and Chromium keep theirs.
QUIT_APP="$SRC/Quitty.app"
make_electron_app "$QUIT_APP"
rm -f "$QUIT_APP/Contents/MacOS/stub"
ln -s /bin/bash "$QUIT_APP/Contents/MacOS/stub"
mkdir -p "$QUIT_APP/Contents/Frameworks/Quitty Helper.app/Contents/MacOS"
ln -s /bin/bash "$QUIT_APP/Contents/Frameworks/Quitty Helper.app/Contents/MacOS/Quitty Helper"
QUIT_FIFO="$SANDBOX/quit-fifo"
rm -f "$QUIT_FIFO"
mkfifo "$QUIT_FIFO"
QUIT_WAIT='read -t 60 x <> "$0"'
QUIT_NO_TERM='trap "" TERM; read -t 60 x <> "$0"'
QUIT_PIDS=""

# Start a fake process: its executable, the script it runs, its arguments. It
# is started from a subshell that ends at once, so launchd becomes its parent
# and reaps it the moment it ends, as it does for an app: an unreaped child of
# this shell would still answer kill -0. QPID is its PID. Returns 0 once ps
# shows it under its own command line.
quit_start() { # executable, script, arguments…
  local exe="$1" script="$2" i=0
  shift 2
  QPID=$("$exe" -c "$script" "$QUIT_FIFO" "$@" </dev/null >/dev/null 2>&1 & echo $!)
  QUIT_PIDS="$QUIT_PIDS $QPID"
  while [ "$i" -lt 100 ]; do
    case "$(/bin/ps -ww -o command= -p "$QPID" 2>/dev/null)" in "$exe "*) return 0 ;; esac
    sleep 0.05; i=$((i + 1))
  done
  return 1
}

quit_alive() { kill -0 "$1" 2>/dev/null; }

# End every process this area started, by its PID, and only while its command
# line still names this run's FIFO: once a process ends, its PID can be given
# to another one. Then wait until they are gone, so rm sees none of them.
quit_kill_all() {
  local pid i=0
  for pid in $QUIT_PIDS; do
    case "$(/bin/ps -ww -o command= -p "$pid" 2>/dev/null)" in
      *"$QUIT_FIFO"*) kill -KILL "$pid" 2>/dev/null ;;
    esac
  done
  for pid in $QUIT_PIDS; do
    while quit_alive "$pid" && [ "$i" -lt 100 ]; do sleep 0.05; i=$((i + 1)); done
  done
  QUIT_PIDS=""
}
trap 'quit_kill_all; cleanup' EXIT INT TERM

# osascript stubs, put first on PATH for one run. Each notes the PID it was
# asked about in QUIT_LOG. no-app answers as for a process that is not an app,
# so quit falls back to SIGTERM. event ends the process itself and says the
# request was sent, as an app does when it takes the quit event. deaf says it
# was sent and does nothing, as an app that asks about unsaved work.
QUIT_LOG="$SANDBOX/quit-log"
QUIT_NOAPP="$SANDBOX/quit-no-app"
QUIT_EVENT="$SANDBOX/quit-event"
QUIT_DEAF="$SANDBOX/quit-deaf"
quit_stub() { # folder, what it does with the PID in $p
  mkdir -p "$1"
  printf '#!/bin/sh\nfor a; do p=$a; done\ncat >/dev/null\nprintf "%%s\\n" "$p" >> "%s"\n%s\n' \
    "$QUIT_LOG" "$2" > "$1/osascript"
  chmod +x "$1/osascript"
}
quit_stub "$QUIT_NOAPP" 'echo none'
quit_stub "$QUIT_EVENT" 'kill -KILL "$p"; echo sent'
quit_stub "$QUIT_DEAF" 'echo sent'

# Run quit with one of the stubs. QUIT_ASKED: the PIDs it was asked about.
quit_run() { # stub folder, launcher name
  : > "$QUIT_LOG"
  PATH="$1:$PATH" ai quit "$2"
  QUIT_ASKED=$(tr '\n' ' ' < "$QUIT_LOG")
}

ai add "$QUIT_APP" --profile Work
ai add "$QUIT_APP" --profile Work2
ai add "$QUIT_APP" --main
QW="Quitty Work"; QW2="Quitty Work2"; QM="Quitty Main"
assert_eq "three launchers for the fake app" "3" "$(count_launchers)"
QTARGET=$(plist_key "$APPS/$QW.app" AIdentityTargetApp)
QEXE="$QTARGET/Contents/MacOS/stub"
QHELPER="$QTARGET/Contents/Frameworks/Quitty Helper.app/Contents/MacOS/Quitty Helper"
QDATA=$(plist_key "$APPS/$QW.app" AIdentityDataDir)
QDATA2=$(plist_key "$APPS/$QW2.app" AIdentityDataDir)
assert_eq "the second profile's folder name starts with the first one's" "${QDATA}2" "$QDATA2"

# --- what it refuses

ai quit
assert_rc_nonzero "quit needs a name" "$RUN_RC" "$RUN_OUT"
assert_contains "and says how it is used" "$RUN_OUT" "Usage: aidentity quit"
ai quit "$QW" "$QW2"
assert_rc_nonzero "quit takes one name" "$RUN_RC" "$RUN_OUT"
assert_contains "and names the extra one" "$RUN_OUT" "Unexpected argument: $QW2"
ai quit "$QW" --force
assert_rc_nonzero "there is no --force" "$RUN_RC" "$RUN_OUT"
assert_contains "and it says so" "$RUN_OUT" "Unknown option for quit: --force"
ai quit "Quitty Nobody"
assert_rc_nonzero "an unknown name is refused" "$RUN_RC" "$RUN_OUT"
assert_contains "and it says there is no such launcher" "$RUN_OUT" "No launcher named 'Quitty Nobody'"
make_decoy_app "$APPS/Decoy.app"
ai quit Decoy
assert_rc_nonzero "a bundle aidentity did not build is refused" "$RUN_RC" "$RUN_OUT"
assert_contains "and it says why" "$RUN_OUT" "not created by aidentity"
rm -rf "$APPS/Decoy.app"

# --- not running

quit_run "$QUIT_NOAPP" "$QW"
assert_rc "a profile that is not running exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "and says it is not running" "$RUN_OUT" "'$QW' is not running."
assert_eq "and no process is asked anything" "" "$QUIT_ASKED"

# --- the profile's copy, and only that one

if quit_start "$QEXE" "$QUIT_WAIT" "--user-data-dir=$QDATA"; then
  _pass "the profile's fake process runs"
else
  _fail "the profile's fake process runs" "ps: $(/bin/ps -ww -o command= -p "$QPID" 2>&1)"
fi
P_W=$QPID
assert_eq "ps shows it as a launcher starts it: the executable, then the folder last" \
  "$QEXE -c $QUIT_WAIT $QUIT_FIFO --user-data-dir=$QDATA" "$(/bin/ps -ww -o command= -p "$P_W")"
quit_start "$QEXE" "$QUIT_WAIT" "--user-data-dir=$QDATA2"; P_W2=$QPID
quit_start "$QEXE" "$QUIT_WAIT"; P_M=$QPID
quit_start "$QHELPER" "$QUIT_WAIT" --type=renderer "--user-data-dir=$QDATA"; P_H=$QPID
for pid in "$P_W2" "$P_M" "$P_H"; do
  if quit_alive "$pid"; then _pass "fake process $pid runs"; else _fail "fake process $pid runs"; fi
done

quit_run "$QUIT_NOAPP" "$QW"
assert_rc "quit exits 0 once the profile's copy is gone" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "and says so" "$RUN_OUT" "Quit $QW."
assert_eq "the quit event is tried first, for that one process" "$P_W " "$QUIT_ASKED"
if quit_alive "$P_W"; then _fail "with no app for the PID, SIGTERM ends it"; else _pass "with no app for the PID, SIGTERM ends it"; fi
if quit_alive "$P_W2"; then _pass "a profile whose folder name starts the same keeps running"; else _fail "a profile whose folder name starts the same keeps running"; fi
if quit_alive "$P_M"; then _pass "the app's own copy keeps running"; else _fail "the app's own copy keeps running"; fi
if quit_alive "$P_H"; then _pass "a helper on the same folder is never matched"; else _fail "a helper on the same folder is never matched"; fi

quit_run "$QUIT_NOAPP" "$QW"
assert_contains "with only a helper on the folder, the profile is not running" "$RUN_OUT" "'$QW' is not running."
assert_eq "and the helper is asked nothing" "" "$QUIT_ASKED"

# A process that ignores SIGTERM ends only through the quit event, so the event
# was sent and SIGTERM was not needed.
quit_start "$QEXE" "$QUIT_NO_TERM" "--user-data-dir=$QDATA"; P_W=$QPID
quit_run "$QUIT_EVENT" "$QW"
assert_rc "an app that takes the quit event is quit" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "and quit says so" "$RUN_OUT" "Quit $QW."
assert_eq "the event went to that process" "$P_W " "$QUIT_ASKED"
if quit_alive "$P_W"; then _fail "the quit event, not SIGTERM, ended it"; else _pass "the quit event, not SIGTERM, ended it"; fi

# The same folder under another spelling is the same profile.
ln -sfn "$DATA" "$SB/quit-alias"
quit_start "$QEXE" "$QUIT_WAIT" "--user-data-dir=$SB/quit-alias/${QDATA##*/}"; P_W=$QPID
quit_run "$QUIT_NOAPP" "$QW"
assert_rc "a copy started through a symlinked folder is found" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "by the folder's identity" "$P_W " "$QUIT_ASKED"
if quit_alive "$P_W"; then _fail "and it is quit"; else _pass "and it is quit"; fi
rm -f "$SB/quit-alias"

# --- a main launcher quits the app's own copy

quit_run "$QUIT_NOAPP" "$QM"
assert_rc "a main launcher quits the app's own copy" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "and says so" "$RUN_OUT" "Quit $QM."
assert_eq "the copy with no --user-data-dir, and only that one" "$P_M " "$QUIT_ASKED"
if quit_alive "$P_M"; then _fail "the app's own copy is gone"; else _pass "the app's own copy is gone"; fi
if quit_alive "$P_W2"; then _pass "the profile keeps running"; else _fail "the profile keeps running"; fi
if quit_alive "$P_H"; then _pass "and so does the helper"; else _fail "and so does the helper"; fi
quit_run "$QUIT_NOAPP" "$QM"
assert_contains "with only profiles running, the app's own copy is not running" "$RUN_OUT" "'$QM' is not running."

# --- a PID is looked at again right before it is sent anything

# The stub ps lists another program's process under the profile's command
# line, as if the profile's process had ended and its PID been given to it.
# The look right before acting (ps -p) is the real one.
QUIT_OTHER="$SANDBOX/quit-other"
ln -sfn /bin/bash "$QUIT_OTHER"
quit_start "$QUIT_OTHER" "$QUIT_WAIT"; P_O=$QPID
QUIT_PS="$SANDBOX/quit-ps"
mkdir -p "$QUIT_PS"
cat > "$QUIT_PS/ps" <<STUB
#!/bin/sh
case " \$* " in *" -p "*) exec /bin/ps "\$@" ;; esac
printf '%s\n' '$(id -u) $P_O $QEXE --user-data-dir=$QDATA'
STUB
chmod +x "$QUIT_PS/ps"
quit_run "$QUIT_PS:$QUIT_NOAPP" "$QW"
assert_rc "a PID whose command no longer matches is skipped" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "and the profile is not running" "$RUN_OUT" "'$QW' is not running."
assert_eq "that process is not sent the quit event" "" "$QUIT_ASKED"
if quit_alive "$P_O"; then _pass "nor SIGTERM: it still runs"; else _fail "nor SIGTERM: it still runs"; fi

# A ps that fails is not "nothing is running".
QUIT_BADPS="$SANDBOX/quit-bad-ps"
mkdir -p "$QUIT_BADPS"
printf '#!/bin/sh\nexit 1\n' > "$QUIT_BADPS/ps"
chmod +x "$QUIT_BADPS/ps"
quit_run "$QUIT_BADPS:$QUIT_NOAPP" "$QW2"
assert_rc_nonzero "a ps that fails is an error" "$RUN_RC" "$RUN_OUT"
assert_contains "and it says so" "$RUN_OUT" "Could not list the running processes"
assert_eq "and nothing is asked to quit" "" "$QUIT_ASKED"
if quit_alive "$P_W2"; then _pass "so the profile still runs"; else _fail "so the profile still runs"; fi

# --- launchers that cannot say which copy is theirs

# A launcher that records no folder must not fall back to the app's own copy.
quit_start "$QEXE" "$QUIT_WAIT"; P_M=$QPID
cp -R "$APPS/$QW2.app" "$APPS/Quitty Blank.app"
/usr/libexec/PlistBuddy -c "Delete :AIdentityDataDir" "$APPS/Quitty Blank.app/Contents/Info.plist"
quit_run "$QUIT_NOAPP" "Quitty Blank"
assert_rc_nonzero "a launcher with no profile folder is refused" "$RUN_RC" "$RUN_OUT"
assert_contains "and it says why" "$RUN_OUT" "records no profile folder"
assert_eq "and asks nothing of any process" "" "$QUIT_ASKED"
if quit_alive "$P_M"; then _pass "the app's own copy keeps running"; else _fail "the app's own copy keeps running"; fi
/usr/libexec/PlistBuddy -c "Set :AIdentityTargetApp $SANDBOX/gone/Quitty.app" "$APPS/Quitty Blank.app/Contents/Info.plist"
quit_run "$QUIT_NOAPP" "Quitty Blank"
assert_rc_nonzero "a launcher whose app is gone is refused" "$RUN_RC" "$RUN_OUT"
assert_contains "and it names the app it looked for" "$RUN_OUT" "$SANDBOX/gone/Quitty.app"
assert_eq "and asks nothing of any process" "" "$QUIT_ASKED"
if quit_alive "$P_W2"; then _pass "the profile on that folder keeps running"; else _fail "the profile on that folder keeps running"; fi
rm -rf "$APPS/Quitty Blank.app"

# --- --help quits nothing

for flag in --help -h; do
  ai quit "$QW2" "$flag"
  assert_rc "quit NAME $flag exits 0" 0 "$RUN_RC" "$RUN_OUT"
  assert_contains "and shows the help" "$RUN_OUT" "USAGE"
  if quit_alive "$P_W2"; then _pass "and quits nothing"; else _fail "and quits nothing"; fi
done

# --- an app that does not quit

# deaf says the event was sent and does nothing. quit waits 10 seconds, then
# says so and exits 1, and sends nothing more: SIGTERM would end this one.
SECONDS_BEFORE=$SECONDS
quit_run "$QUIT_DEAF" "$QW2"
assert_rc "an app still running after the wait exits 1" 1 "$RUN_RC" "$RUN_OUT"
assert_contains "and says it may be asking something" "$RUN_OUT" \
  "$QW2 is still running. It may be asking you something; look at its window."
if [ $((SECONDS - SECONDS_BEFORE)) -ge 9 ]; then _pass "it waited about 10 seconds first"
else _fail "it waited about 10 seconds first" "waited $((SECONDS - SECONDS_BEFORE)) s"; fi
assert_eq "the quit event was sent once" "$P_W2 " "$QUIT_ASKED"
if quit_alive "$P_W2"; then _pass "and no SIGTERM followed"; else _fail "and no SIGTERM followed"; fi

# With the real osascript: a process that is not an app has no app to ask, so
# it is sent SIGTERM.
ai quit "$QW2"
assert_rc "with the real osascript, quit ends a process that is not an app" 0 "$RUN_RC" "$RUN_OUT"
if quit_alive "$P_W2"; then _fail "through SIGTERM"; else _pass "through SIGTERM"; fi

# --- the match itself

# libcall quit_matches executable, data folder, its id, command line.
quit_match() { libcall quit_matches "$@"; if [ "$RUN_RC" -eq 0 ]; then echo yes; else echo no; fi; }
X=/A.app/Contents/MacOS/A
assert_eq "the executable alone is the app's own copy" yes "$(quit_match "$X" "" "" "$X")"
assert_eq "so is the executable with other switches" yes "$(quit_match "$X" "" "" "$X --lang=de")"
assert_eq "a profile's copy is not the app's own" no "$(quit_match "$X" "" "" "$X --user-data-dir=/d")"
assert_eq "an executable whose path only starts the same is another program" no "$(quit_match "$X" "" "" "${X}2")"
assert_eq "the folder is matched up to a space" yes "$(quit_match "$X" /d "" "$X --user-data-dir=/d --lang=de")"
assert_eq "or to the end" yes "$(quit_match "$X" /d "" "$X --user-data-dir=/d")"
assert_eq "a longer folder name does not match" no "$(quit_match "$X" /d "" "$X --user-data-dir=/d2")"
assert_eq "the executable must come first" no "$(quit_match "$X" /d "" "/usr/bin/env $X --user-data-dir=/d")"
assert_eq "a helper never matches" no \
  "$(quit_match "$X" /d "" "/A.app/Contents/Frameworks/A Helper.app/Contents/MacOS/A Helper --user-data-dir=/d")"

# --- cleanup

quit_kill_all
trap cleanup EXIT INT TERM
ai rm "$QW" --purge -y
ai rm "$QW2" --purge -y
ai rm "$QM" -y
rm -f "$QUIT_FIFO" "$QUIT_OTHER"
assert_eq "every launcher this area made is gone" "0" "$(count_launchers)"
