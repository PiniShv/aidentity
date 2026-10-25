# shellcheck shell=bash
# SC2016: single-quoted scripts are handed to "$BASH_BIN" -c and to generated
# stubs, which expand them later, on purpose. shellcheck only recognises that
# when the interpreter is spelled literally as `bash -c`.
# shellcheck disable=SC2016
#
# Area "running": the running check on a real-sized process list.
# Sourced by test/run_tests.sh after test/lib.sh. Run it alone with:
#   bash test/run_tests.sh running

group "running check — a real-sized process list"

# The stub pgrep, PGREP_STUB, is made by make_pgrep_stubs in lib.sh: the
# profile's main process first, then about 120 KB of helper lines.
make_pgrep_stubs
STUB_SIZE=$(PATH="$PGREP_STUB:$PATH" pgrep -fl x | wc -c | tr -d ' ')
if [ "$STUB_SIZE" -gt 65536 ]; then _pass "the stub list is bigger than a pipe buffer ($STUB_SIZE bytes)"
else _fail "the stub list is bigger than a pipe buffer" "only $STUB_SIZE bytes"; fi

# One running check, asked three ways with the same stub and the same cases:
# running_on_profile, as rm, rename and prune ask it; uninstall.sh's copy; and
# running_in_snapshot under one snapshot, as list and the menu ask it. All
# three must give the answers a fresh look gives.
probe_running() { # fresh, uninstall or snapshot; data dir -> RUNNING / STOPPED
  local lib=$LIB snap="" fn=running_on_profile
  case "$1" in uninstall) lib=$UNINST_LIB ;; snapshot) snap=proc_snapshot fn=running_in_snapshot ;; esac
  # `set --` first: a sourced file sees the caller's arguments, and
  # uninstall.sh reads $1 as an option.
  PATH="$PGREP_STUB:$PATH" "$BASH_BIN" -c 'lib=$1 snap=$2 fn=$3 d=$4; set --; . "$lib" >/dev/null 2>&1
    $snap; $fn "$d" && echo RUNNING || echo STOPPED' x "$lib" "$snap" "$fn" "$2"
}
mkdir -p "$BUSY_DATA" "$DATA/fake-other"
ln -sfn "$DATA" "$SB/data-alias"
for how in fresh uninstall snapshot; do
  assert_eq "$how: a profile listed first in a 120 KB process list reads as running" "RUNNING" \
    "$(probe_running $how "$BUSY_DATA")"
  assert_eq "$how: a prefix of a running profile does not match" "STOPPED" "$(probe_running $how "$DATA/fake-bus")"
  assert_eq "$how: a longer name than a running profile does not match" "STOPPED" \
    "$(probe_running $how "$BUSY_DATA-2")"
  # The same folder under another spelling is the same running profile.
  assert_eq "$how: a running profile reached through a symlinked root reads as running" "RUNNING" \
    "$(probe_running $how "$SB/data-alias/fake-busy")"
  assert_eq "$how: a doubled slash does not hide a running profile" "RUNNING" \
    "$(probe_running $how "$DATA//fake-busy")"
  assert_eq "$how: a different folder through the same symlink does not match" "STOPPED" \
    "$(probe_running $how "$SB/data-alias/fake-other")"
done
# A variable of the snapshot's name in the environment is not a snapshot:
# PS_RC=0 with an empty list would read as "nothing is running".
for how in fresh uninstall; do
  assert_eq "$how: an inherited PS_RC does not switch the check off" "RUNNING" \
    "$(PS_RC=0 PS_LIST="" PS_IDS="" probe_running $how "$BUSY_DATA")"
done

# A snapshot answers as a fresh look does, including "running" when pgrep
# failed.
probe_snapshot() { # pgrep status, its list, data dir -> RUNNING / STOPPED
  "$BASH_BIN" -c '. "$1" >/dev/null 2>&1; PS_RC=$2 PS_LIST=$3 PS_IDS="" PS_ALL=""
    running_in_snapshot "$4" && echo RUNNING || echo STOPPED' x "$LIB" "$@"
}
assert_eq "snapshot: a pgrep that failed counts as running, as it does for rm" "RUNNING" \
  "$(probe_snapshot 2 "" "$BUSY_DATA")"
assert_eq "snapshot: no match is not running" "STOPPED" "$(probe_snapshot 1 "" "$BUSY_DATA")"
assert_eq "snapshot: an empty data dir is never running" "STOPPED" \
  "$(probe_snapshot 0 "101 x --user-data-dir=/p" "")"

# The folder identities are worked out only when the anchored match misses,
# and then once, for every question after it.
RUN_OUT=$(PATH="$PGREP_STUB:$PATH" "$BASH_BIN" -c '. "$1" >/dev/null 2>&1; proc_snapshot
  running_in_snapshot "$2"; echo "after a match: [$PS_IDS]"
  running_in_snapshot "$3"; [ -n "$PS_IDS" ] && echo "after a miss: filled"
  PS_IDS="|kept|"; running_in_snapshot "$3"; echo "after another: [$PS_IDS]"' \
  x "$LIB" "$BUSY_DATA" "$SB/data-alias/fake-other" 2>&1)
assert_contains "an anchored match looks at no path" "$RUN_OUT" "after a match: []"
assert_contains "a miss works the identities out" "$RUN_OUT" "after a miss: filled"
assert_contains "and the next question uses them again" "$RUN_OUT" "after another: [|kept|]"
rm -f "$SB/data-alias"
rmdir "$BUSY_DATA" "$DATA/fake-other" 2>/dev/null

ai add "$ELECTRON_APP" --profile Busy
printf 'session\n' > "$BUSY_DATA/Cookies"
PATH="$PGREP_STUB:$PATH" ai rm "Fake Busy" --purge -y
assert_rc_nonzero "rm --purge refuses a profile that is running" "$RUN_RC" "$RUN_OUT"
assert_file "the running profile's session survives" "$BUSY_DATA/Cookies"
# An inherited PS_RC=0 and an empty list, end to end.
PS_RC=0 PS_LIST="" PATH="$PGREP_STUB:$PATH" ai rm "Fake Busy" --purge -y
assert_rc_nonzero "an inherited PS_RC does not switch the check off" "$RUN_RC" "$RUN_OUT"
assert_file "and the session survives" "$BUSY_DATA/Cookies"
# A pgrep that fails is not "nothing is running".
PATH="$FAIL_PGREP:$PATH" ai rm "Fake Busy" --purge -y
assert_rc_nonzero "rm --purge refuses when pgrep fails" "$RUN_RC" "$RUN_OUT"
assert_contains "and says it could not check" "$RUN_OUT" "Could not check which profiles are running (pgrep exited 3)"
assert_file "the session survives a failed check" "$BUSY_DATA/Cookies"
PATH="$PGREP_STUB:$PATH" ai prune -y
assert_file "prune leaves a running, claimed profile alone" "$BUSY_DATA/Cookies"
ai rm "Fake Busy" --purge -y
assert_no_dir "once it stops, --purge deletes it" "$BUSY_DATA"
