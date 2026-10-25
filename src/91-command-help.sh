# --------------------------------------------------------- command help --

# The help of one command, by its name. The first line, the "Also spelled"
# line and the -h, --help line come from the command table; help_text has the
# rest. "Also spelled" goes before the first OPTIONS, EXAMPLES or SET UP
# heading. The -h, --help line closes the OPTIONS block, at its first blank
# line, so an OPTIONS block must have no blank line inside and one after it. A
# page with no OPTIONS gets a short one, so every page has the -h line.
command_help() {
  local line also="" w stage=0 h='  -h, --help           Show this help'
  command_row "$1" || return 1
  for w in $CMD_ALIASES; do also="${also:+$also, }$w"; done
  printf '%saidentity %s%s — %s\n\n' "$C_BOLD" "$CMD_NAME" "$C_RESET" "$CMD_SUMMARY"
  while IFS= read -r line; do
    case "$stage:$line" in
      0:OPTIONS|0:EXAMPLES|"0:SET UP")
        [ -z "$also" ] || printf 'Also spelled: %s\n\n' "$also"
        printf '%sOPTIONS%s\n' "$C_BOLD" "$C_RESET"
        stage=1
        [ "$line" = OPTIONS ] && continue
        printf '%s\n\n' "$h"; stage=2 ;;
      1:) printf '%s\n' "$h"; stage=2 ;;
    esac
    case "$line" in
      USAGE|OPTIONS|EXAMPLES|"SET UP") printf '%s%s%s\n' "$C_BOLD" "$line" "$C_RESET" ;;
      *) printf '%s\n' "$line" ;;
    esac
  done <<EOF
$(help_text "$CMD_NAME")
EOF
}

# What each command's help says beyond the command table: usage, what it does,
# its options and examples.
help_text() {
  case "$1" in
    setup) cat <<'EOF'
USAGE
  aidentity setup

Asks which app to use and what to call each account, then builds all the
launchers in one pass. It needs a terminal. Without one, use 'aidentity add'.

EXAMPLES
  aidentity setup
EOF
    ;;
    add) cat <<'EOF'
USAGE
  aidentity add [APP] [options]

APP is the name of an installed Chromium or Electron app, such as Claude, or the
path to its .app. Run 'aidentity apps' to see which apps work. With no APP or no
--profile, add asks for them. That needs a terminal.

OPTIONS
  -p, --profile NAME   Name for this account, e.g. Work
  -b, --badge X        One character for the icon badge (default: first letter)
  -c, --color NAME     Badge colour: blue green orange purple teal pink red
                       yellow gray graphite, or a hex value like 2E7DF6
  --no-badge           Use the app's own icon, with your name
  --seed               Copy Claude Desktop's MCP server config into the profile
  --main               Build a launcher for your ORIGINAL account (name: Main).
                       While a profile runs, macOS treats it as the app, so
                       the app's own icon only switches to that profile.
  --arg SWITCH         Pass a switch on every launch: a proxy, language,
                       display scale or GPU switch. Repeat to add more.
  --env NAME=VALUE     Set a proxy variable, LANG, LC_ALL, LC_CTYPE, LC_MESSAGES
                       or TZ on every launch. Repeat to add more.
  --own-extensions     VS Code, Cursor, Kiro: a separate extensions folder

EXAMPLES
  aidentity add Claude --profile Work
  aidentity add Claude --profile Work --color blue --seed
  aidentity add Claude --main
EOF
    ;;
    rename) cat <<'EOF'
USAGE
  aidentity rename OLD NEW

OLD is the launcher name that 'aidentity list' shows. NEW is the new profile
name, without the app name. The profile's data folder moves with it, so the
account stays signed in. It stops if the profile is running.

EXAMPLES
  aidentity rename "Claude Work" Client
EOF
    ;;
    set) cat <<'EOF'
USAGE
  aidentity set NAME [options]

NAME is the launcher name that 'aidentity list' shows. Give at least one option.
The account and its data are not touched.

OPTIONS
  -c, --color NAME     New badge colour
  -b, --badge X        New badge character
  --no-badge           Use the app's own icon, unchanged
  --arg SWITCH         Add a launch switch, as on add (repeatable)
  --env NAME=VALUE     Add a launch variable, as on add (repeatable)
  --clear-args         Remove every launch switch
  --clear-env          Remove every launch variable
  --own-extensions     VS Code, Cursor, Kiro: a separate extensions folder
  --shared-extensions  Go back to the app's own extensions folder

