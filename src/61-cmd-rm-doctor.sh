# -------------------------------------------------- commands: rm, doctor --

cmd_rm() {
  local want="" purge=0 yes=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --purge) purge=1; shift ;;
      -y|--yes) yes=1; shift ;;
      -*) die "Unknown option for rm: $1" ;;
      # One name only. Taking the last of several made `rm A B --purge -y`
      # delete B and silently ignore A.
      *) [ -z "$want" ] && want="$1" || die "Unexpected argument: $1  (one profile at a time; quote a name that has spaces)"; shift ;;
    esac
  done
  [ -n "$want" ] || die "Usage: aidentity rm \"<profile>\" [--purge]"

  local app="$APPS_DIR/$want.app"
  [ -d "$app" ] || die "No launcher named '$want'. Run 'aidentity list' to see what exists."
  assert_ours "$app"

  # Read everything needed afterwards now — the launcher is about to go.
  local data target profile main=0
  data=$(plist_get "$app" "AIdentityDataDir")
  target=$(plist_get "$app" "AIdentityTargetApp")
  profile=$(plist_get "$app" "$MARKER_KEY")
  is_main_launcher "$app" && main=1

  if [ "$main" -eq 1 ] && [ "$purge" -eq 1 ]; then
    warn "'$want' opens $(bundle_name "$target")'s own account. aidentity never deletes that
    data, so --purge does nothing here; only the launcher is removed."
    purge=0
  fi

  if [ "$main" -eq 0 ] && running_on_profile "$data"; then
    die "'$want' is running right now. Quit it first (aidentity quit \"$want\"), then re-run."
  fi

  if [ "$yes" -eq 0 ]; then
    if [ "$purge" -eq 1 ]; then
      printf 'Remove launcher "%s" AND move its data to the Trash?\n  %s\n' "$want" "$data"
    elif [ "$main" -eq 1 ]; then
      printf 'Remove launcher "%s"? Your original account is not affected.\n' "$want"
    else
      printf 'Remove launcher "%s"? Its data is kept.\n' "$want"
    fi
    local reply; reply=$(ask 'Type yes to confirm: ')
    [ "$reply" = "yes" ] || die "Cancelled."
  fi

  # Launchers built before restore records existed get one now, while the
  # launcher still says what it was — so the hint below always works. With
  # --purge too: the data goes to the Trash, and once it is moved back,
  # restore needs the record.
  if [ "$main" -eq 0 ] && [ -d "$data" ] && data_is_ours "$data" \
     && [ ! -f "$data/$RESTORE_RECORD" ]; then
    write_restore_record "$data" "$profile" "$target" \
      "$(launcher_badge "$app" "$target" "$profile")" "$(launcher_color "$app" "$want")" \
      "$(extras_of "$app/Contents/Info.plist")" || true
  fi

  # Move it aside first, delete it second. A locked bundle (or one owned by
  # someone else) survived rm -rf with its Info.plist gone — no longer
  # recognisable as ours, so its data then looked orphaned — and this still
  # printed "Removed" and went on to delete the data. A locked bundle cannot be
  # moved, so now it is refused whole, with nothing touched.
  BUILD_STAGE=$(mktemp -d "$APPS_DIR/.aidentity-rm.XXXXXX" 2>/dev/null) \
    || { BUILD_STAGE=""; die "Could not write to $APPS_DIR. Nothing was changed."; }
  if ! mv "$app" "$BUILD_STAGE/" 2>/dev/null; then
    _cleanup_stage
    die "Could not remove $app — it may be locked (Finder → Get Info) or
    owned by another user. Nothing was changed."
  fi
  local leftover="$BUILD_STAGE"
  _cleanup_stage || warn "Part of the old launcher could not be deleted (a locked file?).
    It is out of the way, in: $leftover"
  ok "Removed launcher '$want'."
  [ "$main" -eq 1 ] && return 0

  # How to get the account back. Worked out now: the record cannot be read
  # once the folder is in the Trash, which the system may keep private.
  local again
  if [ -f "$data/$RESTORE_RECORD" ]; then
    again="aidentity restore \"$want\""
  else
    local app_ref; app_ref=$(bundle_name "$target")
    [ "$(resolve_app "$app_ref" 2>/dev/null)" = "$target" ] || app_ref="$target"
    again="aidentity add \"$app_ref\" --profile \"$profile\""
  fi

  if [ "$purge" -eq 1 ]; then
    # Only move data out of our own data root — never an arbitrary recorded path.
    if ! data_is_ours "$data"; then
      warn "Profile data is outside the aidentity data directory; left in place:"
      dim "  $data"
      return 0
    fi
    # Launchers from 1.0.0 could share one directory, and a second add or an
    # import can make one share it again. Moving it away would sign the other
    # launcher out too. When the launchers cannot all be looked for, the data
    # is kept: one that was missed would be signed out.
    local others
    if ! others=$(launchers_sharing "$data"); then
      warn "Profile data kept — could not search all of $APPS_DIR for another launcher that uses it."
      dim "  The launcher is gone; its data is still at: $data"
      dim "  To use this account again:  $again"
      return 1
    fi
    if [ -n "$others" ]; then
      warn "Profile data kept — another launcher uses the same directory: $others"
      dim "  $data"
      return 0
    fi
    # Checked again: the confirmation above can sit for minutes, and the app
    # may have been opened in the meantime.
    if running_on_profile "$data"; then
      die "The profile was opened while waiting for confirmation. The launcher is
    gone, but its data was kept: $data"
    fi
    if [ ! -e "$data" ] && [ ! -L "$data" ]; then
      dim "  It had no profile data to move: $data is gone already."
      return 0
    fi
    local moved
    if ! moved=$(trash_path "$data"); then
      dim "  The launcher is gone; its data is still at: $data"
      dim "  To use this account again:  $again"
      return 1
    fi
    ok "Moved the profile data to the Trash."
    dim "  It is now at: $moved"
    dim "  To undo, move it back to: $data"
    dim "  then run:  $again"
  else
    # `aidentity rm NAME --purge` cannot work any more — that launcher is gone,
    # which is what this used to suggest. These two do.
    dim "  Profile data kept at: $data"
    dim "  To use this account again:     $again"
    dim "  To move the data to the Trash: aidentity prune"
  fi
}

