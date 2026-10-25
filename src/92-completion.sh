# -------------------------------------------------------------- completion --

# `aidentity __complete SHELL CWORD WORD...` prints what Tab can offer for the
# words typed so far, in the form SHELL's script reads (see complete_words).
# `aidentity __complete WHAT` prints the names of one kind (launchers,
# restorable or apps), the form that scripts saved from 1.4.0 use. The scripts
# call it on every Tab, so it prints nothing on stderr and always exits 0,
# whatever is wrong with the folders it reads.
cmd_complete() {
  case "${1:-}" in
    bash|zsh|fish) ( complete_words "$@" ) 2>/dev/null ;;
    *) ( complete_candidates "${1:-}" ) 2>/dev/null ;;
  esac
  return 0
}

complete_candidates() {
  local app name dir label i=0
  case "$1" in
    launchers)   # the names open, rm, set, rename and rebuild take
      launcher_rows names
      while [ "$i" -lt "$LR_N" ]; do
        case "${LR_NAME[$i]}" in *[[:cntrl:]]*) ;; *) printf '%s\n' "${LR_NAME[$i]}" ;; esac
        i=$((i + 1))
      done ;;
    restorable)  # the names restore takes: profiles whose launcher is gone
      while IFS= read -r dir; do
        [ -n "$dir" ] || continue
        label=$(restore_label "$dir") || continue
        printf '%s\n' "$label"
      done <<EOF
$(orphan_dirs)
EOF
      ;;
    apps)        # the names add takes
      while IFS= read -r app; do
        [ -n "$app" ] || continue
        name=$(bundle_name "$app")
        case "$name" in *[[:cntrl:]]*) continue ;; esac
        printf '%s\n' "$name"
      done <<EOF | awk '!seen[$0]++'
$(list_compatible_apps)
EOF
      ;;
  esac
}

# complete_words SHELL CWORD WORD...: what Tab can offer. WORD 0 is the name
# aidentity was typed as, and CWORD is the index of the word under the cursor.
# It turns another spelling into its command, skips the value of an option,
# then offers a command, an option, a colour or the command's first argument,
# all from the command table. bash gets the words that match, quoted for it.
# zsh gets "describe" or "plain" on the first line, then every candidate, as
# word:description after describe. fish gets every candidate, with a tab and
# its description when it has one. zsh and fish match the typed word
# themselves, so their own matching rules (ignoring case, say) keep working.
complete_words() {
  local shell="$1" cword="$2" cur w x i=2 npos=0 valopt="" values="" list="" mode=plain n a p o s
  local -a words
  shift 2
  case "$cword" in ''|*[!0-9]*) return 0 ;; esac
  words=("$@")
  cur="${words[cword]:-}"
  if [ "$cword" -le 1 ]; then
    mode=describe
    case "$cur" in -*) list=$(command_words -) ;; *) list=$(command_words) ;; esac
  elif command_row "${words[1]:-}" && [ "${CMD_NAME#__}" = "$CMD_NAME" ]; then
    # Count the arguments typed so far. The value of an option is not one.
    while IFS='|' read -r n a p o s; do
      for x in $o; do case "$x" in *=) values="$values/${x%=}" ;; esac; done
    done <<EOF