EXAMPLES
  aidentity set "Claude Work" --color purple
  aidentity set "Claude Work" --arg --lang=de
EOF
    ;;
    prune) cat <<'EOF'
USAGE
  aidentity prune [options]

Finds profile folders that no launcher points at. They are left when a launcher
is deleted in Finder, or removed with 'rm' without --purge. It lists them, asks
first, then moves them to the Trash. To keep an account instead, rebuild its
launcher with 'aidentity restore'. A folder moved back from the Trash can be
restored the same way.

OPTIONS
  -y, --yes            Skip the confirmation prompt

EXAMPLES
  aidentity prune
EOF
    ;;
    restore) cat <<'EOF'
USAGE
  aidentity restore [NAME | --all]

Each profile folder keeps a small record of its launcher. restore reads it and
rebuilds the launcher, still signed in. With no NAME and no --all, it lists the
profiles that can be restored.

OPTIONS
  -a, --all            Restore every one of them

EXAMPLES
  aidentity restore
  aidentity restore "Claude Work"
  aidentity restore --all
EOF
    ;;
    rebuild) cat <<'EOF'
USAGE
  aidentity rebuild NAME
  aidentity rebuild --all

Writes the launcher again from what it records. Profile data is not touched,
so every account stays signed in.

OPTIONS
  -a, --all            Rebuild every profile

EXAMPLES
  aidentity rebuild "Claude Work"
  aidentity rebuild --all
EOF
    ;;
    list) cat <<'EOF'
USAGE
  aidentity list [options]

For each profile it shows the app, the profile name, where its data lives and
its status: running, in use, signed out / new, app missing or not running.

OPTIONS
  --json               Print one JSON array instead, with an object for each
                       launcher, for scripts. Variables are listed by name,
                       never by value.

EXAMPLES
  aidentity list
  aidentity ls --json
EOF
    ;;
    open) cat <<'EOF'
USAGE
  aidentity open NAME

NAME is the launcher name that 'aidentity list' shows. Put it in quotes when it
has a space.

EXAMPLES
  aidentity open "Claude Work"
EOF
    ;;
    quit) cat <<'EOF'
USAGE
  aidentity quit NAME

NAME is the launcher name that 'aidentity list' shows. It quits the copy of the
app that runs on that profile, and every other copy keeps running. For a main
launcher, that is the copy on your original account. The app is asked to quit
the way its Quit menu item does, so it can still ask about unsaved work. If it
cannot be asked, its process is sent SIGTERM, which these apps also treat as
quit. It waits up to 10 seconds, and exits 1 if the app is still running then.

EXAMPLES
  aidentity quit "Claude Work"
EOF
    ;;
    rm) cat <<'EOF'
USAGE
  aidentity rm NAME [options]

Removes the launcher and keeps its data, so 'aidentity restore' can bring it
back. It asks you to type yes first. It stops if the profile is running, and it
only removes launchers that aidentity built.

OPTIONS
  --purge              Also move the profile's data to the Trash. To undo, move
                       it back and run 'aidentity restore'. A main launcher
                       has no profile data, so nothing more is moved for it.
  -y, --yes            Skip the confirmation prompt

EXAMPLES
  aidentity rm "Claude Work"
  aidentity rm "Claude Work" --purge
EOF
    ;;
    apps) cat <<'EOF'
USAGE
  aidentity apps

Lists the Chromium and Electron apps found in /Applications and ~/Applications.
Only these apps can run more than one account.

EXAMPLES
  aidentity apps
EOF
    ;;
    doctor) cat <<'EOF'
USAGE
  aidentity doctor [options]

Shows the macOS, aidentity and bash versions, whether the launcher folder can be
written, and any problem it finds in a profile. It only reports, unless you give
--fix.

OPTIONS
  --fix                Repair what can be repaired: rebuild stale launchers
                       and make profile folders owner-only

EXAMPLES
  aidentity doctor
  aidentity doctor --fix
EOF
    ;;
    update) cat <<'EOF'
USAGE
  aidentity update [options]

Asks GitHub for the latest release. If it is newer, downloads it, checks it
against the release's checksum, and replaces this copy in one step. This is the
only command that uses the network, and only when you run it. It never uses
sudo. A copy installed with Homebrew is updated with: brew upgrade aidentity

