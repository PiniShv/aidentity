# shellcheck shell=bash
# SC2016: single-quoted scripts are handed to "$BASH_BIN" -c and to generated
# stubs, which expand them later, on purpose. shellcheck only recognises that
# when the interpreter is spelled literally as `bash -c`.
# shellcheck disable=SC2016
# SC2153: BASH_BIN is set in lib.sh, which shellcheck does not read together
# with this file; it takes it for a misspelling of FISH_BIN.
# shellcheck disable=SC2153
#
# Area "completion": the completion scripts, the candidates, the words table, and bash, zsh and
# fish behaviour.
# Sourced by test/run_tests.sh after test/lib.sh. Run it alone with:
#   bash test/run_tests.sh completion

group "shell completion scripts"

for sh in bash zsh fish; do
  ai_stdout completion "$sh"
  assert_rc "completion $sh exits 0" 0 "$RUN_RC" "$RUN_ERR"
  assert_nonempty "completion $sh prints a script" "$RUN_OUT"
  assert_eq "completion $sh prints nothing on stderr" "" "$RUN_ERR"
  assert_contains "completion $sh asks aidentity what fits" "$RUN_OUT" "aidentity __complete $sh"
  printf '%s\n' "$RUN_OUT" > "$SANDBOX/completion.$sh"
done

if "$BASH_BIN" -n "$SANDBOX/completion.bash" 2>/dev/null; then
  _pass "the bash script is valid bash"
else
  _fail "the bash script is valid bash" "$("$BASH_BIN" -n "$SANDBOX/completion.bash" 2>&1)"
fi
if command -v bash >/dev/null 2>&1 && bash -n "$SANDBOX/completion.bash" 2>/dev/null; then
  _pass "and valid for the first bash on PATH"
else
  _fail "and valid for the first bash on PATH" "bash -n failed"
fi

