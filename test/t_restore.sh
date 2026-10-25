# shellcheck shell=bash
#
# Area "restore": restore records and restore; doctor and --fix; re-adding a profile;
# what doctor and restore vet before they rebuild.
# Sourced by test/run_tests.sh after test/lib.sh. Run it alone with:
#   bash test/run_tests.sh restore

group "restore records and aidentity restore"

ai add "$ELECTRON_APP" --profile Keep --color teal --badge K
KEEP_DATA="$DATA/fake-keep"
printf 'session\n' > "$KEEP_DATA/Cookies"
assert_file "add writes a restore record into the profile folder" "$KEEP_DATA/.aidentity-profile.plist"
assert_eq "the record is owner-only" "600" "$(stat -f '%Lp' "$KEEP_DATA/.aidentity-profile.plist")"
assert_eq "the record names the profile" "Keep" \
  "$(/usr/libexec/PlistBuddy -c 'Print :AIdentityProfile' "$KEEP_DATA/.aidentity-profile.plist" 2>/dev/null)"

# A launcher deleted in Finder: the folder stays, with its record.
rm -rf "$APPS/Fake Keep.app"
ai restore
assert_contains "restore lists a profile whose launcher is gone" "$RUN_OUT" "Fake Keep"
ai prune
assert_contains "prune says a listed folder can be restored" "$RUN_OUT" 'aidentity restore "Fake Keep"'
assert_file "a cancelled prune deletes nothing" "$KEEP_DATA/Cookies"
ai restore "fake keep"
assert_rc "restore rebuilds it by name, any capitals" 0 "$RUN_RC" "$RUN_OUT"
assert_dir "the launcher is back" "$APPS/Fake Keep.app"
assert_eq "it points at the same folder" "$KEEP_DATA" "$(plist_key "$APPS/Fake Keep.app" AIdentityDataDir)"
assert_eq "with the colour it had" "12A594" "$(plist_key "$APPS/Fake Keep.app" AIdentityColor)"
assert_eq "and the badge it had" "K" "$(plist_key "$APPS/Fake Keep.app" AIdentityBadge)"
assert_file "and the session is untouched" "$KEEP_DATA/Cookies"
ai restore "Fake Keep"
assert_rc_nonzero "restore refuses a profile that already has a launcher" "$RUN_RC" "$RUN_OUT"

# The app moved since: restore finds it by name.
MOVER_DIR="$SB/moved-apps"
mkdir -p "$MOVER_DIR"
make_electron_app "$SRC/Mover.app"
ai add "$SRC/Mover.app" --profile Far
rm -rf "$APPS/Mover Far.app"
mv "$SRC/Mover.app" "$MOVER_DIR/"
RUN_OUT=$(AIDENTITY_APP_DIRS="$SRC:$APPS:$MOVER_DIR" detached "$BASH_BIN" "$AIDENTITY" restore --all 2>&1 </dev/null); RUN_RC=$?
assert_rc "restore --all finds an app that moved" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "and points the launcher at its new place" "$MOVER_DIR/Mover.app" \
  "$(plist_key "$APPS/Mover Far.app" AIdentityTargetApp)"
ai rm "Mover Far" --purge -y
rm -rf "$MOVER_DIR"

# A record cannot smuggle in a bad name.
ai add "$ELECTRON_APP" --profile Bent
rm -rf "$APPS/Fake Bent.app"
/usr/libexec/PlistBuddy -c "Set :AIdentityProfile ../../evil" "$DATA/fake-bent/.aidentity-profile.plist"
ai restore --all
assert_rc_nonzero "a record with an invalid profile name is refused" "$RUN_RC" "$RUN_OUT"
assert_no_dir "and builds nothing" "$APPS/Fake ..app"
rm -rf "$DATA/fake-bent"


group "doctor checks every profile, and --fix repairs"

ai doctor
assert_contains "doctor lists each profile" "$RUN_OUT" "Fake Keep"
assert_rc "doctor reports but exits 0" 0 "$RUN_RC" "$RUN_OUT"

# Simulate drift: an older build, an open folder, no restore record.
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 0.9.0" "$APPS/Fake Keep.app/Contents/Info.plist"
chmod 755 "$KEEP_DATA"
rm -f "$KEEP_DATA/.aidentity-profile.plist"
ai doctor
assert_contains "doctor names an older build" "$RUN_OUT" "built by aidentity 0.9.0"
assert_contains "doctor names a folder others can read" "$RUN_OUT" "mode 755"
assert_contains "doctor names a missing restore record" "$RUN_OUT" "no restore record"
assert_contains "doctor points at --fix" "$RUN_OUT" "doctor --fix"
ai doctor --fix
assert_rc "doctor --fix succeeds" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "the launcher is rebuilt by this version" "$(sed -n 's/^AIDENTITY_VERSION="\(.*\)"$/\1/p' "$AIDENTITY")" \
  "$(plist_key "$APPS/Fake Keep.app" CFBundleShortVersionString)"
assert_eq "the folder is owner-only again" "700" "$(stat -f '%Lp' "$KEEP_DATA")"
assert_file "the restore record is back" "$KEEP_DATA/.aidentity-profile.plist"
assert_file "the session was not touched" "$KEEP_DATA/Cookies"
assert_eq "the colour survived" "12A594" "$(plist_key "$APPS/Fake Keep.app" AIdentityColor)"
ai doctor
assert_not_contains "after --fix, nothing fixable is left for it" "$RUN_OUT" "Fake Keep —"

