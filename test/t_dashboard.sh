# shellcheck shell=bash
#
# Dashboard command validation. Server behavior is tested in Python.

group "dashboard command"

ai dashboard --help
assert_rc "dashboard help succeeds" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "dashboard help describes localhost" "$RUN_OUT" "127.0.0.1"
assert_contains "dashboard help documents no-open" "$RUN_OUT" "--no-open"
assert_contains "dashboard help documents Python" "$RUN_OUT" "Python 3"
assert_contains "dashboard help documents stop" "$RUN_OUT" "--stop"

for port in -1 65536 nope 1.2 ""; do
  ai dashboard --port "$port" --no-open
  assert_rc_nonzero "dashboard refuses invalid port [$port]" "$RUN_RC" "$RUN_OUT"
  assert_contains "dashboard explains the port bounds" "$RUN_OUT" "0 to 65535"
done
ai dashboard --port
assert_rc_nonzero "dashboard refuses a missing port" "$RUN_RC" "$RUN_OUT"
ai dashboard unexpected --no-open
assert_rc_nonzero "dashboard refuses positional arguments" "$RUN_RC" "$RUN_OUT"
ai dashboard --host 0.0.0.0
assert_rc_nonzero "dashboard cannot bind a public interface" "$RUN_RC" "$RUN_OUT"
for extra in "--port 1" --no-open; do
  # shellcheck disable=SC2086 # $extra is one option, or an option and its value
  ai dashboard --stop $extra
  assert_rc_nonzero "dashboard refuses --stop with $extra" "$RUN_RC" "$RUN_OUT"
  assert_contains "dashboard says --stop takes no other option [$extra]" "$RUN_OUT" "cannot be combined"
done

# The server itself, end to end: it starts in the background, a second start
# reuses it, and --stop ends it. It needs Python 3.9 or newer, like the command.
if command -v python3 >/dev/null 2>&1 \
    && python3 -I -c 'import sys; sys.exit(sys.version_info < (3, 9))' 2>/dev/null; then
  # A failed assertion, or an interrupted run, must not leave a server behind.
  trap '"$BASH_BIN" "$AIDENTITY" dashboard --stop >/dev/null 2>&1 </dev/null; cleanup' EXIT INT TERM

  ai dashboard --stop
  assert_rc "--stop with no dashboard running succeeds" 0 "$RUN_RC" "$RUN_OUT"
  assert_contains "--stop says no dashboard is running" "$RUN_OUT" "No dashboard is running."

  # `ai` reads the output through a pipe, which ends only once the background
  # server lets go of it. The loop bounds the wait, so a server that keeps the
  # pipe fails here instead of hanging the suite; the trap's --stop frees it.
  rm -f "$SANDBOX/dashboard.rc" "$SANDBOX/dashboard.out"
  ( ai dashboard --no-open
    printf '%s' "$RUN_OUT" > "$SANDBOX/dashboard.out"; printf '%s' "$RUN_RC" > "$SANDBOX/dashboard.rc" ) &
  waited=0
  while kill -0 $! 2>/dev/null && [ "$waited" -lt 100 ]; do sleep 0.1; waited=$((waited + 1)); done
  RUN_RC=$(cat "$SANDBOX/dashboard.rc" 2>/dev/null || printf 'none: still waiting after 10 seconds')
  RUN_OUT=$(cat "$SANDBOX/dashboard.out" 2>/dev/null)
  assert_rc "dashboard starts in the background and returns within 10 seconds" 0 "$RUN_RC" "$RUN_OUT"
  url=$(printf '%s\n' "$RUN_OUT" | sed -n 's|^aidentity dashboard: \(http://127\.0\.0\.1:[0-9][0-9]*\)$|\1|p')
  assert_nonempty "dashboard prints its address" "$url"
  assert_contains "dashboard says how to stop it" "$RUN_OUT" "aidentity dashboard --stop"
  assert_eq "the background dashboard answers" 200 \
    "$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 "$url/" 2>&1)"

  ai dashboard --no-open
  assert_rc "a second dashboard reuses the running one" 0 "$RUN_RC" "$RUN_OUT"
  assert_contains "a second dashboard names the running one" "$RUN_OUT" "$url (already running)"

  port=${url##*:}
  ai dashboard --no-open --port $(( port == 65535 ? 65534 : port + 1 ))
  assert_rc "a second dashboard refuses another port" 1 "$RUN_RC" "$RUN_OUT"
  assert_contains "a second dashboard says to stop the first" "$RUN_OUT" "Run 'aidentity dashboard --stop' first"

  ai dashboard --stop
  assert_rc "--stop stops the running dashboard" 0 "$RUN_RC" "$RUN_OUT"
  assert_contains "--stop says the dashboard stopped" "$RUN_OUT" "Dashboard stopped."
  curl -s -o /dev/null --max-time 2 "$url/"
  assert_rc_nonzero "the stopped dashboard's port refuses connections" "$?"
  trap cleanup EXIT INT TERM
else
  _skip "dashboard runs in the background and --stop stops it" "Python 3.9 or newer is not installed"
fi
