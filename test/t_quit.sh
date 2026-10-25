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

# End processes this area started, by their PIDs, and only while a command
# line still names this run's FIFO: once a process ends, its PID can be given
# to another one. Then wait until they are gone, so rm sees none of them.
quit_end() { # PIDs
  local pid i=0
  for pid in "$@"; do
    case "$(/bin/ps -ww -o command= -p "$pid" 2>/dev/null)" in
      *"$QUIT_FIFO"*) kill -KILL "$pid" 2>/dev/null ;;
    esac
  done
  for pid in "$@"; do
    while quit_alive "$pid" && [ "$i" -lt 100 ]; do sleep 0.05; i=$((i + 1)); done
  done
}
# shellcheck disable=SC2086 # the PIDs are split on purpose
quit_kill_all() { quit_end $QUIT_PIDS; QUIT_PIDS=""; }
trap 'quit_kill_all; cleanup' EXIT INT TERM

# osascript stubs, put first on PATH for one run. Each notes the PID it was
# asked about in QUIT_LOG. no-app answers as for a process that is not an app,
# which quit leaves alone. refused answers as an app that would not take the
# quit event, so quit sends it SIGTERM. event ends the process itself and says
# the request was sent, as an app does when it takes the quit event. deaf says
# it was sent and does nothing, as an app that asks about unsaved work.
# no-osascript fails, as an osascript that cannot run. some answers as an app
# that refused for the PIDs listed in QUIT_APPS, and as no app for the others.
QUIT_LOG="$SANDBOX/quit-log"
QUIT_NOAPP="$SANDBOX/quit-no-app"
QUIT_REFUSED="$SANDBOX/quit-refused"
QUIT_EVENT="$SANDBOX/quit-event"
QUIT_DEAF="$SANDBOX/quit-deaf"
QUIT_NOSCRIPT="$SANDBOX/quit-no-osascript"
QUIT_SOME="$SANDBOX/quit-some"
QUIT_APPS="$SANDBOX/quit-apps"
quit_stub() { # folder, what it does with the PID in $p
  mkdir -p "$1"
  printf '#!/bin/sh\nfor a; do p=$a; done\ncat >/dev/null\nprintf "%%s\\n" "$p" >> "%s"\n%s\n' \
    "$QUIT_LOG" "$2" > "$1/osascript"
  chmod +x "$1/osascript"
}
quit_stub "$QUIT_NOAPP" 'echo none'
quit_stub "$QUIT_REFUSED" 'echo refused'
quit_stub "$QUIT_EVENT" 'kill -KILL "$p"; echo sent'
quit_stub "$QUIT_DEAF" 'echo sent'
quit_stub "$QUIT_NOSCRIPT" 'exit 1'
quit_stub "$QUIT_SOME" 'if grep -qx "$p" "'"$QUIT_APPS"'"; then echo refused; else echo none; fi'

# Run quit with one of the stubs. QUIT_ASKED: the PIDs it was asked about.
quit_run() { # stub folder, launcher name
  : > "$QUIT_LOG"
  PATH="$1:$PATH" ai quit "$2"
  QUIT_ASKED=$(tr '\n' ' ' < "$QUIT_LOG")
}