ZSH_BIN=$(command -v zsh 2>/dev/null || true)
if [ -n "$ZSH_BIN" ]; then
  if "$ZSH_BIN" -n "$SANDBOX/completion.zsh" 2>/dev/null; then
    _pass "the zsh script is valid zsh"
  else
    _fail "the zsh script is valid zsh" "$("$ZSH_BIN" -n "$SANDBOX/completion.zsh" 2>&1)"
  fi
  # Loaded the way the README says, it registers itself for aidentity.
  ZSH_REG=$(HOME="$SANDBOX/tty-home" "$ZSH_BIN" -f -c '
    autoload -Uz compinit; compinit -u -d "$1/zcompdump" >/dev/null 2>&1
    eval "$(cat "$2")"; print -r -- "${_comps[aidentity]}"' zsh "$SANDBOX" "$SANDBOX/completion.zsh" 2>&1)
  assert_eq "zsh registers the completion function for aidentity" "_aidentity" "$ZSH_REG"
else
  _skip "the zsh script is valid zsh" "zsh is not installed"
  _skip "zsh registers the completion function for aidentity" "zsh is not installed"
fi

FISH_BIN=$(command -v fish 2>/dev/null || true)
if [ -n "$FISH_BIN" ]; then
  if "$FISH_BIN" --no-execute "$SANDBOX/completion.fish" 2>/dev/null; then
    _pass "the fish script is valid fish"
  else
    _fail "the fish script is valid fish" "$("$FISH_BIN" --no-execute "$SANDBOX/completion.fish" 2>&1)"
  fi
else
  _skip "the fish script is valid fish" "fish is not installed; the fish script was not syntax-checked"
fi

ai_stdout completion tcsh
assert_rc_nonzero "an unknown shell exits non-zero" "$RUN_RC" "$RUN_ERR"
assert_eq "and prints no script" "" "$RUN_OUT"
assert_contains "and names the shell" "$RUN_ERR" "tcsh"
assert_contains "and says what is supported" "$RUN_ERR" "bash, zsh or fish"
ai_stdout completion
assert_rc_nonzero "no shell exits non-zero" "$RUN_RC" "$RUN_ERR"
assert_contains "and shows the usage" "$RUN_ERR" "Usage: aidentity completion"
ai completion bash zsh
assert_rc_nonzero "two shells are refused" "$RUN_RC" "$RUN_OUT"
ai completion --bogus
assert_rc_nonzero "an unknown option is refused" "$RUN_RC" "$RUN_OUT"

# Homebrew's default shells are bash, zsh and fish. Naming them is refused by
# brew audit --strict, so the line must not list them.
if grep -qxF '    generate_completions_from_executable(bin/"aidentity", "completion")' "$REPO_DIR/Formula/aidentity.rb"; then
  _pass "the Homebrew formula installs bash, zsh and fish completions"
else
  _fail "the Homebrew formula installs bash, zsh and fish completions" "no generate_completions_from_executable line with the default shells"
fi

group "completion candidates (__complete)"

ai add "$ELECTRON_APP" --profile "Home Office"
ai add "$ELECTRON_APP" --profile Work
ai add "$ELECTRON_APP" --profile Gone
ai rm "Fake Gone" -y
make_decoy_app "$APPS/Decoy.app"

has_line() { # description, text, line: the line is there whole, spaces and all
  if printf '%s\n' "$2" | grep -Fxq -- "$3"; then _pass "$1"; else _fail "$1" "no line [$3]" "in: [$2]"; fi
}
lacks_line() {
  if printf '%s\n' "$2" | grep -Fxq -- "$3"; then _fail "$1" "unexpected line [$3]" "in: [$2]"; else _pass "$1"; fi
}

ai_stdout __complete launchers
assert_rc "__complete launchers exits 0" 0 "$RUN_RC" "$RUN_ERR"
assert_eq "and prints nothing on stderr" "" "$RUN_ERR"
has_line "it lists a profile name" "$RUN_OUT" "Fake Work"
has_line "it lists a profile name with a space in the profile" "$RUN_OUT" "Fake Home Office"
lacks_line "it leaves out an app that is not a launcher" "$RUN_OUT" "Decoy"
lacks_line "and a profile whose launcher is gone" "$RUN_OUT" "Fake Gone"
assert_not_contains "and prints no colour codes or paths" "$RUN_OUT" "/"

make_electron_app "$SRC/Space Case.app"
ai_stdout __complete apps
assert_rc "__complete apps exits 0" 0 "$RUN_RC" "$RUN_ERR"
has_line "it lists an Electron app" "$RUN_OUT" "Fake"
has_line "and an app whose name has a space" "$RUN_OUT" "Space Case"
has_line "it lists a Chromium fork" "$RUN_OUT" "Forky"
lacks_line "it leaves out a native app" "$RUN_OUT" "Nativey"
lacks_line "and the launchers" "$RUN_OUT" "Fake Work"

# A folder name is not trusted: an escape sequence in one must not reach the
# terminal through the list Tab prints.
ESC=$(printf '\033')
make_electron_app "$SRC/Evil${ESC}[31mApp.app"
cp -R "$APPS/Fake Work.app" "$APPS/Fake ${ESC}[31mRed.app"
ai_stdout __complete apps
assert_not_contains "an app name with an escape character is left out" "$RUN_OUT" "Evil"
assert_not_contains "and no escape character is printed" "$RUN_OUT" "$ESC"
ai_stdout __complete launchers
assert_not_contains "a launcher name with an escape character is left out" "$RUN_OUT" "Red"
assert_not_contains "and no escape character is printed for launchers" "$RUN_OUT" "$ESC"
has_line "the other launchers are still listed" "$RUN_OUT" "Fake Work"
rm -rf "$SRC/Evil${ESC}[31mApp.app" "$APPS/Fake ${ESC}[31mRed.app"

ai_stdout __complete restorable
assert_rc "__complete restorable exits 0" 0 "$RUN_RC" "$RUN_ERR"
has_line "it lists a profile whose launcher was removed" "$RUN_OUT" "Fake Gone"
lacks_line "and not one that still has a launcher" "$RUN_OUT" "Fake Work"

for what in bogus ""; do
  ai_stdout __complete "$what"
  assert_rc "__complete [$what] exits 0" 0 "$RUN_RC" "$RUN_ERR"
  assert_eq "__complete [$what] prints nothing" "" "$RUN_OUT"
  assert_eq "__complete [$what] says nothing on stderr" "" "$RUN_ERR"
done
ai_stdout __complete
assert_rc "__complete with no argument exits 0" 0 "$RUN_RC" "$RUN_ERR"
assert_eq "and prints nothing" "$RUN_OUT$RUN_ERR" ""

for what in launchers restorable apps; do
  RUN_OUT=$(AIDENTITY_APPS_DIR="$SB/no/such/folder" AIDENTITY_DATA_ROOT="$SB/no/such/data" \
    AIDENTITY_APP_DIRS="$SB/no/such/apps" detached "$BASH_BIN" "$AIDENTITY" __complete "$what" 2>"$SANDBOX/stderr" </dev/null)
  RUN_RC=$?
  assert_rc "__complete $what over folders that do not exist exits 0" 0 "$RUN_RC" "$RUN_OUT"
  assert_eq "and prints nothing" "" "$RUN_OUT$(cat "$SANDBOX/stderr")"
done

group "completion words, one table for all three shells"

# complete_words decides what Tab offers, for all three shells. Each case below
# gives the words typed after "aidentity", the last one under the cursor, and
# the words that must be offered. bash gets only the matches, quoted for it;
# zsh and fish get every candidate and match the typed word themselves, so
# comp_offered does that matching here, the way those shells do.
comp_offered() { # shell, then the words typed after "aidentity"
  local shell="$1" cur; shift
  cur="${!#}"
  libcall complete_words "$shell" "$#" aidentity "$@"
  case "$shell" in
    bash) printf '%s\n' "$RUN_OUT" | sed 's/\\\(.\)/\1/g' ;;
    zsh)  case "$RUN_OUT" in
            describe*) printf '%s\n' "$RUN_OUT" | sed '1d; s/:.*//' ;;
            *) printf '%s\n' "$RUN_OUT" | sed '1d' ;;
          esac ;;
    fish) printf '%s\n' "$RUN_OUT" | cut -f1 ;;
  esac | P="$cur" awk 'NF && index($0, ENVIRON["P"]) == 1' | LC_ALL=C sort
}
comp_case() { # description, the words offered (joined by |), the words typed
  local desc="$1" want sh; shift
  want=$(printf '%s' "$1" | tr '|' '\n' | LC_ALL=C sort); shift
  for sh in bash zsh fish; do
    assert_eq "$sh: $desc" "$want" "$(comp_offered "$sh" "$@")"
  done
}

