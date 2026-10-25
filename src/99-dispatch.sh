# -------------------------------------------------------------- dispatch --

main() {
  local a
  # No command at all is the overview, as it always was.
  if ! command_row "${1:-help}"; then
    printf '%sUnknown command: %s%s\n\n' "$C_RED" "${1:-}" "$C_RESET" >&2; cmd_overview >&2; exit 1
  fi
  [ $# -gt 0 ] && shift
  # -h or --help anywhere after a command shows that command's help and runs
  # nothing else, whatever else was typed: `rm Work --help` removes nothing.
  # This runs before the command reads its arguments. A profile name cannot
  # start with a hyphen, so no real value is ever taken for it. A hidden
  # command has no help: the overview ignores what follows it, and __complete
  # is handed the words typed so far, a -h among them.
  case "$CMD_NAME" in
    __*) ;;
    *) for a in "$@"; do
         case "$a" in -h|--help) command_help "$CMD_NAME"; return 0 ;; esac
       done ;;
  esac
  # Each command reads its own arguments and refuses what it does not take.
  # setup, apps and version take none and ignore extra words on purpose, as
  # they always have: a script that passes one keeps working.
  "cmd_${CMD_NAME#__}" "$@"
}

# Never change this line, and keep it last. Installed copies of 1.4.0 refuse
# an update that does not end on it, with their own fixed copy of the check:
# a new last line would stop all of them from updating. scripts/guards.sh
# (check 7) pins the exact text.
main "$@"
