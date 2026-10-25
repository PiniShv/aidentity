# -------------------------------------------------- ui: keys and actions --

# Wait up to 2 seconds for a key. UI_KEY becomes UP, DOWN, LEFT, RIGHT, ENTER,
# ESC, EOF or TICK (nothing typed), or the character typed. An arrow key starts
# with the same byte as Esc, so after one the next two bytes are read too, one
# at a time (bash 3.2 drops a half-read pair on a timeout). It cannot wait for
# less than a second, so Esc on its own is slow. If what follows is not an
# arrow, it was a separate key; it is kept in UI_PEND.
ui_key() {
  local k="" b1="" b2="" rc=0 t0=$SECONDS
  if [ -n "$UI_PEND" ]; then
    k=${UI_PEND:0:1}; UI_PEND=${UI_PEND:1}
  else
    IFS= read -rsn1 -t 2 k || rc=$?
    [ "$UI_STOPPED" -eq 0 ] || ui_resume
    if [ "$rc" -ne 0 ]; then
      if [ "$rc" -gt 128 ] || [ $((SECONDS - t0)) -ge 2 ]; then UI_KEY=TICK; else UI_KEY=EOF; fi
      return 0
    fi
  fi
  case "$k" in
    ''|$'\r') UI_KEY=ENTER ;;
    $'\004')  UI_KEY=EOF ;;
    $'\032')  # Ctrl-Z, as a byte (see ui_enter). Stop; it is nothing typed.
      if [ "$UI_ACTIVE" -eq 1 ]; then ui_on_tstp; ui_resume; UI_KEY=TICK; else UI_KEY=$k; fi ;;
    "$UI_ESC")
      IFS= read -rsn1 -t 1 b1 || b1=""
      case "$b1" in
        '['|O)
          IFS= read -rsn1 -t 1 b2 || b2=""
          case "$b1$b2" in
            '[A'|OA) UI_KEY=UP ;;
            '[B'|OB) UI_KEY=DOWN ;;
            '[C'|OC) UI_KEY=RIGHT ;;
            '[D'|OD) UI_KEY=LEFT ;;
            *)       UI_KEY=OTHER ;;
          esac ;;
        '') UI_KEY=ESC ;;
        *)  UI_KEY=ESC; UI_PEND=$b1 ;;
      esac ;;
    *) UI_KEY=$k ;;
  esac
  return 0
}

ui_wait_key() { # until a key is typed
  while :; do ui_key; [ "$UI_KEY" = "TICK" ] || break; done
}

ui_pause() {
  printf '\n%sPress any key to return.%s' "$C_DIM" "$C_RESET"
  ui_wait_key
  printf '\n'
}

# Run a command function for the menu, as the command line would. In a
# subshell, so a `die` ends the command and not the menu; the script's own
# traps are set again inside it, so an interrupted rename still moves its data
# back and an unfinished build still removes its staging folder.
ui_run() {
  UI_BUSY=1
  (
    trap '_on_exit' EXIT
    trap '_on_exit; exit 130' INT
    trap '_on_exit; exit 143' TERM
    trap '_on_exit; exit 129' HUP
    "$@"
  )
  UI_BUSY=0
  return 0
}

# Leave the menu, run a command with its output and questions on the normal
# screen, wait for a key, and come back to a menu read again from disk.
ui_screen() { # command and its arguments
  ui_leave
  ui_run "$@"
  ui_pause
  ui_enter
  ui_load
}

# Ask a question on the normal screen. The answer is in UI_ANS, empty when
# nothing was typed, at end of input, or after Ctrl-C, which only cancels the
# question: it is asked in a subshell, like a command.
ui_ask() { # prompt
  UI_BUSY=1
  UI_ANS=$(ui_run ask "$1") || UI_ANS=""
  UI_BUSY=0
  printf '\n'
}

ui_flash() { # ok or err, text
  case "$1" in err) UI_MSG_STYLE=$C_RED ;; *) UI_MSG_STYLE=$C_GREEN ;; esac
  UI_MSG=$2; UI_SWATCH=""; UI_FLASH_AT=$SECONDS; UI_DIRTY=1
}

ui_msg_clear() { UI_MSG=""; UI_MSG_STYLE=""; UI_SWATCH=""; }

ui_move() { # -1 or 1
  UI_SEL=$((UI_SEL + $1))
  [ "$UI_SEL" -lt "$UI_N" ] || UI_SEL=$((UI_N - 1))
  [ "$UI_SEL" -ge 0 ] || UI_SEL=0
  UI_DIRTY=1
}

# Whether a launcher is selected; says so in the footer when there is none.
ui_have_row() {
  [ "$UI_N" -gt 0 ] && return 0
  ui_flash err "There is no profile yet. Press a to add one."
  return 1
}