# The command words come from the command table, like the help tests do.
read_command_table
ALL_WORDS=""; DASH_WORDS=""
for row in "${CMD_ROWS[@]}"; do
  IFS='|' read -r c als _ <<< "$row"
  for w in "$c" $als; do
    case "$w" in __*) ;; -*) DASH_WORDS="$DASH_WORDS|$w" ;; *) ALL_WORDS="$ALL_WORDS|$w" ;; esac
  done
done
libcall eval 'printf "%s|" $COLOR_NAMES'
COLOURS="$RUN_OUT"

comp_case "an empty word offers every command and spelling" "${ALL_WORDS#|}" ""
comp_case "a prefix narrows the commands" "rename|restore|rebuild|repair|remove" re
comp_case "a dash offers the dashed spellings" "${DASH_WORDS#|}" -
comp_case "an option prefix completes the option" "--purge" rm --p
comp_case "another spelling gets its command's options" "--purge" delete --pu
comp_case "list offers --json and --help" "--json|--help" ls --
comp_case "a command with no options offers --help" "--help" version -
comp_case "options are still offered after other arguments" "--seed" add Fake --profile Work --se
comp_case "an option before the name does not count as the name" "Fake Home Office|Fake Work" rm --purge ""
comp_case "a name with a space completes" "Fake Home Office" open "Fake H"
comp_case "rm takes one name, so nothing more is offered" "" rm "Fake Work" ""
comp_case "the new name for rename is not completed" "" rename "Fake Work" ""
comp_case "an app name with a space completes" "Space Case" add Spa
comp_case "--color offers every colour" "${COLOURS%|}" add --color ""
comp_case "-c completes a colour too" "purple" set "Fake Work" -c pu
comp_case "--colour completes a colour as well" "teal" set "Fake Work" --colour te
comp_case "a value that has no list offers nothing" "" add --profile ""
comp_case "an unknown command offers nothing" "" definitely-not-a-command ""
comp_case "a hidden command offers nothing" "" --help ""
# The help tests check each row against its usage line, which says NAME for
# both kinds of profile name. So this one is pinned here.
comp_case "restore offers only profiles that can be restored" "Fake Gone" restore ""

