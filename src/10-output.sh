# ---------------------------------------------------------------- output --

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_RESET=$'\033[0m'; C_DIM=$'\033[2m'; C_BOLD=$'\033[1m'
  C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'
else
  C_RESET=''; C_DIM=''; C_BOLD=''; C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''
fi

info() { printf '%s\n' "$*"; }
ok()   { printf '%s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '%s!%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
die()  { printf '%s✗%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; exit 1; }
dim()  { printf '%s%s%s\n' "$C_DIM" "$*" "$C_RESET"; }

# Ask a question and echo the answer.
#
# stdin first, so the tool behaves like every other Unix command: a terminal
# types the answer, and `printf 'yes\n' | aidentity rm …` still works.
# /dev/tty is only a fallback for when stdin is exhausted or absent — which is
# what happens if this ever runs with the script itself arriving on stdin.
# The prompt goes to stderr on purpose. Callers capture the answer with $(…),
# which swallows stdout — printing the prompt there would make it part of the
# answer ("Type yes to confirm: yes" never equals "yes").
ask() {
  local prompt="$1" reply=""
  printf '%s' "$prompt" >&2
  # `|| [ -n "$reply" ]`: read fails at end of input even after filling the
  # variable, so `printf yes | aidentity rm …` (no newline) read as "Cancelled".
  if IFS= read -r reply || [ -n "$reply" ]; then
    printf '%s' "$reply"; return 0
  fi
  # Only when stdin is NOT the terminal. Ctrl-D at a terminal prompt means "no
  # answer"; reading /dev/tty then would just ask the same terminal again.
  if [ ! -t 0 ] && tty_opens; then
    IFS= read -r reply 2>/dev/null < /dev/tty || [ -n "$reply" ] || return 1
    printf '%s' "$reply"; return 0
  fi
  return 1
}

# Yes/no with a default. $2 is "y" or "n".
confirm() {
  local prompt="$1" def="${2:-y}" hint reply
  case "$def" in y) hint="[Y/n]" ;; *) hint="[y/N]" ;; esac
  reply=$(ask "$prompt $hint ") || return 1
  reply=$(printf '%s' "$reply" | tr '[:upper:]' '[:lower:]')
  [ -z "$reply" ] && reply="$def"
  case "$reply" in y|yes) return 0 ;; *) return 1 ;; esac
}

# Whether /dev/tty can actually be opened. Its mode is crw-rw-rw- on every Mac,
# so `[ -r /dev/tty ]` was true with no controlling terminal at all (cron,
# launchd, CI) and the "needs a terminal" guards built on it never fired.
tty_opens() { ( : < /dev/tty ) 2>/dev/null; }
have_tty() { [ -t 0 ] || tty_opens; }

# Fail unless an option got a real value. `shift 2 || die` only caught a value
# missing at the very end: `--profile --seed` created a profile literally named
# "--seed" and silently dropped the flag.
need_value() {
  case "${2:-}" in
    ''|-*) die "$1 needs a value." ;;
  esac
}

# The first character of a badge, whatever the caller's locale. Under LC_ALL=C,
# `cut -c1` cut "é" to half a character, the Info.plist became invalid UTF-8,
# and the build was refused.
first_char() { printf '%s' "$1" | LC_ALL=en_US.UTF-8 cut -c1 2>/dev/null; }

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# A profile's default badge: its first letter, upper-cased. Names are ASCII.
first_upper() { printf '%s' "$1" | cut -c1 | tr '[:lower:]' '[:upper:]'; }

# ---------------------------------------------------------------- guards --

[ "$(uname)" = "Darwin" ] || die "aidentity is macOS only (this is $(uname))."
