# -------------------------------------------------------------------- ui --
#
# `aidentity ui` is a full-screen menu over the commands above. It decides
# nothing about changing a profile: every action calls the same command
# function the command line calls, so every safety check stays where it is.
# What follows is terminal handling and drawing.
#
# Three things about bash 3.2 shaped it. `read -t` takes whole seconds. On a
# timeout it returns 1, the same status as end of input, so the two are told
# apart by how long the read took. And a trap runs while `read` waits, which is
# why a resize can redraw at once.

UI_ESC=$'\033'
# The colours `set --color` takes by name, in the order the picker shows them.
UI_COLORS="blue green orange purple teal pink red yellow gray graphite"

UI_ACTIVE=0     # 1 while the menu owns the terminal: alternate screen, no echo
UI_BUSY=0       # 1 while a command runs for the menu
UI_HOLD=0       # 1 while rows or a frame are built: a resize must not draw then
UI_RESIZED=0
UI_STOPPED=0    # 1 after Ctrl-Z took the terminal back: it is entered again on resume
UI_SIG=""       # 143 or 129 once TERM or HUP arrived: the loop then ends
UI_DIRTY=1
UI_STTY=""      # the terminal settings to put back
UI_ROWS=24
UI_COLS=80
UI_HDR=2        # header lines, rule included
UI_LH=1         # list lines
UI_NH=1         # key hint lines
UI_NW=12        # width of the name column
UI_HL=()        # the key hint lines
UI_RULE=""
UI_SPACES=""
UI_FRAME=""
UI_KEY=""
UI_PEND=""      # keys read ahead of the one being handled
UI_ANS=""       # the answer to the last question asked
UI_MSG=""       # the footer message line: a result, or a question
UI_MSG_STYLE=""
UI_SWATCH=""    # a colour shown before the message, as a 256-colour number
UI_FLASH_AT=0
UI_LAST=0       # SECONDS at the last refresh
UI_WANT=""      # the launcher to select after the next load
UI_N=0
UI_SEL=0
UI_TOP=0
UI_RUNNING=0
UI_MAXNAME=0
UI_DIRSIG=""
UI_STATSIG=""
UI_L_APP=(); UI_L_NAME=(); UI_L_TARGET=(); UI_L_DATA=(); UI_L_MAIN=()
UI_L_BADGE=(); UI_L_IDX=(); UI_L_STATUS=()

# Escape sequences for the alternate screen and the cursor. tput knows them for
# this terminal; the xterm ones stand in when it does not.
ui_caps() {
  UI_SMCUP=""; UI_RMCUP=""; UI_CIVIS=""; UI_CNORM=""
  if command -v tput >/dev/null 2>&1; then
    UI_SMCUP=$(tput smcup 2>/dev/null) || UI_SMCUP=""
    UI_RMCUP=$(tput rmcup 2>/dev/null) || UI_RMCUP=""
    UI_CIVIS=$(tput civis 2>/dev/null) || UI_CIVIS=""
    UI_CNORM=$(tput cnorm 2>/dev/null) || UI_CNORM=""
  fi
  [ -n "$UI_SMCUP" ] || UI_SMCUP="${UI_ESC}[?1049h"
  [ -n "$UI_RMCUP" ] || UI_RMCUP="${UI_ESC}[?1049l"
  [ -n "$UI_CIVIS" ] || UI_CIVIS="${UI_ESC}[?25l"
  [ -n "$UI_CNORM" ] || UI_CNORM="${UI_ESC}[?25h"
  # Colour is on when the script's own colours are. With NO_COLOR nothing here
  # writes a colour or any other style: the arrow marks the selected row.
  if [ -n "$C_RESET" ]; then
    UI_REV="${UI_ESC}[7m"; UI_NOREV="${UI_ESC}[27m"; UI_GREY="${UI_ESC}[90m"
  else
    UI_REV=""; UI_NOREV=""; UI_GREY=""
  fi
}