# Every command and every other spelling offers what its row says it takes
# first, and the value of each of its options is not taken for that. The
# typed word narrows the apps and the commands, as there are many.
for row in "${CMD_ROWS[@]}"; do
  IFS='|' read -r c als arg opts _ <<< "$row"
  case "$c" in __*) continue ;; esac
  typed=""
  case "$arg" in
    launchers)  want="Fake Home Office|Fake Work"; what="the launchers" ;;
    restorable) want="Fake Gone"; what="only the profiles that can be restored" ;;
    apps)       want="Forky"; typed=Fo; what="the apps" ;;
    shells)     want="bash|zsh|fish"; what="the three shells" ;;
    commands)   want="restore"; typed=rest; what="the commands" ;;
    -)          want=""; what="nothing, as it takes no name" ;;
    *)          _fail "the row for $c takes a known kind of argument" "[$arg]"; continue ;;
  esac
  for w in "$c" $als; do
    comp_case "$w offers $what" "$want" "$w" "$typed"
  done
  [ "$arg" = - ] && continue
  for o in $opts; do
    case "$o" in *=) ;; *) continue ;; esac
    o=${o%=}
    for s in ${o//\// }; do
      comp_case "$c $s VALUE still offers $what" "$want" "$c" "$s" x "$typed"
    done
  done
done

# __complete is hidden, so main hands it every word: a -h or --help typed
# before the Tab must reach it, not show a help page.
ai_stdout __complete zsh 3 aidentity rm -h ''
assert_rc "Tab after rm -h exits 0" 0 "$RUN_RC" "$RUN_ERR"
has_line "and offers the launchers" "$RUN_OUT" "Fake Work"
assert_not_contains "and prints no help page" "$RUN_OUT" "Show this help"
ai_stdout __complete bash 3 aidentity rm --help ''
has_line "Tab after rm --help offers the launchers in bash too" "$RUN_OUT" 'Fake\ Work'
ai_stdout __complete zsh 2 aidentity -h
assert_eq "Tab after -h alone offers nothing" "0:plain" "$RUN_RC:$RUN_OUT"

# What each shell gets besides the words.
libcall complete_words zsh 1 aidentity ""
assert_eq "zsh: the command is offered with descriptions" "describe" "$(printf '%s\n' "$RUN_OUT" | head -n 1)"
has_line "zsh: each with what it does" "$RUN_OUT" "add:Create a profile for an app"
has_line "zsh: and another spelling as the same as its command" "$RUN_OUT" "ls:Same as list"
libcall complete_words zsh 2 aidentity rm ""
assert_eq "zsh: names are offered plain" "plain" "$(printf '%s\n' "$RUN_OUT" | head -n 1)"
libcall complete_words fish 1 aidentity ""
has_line "fish: each command comes with what it does" "$RUN_OUT" "add"$'\t'"Create a profile for an app"
libcall complete_words fish 2 aidentity rm ""
has_line "fish: a name comes alone" "$RUN_OUT" "Fake Work"
for args in "bash" "bash x aidentity" "bash 7 aidentity rm" "fish 3 aidentity"; do
  # shellcheck disable=SC2086  # the words of each case, split on purpose
  ai_stdout __complete $args
  assert_eq "__complete $args prints nothing and exits 0" "0:" "$RUN_RC:$RUN_OUT$RUN_ERR"
done

group "bash completion behaviour"

COMP_BIN="$SANDBOX/comp-bin"
mkdir -p "$COMP_BIN"
printf '#!/bin/sh\nexec "%s" "%s" "$@"\n' "$BASH_BIN" "$AIDENTITY" > "$COMP_BIN/aidentity"
chmod +x "$COMP_BIN/aidentity"

# Run the script's function as bash would, with the words typed so far; the
# last one is the word under the cursor. RUN_OUT holds what COMPREPLY ends up
# with, one entry per line.
bash_complete() {
  RUN_OUT=$(PATH="$COMP_BIN:$PATH" "$BASH_BIN" -c '
    . "$1"; shift
    COMP_WORDS=("$@"); COMP_CWORD=$(( $# - 1 ))
    _aidentity
    for r in "${COMPREPLY[@]}"; do printf "%s\n" "$r"; done' aidentity-comp "$SANDBOX/completion.bash" "$@" 2>&1)
  RUN_RC=$?
}

bash_complete aidentity ""
assert_rc "completing the command works" 0 "$RUN_RC" "$RUN_OUT"
has_line "an empty word offers commands: add" "$RUN_OUT" "add"
has_line "and other spellings: ls" "$RUN_OUT" "ls"
lacks_line "but not options" "$RUN_OUT" "--help"

bash_complete aidentity rm ""
has_line "rm offers a profile name, escaped for the shell" "$RUN_OUT" 'Fake\ Work'
has_line "and one whose profile name has a space" "$RUN_OUT" 'Fake\ Home\ Office'
lacks_line "and not an app that is not a launcher" "$RUN_OUT" "Decoy"
bash_complete aidentity open 'Fake\ H'
assert_eq "a name already escaped by hand completes" 'Fake\ Home\ Office' "$RUN_OUT"
bash_complete aidentity open '"Fake H'
assert_eq "a name inside double quotes completes unescaped" 'Fake Home Office' "$RUN_OUT"
bash_complete aidentity open "'Fake W"
assert_eq "a name inside single quotes completes unescaped" 'Fake Work' "$RUN_OUT"
bash_complete aidentity add Spa
assert_eq "a spaced app name completes with its space escaped" 'Space\ Case' "$RUN_OUT"

# A folder name is not trusted. After an opening quote the name is escaped for
# that quote, so a $, a backtick or a quote mark in it is never run as code.
EVAL_DIR="$SANDBOX/comp-eval"
mkdir -p "$EVAL_DIR"
HOSTILE_NAMES=(
  'Fake Dollar $HOME Work'
  'Fake Sub $(touch pwned-marker) Work'
  'Fake Tick `touch pwned-marker` Work'
  "Fake It's Work"
  'Fake Quote"d Work'
  'Fake Slash\ed Work'
  'Fake Bang! Work'
)
for n in "${HOSTILE_NAMES[@]}"; do cp -R "$APPS/Fake Work.app" "$APPS/$n.app"; done

shell_reads() { # description, quote mark ("" for none), what is typed, the name it must be
  local desc="$1" q="$2" typed="$3" want="$4" got
  bash_complete aidentity open "$q$typed"
  case "$RUN_OUT" in
    ""|*$'\n'*) _fail "$desc" "expected exactly one reply" "got: [$RUN_OUT]"; return ;;
  esac
  rm -f "$EVAL_DIR/pwned-marker"
  got=$(cd "$EVAL_DIR" && "$BASH_BIN" -c "printf '%s' $q$RUN_OUT$q" 2>&1)
  assert_eq "$desc: the shell reads the name back whole" "$want" "$got"
  assert_no_file "$desc: and runs nothing" "$EVAL_DIR/pwned-marker"
}

for q in '"' "'" ""; do
  case "$q" in '"') qn="in double quotes" ;; "'") qn="in single quotes" ;; *) qn="without quotes" ;; esac
  shell_reads "$qn, a dollar sign"      "$q" "Fake Dollar" 'Fake Dollar $HOME Work'
  shell_reads "$qn, a command in \$()"  "$q" "Fake Sub"    'Fake Sub $(touch pwned-marker) Work'
  shell_reads "$qn, a backtick"         "$q" "Fake Tick"   'Fake Tick `touch pwned-marker` Work'
  shell_reads "$qn, an apostrophe"      "$q" "Fake It"     "Fake It's Work"
  shell_reads "$qn, a double quote"     "$q" "Fake Quote"  'Fake Quote"d Work'
  shell_reads "$qn, a backslash"        "$q" "Fake Slash"  'Fake Slash\ed Work'
