# --------------------------------------------------------------- dashboard --

# Only the optional browser dashboard needs Python. Keep dependency detection
# here, so every existing shell command still works without it.
cmd_dashboard() {
  local port=0 no_open=0 python=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --port)
        [ $# -gt 1 ] || die "--port needs a number from 0 to 65535."
        port="$2"
        case "$port" in
          ''|*[!0-9]*) die "--port needs a number from 0 to 65535." ;;
        esac
        [ "${#port}" -le 5 ] || die "--port needs a number from 0 to 65535."
        # Decimal even when the port is written with a leading zero.
        port=$((10#$port))
        [ "$port" -le 65535 ] || die "--port needs a number from 0 to 65535."
        shift 2 ;;
      --no-open) no_open=1; shift ;;
      *) die "Unknown argument for dashboard: $1. Run 'aidentity dashboard --help'." ;;
    esac
  done
  [ "$(uname)" = Darwin ] || die "aidentity dashboard requires macOS."
  python=$(command -v python3) || die "The dashboard needs Python 3.9 or newer.
    Install Python 3, then run 'aidentity dashboard' again.
    All other aidentity commands work without Python."
  "$python" -I -c 'import sys; sys.exit(sys.version_info < (3, 9))' 2>/dev/null \
    || die "The dashboard needs Python 3.9 or newer."
  [ -f "$SELF_PATH" ] || die "Run dashboard from an installed aidentity file."
  if [ "$no_open" = 1 ]; then
    dashboard_runtime "$python" --port "$port" --no-open
  else
    dashboard_runtime "$python" --port "$port"
  fi
}
