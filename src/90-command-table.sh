# ---------------------------------------------------------- command table --

# Every command, one row each:
#
#   name | other spellings | its first argument | options | summary
#
# The first argument is apps, launchers, restorable, shells or commands (what
# Tab offers for it), or - for none. An option lists its spellings joined by /,
# the one Tab offers first, and ends in = when it takes the next word as its
# value. A name that starts with __ is hidden: it has no help page and is never
# listed or offered by Tab, but it and its other spellings still run, and a -h
# or --help after it is not read as a request for help. Dispatch, help, the
# overview and completion all read this table, so a command, spelling or option
# added here reaches all of them. The command runs as the function cmd_ and its
# name, without the __: cmd_add, cmd_overview.
COMMANDS='setup|init wizard|-||Guided walkthrough that sets up accounts (start here)
ui||-||Full-screen menu over your profiles
add||apps|--profile/-p= --badge/-b= --color/--colour/-c= --no-badge --seed --main --arg= --env= --own-extensions|Create a profile for an app
list|ls|-|--json|Show every profile and what is running
open||launchers||Open a profile
quit||launchers||Quit one profile; other copies of the app keep running
rename|mv|launchers||Rename a profile and keep it signed in
set|modify edit|launchers|--badge/-b= --color/--colour/-c= --no-badge --arg= --env= --clear-args --clear-env --own-extensions --shared-extensions|Change how a profile looks or starts
prune||-|--yes/-y|Remove profile data that no launcher uses
restore||restorable|--all/-a|Rebuild a launcher that was deleted
rebuild|repair|launchers|--all/-a|Rebuild launchers after an app moved or updated
rm|remove delete|launchers|--purge --yes/-y|Remove a launcher
apps||-||List apps that can have extra accounts
doctor||-|--fix|Check the setup and every profile
update||-|--check|Install the latest release
completion||shells||Print a tab-completion script
version|--version -v|-||Print the version
help||commands||Show help for all commands or for one
__overview|-h --help|-||List every command
__complete||-||Print what Tab can offer'

# command_row WORD: find the row whose name or other spelling is WORD, and set
# CMD_NAME, CMD_ALIASES, CMD_ARG, CMD_OPTS and CMD_SUMMARY from it. Returns 1,
# with all five empty, when there is none.
command_row() {
  local w
  while IFS='|' read -r CMD_NAME CMD_ALIASES CMD_ARG CMD_OPTS CMD_SUMMARY; do
    for w in "$CMD_NAME" $CMD_ALIASES; do
      [ "$1" = "$w" ] && return 0
    done
  done <<EOF
$COMMANDS
EOF
  CMD_NAME=""; CMD_ALIASES=""; CMD_ARG=""; CMD_OPTS=""; CMD_SUMMARY=""
  return 1
}

# The words that name a command, a line each: the word, a tab and what it does.
# Every name and other spelling that is not hidden, or with "-" only those that
# start with a dash. Another spelling is "Same as" its command, unless that
# command is hidden.
command_words() {
  local n a p o s d w
  while IFS='|' read -r n a p o s; do
    d="$s"
    for w in $n $a; do
      case "$w:${1:-}" in
        __*) ;;
        -*:-|[!-]*:) printf '%s\t%s\n' "$w" "$d" ;;
      esac
      case "$n" in __*) ;; *) d="Same as $n" ;; esac
    done
  done <<EOF
$COMMANDS
EOF
}