done
shell_reads "in single quotes, an exclamation mark" "'" "Fake Bang" 'Fake Bang! Work'
shell_reads "without quotes, an exclamation mark" "" "Fake Bang" 'Fake Bang! Work'

bash_complete aidentity open '"Fake Dollar'
assert_eq 'in double quotes a $ gets a backslash' 'Fake Dollar \$HOME Work' "$RUN_OUT"
bash_complete aidentity open '"Fake Quote'
assert_eq 'and a double quote' 'Fake Quote\"d Work' "$RUN_OUT"
bash_complete aidentity open '"Fake Tick'
assert_eq 'and a backtick' 'Fake Tick \`touch pwned-marker\` Work' "$RUN_OUT"
bash_complete aidentity open '"Fake Slash'
assert_eq 'and a backslash' 'Fake Slash\\ed Work' "$RUN_OUT"
bash_complete aidentity open "'Fake It"
assert_eq "in single quotes an apostrophe closes, escapes and reopens" "Fake It'\\''s Work" "$RUN_OUT"
bash_complete aidentity open "'Fake Dollar"
assert_eq "in single quotes a \$ needs nothing" 'Fake Dollar $HOME Work' "$RUN_OUT"
bash_complete aidentity open '"Fake Bang'
assert_eq "a name with ! is left out inside double quotes, where it cannot be escaped" "" "$RUN_OUT"
bash_complete aidentity open 'Fake\ Bang'
assert_eq "and is escaped without quotes" 'Fake\ Bang\!\ Work' "$RUN_OUT"