make_electron_app "$SRC/Vanish.app"
ai add "$SRC/Vanish.app" --profile V
rm -rf "$SRC/Vanish.app"
ai doctor
assert_contains "doctor says when an app is gone" "$RUN_OUT" "its app is gone"
ai rm "Vanish V" --purge -y


group "re-adding keeps the look; relative data roots are cleaned"

ai set "Fake Keep" --color red --badge Q
ai add "$ELECTRON_APP" --profile Keep
assert_rc "re-adding an existing profile succeeds" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "and says Updated, not Created" "$RUN_OUT" "Updated"
assert_eq "it keeps the colour that was set" "E5484D" "$(plist_key "$APPS/Fake Keep.app" AIdentityColor)"
assert_eq "it keeps the badge that was set" "Q" "$(plist_key "$APPS/Fake Keep.app" AIdentityBadge)"
ai add "$ELECTRON_APP" --profile Keep --color blue
assert_eq "a colour given on re-add still wins" "2E7DF6" "$(plist_key "$APPS/Fake Keep.app" AIdentityColor)"
ai rm "Fake Keep" --purge -y

REL_CWD="$SB/cwd/sub"
mkdir -p "$REL_CWD"
RUN_OUT=$(cd "$REL_CWD" && AIDENTITY_DATA_ROOT=../reldata detached "$BASH_BIN" "$AIDENTITY" add "$ELECTRON_APP" --profile Rel 2>&1 </dev/null); RUN_RC=$?
assert_rc "a relative data root works" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "and is recorded without dot segments" "$SB/cwd/reldata/fake-rel" \
  "$(plist_key "$APPS/Fake Rel.app" AIdentityDataDir)"
RUN_OUT=$(cd "$REL_CWD" && AIDENTITY_DATA_ROOT=../reldata detached "$BASH_BIN" "$AIDENTITY" rm "Fake Rel" --purge -y 2>&1 </dev/null); RUN_RC=$?
assert_no_dir "so purge can delete what it made" "$SB/cwd/reldata/fake-rel"


group "doctor and restore vet what they rebuild"

# A damaged launcher that records no app. resolve_app("") returns an app
# folder itself, which doctor --fix used to "repair" the launcher into.
ai add "$ELECTRON_APP" --profile Hollow
/usr/libexec/PlistBuddy -c "Set :AIdentityTargetApp ''" "$APPS/Fake Hollow.app/Contents/Info.plist"
ai doctor
assert_contains "doctor says a launcher records no app" "$RUN_OUT" "records no app"
ai doctor --fix
assert_eq "doctor --fix does not point it at a folder" "" \
  "$(plist_key "$APPS/Fake Hollow.app" AIdentityTargetApp)"
ai rebuild "Fake Hollow"
assert_rc_nonzero "rebuild refuses a launcher with no app" "$RUN_RC" "$RUN_OUT"
ai rm "Fake Hollow" --purge -y

# An app that moved, where only a plain folder of the same name remains.
make_electron_app "$SRC/Shifty.app"
ai add "$SRC/Shifty.app" --profile S
rm -rf "$SRC/Shifty.app"
mkdir -p "$SRC/Shifty"
ai doctor
assert_contains "a folder with the app's name is not taken for the app" "$RUN_OUT" "its app is gone"
rmdir "$SRC/Shifty"
ai rm "Shifty S" --purge -y

# A 1.0.0 launcher: --fix still says its badge and colour went back to defaults.
ai add "$ELECTRON_APP" --profile Oldie
/usr/libexec/PlistBuddy -c "Delete :AIdentityBadge" -c "Delete :AIdentityColor" \
  "$APPS/Fake Oldie.app/Contents/Info.plist" >/dev/null 2>&1
ai doctor --fix
assert_contains "doctor --fix shows the 1.0.0 note" "$RUN_OUT" "1.0.0"
ai rm "Fake Oldie" --purge -y

# Records that are not valid are not offered, and are never printed raw.
ai add "$ELECTRON_APP" --profile Esc
rm -rf "$APPS/Fake Esc.app"
/usr/libexec/PlistBuddy -c "Set :AIdentityProfile $(printf 'Esc\033[2J')" \
  "$DATA/fake-esc/.aidentity-profile.plist"
ai restore
assert_not_contains "a record with control characters is not listed" "$RUN_OUT" "Esc"
rm -rf "$DATA/fake-esc"

ai restore "Something" --all
assert_rc_nonzero "restore refuses a name together with --all" "$RUN_RC" "$RUN_OUT"

# The colour from a record is stored as hex, whatever spelling the record had.
ai add "$ELECTRON_APP" --profile Hue
rm -rf "$APPS/Fake Hue.app"
/usr/libexec/PlistBuddy -c "Set :AIdentityColor blue" "$DATA/fake-hue/.aidentity-profile.plist"
ai restore "Fake Hue"
assert_eq "a colour name in a record is stored as hex" "2E7DF6" "$(plist_key "$APPS/Fake Hue.app" AIdentityColor)"

# Re-adding under a different data root keeps the folder the profile records.
printf 'session\n' > "$DATA/fake-hue/Cookies"
AIDENTITY_DATA_ROOT="$SB/other-root" ai add "$ELECTRON_APP" --profile Hue
assert_eq "re-adding keeps the profile's own folder" "$DATA/fake-hue" \
  "$(plist_key "$APPS/Fake Hue.app" AIdentityDataDir)"
assert_no_dir "and makes no new one under the other root" "$SB/other-root/fake-hue"
ai rm "Fake Hue" --purge -y