# Enter. One line of result, so it goes in the footer instead of a screen.
ui_do_open() {
  local out rc
  ui_have_row || return 0
  UI_BUSY=1
  out=$(ui_run cmd_open "${UI_L_NAME[$UI_SEL]}" 2>&1); rc=$?
  UI_BUSY=0
  out=$(printf '%s' "$out" | sed "s/${UI_ESC}\[[0-9;]*m//g")
  out=${out//$'\n'/ }
  if [ -z "$out" ]; then out="Opened ${UI_L_NAME[$UI_SEL]}."; fi
  if [ "$rc" -eq 0 ]; then ui_flash ok "$out"; else ui_flash err "$out"; fi
}

ui_do_add() {
  local before="|" i=0
  while [ "$i" -lt "$UI_N" ]; do before="$before${UI_L_NAME[$i]}|"; i=$((i + 1)); done
  ui_screen cmd_add
  i=0
  while [ "$i" -lt "$UI_N" ]; do
    case "$before" in *"|${UI_L_NAME[$i]}|"*) ;; *) UI_SEL=$i; break ;; esac
    i=$((i + 1))
  done
}

ui_do_rename() {
  local name label new
  ui_have_row || return 0
  name=${UI_L_NAME[$UI_SEL]}
  shown label "$name"
  ui_leave
  printf 'Rename %s%s%s. The account stays signed in.\n\n' "$C_BOLD" "$label" "$C_RESET"
  while :; do
    ui_ask 'New account name (e.g. Work, Personal, Client). Empty to cancel: '
    new=$UI_ANS
    [ -n "$new" ] || break
    validate_profile_name "$new" && break
  done
  if [ -z "$new" ]; then ui_enter; ui_load; return 0; fi
  UI_WANT="$(bundle_name "${UI_L_TARGET[$UI_SEL]}") $new"
  ui_run cmd_rename "$name" "$new"
  ui_pause
  ui_enter
  ui_load
}

ui_do_badge() {
  local name label ch
  ui_have_row || return 0
  name=${UI_L_NAME[$UI_SEL]}
  shown label "$name"
  ui_leave
  printf 'Badge for %s%s%s.\n\n' "$C_BOLD" "$label" "$C_RESET"
  ui_ask 'One character for the icon badge. Empty to cancel: '
  ch=$UI_ANS
  if [ -z "$ch" ]; then ui_enter; ui_load; return 0; fi
  ui_run cmd_set "$name" --badge "$ch"
  ui_pause
  ui_enter
  ui_load
}

# The inline colour picker: left and right choose, Enter applies, Esc cancels.
ui_do_color() {
  local name hex n=0 i=0 cur=0 pick="" c
  ui_have_row || return 0
  name=${UI_L_NAME[$UI_SEL]}
  hex=$(launcher_color "${UI_L_APP[$UI_SEL]}" "$name")
  hex=$(lower "$hex")
  # shellcheck disable=SC2086  # a fixed list of words, split on purpose
  set -- $UI_COLORS
  n=$#
  for c in "$@"; do
    [ "$(lower "$(color_hex "$c")")" = "$hex" ] && cur=$i
    i=$((i + 1))
  done
  while :; do
    i=0
    for c in "$@"; do [ "$i" -eq "$cur" ] && pick=$c; i=$((i + 1)); done
    ui_idx256 "$(color_hex "$pick")" || true
    UI_SWATCH=$UI_IDX; UI_MSG_STYLE=$C_BOLD
    UI_MSG="Colour  < ${pick} >   Left and Right choose, Enter applies, Esc cancels"
    ui_draw
    ui_wait_key
    case "$UI_KEY" in
      LEFT)  cur=$(( (cur + n - 1) % n )) ;;
      RIGHT) cur=$(( (cur + 1) % n )) ;;
      ENTER) break ;;
      *)     pick=""; break ;;
    esac
  done
  ui_msg_clear; UI_DIRTY=1
  [ -n "$pick" ] || return 0
  ui_screen cmd_set "$name" --color "$pick"
}

