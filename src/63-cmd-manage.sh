# ------------------------ commands: rename, set, restore, prune, rebuild --

# Resolve a profile label to the launcher bundle that carries it, or explain.
# The path comes back spelled as it is on disk: the disk ignores case, and
# `set "claude work"` used to rebuild the launcher under the typed spelling.
launcher_for() {
  local want="$1" a
  local app="$APPS_DIR/$want.app"
  [ -n "$want" ] || { warn "Which profile? Run 'aidentity list' to see them."; return 1; }
  if [ ! -d "$app" ]; then
    warn "No profile named '$want'. Run 'aidentity list' to see what exists."
    return 1
  fi
  if ! is_our_launcher "$app"; then
    warn "'$want' was not created by aidentity — refusing to touch it."
    return 1
  fi
  # The real bundle, by name, ignoring case. Not by -ef: a symlink pointing
  # at the launcher matched too, and an alias sorting first was renamed or
  # rebuilt instead of the launcher itself.
  local want_lc; want_lc=$(lower "$want.app")
  for a in "$APPS_DIR"/*.app; do
    [ -L "$a" ] && continue
    [ "$(lower "$(basename "$a")")" = "$want_lc" ] && { app="$a"; break; }
  done
  printf '%s' "$app"
}

# Every aidentity launcher that can be found, one path per line: the launcher
# directory and folders inside it, the app search path, and whatever Spotlight
# knows. `prune` moves data that no launcher claims to the Trash, so a launcher
# it cannot see is a signed-in session it would throw out. Looking only in the
# launcher directory deleted the data of any launcher moved somewhere else.
#
# find runs with -H so a symlinked launcher directory is followed, as the old
# "$APPS_DIR"/*.app glob was; without it a symlinked ~/Applications looked
# empty and prune deleted every profile behind it. Our own hidden .aidentity-*
# staging folders, and the Trash, hold launchers on their way out: they claim
# nothing, or a launcher deleted in Finder would keep its data from prune.
all_launchers() {
  local dir app
  {
    for app in "$APPS_DIR"/*.app; do [ -d "$app" ] && printf '%s\n' "$app"; done
    find -H "$APPS_DIR" -maxdepth 3 -type d -name '.aidentity-*' -prune \
      -o -type d -name '*.app' -print -prune 2>/dev/null
    while IFS= read -r dir; do
      [ -d "$dir" ] && find -H "$dir" -maxdepth 2 -type d -name '.aidentity-*' -prune \
        -o -type d -name '*.app' -print -prune 2>/dev/null
    done <<EOF
$(app_search_dirs)
EOF
    if command -v mdfind >/dev/null 2>&1; then
      mdfind "kMDItemCFBundleIdentifier == 'com.aidentity.*'" 2>/dev/null
    fi
  } | awk 'NF && !seen[$0]++' | while IFS= read -r dir; do
    case "$dir" in */.aidentity-*|*/.Trash/*|*/.Trashes/*) continue ;; esac
    is_our_launcher "$dir" && printf '%s\n' "$dir"
  done
}

# The identity of every data directory a launcher points at, space-separated.
claimed_dir_ids() {
  local app d id ids=" "
  while IFS= read -r app; do
    [ -n "$app" ] || continue
    d=$(plist_get "$app" "AIdentityDataDir")
    [ -n "$d" ] || continue
    id=$(dir_id "$d") && ids="$ids$id "
  done <<EOF
$(all_launchers)
EOF
  printf '%s' "$ids"
}

human_bytes() {
  [ -d "$1" ] || { printf '0B'; return 0; }
  du -sh "$1" 2>/dev/null | awk '{print $1}' || printf '?'
}

cmd_rename() {
  local from="" to=""
  while [ $# -gt 0 ]; do
    case "$1" in
      -*) die "Unknown option for rename: $1" ;;
      *) if [ -z "$from" ]; then from="$1"; elif [ -z "$to" ]; then to="$1";
         else die "Usage: aidentity rename \"<profile>\" \"<new name>\""; fi; shift ;;
    esac
  done
  [ -n "$from" ] && [ -n "$to" ] || die "Usage: aidentity rename \"<profile>\" \"<new name>\""

  local app; app=$(launcher_for "$from") || exit 1
  validate_profile_name "$to" || exit 1
  from=$(bundle_name "$app")

  local src_app old_data profile badge hex kind=""
  src_app=$(plist_get "$app" "AIdentityTargetApp")
  old_data=$(plist_get "$app" "AIdentityDataDir")
  profile=$(plist_get "$app" "$MARKER_KEY")
  is_main_launcher "$app" && kind="main"
  badge=$(launcher_badge "$app" "$src_app" "$profile")
  hex=$(launcher_color "$app" "$from")

  [ -d "$src_app" ] || die "'$from' points at an app that is no longer there:
    $src_app
    Run 'aidentity rebuild' after reinstalling it, or remove the profile."

  # A badge that was only the old name's first letter follows the new name;
  # "Client" kept the "W" of "Work". A badge chosen by hand stays.
  if [ -n "$badge" ] && [ "$badge" = "$(first_upper "$profile")" ]; then
    badge=$(first_upper "$to")
  fi

  local new_label; new_label="$(bundle_name "$src_app") $to"
  local new_slug;  new_slug="$(slugify "$new_label")"
  local new_app="$APPS_DIR/$new_label.app"

  [ "$new_label" = "$from" ] && die "'$from' already has that name."

  # On a disk that ignores case, "Work" -> "work" names this very bundle. That
  # is a rename of this launcher, not a collision with another one.
  if [ -e "$new_app" ] && ! [ "$new_app" -ef "$app" ]; then
    die "There is already something at $new_app. Pick another name."
  fi

  local new_data="" moved=0
  if [ "$kind" != "main" ]; then
    [ -n "$new_slug" ] || die "Cannot derive a profile directory from '$new_label'."
    new_data="$DATA_ROOT/$new_slug"

    # Renaming while the app is open would move the directory out from under a
    # live Chromium instance.
    if running_on_profile "$old_data"; then
      die "'$from' is running right now. Quit it, then rename."
    fi

    # Names that differ only in case, or in spaces against hyphens, keep the
    # same directory. Nothing needs to move, and the old -e test refused them.
    if [ "$new_data" = "$old_data" ] || { [ -n "$(dir_id "$old_data")" ] &&
         [ "$(dir_id "$old_data")" = "$(dir_id "$new_data")" ]; }; then
      new_data="$old_data"
    elif [ -e "$new_data" ]; then
      die "A profile directory already exists at:
      $new_data
    Pick a name that does not collide with an existing profile."
    fi

    socket_path_ok "$src_app" "$new_data" "$new_label" new || exit 1

    # Move the data FIRST. If the rebuild then fails, it is moved back and
    # the old launcher, untouched, still points at it.
    if [ "$new_data" != "$old_data" ] && [ -d "$old_data" ]; then
      data_is_ours "$old_data" || die "'$from' records a profile directory outside the aidentity
    data root, so renaming it is not safe:
      $old_data"
      mv "$old_data" "$new_data" || die "Could not move the profile directory to $new_data"
      moved=1
      RENAME_UNDO="$new_data|$old_data"
    fi
  fi

  if ! build_launcher "$src_app" "$to" "$new_data" "$new_label" "$badge" "$hex" "$kind" \
       "$(filter_extras "$(extras_of "$app/Contents/Info.plist")" "$src_app" "$kind")"; then
    RENAME_UNDO=""
    if [ "$moved" -eq 1 ] && ! mv "$new_data" "$old_data" 2>/dev/null; then
      die "Could not build the renamed launcher, and could not move the profile back.
    The signed-in data is at: $new_data
    Move it back to $old_data by hand; '$from' still points there."
    fi
    die "Could not build the renamed launcher. Nothing was changed."
  fi

  # The new launcher is in place and points at the moved data: an interrupt
  # from here on must not move it back.
  RENAME_UNDO=""

  # After a case-only rename the old path IS the new launcher. Deleting it
  # would delete the launcher just built.
  if ! [ "$app" -ef "$new_app" ]; then
    rm -rf "$app" 2>/dev/null
    [ -e "$app" ] && warn "Could not remove the old launcher; delete it by hand: $app"
  fi
  ok "Renamed ${C_BOLD}$from${C_RESET} to ${C_BOLD}$new_label${C_RESET}"
  if [ "$kind" = "main" ]; then
    dim "  It still opens your original account."
  elif [ "$moved" -eq 1 ]; then
    printf '   profile   %s\n' "$(dim "$new_data")"
    dim "  The account stays signed in — only the name and directory moved."
  else
    printf '   profile   %s\n' "$(dim "$new_data")"
    dim "  The account stays signed in — only the name changed."
  fi
}

cmd_set() {
  local want="" badge="" color="" no_badge=0 changed=0 add_extras="" clear_args=0 clear_env=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --badge|-b) need_value "$1" "${2:-}"; badge="$2"; shift 2 ;;
      --color|--colour|-c) need_value "$1" "${2:-}"; color="$2"; shift 2 ;;
      --no-badge) no_badge=1; shift ;;
      --arg) [ -n "${2:-}" ] || die "--arg needs a switch, e.g.  --arg --lang=de"
             validate_switch "$2" || exit 1
             add_extras="${add_extras:+$add_extras
}arg$TAB$2"; shift 2 ;;
      --env) [ -n "${2:-}" ] || die "--env needs NAME=value"
             validate_env "$2" || exit 1
             add_extras="${add_extras:+$add_extras
}env$TAB$2"; shift 2 ;;
      --clear-args) clear_args=1; shift ;;
      --clear-env)  clear_env=1; shift ;;
      --own-extensions)    add_extras="${add_extras:+$add_extras
}ext${TAB}1"; shift ;;
      --shared-extensions) add_extras="${add_extras:+$add_extras
}noext"; shift ;;
      -*) die "Unknown option for set: $1" ;;
      *) [ -z "$want" ] && want="$1" || die "Unexpected argument: $1"; shift ;;
    esac
  done
  [ -n "$want" ] || die "Usage: aidentity set \"<profile>\" [--color NAME] [--badge X] [--no-badge]
    [--arg SWITCH] [--env NAME=value] [--clear-args] [--clear-env]
    [--own-extensions | --shared-extensions]"
  [ -n "$badge" ] || [ -n "$color" ] || [ "$no_badge" -eq 1 ] || [ -n "$add_extras" ] \
    || [ "$clear_args" -eq 1 ] || [ "$clear_env" -eq 1 ] \
    || die "Nothing to change. Pass --color, --badge, --no-badge, --arg, --env,
    --clear-args, --clear-env, --own-extensions or --shared-extensions."

  local app; app=$(launcher_for "$want") || exit 1
  want=$(bundle_name "$app")

  local src_app profile data_dir cur_badge cur_hex kind=""
  src_app=$(plist_get "$app" "AIdentityTargetApp")
  profile=$(plist_get "$app" "$MARKER_KEY")
  data_dir=$(plist_get "$app" "AIdentityDataDir")
  is_main_launcher "$app" && kind="main"
  cur_badge=$(launcher_badge "$app" "$src_app" "$profile")
  cur_hex=$(launcher_color "$app" "$want")

  [ -d "$src_app" ] || die "'$want' points at an app that is no longer there:
    $src_app"

  local new_badge="$cur_badge" new_hex="$cur_hex"
  if [ "$no_badge" -eq 1 ]; then
    new_badge=""; changed=1
  elif [ -n "$badge" ]; then
    new_badge=$(first_char "$badge"); changed=1
    [ -n "$new_badge" ] || die "'$badge' is not a character that can be drawn as a badge."
  fi
  if [ -n "$color" ]; then
    new_hex=$(color_hex "$color") \
      || die "Unknown colour '$color'. Try one of: $COLOR_NAMES, or a hex value like 2E7DF6."
    changed=1
    # Asking for a colour with no badge showing is almost certainly a mistake.
    [ -z "$new_badge" ] && [ "$no_badge" -eq 0 ] && {
      new_badge=$(first_upper "$profile")
      dim "  No badge was set, so --color added one: $new_badge"
    }
  fi
  local extras settings_changed=0
  extras=$(filter_extras "$(extras_of "$app/Contents/Info.plist")" "$src_app" "$kind")
  if [ "$clear_args" -eq 1 ]; then extras=$(printf '%s\n' "$extras" | /usr/bin/grep -v "^arg$TAB" || true); changed=1; settings_changed=1; fi
  if [ "$clear_env" -eq 1 ];  then extras=$(printf '%s\n' "$extras" | /usr/bin/grep -v "^env$TAB" || true); changed=1; settings_changed=1; fi
  if [ -n "$add_extras" ]; then extras=$(extras_merge "$extras" "$add_extras"); changed=1; settings_changed=1; fi
  [ "$changed" -eq 1 ] || die "Nothing to change."

  # Only the launcher bundle is rewritten; the profile directory is untouched,
  # so the account stays signed in even if the app is open right now.
  build_launcher "$src_app" "$profile" "$data_dir" "$want" "$new_badge" "$new_hex" "$kind" "$extras" || exit 1
  ok "Updated ${C_BOLD}$want${C_RESET}"
  if [ "$settings_changed" -eq 1 ]; then
    dim "  The signed-in account is untouched. New launch settings apply the next time"
    dim "  this profile opens; quit it first if it is open now."
  else
    dim "  The signed-in account is untouched — only the icon changed."
  fi
}

# Profile directories in the data root that no launcher points at, one per
# line. Compared by directory identity, not by spelling: a string match made a
# live profile look orphaned whenever its launcher recorded the root
# differently — a symlinked root, a trailing slash, /tmp against /private/tmp.
orphan_dirs() {
  local claimed d id
  [ -d "$DATA_ROOT" ] || return 0
  claimed=$(claimed_dir_ids)
  for d in "$DATA_ROOT"/*; do
    [ -d "$d" ] || continue
    id=$(dir_id "$d") || continue
    case "$claimed" in *" $id "*) continue ;; esac
    printf '%s\n' "$d"
  done
}

# The launcher name a profile directory's restore record would rebuild, e.g.
# "Claude Work". Fails when the directory has no readable record.
restore_label() {
  local profile src
  [ -f "$1/$RESTORE_RECORD" ] || return 1
  profile=$(record_get "$1" "$MARKER_KEY") || return 1
  src=$(record_get "$1" AIdentityTargetApp) || return 1
  [ -n "$profile" ] && [ -n "$src" ] || return 1
  # Printed to the terminal by restore and prune: a record carrying escape
  # sequences could rewrite what the prune prompt shows. Invalid records are
  # simply not offered.
  validate_profile_name "$profile" 2>/dev/null || return 1
  case "$src" in *[[:cntrl:]]*) return 1 ;; esac
  printf '%s %s' "$(bundle_name "$src")" "$profile"
}

# Rebuild the launcher for one orphaned profile directory from its restore
# record. Everything read from the record is checked as if typed on the
# command line: the profile name is validated, the app must be a real
# Chromium/Electron app and not one of our launchers, and the directory must
# sit inside the data root.
restore_one() {
  local dir="$1" profile src bid found label badge hex
  if ! data_is_ours "$dir"; then
    warn "Skipping $dir — it is outside the aidentity data folder."
    return 1
  fi
  profile=$(record_get "$dir" "$MARKER_KEY") || { warn "Cannot read the restore record in $dir"; return 1; }
  validate_profile_name "$profile" || return 1
  src=$(record_get "$dir" AIdentityTargetApp)
  bid=$(record_get "$dir" AIdentityTargetBundleID)
  is_bundle_id "$bid" || bid=""

  if [ ! -d "$src" ]; then
    # The app moved: look it up by name, then by bundle identifier — but only
    # inside the app folders. A Spotlight hit on a mounted installer or an
    # unpacked download would otherwise be handed this signed-in profile.
    found=$(refind_app "$src" || true)
    if [ -z "$found" ] && [ -n "$bid" ] && command -v mdfind >/dev/null 2>&1; then
      local hit dir
      while IFS= read -r hit; do
        [ -n "$hit" ] || continue
        while IFS= read -r dir; do
          case "$hit" in "${dir%/}"/*) found="$hit"; break ;; esac
        done <<EOF
$(app_search_dirs)
EOF
        [ -n "$found" ] && break
      done <<EOF
$(mdfind "kMDItemCFBundleIdentifier == '$bid'" 2>/dev/null)
EOF
    fi
    if [ -z "$found" ]; then
      warn "$(bundle_name "$src") is not installed any more. Reinstall it, then run this again."
      return 1
    fi
    info "  The app moved; using $found"
    src="$found"
  fi
  src=$(resolve_target_app "$src") || return 1

  label="$(bundle_name "$src") $profile"
  if [ -e "$APPS_DIR/$label.app" ]; then
    warn "There is already something at $APPS_DIR/$label.app — remove or rename it first."
    return 1
  fi
  socket_path_ok "$src" "$dir" "$label" restore || return 1

  badge=$(first_char "$(record_get "$dir" AIdentityBadge)")
  hex=$(color_hex "$(record_get "$dir" AIdentityColor)" 2>/dev/null) \
    || hex=$(color_hex "$(auto_color "$label")")

  # The record's launch settings go through build_launcher's checks like any.
  build_launcher "$src" "$profile" "$dir" "$label" "$badge" "$hex" "" \
    "$(filter_extras "$(extras_of "$dir/$RESTORE_RECORD")" "$src" "")" || return 1
  ok "Restored ${C_BOLD}$label${C_RESET} — it opens the same profile folder as before."
}

cmd_restore() {
  local want="" all=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --all|-a) all=1; shift ;;
      -*) die "Unknown option for restore: $1" ;;
      *) [ -z "$want" ] && want="$1" || die "Unexpected argument: $1"; shift ;;
    esac
  done
  [ -n "$want" ] && [ "$all" -eq 1 ] && die "Give a name or --all, not both."

  local dirs=() labels=() d label
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    label=$(restore_label "$d") || continue
    dirs+=("$d"); labels+=("$label")
  done <<EOF
$(orphan_dirs)
EOF

  if [ "${#dirs[@]}" -eq 0 ]; then
    info "Nothing to restore — every profile with a restore record has a launcher."
    [ -z "$want" ] && [ "$all" -eq 0 ] && return 0
    return 1
  fi

  local i=0
  if [ -z "$want" ] && [ "$all" -eq 0 ]; then
    info "${C_BOLD}Profiles whose launcher is gone, and can be rebuilt:${C_RESET}"
    info ""
    while [ "$i" -lt "${#dirs[@]}" ]; do
      printf '  %-28s %s\n' "${labels[$i]}" "$(dim "${dirs[$i]}")"
      i=$((i+1))
    done
    info ""
    dim "  One:  aidentity restore \"${labels[0]}\"      All:  aidentity restore --all"
    return 0
  fi

  local matched=0 failed=0
  while [ "$i" -lt "${#dirs[@]}" ]; do
    if [ "$all" -eq 1 ] || [ "$(lower "${labels[$i]}")" = "$(lower "$want")" ]; then
      matched=$((matched+1))
      restore_one "${dirs[$i]}" || failed=$((failed+1))
    fi
    i=$((i+1))
  done
  [ "$matched" -gt 0 ] || die "No restorable profile named '$want'. Run 'aidentity restore' to see them."
  [ "$failed" -eq 0 ]
}

cmd_prune() {
  local yes=0
  while [ $# -gt 0 ]; do
    case "$1" in
      -y|--yes) yes=1; shift ;;
      -*) die "Unknown option for prune: $1" ;;
      *) die "Unexpected argument: $1" ;;
    esac
  done

  [ -d "$DATA_ROOT" ] || { info "No profile data directory yet — nothing to prune."; return 0; }

  local orphans=() d n=0 label
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    orphans+=("$d"); n=$((n+1))
  done <<EOF
$(orphan_dirs)
EOF

  if [ "$n" -eq 0 ]; then
    ok "No orphaned profile data — every directory belongs to a launcher."
    return 0
  fi

  info "${C_BOLD}Profile data with no launcher pointing at it:${C_RESET}"
  info ""
  local restorable=0
  for d in "${orphans[@]}"; do
    printf '  %-10s %s\n' "$(human_bytes "$d")" "$(basename "$d")"
    dim "             $d"
    if label=$(restore_label "$d"); then
      dim "             can be restored: aidentity restore \"$label\""
      restorable=$((restorable+1))
    fi
  done
  info ""
  if [ "$restorable" -gt 0 ]; then
    info "To keep an account, restore it first — then it is no longer listed here."
    info ""
  fi
  dim "  This is what is left when a launcher is deleted in Finder, or removed with"
  dim "  'aidentity rm' without --purge. Launchers were looked for in $APPS_DIR"
  dim "  (and folders inside it), in the app folders and through Spotlight. If you"
  dim "  keep a launcher anywhere else, its account is listed here: do not remove it."
  info ""

  if [ "$yes" -eq 0 ]; then
    local reply; reply=$(ask "Move $n orphaned profile(s) to the Trash? Type yes to confirm: ") \
      || die "Nothing to confirm with."
    [ "$reply" = "yes" ] || die "Cancelled. Nothing was moved."
  fi

  local moved=0 dest
  for d in "${orphans[@]}"; do
    if running_on_profile "$d"; then
      warn "Skipping $(basename "$d") — something is running on it."
      continue
    fi
    if ! data_is_ours "$d"; then
      warn "Skipping $(basename "$d") — outside the aidentity data root."
      continue
    fi
    # trash_path says why when it cannot; the folder then stays where it is.
    if dest=$(trash_path "$d"); then
      moved=$((moved+1))
      dim "  $(basename "$d") is now at: $dest"
    fi
  done
  ok "Moved $moved orphaned profile(s) to the Trash."
  [ "$moved" -eq 0 ] || dim "  To undo, move a folder back into $DATA_ROOT, then run: aidentity restore"
}

# Rebuild one launcher from what its Info.plist records. Profile data is never
# touched. Returns non-zero, after saying why, if it could not be rebuilt.
# Shared by `rebuild` and `doctor --fix`.
rebuild_one() {
  local app="$1" label src_app profile data_dir badge hex kind="" found
  label=$(bundle_name "$app")
  src_app=$(plist_get "$app" "AIdentityTargetApp")
  profile=$(plist_get "$app" "$MARKER_KEY")
  data_dir=$(plist_get "$app" "AIdentityDataDir")
  is_main_launcher "$app" && kind="main"
  hex=$(launcher_color "$app" "$label")

  if [ ! -d "$src_app" ]; then
    # The app moved or was uninstalled. Try to find it again by name before
    # giving up, which covers the common /Applications -> ~/Applications move.
    found=$(refind_app "$src_app" || true)
    if [ -n "$found" ]; then
      info "  $label: target moved, now $found"
      src_app="$found"
    else
      warn "$label: target app is missing and could not be found again:"
      dim  "    $src_app"
      return 1
    fi
  fi

  # Only now, with the app found: a 1.0.0 launcher's badge is worked out by
  # comparing its icon with the app's, which fails against a path that moved.
  badge=$(launcher_badge "$app" "$src_app" "$profile")
  if is_legacy_launcher "$app"; then
    info "  $label: built by aidentity 1.0.0 — badge and colour restored to its defaults."
    dim  "    A colour or letter you picked yourself back then: aidentity set \"$label\" --color …"
  fi

  if ! build_launcher "$src_app" "$profile" "$data_dir" "$label" "$badge" "$hex" "$kind" \
       "$(filter_extras "$(extras_of "$app/Contents/Info.plist")" "$src_app" "$kind")"; then
    warn "$label: rebuild failed."
    return 1
  fi
  return 0
}

cmd_rebuild() {
  local want="" all=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --all|-a) all=1; shift ;;
      -*) die "Unknown option for rebuild: $1" ;;
      *) [ -z "$want" ] && want="$1" || die "Unexpected argument: $1"; shift ;;
    esac
  done
  [ -n "$want" ] || [ "$all" -eq 1 ] \
    || die "Usage: aidentity rebuild \"<profile>\"   or   aidentity rebuild --all"

  local targets=() app
  if [ "$all" -eq 1 ]; then
    for app in "$APPS_DIR"/*.app; do
      [ -d "$app" ] || continue
      is_our_launcher "$app" && targets+=("$app")
    done
    [ "${#targets[@]}" -gt 0 ] || { info "No profiles to rebuild."; return 0; }
  else
    app=$(launcher_for "$want") || exit 1
    targets+=("$app")
  fi

  local done_n=0 failed=0
  for app in "${targets[@]}"; do
    if rebuild_one "$app"; then done_n=$((done_n+1)); else failed=$((failed+1)); fi
  done

  info ""
  [ "$done_n" -gt 0 ] && ok "Rebuilt $done_n launcher(s)."
  dim "  Profile data was not touched — every account stays signed in."
  # A failure is a failure: this printed a green tick and exited 0 even when
  # nothing could be rebuilt, so a script never noticed.
  if [ "$failed" -gt 0 ]; then
    warn "$failed launcher(s) could not be rebuilt."
    return 1
  fi
  return 0
}
