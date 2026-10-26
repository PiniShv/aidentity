# shellcheck shell=bash
#
# Area "help": help for one command, and --help never running the command.
# Sourced by test/run_tests.sh after test/lib.sh. Run it alone with:
#   bash test/run_tests.sh help

group "help for one command"

# The command table, a row per command: name|spellings|argument|options|summary.
# The checks below loop over it, so a new command or spelling is tested too.
read_command_table
assert_rc "the command table can be read" 0 "$RUN_RC" "$RUN_OUT"
assert_nonempty "it has rows" "${CMD_ROWS[*]:-}"

ai help
HELP_ALL="$RUN_OUT"
assert_rc "help exits 0" 0 "$RUN_RC" "$RUN_OUT"
for row in "${CMD_ROWS[@]}"; do
  IFS='|' read -r c als arg opts summary <<< "$row"
  pipes=${row//[!|]/}
  assert_eq "the row for $c has five fields" "||||" "$pipes"
  libcall type -t "cmd_${c#__}"
  assert_eq "$c runs as the function cmd_${c#__}" "function" "$RUN_OUT"
  case "$c" in
    __*)
      ai help "$c"
      assert_rc_nonzero "the hidden $c has no help" "$RUN_RC" "$RUN_OUT"
      assert_not_contains "and the overview leaves it out" "$HELP_ALL" "$c"
      continue ;;
  esac
  assert_contains "the overview lists $c with what it does" "$HELP_ALL" "$(printf '  %-12s %s' "$c" "$summary")"
  for w in "$c" $als; do
    ai "$w" --help
    assert_rc "$w --help exits 0" 0 "$RUN_RC" "$RUN_OUT"
    assert_contains "$w --help names its command and what it does" "$RUN_OUT" "aidentity $c — $summary"
    assert_contains "$w --help has a usage section" "$RUN_OUT" "USAGE"
    assert_contains "$w --help lists -h, --help" "$RUN_OUT" "  -h, --help "
    assert_contains "$w --help has an example" "$RUN_OUT" "EXAMPLES"
    HELP_LONG="$RUN_OUT"
    ai "$w" -h
    assert_eq "$w -h prints the same as $w --help" "$HELP_LONG" "$RUN_OUT"
    ai help "$w"
    assert_eq "help $w prints the same as $w --help" "$HELP_LONG" "$RUN_OUT"
    [ "$w" = "$c" ] || assert_contains "help for $c names its spelling $w" "$HELP_LONG" "$w"
  done
  # Tab offers what the row says the first argument is. The usage line, written
  # by hand, must say the same: NAME or OLD is a profile, APP an app, and so on.
  first=$(printf '%s\n' "$HELP_LONG" | awk '/USAGE/ { getline; print $3; exit }' | tr -d '[]')
  case "$first" in
    NAME|OLD) took="launchers restorable" ;;
    APP)      took=apps ;;
    SHELL)    took=shells ;;
    COMMAND)  took=commands ;;
    *)        took=- ;;
  esac
  case " $took " in
    *" $arg "*) _pass "the row for $c takes what its usage line says ($arg)" ;;
    *) _fail "the row for $c takes what its usage line says" "row: [$arg]" "usage: [$first]" ;;
  esac
  # Every option is in the help, by the spelling Tab offers and its short one.
  # The help shows a value after it exactly when the row says it takes one,
  # which is what Tab skips.
  for o in $opts; do
    long=${o%%[/=]*}; short=""
    for s in $(printf '%s' "${o%=}" | tr '/' ' '); do
      case "$s" in --*) ;; -*) short="$s, " ;; esac
    done
    assert_contains "help for $c documents $long" "$HELP_LONG" "  $short$long"
    value=$(printf '%s\n' "$HELP_LONG" | awk -v o="  $short$long" \
      'index($0, o " ") == 1 { s = substr($0, length(o) + 1); sub(/  .*/, "", s); print s; exit }')
    case "$o" in *=) want=yes ;; *) want=no ;; esac
    [ -n "$value" ] && got=yes || got=no
    assert_eq "help for $c shows a value after $long exactly when its row does" "$want" "$got"
  done
done

assert_contains "the overview points to the help of one command" "$HELP_ALL" "Run 'aidentity help COMMAND'"
assert_contains "its examples include quit" "$HELP_ALL" '  aidentity quit "Claude Work"'
assert_contains "and export" "$HELP_ALL" "  aidentity export > profiles.json"
ai help prune
assert_contains "prune's help promises restore only for the folders marked so" "$RUN_OUT" \
  'this works for the folders the list marks
"can be restored"'
assert_contains "and gives add for the others" "$RUN_OUT" "add the profile again with the"
ai help ui
assert_contains "ui's help calls the s key stop, as the menu does" "$RUN_OUT" \
  "keys to
open, stop (quit a profile), add, rename"
ai
assert_eq "no arguments print the overview, as before" "$HELP_ALL" "$RUN_OUT"
ai --help
assert_eq "--help prints the overview" "$HELP_ALL" "$RUN_OUT"
ai -h rm
assert_rc "-h before a command is still the overview" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "and ignores what follows, as before" "$HELP_ALL" "$RUN_OUT"
ai --help rm -h
assert_eq "a -h after it too: the overview is hidden, so it has no help page" "$HELP_ALL" "$RUN_OUT"
ai help help
assert_contains "the help for help says -h on its own shows the overview" "$RUN_OUT" "aidentity -h and aidentity --help show the same overview"
assert_contains "and that what follows it is ignored" "$RUN_OUT" "ignore what comes after them"

ai_stdout help definitely-not-a-command
assert_rc_nonzero "help for an unknown command fails" "$RUN_RC" "$RUN_OUT"
assert_eq "and prints nothing on stdout" "" "$RUN_OUT"
assert_contains "and says which name has no help" "$RUN_ERR" "definitely-not-a-command"
ai help --bogus
assert_rc_nonzero "help for an unknown option fails" "$RUN_RC" "$RUN_OUT"
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