$COMMANDS
EOF
    values="${values//\// } "
    while [ "$i" -lt "$cword" ]; do
      w="${words[i]:-}"
      case "$values" in
        *" $w "*) [ $((i + 1)) -eq "$cword" ] && valopt="$w"; i=$((i + 1)) ;;
        *) case "$w" in -*) ;; *) npos=$((npos + 1)) ;; esac ;;
      esac
      i=$((i + 1))
    done
    if [ -n "$valopt" ]; then
      # Of all the values, only a colour has a list to offer.
      for x in $CMD_OPTS; do
        case "$x" in --color/*) ;; *) continue ;; esac
        # shellcheck disable=SC2086  # a fixed list of words, split on purpose
        case "/${x%=}/" in *"/$valopt/"*) list=$(printf '%s\n' $COLOR_NAMES) ;; esac
      done
    elif [ "${cur#-}" != "$cur" ]; then
      list=$(for x in $CMD_OPTS --help; do printf '%s\n' "${x%%[/=]*}"; done)
    elif [ "$npos" -eq 0 ]; then
      case "$CMD_ARG" in
        apps|launchers|restorable) list=$(complete_candidates "$CMD_ARG") ;;
        shells) list=$(printf '%s\n' bash zsh fish) ;;
        commands) list=$(command_words) ;;
      esac
    fi
  fi
  case "$shell" in
    bash) complete_bash_reply "$cur" <<EOF
$list
EOF
      return 0 ;;
    zsh) printf '%s\n' "$mode" ;;
  esac
  while IFS="$TAB" read -r w x; do
    [ -n "$w" ] || continue
    case "$shell:$mode" in
      zsh:describe) printf '%s:%s\n' "$w" "$x" ;;
      zsh:*) printf '%s\n' "$w" ;;
      *) printf '%s%s\n' "$w" "${x:+$TAB$x}" ;;
    esac
  done <<EOF
$list
EOF
}

# complete_bash_reply WORD: of the candidates on stdin (a line each, maybe with
# a tab and a description), print those that start with WORD, quoted for bash.
# When WORD starts with a quote mark, a name is escaped for that quote instead,
# so a $ or a quote mark in a folder name is never read by the shell as code.
complete_bash_reply() {
  local word="$1" line quote=""
  case "$word" in
    \"*) quote='"'; word="${word#\"}" ;;
    \'*) quote="'"; word="${word#\'}" ;;
    *)   word="${word//\\/}" ;;
  esac
  if [ -n "$quote" ]; then complete_unescape "$quote" "$word"; word="$REPLY"; fi
  while IFS= read -r line; do
    line="${line%%"$TAB"*}"
    [ -n "$line" ] || continue
    case "$line" in
      "$word"*)
        if [ -z "$quote" ]; then
          printf '%q\n' "$line"
        elif complete_escape "$quote" "$line"; then
          printf '%s\n' "$REPLY"
        fi ;;
    esac
  done
}

# complete_escape QUOTE TEXT: set REPLY to TEXT as it can sit inside a QUOTE
# (" or ') the user has already opened. Inside double quotes ! cannot be
# escaped, so a name with one fails (returns 1) and is left out.
complete_escape() {
  local q="$1" s="$2" c i=0
  REPLY=""
  while [ "$i" -lt "${#s}" ]; do
    c="${s:i:1}"
    if [ "$q" = "'" ]; then
      if [ "$c" = "'" ]; then c="'\\''"; fi
    else
      case "$c" in
        '!') REPLY=""; return 1 ;;
        \\|'"'|'$'|'`') c="\\$c" ;;
      esac
    fi
    REPLY="$REPLY$c"
    i=$((i + 1))
  done
}

# complete_unescape QUOTE TEXT: the reverse, for the part of the word that is
# typed already. Sets REPLY.
complete_unescape() {
  local q="$1" s="$2" c i=0 n
  REPLY=""
  while [ "$i" -lt "${#s}" ]; do
    c="${s:i:1}"
    n=$((i + 1))
    if [ "$q" = "'" ]; then
      if [ "${s:i:4}" = "'\\''" ]; then c="'"; i=$((i + 3)); fi
    elif [ "$c" = "\\" ]; then
      case "${s:n:1}" in
        \\|'"'|'$'|'`') c="${s:n:1}"; i=$n ;;
        '') c="" ;;   # a backslash with nothing after it yet
      esac
    fi
    REPLY="$REPLY$c"
    i=$((i + 1))
  done
}

# aidentity completion SHELL. The script goes to stdout. It is a short shim
# that asks `aidentity __complete` on every Tab, so it holds no list of its
# own: a new command, spelling or option reaches all three shells at once.
cmd_completion() {
  local shell=""
  while [ $# -gt 0 ]; do
    case "$1" in
      -*) die "Unknown option for completion: $1" ;;
      *) [ -z "$shell" ] && shell="$1" || die "Unexpected argument: $1"; shift ;;
    esac
  done
  [ -n "$shell" ] || die "Usage: aidentity completion bash|zsh|fish"
  case "$shell" in
    bash) cat <<'EOF'
# bash completion for aidentity
#
#   eval "$(aidentity completion bash)"     # in ~/.bashrc
#
# On every Tab it asks 'aidentity __complete' what fits, already quoted for
# bash. That command is not meant to be run by hand.
_aidentity() {
  local line
  COMPREPLY=()
  while IFS= read -r line; do
    [ -n "$line" ] && COMPREPLY+=("$line")
  done <<< "$(command aidentity __complete bash "$COMP_CWORD" "${COMP_WORDS[@]}" 2>/dev/null)"
  return 0
}
complete -F _aidentity aidentity
EOF
      ;;
    zsh) cat <<'EOF'
#compdef aidentity
# zsh completion for aidentity
#
#   eval "$(aidentity completion zsh)"      # in ~/.zshrc, after compinit
#
# Or save the output as a file named _aidentity in a folder on your fpath.
# On every Tab it asks 'aidentity __complete' what fits. That command is not
# meant to be run by hand.
_aidentity() {
  local -a cands
  cands=("${(@f)$(command aidentity __complete zsh $(( CURRENT - 1 )) "${words[@]}" 2>/dev/null)}")
  case $cands[1] in
    describe) cands=("${(@)cands[2,-1]}"); _describe -t commands 'aidentity command' cands ;;
    plain) cands=("${(@)cands[2,-1]}"); compadd -a cands ;;
  esac
}

if [[ $funcstack[1] == _aidentity ]]; then
  _aidentity "$@"
else
  compdef _aidentity aidentity
fi
EOF
      ;;
    fish) cat <<'EOF'
# fish completion for aidentity
#
#   aidentity completion fish | source      # in ~/.config/fish/config.fish
#
# Or save the output as ~/.config/fish/completions/aidentity.fish.
# On every Tab it asks 'aidentity __complete' what fits. That command is not
# meant to be run by hand.
complete -c aidentity -f -a '(command aidentity __complete fish (count (commandline -opc)) (commandline -opc) (commandline -ct) 2>/dev/null)'
EOF
      ;;
    *) die "Unknown shell '$shell'. Use bash, zsh or fish." ;;
  esac
}