# What is typed already is read back through the same escapes.
bash_complete aidentity open '"Fake Dollar \$H'
assert_eq "an escaped \$ already typed still matches" 'Fake Dollar \$HOME Work' "$RUN_OUT"
bash_complete aidentity open "\"Fake Dollar \\"
assert_eq "so does a backslash with nothing after it yet" 'Fake Dollar \$HOME Work' "$RUN_OUT"
bash_complete aidentity open '"Fake Quote\"'
assert_eq "an escaped double quote already typed still matches" 'Fake Quote\"d Work' "$RUN_OUT"
bash_complete aidentity open "\"Fake Slash\\\\"
assert_eq "an escaped backslash already typed still matches" 'Fake Slash\\ed Work' "$RUN_OUT"
bash_complete aidentity open "'Fake It'\\''s"
assert_eq "an escaped apostrophe already typed still matches" "Fake It'\\''s Work" "$RUN_OUT"

group "zsh completion behaviour"

if [ -n "$ZSH_BIN" ]; then
# The script's function runs under zsh -f. compadd and _describe, which only
# exist inside zsh's completion system, are replaced by stand-ins that print the
# candidates starting with the word under the cursor. zsh's own compadd does the
# quoting of names, so these tests cover what reaches it: the words, as they are.
ZSH_DRIVER="$SANDBOX/zsh-driver.zsh"
cat > "$ZSH_DRIVER" <<'ZSH_DRIVER_END'
compdef() { :; }
compadd() {
  local arr=0 c
  while [[ $1 == -* && $1 != -- ]]; do [[ $1 == -a ]] && arr=1; shift; done
  [[ $1 == -- ]] && shift
  if (( arr )); then set -- "${(@P)1}"; fi
  for c in "$@"; do [[ $c == "$words[CURRENT]"* ]] && print -r -- "$c"; done
  return 0
}
_describe() {
  local c
  for c in "${(@P)argv[-1]}"; do c=${c%%:*}; [[ $c == "$words[CURRENT]"* ]] && print -r -- "$c"; done
  return 0
}
. "$1"; shift
words=("$@"); CURRENT=$#
_aidentity
ZSH_DRIVER_END

# Like bash_complete: the words typed so far, the last one under the cursor.
# The output is sorted, since zsh lists its own order.
zsh_complete() {
  RUN_OUT=$(cd "$EVAL_DIR" && PATH="$COMP_BIN:$PATH" HOME="$SANDBOX/tty-home" "$ZSH_BIN" -f "$ZSH_DRIVER" "$SANDBOX/completion.zsh" "$@" 2>&1)
  RUN_RC=$?
  RUN_OUT=$(printf '%s\n' "$RUN_OUT" | LC_ALL=C sort)
}

