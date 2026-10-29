# shellcheck shell=bash
#
# Dashboard command validation. Server behavior is tested in Python.

group "dashboard command"

ai dashboard --help
assert_rc "dashboard help succeeds" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "dashboard help describes localhost" "$RUN_OUT" "127.0.0.1"
assert_contains "dashboard help documents no-open" "$RUN_OUT" "--no-open"
assert_contains "dashboard help documents Python" "$RUN_OUT" "Python 3"

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
