# -------------------------------------------------------- commands: quit --

# Several copies of one app run at once, one per profile, and the Dock shows
# them as identical icons. `quit` finds the one copy that runs on a profile and
# asks only that one to quit.

# Whether a command line names the profile's folder in a real --user-data-dir
# argument: after a space, the whole folder, up to the next " --" or the end,
# as proc_dir_ids reads it. A folder can hold spaces, so a space alone does not
# end it: ".../fake-work archive/x" is another folder, not "fake-work". The same
# folder under another spelling matches too (id is its device:inode). The same
# words inside another switch's value, such as
# --proxy-bypass-list=user-data-dir=<folder>, are not that argument. With no
# folder it is the app's own account: no --user-data-dir at all, as
# main_running reads it.
quit_on_folder() { # data folder or "", its id or "", command line
  local data="$1" id="$2" rest="$3" value
  if [ -z "$data" ]; then
    case "$rest" in *--user-data-dir=*) return 1 ;; esac
    return 0
  fi
  while :; do
    case "$rest" in *" --user-data-dir="*) rest=${rest#*" --user-data-dir="} ;; *) return 1 ;; esac
    value=${rest%% --*}
    [ "$value" = "$data" ] && return 0
    [ -n "$id" ] && [ "$(dir_id "$value")" = "$id" ] && return 0
  done
}

# Whether a process command line is the main process of a profile: it starts
# with the app's executable (starts_with_exe), and names the folder as above.
# A helper has its own executable inside the app's Frameworks folder, so it
# never matches.
quit_matches() { # executable, its exe_id or "", data folder or "", its id or "", command line
  starts_with_exe "$1" "$2" "$5" && quit_on_folder "$3" "$4" "$5"
}

# The PIDs in a ps listing ("uid pid command" lines) that are this user's and
# match, a line each. Another user's copy of the app is never ours to quit.
# The match runs in the shell, never through `| grep -q`: see the comment
# above running_in_snapshot.
quit_scan() { # listing, uid, executable, its exe_id, data folder or "", its id or ""
  local uid pid cmd
  while read -r uid pid cmd; do
    [ "$uid" = "$2" ] || continue
    case "$pid" in ''|*[!0-9]*) continue ;; esac
    quit_matches "$3" "$4" "$5" "$6" "$cmd" && printf '%s\n' "$pid"
  done <<EOF
$1
EOF
  return 0
}

# ps, in UTF-8 whatever the caller's locale: in the C locale ps writes a
# non-ASCII byte as "M-CM-)", so a path with "é" in it never matched.
quit_ps() { LC_ALL=en_US.UTF-8 ps "$@" 2>/dev/null; }

# "  PID n  name" for each of the PIDs (a comma list) that still runs, the
# first five of them: the name is the last part of the program's path, with
# any control character shown as "?".
quit_names() { # pid,pid,…
  local pid cmd name n=0 more=0
  [ -n "$1" ] || return 0
  while read -r pid cmd; do
    case "$pid" in ''|*[!0-9]*) continue ;; esac
    n=$((n + 1))
    [ "$n" -le 5 ] || { more=$((more + 1)); continue; }
    shown name "${cmd##*/}"
    printf '  PID %s  %s\n' "$pid" "$name"
  done <<EOF
$(quit_ps -o pid=,comm= -p "$1")
EOF
  [ "$more" -eq 0 ] || printf '  and %s more\n' "$more"
  return 0
}

# What quit left alone that list and rm still count as running: anything on
# the profile's folder, helpers too, or for a main launcher a process on the
# app's own account. Any user's, as they count them.
quit_left() { # listing, executable, its exe_id, data folder or ""
  local uid pid cmd pids=""
  while read -r uid pid cmd; do
    case "$pid" in ''|*[!0-9]*) continue ;; esac
    if [ -n "$4" ]; then
      quit_on_folder "$4" "" "$cmd" || continue
    else
      quit_matches "$2" "$3" "" "" "$cmd" || continue
    fi
    pids="$pids,$pid"
  done <<EOF