OPTIONS
  --check              Only say whether a newer release is out

EXAMPLES
  aidentity update --check
  aidentity update
EOF
    ;;
    ui) cat <<'EOF'
USAGE
  aidentity ui

A full-screen menu in Terminal: every profile, what is running, and keys to
open, quit, add, rename, recolour, change the badge, remove, and run doctor.
Each key runs the same command you would type, with the same checks. It needs
a terminal; in a script, use the commands themselves or aidentity list --json.
Press ? in the menu for its keys, and q to leave.

EXAMPLES
  aidentity ui
EOF
    ;;
    completion) cat <<'EOF'
USAGE
  aidentity completion SHELL

SHELL is bash, zsh or fish. The script goes to standard output. It completes
commands, options, profile names, app names and colours. A name with a space
is quoted for you. Homebrew installs these scripts for you.

SET UP
  bash   eval "$(aidentity completion bash)"     in ~/.bashrc
  zsh    eval "$(aidentity completion zsh)"      in ~/.zshrc, after compinit
  fish   aidentity completion fish | source      in ~/.config/fish/config.fish

EXAMPLES
  aidentity completion zsh
EOF
    ;;
    version) cat <<'EOF'
USAGE
  aidentity version

EXAMPLES
  aidentity version
EOF
    ;;
    help) cat <<'EOF'
USAGE
  aidentity help [COMMAND]
  aidentity COMMAND --help

With no COMMAND it shows every command. With one it shows that command's
options and examples. aidentity -h and aidentity --help show the same overview
as aidentity help, and ignore what comes after them. After a command, -h or
--help shows that command's help and does nothing else.

EXAMPLES
  aidentity help
  aidentity help rm
  aidentity rm --help
EOF
    ;;
  esac
}

# aidentity help [command]
cmd_help() {
  [ $# -le 1 ] || die "Usage: aidentity help [command]"
  if [ $# -eq 0 ]; then cmd_overview; return 0; fi
  command_row "$1" && [ "${CMD_NAME#__}" = "$CMD_NAME" ] \
    || die "No help for '$1'. Run 'aidentity help' to see the commands."
  command_help "$CMD_NAME"
}

# aidentity on its own, aidentity help, -h and --help: every command in a line.
cmd_overview() {
  local n a p o s
  cat <<EOF
${C_BOLD}aidentity${C_RESET} — run several accounts of the same Mac app at the same time.

${C_BOLD}USAGE${C_RESET}
  aidentity <command> [options]

${C_BOLD}COMMANDS${C_RESET}
EOF
  while IFS='|' read -r n a p o s; do
    case "$n" in __*) ;; *) printf '  %-12s %s\n' "$n" "$s" ;; esac
  done <<EOF
$COMMANDS
EOF
  cat <<EOF

Run 'aidentity help COMMAND' or 'aidentity COMMAND --help' for its options.

${C_BOLD}EXAMPLES${C_RESET}
  aidentity setup
  aidentity ui
  aidentity add Claude --profile Work --color blue --seed
  aidentity add ChatGPT --profile Personal
  aidentity add Claude --main
  aidentity list
  aidentity rename "Claude Work" Client
  aidentity set "Claude Work" --color purple
  aidentity rebuild --all
  aidentity doctor --fix
  aidentity restore "Claude Work"
  aidentity prune
  aidentity rm "Claude Work" --purge
  aidentity help rm
  aidentity completion zsh
  aidentity update --check

${C_BOLD}ENVIRONMENT${C_RESET}
  AIDENTITY_APPS_DIR    Where launchers are written (default: ~/Applications)
  AIDENTITY_DATA_ROOT   Where profile data lives (default:
                        ~/Library/Application Support/aidentity/profiles)
  AIDENTITY_APP_DIRS    Folders searched for apps, colon-separated
                        (default: /Applications:~/Applications)

${C_BOLD}HOW IT WORKS${C_RESET}
  Chromium and Electron apps keep their single-instance lock inside their data
  directory. Point a second instance at a different directory and the two never
  see each other's lock, so both run at once — each signed into its own account.

  aidentity builds a small launcher app that does exactly that. Your real app is
  never copied, patched or re-signed, so its signature, keychain access and
  auto-update all keep working.

${C_BOLD}MORE${C_RESET}
  https://github.com/PiniShv/aidentity
EOF
}
