# -------------------------------------------------------- commands: quit --

# Several copies of one app run at once, one per profile, and the Dock shows
# them as identical icons. `quit` finds the one copy that runs on a profile and
# asks only that one to quit.

# Whether a process command line is the main process of a profile. It starts
# with the app's executable, then a space or the end: a helper has its own
# executable inside the app's Frameworks folder, so it never matches. With a
# data folder, the line carries --user-data-dir for it, matched the anchored way
# running_in_snapshot matches it, or for the same folder under another spelling
# (id is the folder's device:inode). With no data folder it is the app's own
# account: no --user-data-dir at all, as main_running reads it.
quit_matches() { # executable, data folder or "", its id or "", command line
  local exe="$1" data="$2" id="$3" cmd="$4"
  case "$cmd" in "$exe"|"$exe "*) ;; *) return 1 ;; esac
  if [ -z "$data" ]; then
    case "$cmd" in *--user-data-dir=*) return 1 ;; esac
    return 0
  fi
  case "$cmd" in *"user-data-dir=$data "*|*"user-data-dir=$data") return 0 ;; esac
  [ -n "$id" ] || return 1
  case "$cmd" in *user-data-dir=*) ;; *) return 1 ;; esac
  case "$(proc_dir_ids "$cmd")" in *"|$id|"*) return 0 ;; esac
  return 1
}

# The PIDs in a ps listing ("uid pid command" lines) that are this user's and
# match, a line each. Another user's copy of the app is never ours to quit.
# The match runs in the shell, never through `| grep -q`: see the comment
# above running_in_snapshot.
quit_scan() { # listing, uid, executable, data folder or "", its id or ""
  local uid pid cmd
  while read -r uid pid cmd; do
    [ "$uid" = "$2" ] || continue
    case "$pid" in ''|*[!0-9]*) continue ;; esac
    quit_matches "$3" "$4" "$5" "$cmd" && printf '%s\n' "$pid"
  done <<EOF
$1
EOF
  return 0
}

# Ask one app to quit, the same as its Quit menu item, so it can still ask
# about unsaved work. It needs no permission. Prints "sent" when the request
# went to an app; anything else means no app has that PID. osascript is called
# through PATH, as the icon code calls it.
quit_event() { # pid
  osascript -l JavaScript - "$1" 2>/dev/null <<'JXA'
ObjC.import("AppKit");
function run(argv) {
  var app = $.NSRunningApplication.runningApplicationWithProcessIdentifier(Number(argv[0]));
  if (app.isNil()) return "none";
  return app.terminate ? "sent" : "none";
}
JXA
}

cmd_quit() {
  local want=""
  while [ $# -gt 0 ]; do
    case "$1" in
      -*) die "Unknown option for quit: $1" ;;
      *) [ -z "$want" ] && want="$1" || die "Unexpected argument: $1  (one profile at a time; quote a name that has spaces)"; shift ;;
    esac
  done
  [ -n "$want" ] || die "Usage: aidentity quit \"<profile>\""
  local app="$APPS_DIR/$want.app"
  [ -d "$app" ] || die "No launcher named '$want'. Run 'aidentity list' to see what exists."
  assert_ours "$app"

  local target exe data="" ident="" me list pids pid sent="" left i=0
  target=$(plist_get "$app" AIdentityTargetApp)
  exe=$(app_exe "$target") \
    || die "Cannot find the app that '$want' opens${target:+: $target}. Nothing was quit."
  # A main launcher's copy is the one with no --user-data-dir. Any other
  # launcher must name its folder: without one, its copy cannot be told from
  # the app's own, and the wrong one would be quit.
  if ! is_main_launcher "$app"; then
    data=$(plist_get "$app" AIdentityDataDir)
    [ -n "$data" ] || die "'$want' records no profile folder, so its copy of the app cannot be told
    apart from the others. Nothing was quit."
    ident=$(dir_id "$data") || ident=""
  fi
  me=$(id -u 2>/dev/null) && [ -n "$me" ] || die "Could not tell which user this is. Nothing was quit."
  list=$(ps -axww -o uid=,pid=,command= 2>/dev/null) && [ -n "$list" ] \
    || die "Could not list the running processes. Nothing was quit."
  pids=$(quit_scan "$list" "$me" "$exe" "$data" "$ident")

  for pid in $pids; do
    # Looked at again right before acting: once a process ends, its PID can
    # be given to another one.
    [ "$(quit_scan "$(ps -ww -o uid=,pid=,command= -p "$pid" 2>/dev/null)" \
        "$me" "$exe" "$data" "$ident")" = "$pid" ] || continue
    # The quit event first. A process that is not an app, or an app that did
    # not take the request, gets SIGTERM, which Electron and Chromium apps
    # also treat as quit.
    if [ "$(quit_event "$pid")" != sent ]; then
      kill -TERM "$pid" 2>/dev/null || continue
    fi
    sent="$sent $pid"
  done
  if [ -z "$sent" ]; then
    info "'$want' is not running."
    return 0
  fi

  # Up to 10 seconds, in steps of 0.2. No --force: an app that is still
  # running may be asking about unsaved work, and that is for the user.
  while :; do
    left=""
    for pid in $sent; do kill -0 "$pid" 2>/dev/null && left="$left $pid"; done
    [ -n "$left" ] && [ "$i" -lt 50 ] || break
    sent=$left
    sleep 0.2
    i=$((i + 1))
  done
  if [ -n "$left" ]; then
    warn "${want} is still running. It may be asking you something; look at its window."
    return 1
  fi
  ok "Quit ${want}."
}