# Take the terminal over. UI_ACTIVE goes up first, so a signal that lands half
# way through still puts everything back.
#
# Ctrl-Z is handled here in two ways, because the terminal sends its stop
# signal to every process of the job, not only to this one. While the menu is
# up, the key is turned into a plain byte (susp undef) that ui_key reads and
# acts on: no process gets a signal, so none can be stopped alone while this
# script waits for it. At a question or in a command's output the terminal is
# as the user had it, Ctrl-Z stops the whole job, and the TSTP handler must not
# be set (a question is asked in a subshell, which would stop alone). So the
# handler is set here and removed in ui_leave; it is left for a stop signal that
# is sent to the menu by hand.
ui_enter() {
  UI_ACTIVE=1
  trap 'ui_on_tstp' TSTP
  stty -echo susp undef 2>/dev/null
  printf '%s%s%s[2J%s[H' "$UI_SMCUP" "$UI_CIVIS" "$UI_ESC" "$UI_ESC"
}

# Give it back exactly as it was found. Safe to call twice, and from a trap.
ui_leave() {
  [ "$UI_ACTIVE" -eq 1 ] || return 0
  UI_ACTIVE=0
  printf '%s%s%s' "$C_RESET" "$UI_CNORM" "$UI_RMCUP"
  if [ -n "$UI_STTY" ]; then
    stty "$UI_STTY" 2>/dev/null || stty sane 2>/dev/null
  else
    stty sane 2>/dev/null
  fi
  trap - TSTP
  return 0
}

ui_size() {
  local out r c
  out=$(stty size 2>/dev/null) || out=""
  r=${out%% *}; c=${out##* }
  case "$r$c" in ''|*[!0-9]*) r=0; c=0 ;; esac
  # A terminal that reports no size (0 0) gets what terminfo says, then 24x80.
  if [ "$r" -lt 1 ] || [ "$c" -lt 1 ]; then
    r=$(tput lines 2>/dev/null) || r=24
    c=$(tput cols 2>/dev/null) || c=80
    case "$r$c" in ''|*[!0-9]*) r=24; c=80 ;; esac
  fi
  UI_ROWS=$r; UI_COLS=$c
}