# What list says of a launcher, in QUIT_STATUS.
quit_status() { # launcher name
  ai_stdout list --json
  QUIT_STATUS=$(json_get "$RUN_OUT" 'byName(arg).status' "$1")
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

quit_run "$QUIT_REFUSED" "$QW"
assert_rc "quit exits 0 once the profile's copy is gone" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "and says so" "$RUN_OUT" "Quit $QW."
assert_eq "the quit event is tried first, for that one process" "$P_W " "$QUIT_ASKED"
if quit_alive "$P_W"; then _fail "an app that would not take the quit event gets SIGTERM"; else _pass "an app that would not take the quit event gets SIGTERM"; fi
if quit_alive "$P_W2"; then _pass "a profile whose folder name starts the same keeps running"; else _fail "a profile whose folder name starts the same keeps running"; fi
if quit_alive "$P_M"; then _pass "the app's own copy keeps running"; else _fail "the app's own copy keeps running"; fi
if quit_alive "$P_H"; then _pass "a helper on the same folder is never matched"; else _fail "a helper on the same folder is never matched"; fi

# Only a helper is left on the folder. list and rm count it as running, so
# quit does not say "not running" either: it names what is left and exits 1.
quit_run "$QUIT_NOAPP" "$QW"
assert_rc "with only a helper on the folder, quit exits 1" 1 "$RUN_RC" "$RUN_OUT"
assert_contains "and says the profile has no app open" "$RUN_OUT" \
  "'$QW' has no app open, but these still use its profile folder:"
assert_contains "and names the helper" "$RUN_OUT" "PID $P_H  Quitty Helper"
assert_contains "and says nothing was quit" "$RUN_OUT" "They are not apps, so quit leaves them alone. Nothing was quit."
assert_not_contains "never that it is not running" "$RUN_OUT" "is not running"
assert_eq "the helper is asked nothing" "" "$QUIT_ASKED"
if quit_alive "$P_H"; then _pass "and is sent nothing"; else _fail "and is sent nothing"; fi
quit_status "$QW"
assert_eq "list says the profile is running too" "running" "$QUIT_STATUS"
ai rm "$QW"
assert_rc_nonzero "and rm refuses to remove it" "$RUN_RC" "$RUN_OUT"
assert_contains "as running" "$RUN_OUT" "'$QW' is running right now. Quit it first"
quit_end "$P_H"
quit_run "$QUIT_NOAPP" "$QW"
assert_rc "once the helper is gone, quit exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "and says the profile is not running" "$RUN_OUT" "'$QW' is not running."

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
quit_run "$QUIT_REFUSED" "$QW"
assert_rc "a copy started through a symlinked folder is found" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "by the folder's identity" "$P_W " "$QUIT_ASKED"
if quit_alive "$P_W"; then _fail "and it is quit"; else _pass "and it is quit"; fi
rm -f "$SB/quit-alias"

# --- a main launcher quits the app's own copy

quit_run "$QUIT_REFUSED" "$QM"
assert_rc "a main launcher quits the app's own copy" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "and says so" "$RUN_OUT" "Quit $QM."
assert_eq "the copy with no --user-data-dir, and only that one" "$P_M " "$QUIT_ASKED"
if quit_alive "$P_M"; then _fail "the app's own copy is gone"; else _pass "the app's own copy is gone"; fi
if quit_alive "$P_W2"; then _pass "the profile keeps running"; else _fail "the profile keeps running"; fi
quit_run "$QUIT_NOAPP" "$QM"
assert_contains "with only profiles running, the app's own copy is not running" "$RUN_OUT" "'$QM' is not running."

# --- a process on the app's executable that is not an app

# VS Code's `code` command runs the app's own executable as a plain program,
# "<executable> <cli.js> --wait FILE". It is not an app. SIGTERM would end the
# command, and a commit waiting on it, not the app; so it is sent nothing.
QCLI="$QTARGET/Contents/Resources/app/out/cli.js"
quit_start "$QEXE" "$QUIT_WAIT" "$QCLI" --wait "$SB/COMMIT_EDITMSG"; P_CLI=$QPID
quit_run "$QUIT_NOAPP" "$QM"
assert_rc "a main launcher with only a command line tool on its executable exits 1" 1 "$RUN_RC" "$RUN_OUT"
assert_not_contains "and never says it quit" "$RUN_OUT" "Quit $QM."
assert_contains "it says what still runs" "$RUN_OUT" \
  "'$QM' has no app open, but these still run the app on your original account:"
assert_contains "and names it" "$RUN_OUT" "PID $P_CLI  stub"
assert_eq "it asked whether that process is an app" "$P_CLI " "$QUIT_ASKED"
if quit_alive "$P_CLI"; then _pass "and sent it no SIGTERM"; else _fail "and sent it no SIGTERM"; fi
quit_status "$QM"
assert_eq "list says the main launcher is running too" "running" "$QUIT_STATUS"

# With the app's own copy running as well, the app is quit and the tool is
# left alone.
quit_start "$QEXE" "$QUIT_WAIT"; P_M=$QPID
printf '%s\n' "$P_M" > "$QUIT_APPS"
quit_run "$QUIT_SOME" "$QM"
assert_rc "with the app and the tool running, quit quits the app" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "and says so" "$RUN_OUT" "Quit $QM."
assert_contains "and that the tool was left running" "$RUN_OUT" "Not an app, so left running:"
assert_contains "naming it" "$RUN_OUT" "PID $P_CLI  stub"
if quit_alive "$P_M"; then _fail "the app's copy is gone"; else _pass "the app's copy is gone"; fi
if quit_alive "$P_CLI"; then _pass "the tool still runs"; else _fail "the tool still runs"; fi
quit_end "$P_CLI"

# The same tool started on a profile's folder.
quit_start "$QEXE" "$QUIT_WAIT" "$QCLI" "--user-data-dir=$QDATA" --wait "$SB/COMMIT_EDITMSG"; P_CLI=$QPID
quit_run "$QUIT_NOAPP" "$QW"
assert_rc "a profile with only the tool on its folder exits 1" 1 "$RUN_RC" "$RUN_OUT"
assert_contains "and quit names the tool" "$RUN_OUT" "PID $P_CLI  stub"
if quit_alive "$P_CLI"; then _pass "and sends it no SIGTERM"; else _fail "and sends it no SIGTERM"; fi
quit_end "$P_CLI"

# An osascript that cannot run leaves nothing to tell an app from such a
# program, so nothing is sent.
quit_run "$QUIT_NOSCRIPT" "$QW2"
assert_rc_nonzero "an osascript that cannot run is an error" "$RUN_RC" "$RUN_OUT"
assert_contains "and quit says so" "$RUN_OUT" "Could not ask macOS whether $QW2's process is the app. Nothing was quit."
assert_eq "it was asked about the profile's process" "$P_W2 " "$QUIT_ASKED"
if quit_alive "$P_W2"; then _pass "and no SIGTERM followed"; else _fail "and no SIGTERM followed"; fi

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
quit_run "$QUIT_PS:$QUIT_REFUSED" "$QW"
assert_rc "a PID whose command no longer matches is skipped" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "and the profile is not running" "$RUN_OUT" "'$QW' is not running."
assert_eq "that process is not sent the quit event" "" "$QUIT_ASKED"
if quit_alive "$P_O"; then _pass "nor SIGTERM: it still runs"; else _fail "nor SIGTERM: it still runs"; fi

# --- another user's copy of the app is never ours to quit

# Two real copies on the profile's folder. The stub ps lists the second one
# under another user (root), as if someone else had the same profile open.
# The look right before acting is the real ps, which shows both as ours, so
# only the first scan's user check keeps the second one safe.
quit_start "$QEXE" "$QUIT_WAIT" "--user-data-dir=$QDATA"; P_MINE=$QPID
quit_start "$QEXE" "$QUIT_WAIT" "--user-data-dir=$QDATA"; P_THEIRS=$QPID
QUIT_PSU="$SANDBOX/quit-ps-users"
mkdir -p "$QUIT_PSU"
cat > "$QUIT_PSU/ps" <<STUB
#!/bin/sh
case " \$* " in *" -p "*) exec /bin/ps "\$@" ;; esac
printf '%s\n' '$(id -u) $P_MINE $QEXE --user-data-dir=$QDATA' '0 $P_THEIRS $QEXE --user-data-dir=$QDATA'
STUB
chmod +x "$QUIT_PSU/ps"
quit_run "$QUIT_PSU:$QUIT_REFUSED" "$QW"
assert_rc "with another user's copy listed, quit still quits ours" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "only this user's copy is sent the quit event" "$P_MINE " "$QUIT_ASKED"
if quit_alive "$P_MINE"; then _fail "this user's copy is gone"; else _pass "this user's copy is gone"; fi
if quit_alive "$P_THEIRS"; then _pass "the copy listed under another user still runs"; else _fail "the copy listed under another user still runs"; fi
quit_end "$P_THEIRS"