zsh_complete aidentity ""
assert_rc "zsh: completing the command works" 0 "$RUN_RC" "$RUN_OUT"
has_line "zsh: an empty word offers commands: add" "$RUN_OUT" "add"
has_line "zsh: and other spellings: ls" "$RUN_OUT" "ls"
lacks_line "zsh: but not options" "$RUN_OUT" "--help"
zsh_complete aidentity rm ""
has_line "zsh: rm offers a profile name" "$RUN_OUT" "Fake Work"
has_line "zsh: and one whose profile name has a space" "$RUN_OUT" "Fake Home Office"
lacks_line "zsh: and not an app that is not a launcher" "$RUN_OUT" "Decoy"
zsh_complete aidentity open "Fake H"
assert_eq "zsh: a name with a space completes" "Fake Home Office" "$RUN_OUT"

# Folder names are handed to zsh as they are. zsh quotes them itself, and
# nothing in the function reads them as code.
for want in "${HOSTILE_NAMES[@]}"; do
  zsh_complete aidentity open "${want% Work}"
  has_line "zsh: the name [$want] is offered as it is" "$RUN_OUT" "$want"
done
assert_no_file "zsh: and no folder name ran as code" "$EVAL_DIR/pwned-marker"
else
  _skip "zsh completion behaviour" "zsh is not installed"
fi

group "fish completion behaviour"

# fish's own `complete -C` completes a command line with the script loaded,
# the way Tab does. It prints each candidate as fish reads it back (no
# escapes), with a tab and the description when there is one. --no-config and
# a home in the sandbox keep out the fish setup of whoever runs the tests.
FISH_HOME="$SANDBOX/fish-home"
mkdir -p "$FISH_HOME"
if [ -n "$FISH_BIN" ] && HOME="$FISH_HOME" "$FISH_BIN" --no-config -c true >/dev/null 2>&1; then
fish_complete() { # the command line typed so far, as typed
  RUN_OUT=$(cd "$EVAL_DIR" && PATH="$COMP_BIN:$PATH" HOME="$FISH_HOME" XDG_CONFIG_HOME="$FISH_HOME" \
    XDG_DATA_HOME="$FISH_HOME" XDG_CACHE_HOME="$FISH_HOME" "$FISH_BIN" --no-config \
    -c 'source $argv[1]; complete -C $argv[2]' "$SANDBOX/completion.fish" "$1" 2>"$SANDBOX/fish.err")
  RUN_RC=$?
  RUN_OUT=$(printf '%s\n' "$RUN_OUT" | LC_ALL=C sort)
}

fish_complete "aidentity "
assert_rc "fish: completing the command works" 0 "$RUN_RC" "$RUN_OUT"
has_line "fish: an empty word offers commands, with what each does" "$RUN_OUT" "add"$'\t'"Create a profile for an app"
has_line "fish: and other spellings" "$RUN_OUT" "ls"$'\t'"Same as list"
fish_complete "aidentity rm --p"
assert_eq "fish: an option prefix completes the option" "--purge" "$RUN_OUT"
fish_complete "aidentity rm "
has_line "fish: rm offers a profile name" "$RUN_OUT" "Fake Work"
has_line "fish: and one whose profile name has a space" "$RUN_OUT" "Fake Home Office"
lacks_line "fish: and not an app that is not a launcher" "$RUN_OUT" "Decoy"
fish_complete "aidentity rm 'Fake Work' "
assert_eq "fish: rm takes one name, so nothing more is offered" "" "$RUN_OUT"
fish_complete 'aidentity open Fake\ H'
assert_eq "fish: a name with a space completes" "Fake Home Office" "$RUN_OUT"

for want in "${HOSTILE_NAMES[@]}"; do
  typed=${want#Fake }; typed=${typed%%[!A-Za-z]*}
  fish_complete "aidentity open Fake\\ $typed"
  has_line "fish: the name [$want] is offered as it is" "$RUN_OUT" "$want"
done
assert_no_file "fish: and no folder name ran as code" "$EVAL_DIR/pwned-marker"
else
  _skip "fish completion behaviour" "fish is not installed or does not start; CI installs it and runs these"
fi

for n in "${HOSTILE_NAMES[@]}"; do rm -rf "$APPS/$n.app"; done
rm -rf "$EVAL_DIR"

ai rm "Fake Home Office" --purge -y
ai rm "Fake Work" --purge -y
rm -rf "$DATA/fake-gone" "$APPS/Decoy.app" "$SRC/Space Case.app"