# Other launchers that point at the same data directory as $1, however it is
# spelled. Prints them comma-separated: by name when they sit in the launcher
# directory, by path anywhere else. They are found the way prune finds them
# (all_launchers), in folders and app folders too: looking only at the top of
# the launcher directory missed a launcher filed into a folder, and rm --purge
# moved the data it was signed in with. Returns non-zero when that search
# fails, so a caller about to move the data keeps it. A view that asks about
# many launchers passes the list from one all_launchers as $3. A folder that
# does not exist yet is matched by its path as recorded: add asks before it
# makes one, and a launcher can still record a folder that was removed.
launchers_sharing() { # data dir, [a launcher to leave out], [launcher list]
  local id="" app d list names="" seen=" " app_id
  id=$(dir_id "$1") || id=""
  if [ $# -ge 3 ]; then list=$3; else list=$(all_launchers) || return 1; fi
  while IFS= read -r app; do
    [ -n "$app" ] || continue
    [ -n "${2:-}" ] && [ "$app" -ef "$2" ] && continue
    # One launcher can be found under two spellings (Spotlight resolves the
    # path); name it once.
    app_id=$(dir_id "$app") || continue
    case "$seen" in *" $app_id "*) continue ;; esac
    seen="$seen$app_id "
    d=$(plist_get "$app" "AIdentityDataDir")
    [ -n "$d" ] || continue
    [ "$d" = "$1" ] || { [ -n "$id" ] && [ "$(dir_id "$d")" = "$id" ]; } || continue
    [ "${app%/*}" = "$APPS_DIR" ] && app=$(bundle_name "$app")
    names="${names:+$names, }$app"
  done <<EOF
$list
EOF
  printf '%s' "$names"
}

# Find a moved app again by its name, accepting only a real Chromium or
# Electron .app that is not one of our launchers. resolve_app alone also
# returns plain folders — and given an empty name, an app folder itself — so a
# launcher with a damaged plist was "fixed" into opening /Applications.
refind_app() {
  local name found
  [ -n "$1" ] || return 1
  name=$(bundle_name "$1")
  [ -n "$name" ] || return 1
  found=$(resolve_app "$name" 2>/dev/null) || return 1
  case "$found" in *.app) ;; *) return 1 ;; esac
  is_our_launcher "$found" && return 1
  is_chromium_app_deep "$found" || return 1
  printf '%s' "$found"
}