# A ps that fails is not "nothing is running".
QUIT_BADPS="$SANDBOX/quit-bad-ps"
mkdir -p "$QUIT_BADPS"
printf '#!/bin/sh\nexit 1\n' > "$QUIT_BADPS/ps"
chmod +x "$QUIT_BADPS/ps"
quit_run "$QUIT_BADPS:$QUIT_REFUSED" "$QW2"
assert_rc_nonzero "a ps that fails is an error" "$RUN_RC" "$RUN_OUT"
assert_contains "and it says so" "$RUN_OUT" "Could not list the running processes"
assert_eq "and nothing is asked to quit" "" "$QUIT_ASKED"
if quit_alive "$P_W2"; then _pass "so the profile still runs"; else _fail "so the profile still runs"; fi

# --- launchers that cannot say which copy is theirs

# A launcher that records no folder must not fall back to the app's own copy.
quit_start "$QEXE" "$QUIT_WAIT"; P_M=$QPID
cp -R "$APPS/$QW2.app" "$APPS/Quitty Blank.app"
/usr/libexec/PlistBuddy -c "Delete :AIdentityDataDir" "$APPS/Quitty Blank.app/Contents/Info.plist"
quit_run "$QUIT_REFUSED" "Quitty Blank"
assert_rc_nonzero "a launcher with no profile folder is refused" "$RUN_RC" "$RUN_OUT"
assert_contains "and it says why" "$RUN_OUT" "records no profile folder"
assert_eq "and asks nothing of any process" "" "$QUIT_ASKED"
if quit_alive "$P_M"; then _pass "the app's own copy keeps running"; else _fail "the app's own copy keeps running"; fi
/usr/libexec/PlistBuddy -c "Set :AIdentityTargetApp $SANDBOX/gone/Quitty.app" "$APPS/Quitty Blank.app/Contents/Info.plist"
quit_run "$QUIT_REFUSED" "Quitty Blank"
assert_rc_nonzero "a launcher whose app is gone is refused" "$RUN_RC" "$RUN_OUT"
assert_contains "and it names the app it looked for" "$RUN_OUT" "$SANDBOX/gone/Quitty.app"
assert_eq "and asks nothing of any process" "" "$QUIT_ASKED"
if quit_alive "$P_W2"; then _pass "the profile on that folder keeps running"; else _fail "the profile on that folder keeps running"; fi
rm -rf "$APPS/Quitty Blank.app"