# d: k removes the launcher and keeps the data, p deletes the data as well.
# Both end in `rm`, which refuses a running profile and, for p, asks for yes.
# k needs no yes: the data stays, and `restore` brings the launcher back.
ui_do_remove() {
  local name short opts room main=${UI_L_MAIN[$UI_SEL]:-0}
  ui_have_row || return 0
  name=${UI_L_NAME[$UI_SEL]}
  # The name is cut first, so a narrow window still shows the keys.
  room=$((UI_COLS - 70)); [ "$room" -ge 8 ] || room=8
  ui_fit "$name" $((${#name} < room ? ${#name} : room)); short=$UI_FIT
  UI_MSG_STYLE=$C_BOLD; UI_SWATCH=""
  if [ "$main" = "1" ]; then
    opts="k  remove the launcher only   Esc  cancel"
  else
    opts="k  keep the data   p  delete the data too   Esc  cancel"
  fi
  if [ "$UI_COLS" -ge 80 ]; then UI_MSG="Remove ${short}?   $opts"; else UI_MSG="$opts   ($short)"; fi
  ui_draw
  ui_wait_key
  ui_msg_clear; UI_DIRTY=1
  case "$UI_KEY" in
    k) ui_screen cmd_rm "$name" -y ;;
    p) if [ "$main" = "1" ]; then
         ui_flash err "A main launcher never deletes the app's data. Press d, then k, to remove it."
       else
         ui_screen cmd_rm "$name" --purge
       fi ;;
  esac
}

# x: the doctor's report. f then runs doctor --fix.
ui_do_doctor() {
  ui_leave
  ui_run cmd_doctor
  printf '\n%sPress f to repair what can be repaired (doctor --fix). Any other key returns.%s' "$C_DIM" "$C_RESET"
  ui_wait_key
  printf '\n'
  if [ "$UI_KEY" = "f" ]; then
    printf '\n'
    ui_run cmd_doctor --fix
    ui_pause
  fi
  ui_enter
  ui_load
}

ui_help() {
  local row=1 line key desc
  UI_HOLD=1
  UI_FRAME="${UI_ESC}[2J"
  ui_put 1 " ${C_BOLD}aidentity ui${C_RESET}"
  row=3
  while IFS='|' read -r key desc; do
    [ -n "$key" ] || continue
    [ "$row" -lt "$UI_ROWS" ] || break
    ui_fit "$desc" $((UI_COLS - 19)); line=$UI_FIT
    ui_fit "$key" 16
    ui_put "$row" " ${C_BOLD}${UI_FIT}${C_RESET} ${line}"
    row=$((row + 1))
  done <<EOF
Up, Down, k, j|move
Enter|open the profile
a|add a profile: pick an app, then name the account
r|rename the account name (it stays signed in)
c|colour: arrows choose, Enter applies, Esc cancels
b|badge: one character on the icon
d|remove: k keeps the data, p deletes it too
x|doctor report; f then repairs what it can
?|this help
q, Esc|quit
EOF
  ui_put $((UI_ROWS)) " ${C_DIM}Press any key to return.${C_RESET}"
  printf '%s' "$UI_FRAME"
  UI_HOLD=0
  ui_wait_key
  UI_DIRTY=1
}

ui_loop() {
  while :; do
    [ -z "$UI_SIG" ] || return 0
    if [ "$UI_RESIZED" -eq 1 ]; then UI_RESIZED=0; ui_resize; fi
    if [ $((SECONDS - UI_LAST)) -ge 2 ]; then UI_LAST=$SECONDS; ui_sync; fi
    if [ -n "$UI_MSG" ] && [ $((SECONDS - UI_FLASH_AT)) -ge 6 ]; then ui_msg_clear; UI_DIRTY=1; fi
    if [ "$UI_DIRTY" -eq 1 ]; then UI_DIRTY=0; ui_draw; fi
    ui_key
    [ -z "$UI_SIG" ] || return 0
    if [ "$UI_KEY" != "TICK" ] && [ -n "$UI_MSG" ]; then ui_msg_clear; UI_DIRTY=1; fi
    case "$UI_KEY" in
      TICK) ;;
      q|Q|ESC|EOF) return 0 ;;
      UP|k)   ui_move -1 ;;
      DOWN|j) ui_move 1 ;;
      ENTER)  ui_do_open ;;
      a)      ui_do_add ;;
      r)      ui_do_rename ;;
      c)      ui_do_color ;;
      b)      ui_do_badge ;;
      d)      ui_do_remove ;;
      x)      ui_do_doctor ;;
      '?')    ui_help ;;
    esac
  done
}

cmd_ui() {
  [ $# -eq 0 ] || die "Unexpected argument: $1  (ui takes no arguments)"
  if [ ! -t 0 ] || [ ! -t 1 ]; then
    die "aidentity ui needs a terminal. In a script, use: aidentity list --json"
  fi
  case "${TERM:-}" in
    ''|dumb|unknown) die "aidentity ui needs a terminal that can move the cursor. Your TERM is '${TERM:-not set}'." ;;
  esac

  ui_caps
  UI_STTY=$(stty -g 2>/dev/null) || UI_STTY=""
  # Whatever ends us, the terminal is given back first. TERM and HUP only
  # note the signal: the menu waits in `read -s`, and bash puts back the
  # terminal mode it saved when that read began AFTER a trap that exits from
  # inside it, so exiting there left the terminal with echo off. bash 3.2 does
  # not cut the read short for these signals either, so the loop sees UI_SIG
  # within the 2 seconds of one read and leaves through the normal path below.
  # (INT is different: bash restores the terminal before the INT trap runs.)
  UI_SIG=""
  trap 'ui_leave; _on_exit' EXIT
  trap 'ui_on_int' INT
  trap 'UI_SIG=143' TERM
  trap 'UI_SIG=129' HUP
  trap 'ui_on_winch' WINCH

  ui_enter
  ui_size; ui_layout
  UI_LAST=$SECONDS
  # The first read takes a moment when there are many profiles.
  printf ' Reading the profiles…\n'
  ui_load
  ui_loop
  ui_leave

  trap - WINCH TSTP
  trap '_on_exit' EXIT
  trap '_on_exit; exit 130' INT
  trap '_on_exit; exit 143' TERM
  trap '_on_exit; exit 129' HUP
  # Ended by TERM or HUP: same exit status as before, terminal already back.
  [ -z "$UI_SIG" ] || exit "$UI_SIG"
  return 0
}