# What is wrong with one launcher: one finding per line, "fix<TAB>message" for
# what `doctor --fix` repairs and "warn<TAB>message" for what needs a person.
# $2 is every launcher, from one all_launchers, for the shared-folder check.
launcher_findings() { # launcher, launcher list
  local app="$1" label src data ver perms others tab n room fix
  tab=$(printf '\t')
  label=$(bundle_name "$app")
  src=$(plist_get "$app" AIdentityTargetApp)
  data=$(plist_get "$app" AIdentityDataDir)
  ver=$(plist_get "$app" CFBundleShortVersionString)
  if [ -z "$src" ]; then
    printf 'warn%sit records no app — remove it and add the profile again\n' "$tab"
  elif [ ! -d "$src" ]; then
    if [ -n "$(refind_app "$src")" ]; then
      printf 'fix%sits app moved; a rebuild finds it again\n' "$tab"
    else
      printf 'warn%sits app is gone: %s — reinstall it, then: aidentity rebuild "%s"\n' "$tab" "$src" "$label"
    fi
  elif ! is_chromium_app "$src"; then
    printf 'warn%s%s no longer looks like a Chromium or Electron app\n' "$tab" "$(bundle_name "$src")"
  fi
  if is_legacy_launcher "$app"; then
    printf 'fix%sbuilt by aidentity 1.0.0\n' "$tab"
  elif [ "$ver" != "$AIDENTITY_VERSION" ]; then
    printf 'fix%sbuilt by aidentity %s; a rebuild picks up %s\n' "$tab" "${ver:-(unknown)}" "$AIDENTITY_VERSION"
  fi
  [ -x "$app/Contents/MacOS/launcher" ] || printf 'fix%sits launcher script is missing\n' "$tab"
  is_main_launcher "$app" && return 0
  if [ -z "$data" ]; then
    printf 'warn%sit records no profile folder\n' "$tab"; return 0
  fi
  if ! data_is_ours "$data"; then
    printf 'warn%sits profile folder is outside the aidentity data folder: %s\n' "$tab" "$data"; return 0
  fi
  # Renaming is the fix, and the new name is the user's to choose.
  if is_vscode_family "$src"; then
    n=$(socket_path_bytes "$src" "$data")
    if [ "$n" -gt "$SOCKET_PATH_MAX" ]; then
      room=$(profile_name_room "$src")
      if [ "$room" -ge 1 ]; then
        fix="rename it to a name of at most $(count "$room" character): aidentity rename \"$label\" \"<new name>\""
      else
        fix="even a one-character name is too long in this data folder; remove it and add it again with a shorter AIDENTITY_DATA_ROOT"
      fi
      printf 'warn%s%s cannot open it: the socket path in its profile folder would be %s bytes, and macOS allows %s — %s\n' \
        "$tab" "$(bundle_name "$src")" "$n" "$SOCKET_PATH_MAX" "$fix"
    fi
  fi
  if [ ! -d "$data" ]; then
    printf 'warn%sits profile folder is gone, so it opens signed out\n' "$tab"; return 0
  fi
  [ -f "$data/$RESTORE_RECORD" ] || printf 'fix%sno restore record yet (made by an older aidentity)\n' "$tab"
  perms=$(/usr/bin/stat -f '%Lp' "$data" 2>/dev/null)
  [ "$perms" = "700" ] || printf 'fix%sother users can read its profile folder (mode %s)\n' "$tab" "$perms"
  others=$(launchers_sharing "$data" "$app" "$2")
  [ -z "$others" ] || printf 'warn%sshares its profile folder with: %s\n' "$tab" "$others"
  return 0
}

# Repair what launcher_findings marks "fix": a rebuild for anything about the
# launcher itself, chmod 700 for the profile folder's mode. Profile data inside
# the folder is never read or changed.
fix_launcher() { # launcher, launcher list
  local app="$1" findings data rebuild=0 rc=0
  findings=$(launcher_findings "$app" "$2")
  case "$findings" in
    *"fix"$'\t'"its app moved"*|*"fix"$'\t'"built by"*|*"fix"$'\t'"its launcher script"*|*"fix"$'\t'"no restore record"*) rebuild=1 ;;
  esac
  data=$(plist_get "$app" AIdentityDataDir)
  case "$findings" in
    *"fix"$'\t'"other users can read"*)
      if data_is_ours "$data" && [ -d "$data" ]; then chmod 700 "$data" || rc=1; fi ;;
  esac
  # A launcher whose folder lies outside the data root needs a person: a
  # rebuild would recreate that folder wherever the plist says.
  if [ -n "$data" ] && ! data_is_ours "$data"; then rebuild=0; fi
  # Its notes (an app that moved, a 1.0.0 badge reset) are worth seeing.
  if [ "$rebuild" -eq 1 ]; then rebuild_one "$app" | sed 's/^/    /' || rc=1; fi
  return "$rc"
}