# --- the app as Launch Services starts it

# Launch Services starts an app by its real path: symlinks resolved, each name
# in its real case. A launcher can record another spelling, a path through a
# symlink or "quitty.app" typed in lower case. The copy is found by its
# executable file, not by the spelling.
ln -sfn "$QUIT_APP" "$SRC/Linked.app"
ai add "$SRC/Linked.app" --profile Lk
QLK="Linked Lk"
assert_eq "a launcher keeps the symlinked app's path" "$SRC/Linked.app" "$(plist_key "$APPS/$QLK.app" AIdentityTargetApp)"
QLK_DATA=$(plist_key "$APPS/$QLK.app" AIdentityDataDir)
quit_start "$QEXE" "$QUIT_WAIT" "--user-data-dir=$QLK_DATA"; P_LK=$QPID
quit_status "$QLK"
assert_eq "list says its copy, started by the real path, runs" "running" "$QUIT_STATUS"
quit_run "$QUIT_REFUSED" "$QLK"
assert_rc "quit finds that copy through the symlinked app" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "and quits it" "$RUN_OUT" "Quit $QLK."
assert_eq "that copy, and only that one" "$P_LK " "$QUIT_ASKED"
if quit_alive "$P_LK"; then _fail "the symlinked app's copy is gone"; else _pass "the symlinked app's copy is gone"; fi

