# -------------------------------------------------- commands: add, setup --

cmd_add() {
  local app_arg="" profile="" badge="" color="" seed=0 no_badge=0 main=0 extras=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --profile|-p) need_value "$1" "${2:-}"; profile="$2"; shift 2 ;;
      --badge|-b)   need_value "$1" "${2:-}"; badge="$2";   shift 2 ;;
      --color|--colour|-c) need_value "$1" "${2:-}"; color="$2"; shift 2 ;;
      --no-badge)   no_badge=1; shift ;;
      --seed)       seed=1; shift ;;
      --main)       main=1; shift ;;
      --arg)        [ -n "${2:-}" ] || die "--arg needs a switch, e.g.  --arg --lang=de"
                    validate_switch "$2" || exit 1
                    extras="${extras:+$extras
}arg$TAB$2"; shift 2 ;;
      --env)        [ -n "${2:-}" ] || die "--env needs NAME=value"
                    validate_env "$2" || exit 1
                    extras="${extras:+$extras
}env$TAB$2"; shift 2 ;;
      --own-extensions) extras="${extras:+$extras
}ext${TAB}1"; shift ;;
      --)           shift; break ;;
      -*)           die "Unknown option for add: $1" ;;
      *)            [ -z "$app_arg" ] && app_arg="$1" || die "Unexpected argument: $1"; shift ;;
    esac
  done

  # ---- interactive wizard when arguments are missing ----
  if [ -z "$app_arg" ]; then
    have_tty || die "No app given. Usage: aidentity add \"<app>\" --profile \"<name>\""
    app_arg=$(pick_app) || exit 1
    info ""
  fi

  if [ "$main" -eq 1 ]; then
    [ -n "$profile" ] || profile="Main"
  elif [ -z "$profile" ]; then
    # Ask for the account name. 1.0.0 did; a refactor in 1.1.0 lost the prompt,
    # so `aidentity add` picked an app and then failed on the empty name. The
    # app is vetted first, so nobody names an account for an app that is then
    # refused.
    local src_app; src_app=$(resolve_target_app "$app_arg") || exit 1
    have_tty || die "No profile name given. Use --profile \"<name>\"."
    while :; do
      profile=$(ask 'Name this account (e.g. Work, Personal, Client): ') || exit 1
      validate_profile_name "$profile" && break
    done
    app_arg="$src_app"
  fi

  create_profile "$app_arg" "$profile" "$badge" "$color" "$seed" "$no_badge" "$main" "$extras" || exit 1
}

# Resolve and vet the app a launcher would open. Prints its bundle path, or
# warns and returns non-zero if it is missing, is one of our own launchers, or
# has no separate-profile switch.
resolve_target_app() {
  local app_arg="$1" src_app
  src_app=$(resolve_app "$app_arg") || {
    warn "Could not find an app called '$app_arg'. Run 'aidentity apps' to see what is available."
    return 1; }

  if is_our_launcher "$src_app"; then
    warn "'$app_arg' is an aidentity launcher, not an app. Pick the real app."
    return 1
  fi

  if ! is_chromium_app_deep "$src_app"; then
    warn "$(bundle_name "$src_app") is not a Chromium- or Electron-based app, so it has no
    separate-profile switch. aidentity cannot give it extra accounts yet.
    See: https://github.com/PiniShv/aidentity#which-apps-work"
    return 1
  fi
  printf '%s' "$src_app"
}