# Six hex digits -> UI_IDX, the nearest colour of the 256-colour cube. Plain
# 256-colour codes, because Terminal.app does not draw 24-bit ones.
# LC_ALL=C: in a UTF-8 locale, fullwidth digits passed the pattern and
# $((16#…)) then stopped the menu with an error.
ui_idx256() {
  local LC_ALL=C
  UI_IDX=""
  case "$1" in
    [0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]) ;;
    *) return 1 ;;
  esac
  local r g b
  r=$((16#${1:0:2})); g=$((16#${1:2:2})); b=$((16#${1:4:2}))
  UI_IDX=$((16 + 36 * ((r * 5 + 127) / 255) + 6 * ((g * 5 + 127) / 255) + (b * 5 + 127) / 255))
}

# $1 cut to $2 columns, with "…" where it was cut, and padded to exactly $2.
# The text goes through shown: a name comes off the disk. Width is the
# character count, so it is exact for ASCII; a cut is made by cut(1) in a UTF-8
# locale so it never splits a character.
ui_fit() { # text, width -> UI_FIT
  local s w="$2" n pad
  [ "$w" -ge 0 ] || w=0
  shown s "$1"
  n=${#s}
  if [ "$n" -gt "$w" ]; then
    if [ "$w" -le 1 ]; then
      s=${s:0:$w}; n=${#s}
    else
      s=$(printf '%s' "$s" | LC_ALL=en_US.UTF-8 cut -c1-$((w - 1)) 2>/dev/null)
      s="${s}…"; n=$w
    fi
  fi
  pad=$((w - n)); [ "$pad" -ge 0 ] || pad=0
  UI_FIT="$s${UI_SPACES:0:$pad}"
}

# Append one screen line to the frame being built: move there, write, clear
# the rest of the line.
ui_put() { # row, text
  UI_FRAME="$UI_FRAME${UI_ESC}[$1;1H$2${UI_ESC}[K"
}

# The key hints, packed into as many lines as the width needs. A narrow
# window shows only the keys that matter; ? lists the rest.
ui_pack_hints() {
  local width=$((UI_COLS - 2)) line="" lw=0 key kw label iw
  UI_HL=()
  if [ "$UI_COLS" -lt 60 ]; then
    set -- "↑↓" 2 move Enter 5 open "?" 1 help q 1 quit
  else
    set -- "↑↓" 2 move Enter 5 open s 1 stop a 1 add r 1 rename c 1 colour \
      b 1 badge d 1 remove x 1 doctor "?" 1 help q 1 quit
  fi
  while [ $# -ge 3 ]; do
    key=$1; kw=$2; label=$3; shift 3
    iw=$((kw + 1 + ${#label}))
    if [ "$lw" -gt 0 ] && [ $((lw + 2 + iw)) -gt "$width" ]; then
      UI_HL[${#UI_HL[@]}]=$line; line=""; lw=0
    fi
    if [ "$lw" -gt 0 ]; then line="$line  "; lw=$((lw + 2)); fi
    line="$line${C_BOLD}${key}${C_RESET} ${C_DIM}${label}${C_RESET}"
    lw=$((lw + iw))
  done
  UI_HL[${#UI_HL[@]}]=$line
  UI_NH=${#UI_HL[@]}
}

# Work out the screen: header, list and footer sizes from the window size.
ui_layout() {
  local n=0 rule=""
  printf -v UI_SPACES '%*s' "$((UI_COLS + 4))" ''
  while [ "$n" -lt $((UI_COLS - 2)) ]; do rule="${rule}─"; n=$((n + 1)); done
  UI_RULE=" ${C_DIM}${rule}${C_RESET}"
  ui_pack_hints
  # The title and the counts share a line when they fit, else take two.
  if [ "$UI_COLS" -ge $((40 + ${#AIDENTITY_VERSION})) ]; then UI_HDR=2; else UI_HDR=3; fi
  UI_LH=$((UI_ROWS - UI_HDR - 1 - UI_NH))
}

ui_resize() { ui_size; ui_layout; UI_DIRTY=1; }

# Keep the selected row on screen.
ui_clamp() {
  local lh=$UI_LH
  [ "$lh" -ge 1 ] || lh=1
  [ "$UI_SEL" -lt "$UI_N" ] || UI_SEL=$((UI_N - 1))
  [ "$UI_SEL" -ge 0 ] || UI_SEL=0
  [ "$UI_SEL" -ge "$UI_TOP" ] || UI_TOP=$UI_SEL
  [ "$UI_SEL" -lt $((UI_TOP + lh)) ] || UI_TOP=$((UI_SEL - lh + 1))
  [ "$UI_TOP" -le $((UI_N - lh)) ] || UI_TOP=$((UI_N - lh))
  [ "$UI_TOP" -ge 0 ] || UI_TOP=0
}

# What every launcher is doing now, from one look at the processes for all the
# rows: a look for each row took longer than the time between two refreshes
# once there were a dozen profiles. The words are launcher_status's, as in
# `list`. Warnings go nowhere: one on this screen would be written over the
# menu.
ui_status_rows() {
  local i=0 sig="" STATUS PS_RC="" PS_LIST="" PS_IDS="" PS_ALL=""
  UI_RUNNING=0
  proc_snapshot 2>/dev/null
  while [ "$i" -lt "$UI_N" ]; do
    launcher_status "${UI_L_TARGET[$i]}" "${UI_L_DATA[$i]}" "${UI_L_MAIN[$i]}"
    UI_L_STATUS[i]=$STATUS
    [ "$STATUS" = "running" ] && UI_RUNNING=$((UI_RUNNING + 1))
    sig="$sig|$STATUS"
    i=$((i + 1))
  done
  UI_STATSIG=$sig
}

# Read every launcher: what never changes while the menu is open (name, badge,
# colour, app, folder), then its status. The launcher that was selected stays
# selected, or UI_WANT if that is set.
ui_load() {
  local app badge keep="" n=0 i=0
  UI_HOLD=1
  if [ -n "$UI_WANT" ]; then
    keep=$UI_WANT
  elif [ "$UI_N" -gt 0 ] && [ "$UI_SEL" -lt "$UI_N" ]; then
    keep=${UI_L_NAME[$UI_SEL]}
  fi
  UI_WANT=""; UI_DIRSIG=""; UI_MAXNAME=0
  UI_L_APP=(); UI_L_NAME=(); UI_L_TARGET=(); UI_L_DATA=(); UI_L_MAIN=()
  UI_L_BADGE=(); UI_L_IDX=(); UI_L_STATUS=()
  # The names ui_sync compares, taken before the launchers are read: one that
  # comes in between then shows on the next refresh, not never.
  for app in "$APPS_DIR"/*.app; do UI_DIRSIG="$UI_DIRSIG|$app"; done
  launcher_rows
  while [ "$n" -lt "$LR_N" ]; do
    app=${LR_PATH[$n]}
    badge=$(launcher_badge "$app" "${LR_TARGET[$n]}" "${LR_PROFILE[$n]}")
    [ "${#badge}" -le 1 ] || badge=$(first_char "$badge")
    ui_idx256 "$(launcher_color "$app" "${LR_NAME[$n]}")" || true
    UI_L_APP[n]=$app; UI_L_NAME[n]=${LR_NAME[$n]}; UI_L_TARGET[n]=${LR_TARGET[$n]}
    UI_L_DATA[n]=${LR_DATA[$n]}; UI_L_MAIN[n]=${LR_MAIN[$n]}; UI_L_IDX[n]=$UI_IDX
    shown badge "$badge"; UI_L_BADGE[n]=$badge
    [ "${#LR_NAME[$n]}" -le "$UI_MAXNAME" ] || UI_MAXNAME=${#LR_NAME[$n]}
    n=$((n + 1))
  done
  UI_N=$n
  if [ -n "$keep" ]; then
    while [ "$i" -lt "$n" ]; do
      [ "${UI_L_NAME[$i]}" = "$keep" ] && { UI_SEL=$i; break; }
      i=$((i + 1))
    done
  fi
  ui_status_rows
  UI_HOLD=0
  UI_LAST=$SECONDS
  UI_DIRTY=1
}

# On a timer: load again if launchers came or went (a name list costs no
# process), else look at the statuses only.
ui_sync() {
  local sig="" a old=$UI_STATSIG
  for a in "$APPS_DIR"/*.app; do sig="$sig|$a"; done
  if [ "$sig" != "$UI_DIRSIG" ]; then ui_load; return 0; fi
  UI_HOLD=1; ui_status_rows; UI_HOLD=0
  [ "$UI_STATSIG" = "$old" ] || UI_DIRTY=1
  return 0
}

# One launcher's row, in UI_LINE. $2 is 1 for the selected row, which is
# marked with ▸ and shown in reverse video. Each coloured part ends by going
# back to that style, so the highlight is not cut in two.
ui_row() { # index, selected
  local i=$1 sel=$2 off="$C_RESET" mk=" " pre="" rev_off="" st nm bs ss dot dsty b used pad
  st=${UI_L_STATUS[$i]}
  if [ "$sel" -eq 1 ]; then off="$C_RESET$UI_REV"; mk="▸"; pre=$UI_REV; rev_off=$UI_NOREV; fi

  if [ "$st" = "running" ]; then dot="●"; dsty="$rev_off$C_GREEN"; else dot="○"; dsty="$rev_off$UI_GREY"; fi

  ui_fit "${UI_L_NAME[$i]}" "$UI_NW"; nm=$UI_FIT
  [ "$sel" -eq 1 ] && nm="${C_BOLD}${nm}${off}"

  case "$st" in
    running)       ss=$C_GREEN ;;
    "app missing") ss=$C_YELLOW ;;
    *)             ss=$C_DIM ;;
  esac
  if [ "$UI_COLS" -lt 60 ]; then
    [ "$st" = "signed out / new" ] && st="signed out"
    ui_fit "$st" 11; ss="${ss}${UI_FIT}${off}"
    UI_LINE="$pre $mk ${dsty}${dot}${off} ${nm}  $ss"
    used=$((18 + UI_NW))
  else
    ui_fit "$st" 16; ss="${ss}${UI_FIT}${off}"
    if [ "${UI_L_MAIN[$i]}" = "1" ]; then
      bs="original"
      [ -n "${UI_L_IDX[$i]}" ] && [ -n "$C_RESET" ] && bs="${rev_off}${UI_ESC}[38;5;${UI_L_IDX[$i]}moriginal${off}"
    elif [ -z "${UI_L_BADGE[$i]}" ]; then
      bs="${C_DIM}no badge${off}"
    else
      b=${UI_L_BADGE[$i]}
      if [ -n "${UI_L_IDX[$i]}" ] && [ -n "$C_RESET" ]; then
        bs="${rev_off}${UI_ESC}[48;5;${UI_L_IDX[$i]}m${UI_ESC}[1;97m ${b} ${off}     "
      else
        bs="[${b}]     "
      fi
    fi
    UI_LINE="$pre $mk ${dsty}${dot}${off} ${nm}  ${bs}  $ss"
    used=$((33 + UI_NW))
  fi
  # Fill a selected row to the edge, so the highlight is a bar.
  if [ "$sel" -eq 1 ]; then
    pad=$((UI_COLS - 1 - used)); [ "$pad" -ge 0 ] || pad=0
    UI_LINE="$UI_LINE${UI_SPACES:0:$pad}${C_RESET}"
  else
    UI_LINE="$UI_LINE${C_RESET}"
  fi
}

# Paint the whole screen in one write: no flicker, and a line is never
# cleared before it is rewritten. The window's last column is left empty so a
# full line cannot wrap.
ui_draw() {
  local title right pc rc rw gap r i end sel w nw mx below hint
  UI_HOLD=1
  # A resize that came while a frame was being built is taken up now.
  if [ "$UI_RESIZED" -eq 1 ]; then UI_RESIZED=0; ui_size; ui_layout; fi
  ui_clamp
  UI_FRAME=""
  if [ "$UI_COLS" -lt 22 ] || [ "$UI_LH" -lt 1 ]; then
    ui_fit "Window too small." $((UI_COLS - 1)); ui_put 1 "$UI_FIT"
    ui_fit "Press q to quit." $((UI_COLS - 1)); ui_put 2 "$UI_FIT"
    printf '%s%s[J' "$UI_FRAME" "$UI_ESC"
    UI_HOLD=0
    return 0
  fi
  w=$((UI_COLS - 1))

  title=" aidentity $AIDENTITY_VERSION"
  if [ "$UI_N" -eq 1 ]; then pc="1 profile"; else pc="$UI_N profiles"; fi
  rc="$UI_RUNNING running"
  right="$pc · $rc"                    # " · " is three columns
  if [ "$UI_HDR" -eq 2 ]; then
    rw=$((${#pc} + 3 + ${#rc}))
    gap=$((w - 1 - ${#title} - rw)); [ "$gap" -ge 1 ] || gap=1
    ui_put 1 "${C_BOLD}${title}${C_RESET}${UI_SPACES:0:$gap}${C_DIM}${right}${C_RESET}"
  else
    ui_put 1 "${C_BOLD}${title}${C_RESET}"
    ui_put 2 " ${C_DIM}${right}${C_RESET}"
  fi
  ui_put "$UI_HDR" "$UI_RULE"

  # The name column: as wide as the longest name, within what is left.
  if [ "$UI_COLS" -lt 60 ]; then mx=$((w - 18)); nw=4; else mx=$((w - 33)); nw=12; fi
  [ "$UI_MAXNAME" -le "$nw" ] || nw=$UI_MAXNAME
  [ "$nw" -le "$mx" ] || nw=$mx
  UI_NW=$nw

  r=$((UI_HDR + 1))
  if [ "$UI_N" -eq 0 ]; then
    ui_put "$r" " No profiles yet."
    ui_put $((r + 1)) " ${C_DIM}Press ${C_RESET}${C_BOLD}a${C_RESET}${C_DIM} to add one.${C_RESET}"
    r=$((r + 2))
  else
    i=$UI_TOP; end=$((UI_TOP + UI_LH)); [ "$end" -le "$UI_N" ] || end=$UI_N
    while [ "$i" -lt "$end" ]; do
      sel=0; [ "$i" -eq "$UI_SEL" ] && sel=1
      ui_row "$i" "$sel"; ui_put "$r" "$UI_LINE"
      r=$((r + 1)); i=$((i + 1))
    done
  fi
  while [ "$r" -le $((UI_HDR + UI_LH)) ]; do ui_put "$r" ""; r=$((r + 1)); done

  # The message line: a result or a question, else how much list is out of view.
  r=$((UI_HDR + UI_LH + 1))
  if [ -n "$UI_MSG" ]; then
    if [ -n "$UI_SWATCH" ] && [ -n "$C_RESET" ]; then
      ui_fit "$UI_MSG" $((w - 5)); ui_put "$r" " ${UI_ESC}[48;5;${UI_SWATCH}m   ${C_RESET} ${UI_MSG_STYLE}${UI_FIT}${C_RESET}"
    else
      ui_fit "$UI_MSG" $((w - 1)); ui_put "$r" " ${UI_MSG_STYLE}${UI_FIT}${C_RESET}"
    fi
  elif [ "$UI_TOP" -gt 0 ] || [ $((UI_TOP + UI_LH)) -lt "$UI_N" ]; then
    below=$((UI_N - UI_TOP - UI_LH)); [ "$below" -ge 0 ] || below=0
    hint=""
    [ "$UI_TOP" -eq 0 ] || hint="$UI_TOP more above"
    [ "$below" -eq 0 ] || hint="${hint:+$hint, }$below more below"
    ui_fit "$hint" $((w - 1))
    ui_put "$r" " ${C_DIM}${UI_FIT}${C_RESET}"
  else
    ui_put "$r" ""
  fi
  i=0
  while [ "$i" -lt "$UI_NH" ]; do
    r=$((r + 1)); ui_put "$r" " ${UI_HL[$i]}"; i=$((i + 1))
  done
  printf '%s' "$UI_FRAME"
  UI_HOLD=0
}

# Redraw from a signal handler, when it is safe to: not while a frame or the
# rows are being built, and not while a command has the terminal.
ui_redraw_now() {
  ui_resize
  [ "$UI_ACTIVE" -eq 1 ] && [ "$UI_HOLD" -eq 0 ] && [ "$UI_BUSY" -eq 0 ] || return 0
  UI_DIRTY=0
  ui_draw
}

ui_on_winch() {
  UI_RESIZED=1
  if [ "$UI_ACTIVE" -eq 1 ] && [ "$UI_HOLD" -eq 0 ] && [ "$UI_BUSY" -eq 0 ]; then
    UI_RESIZED=0
    ui_redraw_now
  fi
  return 0
}

# Ctrl-C quits the menu. While a command runs it only ends that command, which
# has stopped itself: back to the menu, not out of it.
ui_on_int() {
  [ "$UI_BUSY" -eq 1 ] && return 0
  ui_leave; _on_exit; exit 130
}

# Hand the terminal back and stop (the Ctrl-Z key, or a stop signal sent to the
# menu). Taking it again on `fg` is done by ui_resume, from ui_key, not here: a
# `read -t` that ran out while we were stopped jumps out of this handler as
# soon as it is continued, so nothing after the kill would run.
ui_on_tstp() {
  UI_STOPPED=$UI_ACTIVE
  ui_leave
  trap - TSTP
  kill -STOP $$
}

ui_resume() {
  [ "$UI_STOPPED" -eq 1 ] || return 0
  UI_STOPPED=0
  ui_enter
  ui_redraw_now
}