# A main launcher, through the symlink: list and quit find the app's own copy
# (P_M, from the group above) the same way.
plutil -replace AIdentityTargetApp -string "$SRC/Linked.app" "$APPS/$QM.app/Contents/Info.plist"
quit_status "$QM"
assert_eq "list says a main launcher through a symlink is running" "running" "$QUIT_STATUS"
quit_run "$QUIT_REFUSED" "$QM"
assert_rc "and quit quits its copy" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "that copy, and only that one" "$P_M " "$QUIT_ASKED"
if quit_alive "$P_M"; then _fail "the app's own copy is gone"; else _pass "the app's own copy is gone"; fi

# The same with an app path that is not ASCII, started by that path. In the
# C locale (this suite's) ps writes "é" as "M-CM-)", so it never matched.
QUNI_APP="$SRC/Quitt$(printf '\303\251').app"
ln -sfn "$QUIT_APP" "$QUNI_APP"
plutil -replace AIdentityTargetApp -string "$QUNI_APP" "$APPS/$QM.app/Contents/Info.plist"
LC_ALL=en_US.UTF-8 quit_start "$QUNI_APP/Contents/MacOS/stub" "$QUIT_WAIT"; P_M=$QPID
quit_status "$QM"
assert_eq "list says a main launcher on a path that is not ASCII is running" "running" "$QUIT_STATUS"
quit_run "$QUIT_REFUSED" "$QM"
assert_rc "and quit quits its copy" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "that copy, and only that one" "$P_M " "$QUIT_ASKED"
if quit_alive "$P_M"; then _fail "the copy on that path is gone"; else _pass "the copy on that path is gone"; fi
plutil -replace AIdentityTargetApp -string "$QTARGET" "$APPS/$QM.app/Contents/Info.plist"
rm -f "$QUNI_APP"

if [ -d "$SRC/quitty.app" ]; then
  ai add "$SRC/quitty.app" --profile Case
  QCASE="quitty Case"
  assert_eq "a launcher keeps the app's path as typed" "$SRC/quitty.app" "$(plist_key "$APPS/$QCASE.app" AIdentityTargetApp)"
  QCASE_DATA=$(plist_key "$APPS/$QCASE.app" AIdentityDataDir)
  quit_start "$QEXE" "$QUIT_WAIT" "--user-data-dir=$QCASE_DATA"; P_C=$QPID
  quit_run "$QUIT_REFUSED" "$QCASE"
  assert_rc "quit finds a copy whose path differs in case" 0 "$RUN_RC" "$RUN_OUT"
  assert_eq "that copy, and only that one" "$P_C " "$QUIT_ASKED"
  if quit_alive "$P_C"; then _fail "and quits it"; else _pass "and quits it"; fi
  ai rm "$QCASE" --purge -y
else
  _skip "quit finds a copy whose path differs in case" "this file system tells case apart"
fi

# In the C locale (this suite's) ps writes "é" as "M-CM-)": a profile folder
# with it never matched.
QUNI_ROOT="$SB/jos$(printf '\303\251') data"
mkdir -p "$QUNI_ROOT"
AIDENTITY_DATA_ROOT="$QUNI_ROOT" ai add "$QUIT_APP" --profile Uni
QUNI="Quitty Uni"
QUNI_DATA=$(plist_key "$APPS/$QUNI.app" AIdentityDataDir)
assert_contains "a profile can live under a folder name that is not ASCII" "$QUNI_DATA" "$QUNI_ROOT/"
quit_start "$QEXE" "$QUIT_WAIT" "--user-data-dir=$QUNI_DATA"; P_U=$QPID
quit_run "$QUIT_REFUSED" "$QUNI"
assert_rc "quit finds the copy on a folder that is not ASCII" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "that copy, and only that one" "$P_U " "$QUIT_ASKED"
if quit_alive "$P_U"; then _fail "and quits it"; else _pass "and quits it"; fi
AIDENTITY_DATA_ROOT="$QUNI_ROOT" ai rm "$QUNI" --purge -y

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