# The --main launcher already built for an app, if there is one.
main_launcher_for() {
  local app
  for app in "$APPS_DIR"/*.app; do
    [ -d "$app" ] || continue
    is_our_launcher "$app" || continue
    is_main_launcher "$app" || continue
    [ "$(plist_get "$app" "AIdentityTargetApp")" = "$1" ] && { printf '%s' "$app"; return 0; }
  done
  return 1
}

# Create one profile end to end. Returns non-zero on any failure instead of
# exiting, so the wizard can report it and carry on with the next account.
# cmd_add is the CLI wrapper; cmd_setup calls this directly.
# main=1 builds a launcher for the app's own, original account instead.
create_profile() {
  local app_arg="$1" profile="$2" badge="$3" color="$4" seed="$5" no_badge="${6:-0}" main="${7:-0}"
  local extras="${8:-}"

  local src_app
  src_app=$(resolve_target_app "$app_arg") || return 1

  validate_profile_name "$profile" || return 1

  local label; label="$(bundle_name "$src_app") $profile"
  local slug;  slug="$(slugify "$label")"
  local data_dir="" kind=""
  local dst="$APPS_DIR/$label.app"

  if [ "$main" -eq 1 ]; then
    kind="main"
    # One is enough. Two launchers for the same original account would only
    # be two names for one thing.
    local other; other=$(main_launcher_for "$src_app")
    if [ -n "$other" ] && [ "$other" != "$dst" ]; then
      warn "'$(bundle_name "$other")' already opens your original $(bundle_name "$src_app") account."
      return 1
    fi
  else
    data_dir="$DATA_ROOT/$slug"
    # slugify folds spaces, underscores and hyphens together and drops
    # non-ASCII, so "Work 2", "Work_2" and "Work-2" all produced ONE data
    # directory. Three launchers then shared a single profile — the opposite
    # of the tool's job.
    if [ -z "$slug" ]; then
      warn "Cannot derive a profile directory from '$label'.
    Use a name containing at least one letter or number."
      return 1
    fi
    # Every launcher counts, the way rm --purge looks: one filed into a
    # folder shares the data just the same. If they cannot all be looked at,
    # no profile is made, rather than one that might share.
    local others
    if ! others=$(launchers_sharing "$data_dir" "$dst"); then
      warn "Could not look through every launcher, so '$label' was not made: it might
    share its profile directory with one. Check that $APPS_DIR can be read."
      return 1
    fi
    if [ -n "$others" ]; then
      warn "'$label' would share its profile directory with '$others':
      $data_dir
    Spaces, underscores, hyphens and capitals are treated the same. Pick a more distinct name."
      return 1
    fi
  fi

  # Never turn a separate profile into a main launcher or back by re-adding
  # under the same name. The profile's data would be left with nothing pointing
  # at it — and that is exactly what `prune` moves to the Trash.
  if [ -e "$dst" ] && is_our_launcher "$dst"; then
    local was=""
    is_main_launcher "$dst" && was="main"
    if [ "$was" != "$kind" ]; then
      if [ "$was" = "main" ]; then
        warn "'$label' already opens your original account. Pick another profile name."
      else
        warn "'$label' is already a separate profile. Pick another name for the original account:
      aidentity add \"$(bundle_name "$src_app")\" --main --profile Original"
      fi
      return 1
    fi
  fi

  # Adding a profile that already exists rebuilds its launcher. It keeps the
  # badge and colour it has unless new ones are given; re-adding used to reset
  # a hand-picked colour to the default and call the result "Created".
  local existing_launcher=0
  [ -e "$dst" ] && is_our_launcher "$dst" && existing_launcher=1

  # An existing profile keeps the folder it records. Recomputing it from the
  # data root repointed the launcher at a new, empty folder whenever
  # AIDENTITY_DATA_ROOT differed from the shell it was made in — signed out,
  # with the real session left for prune.
  if [ "$existing_launcher" -eq 1 ] && [ "$kind" != "main" ]; then
    local recorded; recorded=$(plist_get "$dst" AIdentityDataDir)
    if [ -n "$recorded" ] && [ "$recorded" != "$data_dir" ]; then
      dim "  Keeping its profile folder: $recorded"
      data_dir="$recorded"
    fi
  fi

  if [ -n "$data_dir" ]; then
    local why=new
    [ "$existing_launcher" -eq 1 ] && why=existing
    socket_path_ok "$src_app" "$data_dir" "$label" "$why" || return 1
  fi

  if [ "$no_badge" -eq 1 ]; then
    badge=""
  elif [ -n "$badge" ]; then
    local wanted="$badge"
    badge=$(first_char "$badge")
    # Bytes that are not text (a Latin-1 é, say) cut to nothing, which would
    # quietly mean "no badge". Say so and use the default instead.
    if [ -z "$badge" ]; then
      badge=$(first_upper "$profile")
      warn "'$wanted' is not a character that can be drawn; using the badge $badge."
    fi
  elif [ "$existing_launcher" -eq 1 ]; then
    badge=$(launcher_badge "$dst" "$src_app" "$profile")
  else
    badge=$(first_upper "$profile")
  fi

  local hex
  if [ -n "$color" ]; then
    hex=$(color_hex "$color") || {
      warn "Unknown colour '$color'. Try one of: $COLOR_NAMES, or a hex value like 2E7DF6."
      return 1; }
  elif [ "$existing_launcher" -eq 1 ]; then
    hex=$(launcher_color "$dst" "$label")
  else
    hex=$(color_hex "$(auto_color "$label")")
  fi

  # Launch settings an existing profile has are kept, new ones win, and a
  # setting given twice counts once.
  if [ "$existing_launcher" -eq 1 ]; then
    extras=$(extras_merge "$(filter_extras "$(extras_of "$dst/Contents/Info.plist")" "$src_app" "$kind")" "$extras")
  else
    extras=$(extras_merge "" "$extras")
  fi

  if [ -e "$APPS_DIR/$label.app" ] && ! is_our_launcher "$APPS_DIR/$label.app"; then
    warn "There is already something at $APPS_DIR/$label.app that aidentity did not create.
    Refusing to overwrite it. Pick a different profile name."
    return 1
  fi

  if [ -n "$data_dir" ] && running_on_profile "$data_dir"; then
    warn "'$label' is running right now. Quit it, then re-run."
    return 1
  fi

  # Called directly, NOT via $(…). In a command substitution the builder runs in
  # a subshell, so a failure there could not stop the caller printing
  # "✓ Created" after a failed build.
  local had_data=0
  [ -n "$data_dir" ] && [ -d "$data_dir" ] && had_data=1
  if ! build_launcher "$src_app" "$profile" "$data_dir" "$label" "$badge" "$hex" "$kind" "$extras"; then
    # Leave no empty directory behind for `prune` to report later.
    [ "$had_data" -eq 0 ] && [ -n "$data_dir" ] && rmdir "$data_dir" 2>/dev/null
    return 1
  fi

  if [ "$seed" -eq 1 ]; then
    local primary="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
    if [ "$(bundle_id "$src_app")" != "com.anthropic.claudefordesktop" ]; then
      warn "--seed only applies to Claude Desktop; ignoring it for $(bundle_name "$src_app")."
    elif [ "$main" -eq 1 ]; then
      dim "  Nothing to seed — the original account already has your config."
    elif [ -f "$primary" ] && [ ! -f "$data_dir/claude_desktop_config.json" ]; then
      # Owner-only: MCP server entries often carry API keys in their env.
      cp "$primary" "$data_dir/claude_desktop_config.json" \
        && chmod 600 "$data_dir/claude_desktop_config.json" \
        && ok "Copied your MCP server config into the new profile."
    else
      dim "  Nothing to seed (no existing config, or the profile already has one)."
    fi
  fi

  local app_name; app_name=$(bundle_name "$src_app")
  info ""
  if [ "$existing_launcher" -eq 1 ] && [ "$main" -eq 1 ]; then
    ok "Updated ${C_BOLD}$label${C_RESET} — it already existed"
  elif [ "$existing_launcher" -eq 1 ]; then
    ok "Updated ${C_BOLD}$label${C_RESET} — it already existed; its profile data was not touched"
  else
    ok "Created ${C_BOLD}$label${C_RESET}"
  fi
  printf '   launcher  %s\n' "$dst"
  if [ "$main" -eq 1 ]; then
    printf '   opens     %s\n' "$(dim "your original $app_name account, with $app_name's own data")"
    info ""
    info "${C_BOLD}Next:${C_RESET}"
    printf '  Drag %s onto your Dock in place of %s.app.\n' "$(basename "$dst")" "$app_name"
    info ""
    dim "  While any profile is running, macOS treats it as $app_name itself, so"
    dim "  clicking $app_name.app only switches to that profile. This launcher always"
    dim "  opens your original account."
    return 0
  fi
  printf '   profile   %s\n' "$(dim "$data_dir")"
  info ""
  info "${C_BOLD}Next:${C_RESET}"
  printf '  1. Open it:      aidentity open "%s"\n' "$label"
  printf '  2. Sign in with the other account in the window that appears.\n'
  if app_running "$src_app"; then
    printf '     %s is open already: quit it for this first sign-in. A browser\n' "$app_name"
    printf '     sign-in goes back to the %s that started first, not to this one.\n' "$app_name"
  fi
  printf '  3. Keep it handy: drag %s from Finder onto your Dock.\n' "$(basename "$dst")"
  info ""
  dim "  Nothing to re-run when the app updates — the launcher holds no copy of it."
  return 0
}

# The guided walkthrough. This is what a first-time user sees, and what the
# installer offers to run at the end of a `curl | bash`.
cmd_setup() {
  have_tty || die "aidentity setup needs a terminal. Use 'aidentity add' with flags instead."

  info ""
  info "${C_BOLD}Welcome to aidentity.${C_RESET}"
  info ""
  info "macOS runs one copy of an app, so one account at a time. This sets up extra"
  info "copies of an app you already have, each signed into a different account, all"
  info "running together."
  info ""
  dim  "Your existing app and its current account are not touched."
  info ""

  local badge_style="badge"
  if ! confirm "Add a small coloured badge to each icon so you can tell them apart?" y; then
    badge_style="plain"
    dim "  Using the app's own icon with your chosen name."
  fi
  info ""

  local made=0 src_app profile main_declined="|"
  while :; do
    src_app=$(pick_app) || break
    info ""

    # validate_profile_name now prints the ACTUAL reason and returns a status,
    # so a bad name re-prompts with a message that matches why it was refused.
    while :; do
      profile=$(ask 'Name this account (e.g. Work, Personal, Client): ') || break 2
      validate_profile_name "$profile" && break
    done

    local seed=0
    if [ "$(bundle_id "$src_app")" = "com.anthropic.claudefordesktop" ] &&
       [ -f "$HOME/Library/Application Support/Claude/claude_desktop_config.json" ]; then
      confirm "Copy your existing MCP server config into this profile?" y && seed=1
    fi

    local nb=0
    [ "$badge_style" = "plain" ] && nb=1

    info ""
    # create_profile RETURNS a status. The old code called cmd_add, whose every
    # failure path was `exit 1`, so this else branch was unreachable and one bad
    # answer ended the whole walkthrough.
    if create_profile "$src_app" "$profile" "" "" "$seed" "$nb"; then
      made=$((made+1))
      offer_main_launcher "$src_app" "$nb"
    else
      info ""
      warn "That one did not work — nothing was created for it. Carrying on."
    fi

    info ""
    confirm "Set up another account?" y || break
    info ""
  done

  info ""
  if [ "$made" -eq 0 ]; then
    info "Nothing set up. Run ${C_BOLD}aidentity setup${C_RESET} again whenever you like."
    return 0
  fi

  ok "Done — $made profile(s) created."
  info ""
  info "${C_BOLD}To use them:${C_RESET}"
  info "  1. Open Finder → Go → Home → Applications."
  info "  2. Drag each new icon onto your Dock."
  info "  3. Click one, sign in with that account, and leave it signed in."
  info ""
  dim  "  See them any time with:  aidentity list"

  if confirm "Open the Applications folder now?" y; then
    open "$APPS_DIR" 2>/dev/null || true
  fi
}

# Offered in the walkthrough after an app's first new profile, until the app
# has a main launcher or the person says no. While any profile runs, macOS
# treats it as the app itself, so clicking the app switches to that profile
# instead of opening the original account. A --main launcher always opens the
# original. A "no" is remembered for the rest of the walkthrough in
# cmd_setup's main_declined (bash locals are visible to the functions a
# function calls).
offer_main_launcher() {
  local src_app="$1" nb="$2" name
  name=$(bundle_name "$src_app")
  main_launcher_for "$src_app" >/dev/null && return 0
  [ -e "$APPS_DIR/$name Main.app" ] && return 0
  case "${main_declined:-}" in *"|$src_app|"*) return 0 ;; esac
  info ""
  dim "  While a profile is running, clicking $name.app only switches to that profile."
  if confirm "Add a '$name Main' launcher that always opens your original account?" y; then
    info ""
    create_profile "$src_app" "Main" "" "" 0 "$nb" 1 \
      || warn "Skipped. Add it later with: aidentity add \"$name\" --main"
  else
    main_declined="${main_declined:-|}$src_app|"
  fi
  return 0
}