$1
EOF
  quit_names "${pids#,}"
}

# Ask one app to quit, the same as its Quit menu item, so it can still ask
# about unsaved work. It needs no permission. Prints "sent" when the request
# went to an app, "refused" when the app would not take it, "none" when no
# app has that PID, and nothing when osascript itself could not run.
# osascript is called through PATH, as the icon code calls it.
quit_event() { # pid
  osascript -l JavaScript - "$1" 2>/dev/null <<'JXA'
ObjC.import("AppKit");
function run(argv) {
  var app = $.NSRunningApplication.runningApplicationWithProcessIdentifier(Number(argv[0]));
  if (app.isNil()) return "none";
  return app.terminate ? "sent" : "refused";
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

  local target exe xid data="" ident="" me list pids pid sent="" other="" asked=1 left i=0
  local PS_RC="" PS_LIST="" PS_IDS="" PS_ALL=""
  target=$(plist_get "$app" AIdentityTargetApp)
  exe=$(app_exe "$target") \
    || die "Cannot find the app that '$want' opens${target:+: $target}. Nothing was quit.
    Run: aidentity rebuild \"$want\", then quit again."
  xid=$(exe_id "$exe") || xid=""
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
  list=$(quit_ps -axww -o uid=,pid=,command=) && [ -n "$list" ] \
    || die "Could not list the running processes. Nothing was quit."
  pids=$(quit_scan "$list" "$me" "$exe" "$xid" "$data" "$ident")

  for pid in $pids; do
    # Looked at again right before acting: once a process ends, its PID can
    # be given to another one.
    [ "$(quit_scan "$(quit_ps -ww -o uid=,pid=,command= -p "$pid")" \
        "$me" "$exe" "$xid" "$data" "$ident")" = "$pid" ] || continue
    # Only an app is asked to quit, and only an app is ever sent SIGTERM. The
    # app's executable also runs as a plain program that is not the app: VS
    # Code's `code` command runs it that way (code --wait, --install-extension),
    # and SIGTERM would end that command, not the app. An app that would not
    # take the request is sent SIGTERM, which Electron and Chromium apps also
    # treat as quit. When osascript cannot run, nothing tells an app from such
    # a program, so nothing is sent.
    case "$(quit_event "$pid")" in
      sent) sent="$sent $pid" ;;
      refused) kill -TERM "$pid" 2>/dev/null && sent="$sent $pid" ;;
      none) other="$other,$pid" ;;
      *) other="$other,$pid"; asked=0 ;;
    esac
  done

  if [ -z "$sent" ]; then
    if [ "$asked" -eq 0 ]; then
      warn "Could not ask macOS whether $want's process is the app. Nothing was quit."
      return 1
    fi
    # Not "not running" while list and rm say it is: they count helpers left
    # on the folder, and a program on the app's executable that is not an app.
    # The same checks are asked here.
    if { [ -n "$data" ] && running_on_profile "$data"; } \
       || { [ -z "$data" ] && main_running "$target"; }; then
      left=$(quit_left "$list" "$exe" "$xid" "$data")
      if [ -z "$left" ]; then
        warn "'$want' has no app open, but other processes still use it. Nothing was quit."
        return 1
      fi
      if [ -n "$data" ]; then
        warn "'$want' has no app open, but these still use its profile folder:"
      else
        warn "'$want' has no app open, but these still run the app on your original account:"
      fi
      printf '%s\n  They are not apps, so quit leaves them alone. Nothing was quit.\n' "$left" >&2
      return 1
    fi
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
    warn "${want} is still running; it may be asking you something."
    return 1
  fi
  ok "Quit ${want}."
  # A program on the app's executable that is not an app was left alone.
  left=$(quit_names "${other#,}")
  [ -z "$left" ] || printf 'Not an app, so left running:\n%s\n' "$left"
  return 0
}