# With the real osascript: the fake process is not an app, so it is sent
# nothing, and quit says what still runs.
ai quit "$QW2"
assert_rc "with the real osascript, a process that is not an app is not quit" 1 "$RUN_RC" "$RUN_OUT"
assert_contains "quit names it" "$RUN_OUT" "PID $P_W2  stub"
if quit_alive "$P_W2"; then _pass "and sends it no SIGTERM"; else _fail "and sends it no SIGTERM"; fi

# --- the match itself

# libcall quit_matches executable, its exe_id, data folder, its id, command
# line. quit_match matches by the path alone; quit_match_file by the
# executable file too.
quit_match() { libcall quit_matches "$1" "" "$2" "$3" "$4"; if [ "$RUN_RC" -eq 0 ]; then echo yes; else echo no; fi; }
quit_match_file() { # executable as recorded, command line
  libcall quit_matches "$1" "$(/usr/bin/stat -f '%d:%i' "$1")" "" "" "$2"
  if [ "$RUN_RC" -eq 0 ]; then echo yes; else echo no; fi
}
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

# Only a real --user-data-dir argument names the folder, never the same words
# inside an allowed switch's value: that made quit A end B's copy.
assert_eq "the folder inside another switch's value is not the argument" no \
  "$(quit_match "$X" /d "" "$X --user-data-dir=/e --proxy-bypass-list=user-data-dir=/d")"
ln -sfn "$DATA" "$SANDBOX/qa"
QID=$(/usr/bin/stat -L -f '%d:%i' "$QDATA")
assert_eq "the folder under another spelling, in a real argument, matches" yes \
  "$(quit_match "$X" "$QDATA" "$QID" "$X --user-data-dir=$SANDBOX/qa/${QDATA##*/}")"
assert_eq "but not inside another switch's value" no \
  "$(quit_match "$X" "$QDATA" "$QID" "$X --user-data-dir=/e --proxy-bypass-list=user-data-dir=$SANDBOX/qa/${QDATA##*/}")"
rm -f "$SANDBOX/qa"

# The executable file, under the spellings Launch Services does not use.
ln -sfn "$SRC" "$SB/src-link"
assert_eq "an executable recorded through a symlinked app is the same file" yes \
  "$(quit_match_file "$SRC/Linked.app/Contents/MacOS/stub" "$QEXE --lang=de")"
assert_eq "so is one recorded through a symlinked folder" yes \
  "$(quit_match_file "$SB/src-link/Quitty.app/Contents/MacOS/stub" "$QEXE")"
if [ -d "$SRC/quitty.app" ]; then
  assert_eq "and one recorded in another case" yes \
    "$(quit_match_file "$SRC/quitty.app/Contents/MacOS/stub" "$QEXE --lang=de")"
else
  _skip "and one recorded in another case" "this file system tells case apart"
fi
make_electron_app "$SB/Other.app"
rm -f "$SB/Other.app/Contents/MacOS/stub"
ln -s /bin/bash "$SB/Other.app/Contents/MacOS/stub"
assert_eq "another app's executable of the same name is not it, though both link to one file" no \
  "$(quit_match_file "$QEXE" "$SB/Other.app/Contents/MacOS/stub --lang=de")"
assert_eq "the executable as another program's argument is not it" no \
  "$(quit_match_file "$SB/src-link/Quitty.app/Contents/MacOS/stub" "/usr/bin/env $QEXE")"
rm -rf "$SB/Other.app" "$SB/src-link"

# libcall quit_scan listing, uid, executable, its exe_id, data folder, its id.
libcall quit_scan "$(printf '%s\n' "501 11 $X" "0 12 $X" "501 13 $X --user-data-dir=/d")" 501 "$X" "" "" ""
assert_eq "the scan keeps only the given user's matching lines" "11" "$RUN_OUT"

# --- cleanup

quit_kill_all
trap cleanup EXIT INT TERM
ai rm "$QW" --purge -y
ai rm "$QW2" --purge -y
ai rm "$QLK" --purge -y
ai rm "$QM" -y
rm -f "$QUIT_FIFO" "$QUIT_OTHER" "$SRC/Linked.app" "$QUIT_APPS"
assert_eq "every launcher this area made is gone" "0" "$(count_launchers)"