cmd_doctor() {
  local problems=0 fixable=0 fix=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --fix) fix=1; shift ;;
      -*) die "Unknown option for doctor: $1" ;;
      *) die "Unexpected argument: $1" ;;
    esac
  done

  info "${C_BOLD}aidentity doctor${C_RESET}"
  info ""
  printf '  macOS               %s\n' "$(sw_vers -productVersion 2>/dev/null || echo unknown)"
  printf '  aidentity           %s\n' "$AIDENTITY_VERSION"
  printf '  bash                %s\n' "${BASH_VERSION:-unknown}"

  if [ -d "$APPS_DIR" ] && [ -w "$APPS_DIR" ]; then
    printf '  launcher dir        %s\n' "$(printf '%sok%s %s' "$C_GREEN" "$C_RESET" "$APPS_DIR")"
  elif [ ! -d "$APPS_DIR" ]; then
    printf '  launcher dir        %s\n' "$(dim "will be created: $APPS_DIR")"
  else
    printf '  launcher dir        %sNOT WRITABLE%s %s\n' "$C_RED" "$C_RESET" "$APPS_DIR"; problems=$((problems+1))
  fi

  if xcode-select -p >/dev/null 2>&1; then
    printf '  codesign            %savailable%s (launchers will be signed)\n' "$C_GREEN" "$C_RESET"
  else
    printf '  codesign            %sabsent%s — launchers work, just unsigned\n' "$C_YELLOW" "$C_RESET"
    dim "                      install with: xcode-select --install"
  fi

  local n; n=$(list_compatible_apps | wc -l | tr -d ' ')
  printf '  compatible apps     %s found\n' "$n"
  [ "$n" -eq 0 ] && { warn "No Chromium/Electron apps detected."; problems=$((problems+1)); }

  local launchers=() app
  for app in "$APPS_DIR"/*.app; do
    [ -d "$app" ] || continue
    is_our_launcher "$app" && launchers+=("$app")
  done
  printf '  profiles            %s\n' "${#launchers[@]}"

  # One row per launcher. `--fix` repairs first, then the rows show what is left.
  if [ "${#launchers[@]}" -gt 0 ]; then
    info ""
    info "${C_BOLD}Profiles${C_RESET}"
    local findings kind msg failed=0 found
    # Every launcher, looked for once, for the shared-folder check of each
    # row. A report uses what it found, even when part of the search failed.
    found=$(all_launchers) || true
    for app in "${launchers[@]}"; do
      findings=$(launcher_findings "$app" "$found")
      if [ "$fix" -eq 1 ] && [ -n "$findings" ] && printf '%s\n' "$findings" | grep -q '^fix'; then
        if fix_launcher "$app" "$found"; then
          printf '  %s✓%s %s %s\n' "$C_GREEN" "$C_RESET" "$(bundle_name "$app")" "$(dim "— fixed")"
        else
          failed=$((failed+1))
        fi
        findings=$(launcher_findings "$app" "$found")
      fi
      if [ -z "$findings" ]; then
        [ "$fix" -eq 1 ] || printf '  %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$(bundle_name "$app")"
        continue
      fi
      while IFS="$(printf '\t')" read -r kind msg; do
        [ -n "$kind" ] || continue
        problems=$((problems+1))
        [ "$kind" = "fix" ] && fixable=$((fixable+1))
        printf '  %s!%s %s — %s\n' "$C_YELLOW" "$C_RESET" "$(bundle_name "$app")" "$msg"
      done <<EOF
$findings
EOF
    done
  fi

  local orphans; orphans=$(orphan_dirs | grep -c . || true)
  if [ "${orphans:-0}" -gt 0 ]; then
    info ""
    printf '  %s!%s %s profile folder(s) have no launcher — see: aidentity restore, aidentity prune\n' \
      "$C_YELLOW" "$C_RESET" "$orphans"
    problems=$((problems+1))
  fi

  info ""
  if [ "$problems" -eq 0 ]; then
    ok "No problems found."
  elif [ "$fixable" -gt 0 ]; then
    warn "$problems problem(s) found. $fixable can be fixed with: aidentity doctor --fix"
  else
    warn "$problems problem(s) found."
  fi
  # doctor reports; it does not fail. Only a --fix that could not fix
  # something exits non-zero.
  [ "$fix" -eq 1 ] && [ "${failed:-0}" -gt 0 ] && return 1
  return 0
}
