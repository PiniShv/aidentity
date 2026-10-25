# shellcheck shell=bash
# SC2016: single-quoted scripts are handed to "$BASH_BIN" -c and to generated
# stubs, which expand them later, on purpose. shellcheck only recognises that
# when the interpreter is spelled literally as `bash -c`.
# shellcheck disable=SC2016
# SC2153: REAL_APPS is set in lib.sh, which shellcheck does not read together
# with this file; it takes it for a misspelling of REG_APPS.
# shellcheck disable=SC2153
#
# Area "lifecycle": add, list and rm; --purge; --seed; icons; injection attempts and refusals;
# regressions from review; rename, set, prune and rebuild.
# Sourced by test/run_tests.sh after test/lib.sh. Run it alone with:
#   bash test/run_tests.sh lifecycle

# The fake Electron app as built for this area, before any launcher points at
# it. "add → list → rm lifecycle" checks that nothing changed it.
ELECTRON_FP_BEFORE=$(fingerprint "$ELECTRON_APP")

group "app detection"

libcall is_chromium_app "$ELECTRON_APP"
assert_rc "an Electron bundle is detected" 0 "$RUN_RC" "$RUN_OUT"
libcall is_chromium_app "$FORK_APP"
assert_rc "a Chromium-fork bundle is detected" 0 "$RUN_RC" "$RUN_OUT"
libcall is_chromium_app "$NATIVE_APP"
assert_rc_nonzero "a native bundle is not detected" "$RUN_RC" "$RUN_OUT"
libcall is_chromium_app_deep "$NATIVE_APP"
assert_rc_nonzero "the deep check also rejects a native bundle" "$RUN_RC" "$RUN_OUT"

ai add "$NATIVE_APP" --profile Work
assert_rc_nonzero "add refuses a native app" "$RUN_RC" "$RUN_OUT"
assert_contains "add explains why a native app cannot work" "$RUN_OUT" "Chromium"
assert_no_dir "add left no launcher behind for a native app" "$APPS/Nativey Work.app"

ai add "$SRC/Nope.app" --profile Work
assert_rc_nonzero "add refuses an app that does not exist" "$RUN_RC" "$RUN_OUT"

group "marker-key safety rule"

DECOY="$APPS/Decoy.app"
make_decoy_app "$DECOY"
DECOY_FP=$(fingerprint "$DECOY")

libcall is_our_launcher "$DECOY"
assert_rc_nonzero "a bundle without the marker key is not ours" "$RUN_RC" "$RUN_OUT"

ai rm Decoy -y
assert_rc_nonzero "rm refuses a bundle aidentity did not create" "$RUN_RC" "$RUN_OUT"
assert_contains "rm says why it refused" "$RUN_OUT" "not created by aidentity"
assert_dir "the decoy still exists after rm" "$DECOY"
assert_file "the decoy's contents are untouched" "$DECOY/Contents/Resources/important.txt"
assert_eq "the decoy tree is unchanged" "$DECOY_FP" "$(fingerprint "$DECOY")"

ai rm Decoy --purge -y
assert_rc_nonzero "rm --purge also refuses a bundle aidentity did not create" "$RUN_RC" "$RUN_OUT"
assert_dir "the decoy still exists after rm --purge" "$DECOY"

ai open Decoy
assert_rc_nonzero "open refuses a bundle aidentity did not create" "$RUN_RC" "$RUN_OUT"

# add builds "<App> <Profile>.app", so a decoy at that exact name is a collision.
GUARD="$APPS/Fake Guard.app"
make_decoy_app "$GUARD"
GUARD_FP=$(fingerprint "$GUARD")
ai add "$ELECTRON_APP" --profile Guard
assert_rc_nonzero "add refuses to overwrite a bundle it did not create" "$RUN_RC" "$RUN_OUT"
assert_contains "add says it will not overwrite" "$RUN_OUT" "Refusing to overwrite"
assert_dir "the colliding bundle survives" "$GUARD"
assert_eq "the colliding bundle is unchanged" "$GUARD_FP" "$(fingerprint "$GUARD")"
assert_no_dir "no profile data was created for the refused add" "$DATA/fake-guard"

ai list
assert_not_contains "list ignores bundles without the marker key" "$RUN_OUT" "Decoy"

rm -rf "$DECOY" "$GUARD"

group "add → list → rm lifecycle"

ai add "$ELECTRON_APP" --profile Work
assert_rc "add succeeds against a fake Electron app" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "add reports what it created" "$RUN_OUT" "Fake Work"

LAUNCHER="$APPS/Fake Work.app"
PROFILE_DATA="$DATA/fake-work"

assert_dir "the launcher lands in AIDENTITY_APPS_DIR" "$LAUNCHER"
assert_dir "the profile data directory is created" "$PROFILE_DATA"
assert_no_dir "nothing was written to the real ~/Applications" "$REAL_APPS/Fake Work.app"

assert_eq "the launcher carries the marker key" "Work" "$(plist_key "$LAUNCHER" AIdentityProfile)"
assert_eq "the launcher records its target app" "$ELECTRON_APP" "$(plist_key "$LAUNCHER" AIdentityTargetApp)"
assert_eq "the launcher records its data directory" "$PROFILE_DATA" "$(plist_key "$LAUNCHER" AIdentityDataDir)"
assert_eq "the launcher is a background agent (LSUIElement)" "true" "$(plist_key "$LAUNCHER" LSUIElement)"
assert_contains "the launcher gets its own bundle identifier" \
  "$(plist_key "$LAUNCHER" CFBundleIdentifier)" "com.aidentity."

if plutil -lint "$LAUNCHER/Contents/Info.plist" >/dev/null 2>&1; then
  _pass "the generated Info.plist is valid"
else
  _fail "the generated Info.plist is valid" "plutil -lint rejected it"
fi

assert_file "the launcher has a launcher script" "$LAUNCHER/Contents/MacOS/launcher"
assert_exec "the launcher script is executable" "$LAUNCHER/Contents/MacOS/launcher"
LAUNCH_SRC=$(cat "$LAUNCHER/Contents/MacOS/launcher")
assert_contains "the launcher is a plain sh script" "$LAUNCH_SRC" "#!/bin/sh"
assert_contains "the launcher passes --user-data-dir" "$LAUNCH_SRC" "--user-data-dir='$PROFILE_DATA'"
assert_contains "the launcher opens the real app by path" "$LAUNCH_SRC" "'$ELECTRON_APP'"
assert_contains "the launcher asks for a new instance (-na)" "$LAUNCH_SRC" "-na"

# The whole design rests on this: the real app is never copied or touched.
assert_no_dir "the launcher does not embed a copy of the app" "$LAUNCHER/Contents/Frameworks"
assert_eq "the source app is not modified" "$ELECTRON_FP_BEFORE" "$(fingerprint "$ELECTRON_APP")"

if command -v codesign >/dev/null 2>&1 && xcode-select -p >/dev/null 2>&1; then
  if codesign --verify "$LAUNCHER" >/dev/null 2>&1; then
    _pass "the generated launcher passes codesign --verify"
  else
    _fail "the generated launcher passes codesign --verify" "codesign rejected $LAUNCHER"
  fi
else
  _skip "the generated launcher passes codesign --verify" "no codesign toolchain on this machine"
fi

ai list
assert_rc "list exits 0 with a profile present" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "list shows the launcher name" "$RUN_OUT" "Fake Work"
assert_contains "list shows the profile name" "$RUN_OUT" "Work"
assert_contains "list shows where the data lives" "$RUN_OUT" "$PROFILE_DATA"
assert_contains "a fresh profile is reported as signed out" "$RUN_OUT" "signed out"

ai doctor
assert_contains "doctor counts profiles" "$RUN_OUT" "profiles"

ai add "$ELECTRON_APP" --profile Work
assert_rc "adding the same profile again is idempotent" 0 "$RUN_RC" "$RUN_OUT"
assert_dir "the launcher still exists after a re-add" "$LAUNCHER"
assert_eq "a re-add does not create a second launcher" "1" "$(count_launchers)"

ai add "$ELECTRON_APP" --profile Personal --color teal --badge P
assert_rc "add accepts --color and --badge" 0 "$RUN_RC" "$RUN_OUT"
assert_dir "the second launcher exists" "$APPS/Fake Personal.app"
ai list
assert_contains "list shows the first profile" "$RUN_OUT" "Fake Work"
assert_contains "list shows the second profile" "$RUN_OUT" "Fake Personal"
assert_ne "the two profiles get different data directories" \
  "$(plist_key "$APPS/Fake Work.app" AIdentityDataDir)" \
  "$(plist_key "$APPS/Fake Personal.app" AIdentityDataDir)"

ai add "$ELECTRON_APP" --profile Bad --color chartreuse
assert_rc_nonzero "add rejects an unknown colour" "$RUN_RC" "$RUN_OUT"
assert_no_dir "no launcher is built when the colour is rejected" "$APPS/Fake Bad.app"

ai add "$FORK_APP" --profile Work
assert_rc "add works against a Chromium-fork bundle too" 0 "$RUN_RC" "$RUN_OUT"
assert_dir "the fork launcher exists" "$APPS/Forky Work.app"
ai rm "Forky Work" -y
assert_rc "rm removes the fork launcher" 0 "$RUN_RC" "$RUN_OUT"

ai add "$APPS/Fake Work.app" --profile Nested
assert_rc_nonzero "add refuses to profile one of its own launchers" "$RUN_RC" "$RUN_OUT"

ai_in "no" rm "Fake Personal"
assert_rc_nonzero "rm without --yes cancels when the answer is not 'yes'" "$RUN_RC" "$RUN_OUT"
assert_contains "a cancelled rm says so" "$RUN_OUT" "Cancelled"
assert_dir "a cancelled rm leaves the launcher in place" "$APPS/Fake Personal.app"

ai_in "yes" rm "Fake Personal"
assert_rc "rm proceeds when the answer is 'yes'" 0 "$RUN_RC" "$RUN_OUT"
assert_no_dir "the confirmed launcher is gone" "$APPS/Fake Personal.app"
assert_dir "rm without --purge keeps the profile data" "$DATA/fake-personal"

ai rm "No Such Profile" -y
assert_rc_nonzero "rm of an unknown profile exits non-zero" "$RUN_RC" "$RUN_OUT"

ai rm "Fake Work" -y
assert_rc "rm --yes removes without prompting" 0 "$RUN_RC" "$RUN_OUT"
assert_no_dir "the launcher is gone" "$LAUNCHER"
assert_dir "the data survives a plain rm" "$PROFILE_DATA"

ai list
assert_contains "list is empty again after removing every profile" "$RUN_OUT" "No profiles yet."

group "--purge stays inside the data root"

ai add "$ELECTRON_APP" --profile Purgeable
assert_rc "add a profile to purge" 0 "$RUN_RC" "$RUN_OUT"
touch "$DATA/fake-purgeable/marker"
assert_file "the profile data has a marker file" "$DATA/fake-purgeable/marker"
ai rm "Fake Purgeable" --purge -y
assert_rc "rm --purge exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_no_dir "rm --purge takes data inside the data root away" "$DATA/fake-purgeable"
assert_dir "rm --purge leaves the data root itself alone" "$DATA"

# A launcher whose recorded data directory points outside the data root must not
# be able to talk aidentity into deleting that path.
purge_guard_case() { # description outside_path
  local desc="$1" outside="$2"
  mkdir -p "$outside"
  printf 'do not delete me\n' > "$outside/precious.txt"
  ai add "$ELECTRON_APP" --profile Escape
  if [ "$RUN_RC" -ne 0 ]; then _fail "$desc (setup)" "add failed: $RUN_OUT"; return 0; fi
  /usr/libexec/PlistBuddy -c "Set :AIdentityDataDir $outside" \
    "$APPS/Fake Escape.app/Contents/Info.plist" >/dev/null 2>&1
  ai rm "Fake Escape" --purge -y
  assert_rc "$desc — rm still exits 0" 0 "$RUN_RC" "$RUN_OUT"
  assert_contains "$desc — rm warns the data is outside the data root" "$RUN_OUT" "outside"
  assert_file "$desc — the outside data is left in place" "$outside/precious.txt"
  assert_no_dir "$desc — the launcher itself is removed" "$APPS/Fake Escape.app"
  rm -rf "$outside"
}

purge_guard_case "an unrelated directory" "$SB/somewhere else"
purge_guard_case "a sibling that merely shares the data-root prefix" "${DATA}-evil"

# The data root itself is not "inside" the data root, so it must survive too.
mkdir -p "$DATA/keep-me"
ai add "$ELECTRON_APP" --profile Root
/usr/libexec/PlistBuddy -c "Set :AIdentityDataDir $DATA" \
  "$APPS/Fake Root.app/Contents/Info.plist" >/dev/null 2>&1
ai rm "Fake Root" --purge -y
assert_rc "rm --purge pointed at the data root exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_dir "rm --purge never deletes the data root itself" "$DATA"
assert_dir "unrelated profile data survives" "$DATA/keep-me"
rm -rf "$DATA/keep-me"

group "--purge keeps a folder another launcher uses"

# Two launchers on one profile folder: 1.0.0 made them, and a second add or an
# import makes them again. Moving the folder for one signs the other out, so
# the other is looked for everywhere prune looks.
trash_reset
ai add "$ELECTRON_APP" --profile Shared
printf 'session\n' > "$DATA/fake-shared/Cookies"
cp -R "$APPS/Fake Shared.app" "$APPS/Fake Shared Copy.app"
ai rm "Fake Shared" --purge -y
assert_rc "with a second launcher beside it, rm --purge exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "it names the other launcher" "$RUN_OUT" \
  "Profile data kept — another launcher uses the same directory: Fake Shared Copy"
assert_file "and the data stays" "$DATA/fake-shared/Cookies"
assert_no_dir "the launcher asked for is removed" "$APPS/Fake Shared.app"

# Filed into a folder: a second add for the same profile is refused, as an
# import would be. A copy of the launcher still uses the same folder.
mkdir -p "$APPS/Filed"
mv "$APPS/Fake Shared Copy.app" "$APPS/Filed/"
ai add "$ELECTRON_APP" --profile Shared
assert_rc_nonzero "a second add for the folder a filed launcher uses is refused" "$RUN_RC" "$RUN_OUT"
assert_contains "and names that launcher by its path" "$RUN_OUT" "$APPS/Filed/Fake Shared Copy.app"
cp -R "$APPS/Filed/Fake Shared Copy.app" "$APPS/Fake Shared.app"
assert_eq "a copy of it uses the same folder" "$DATA/fake-shared" \
  "$(plist_key "$APPS/Fake Shared.app" AIdentityDataDir)"
ai doctor
assert_contains "doctor sees the filed launcher on the same folder" "$RUN_OUT" \
  "shares its profile folder with: $APPS/Filed/Fake Shared Copy.app"
ai rm "Fake Shared" --purge -y
assert_rc "with the other launcher in a folder, rm --purge exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "it names that launcher by its path" "$RUN_OUT" \
  "another launcher uses the same directory: $APPS/Filed/Fake Shared Copy.app"
assert_file "and the data stays" "$DATA/fake-shared/Cookies"
assert_no_dir "nothing went to the Trash" "$SB_TRASH/fake-shared"

# In an app folder, outside the launcher directory.
mv "$APPS/Filed/Fake Shared Copy.app" "$SRC/"
cp -R "$SRC/Fake Shared Copy.app" "$APPS/Fake Shared.app"
ai rm "Fake Shared" --purge -y
assert_contains "a launcher in an app folder counts too" "$RUN_OUT" \
  "another launcher uses the same directory: $SRC/Fake Shared Copy.app"
assert_file "and the data stays" "$DATA/fake-shared/Cookies"

# A symlink at the top of the launcher directory, to the launcher in a folder:
# rm removes the symlink, and the launcher it pointed at still uses the data.
mv "$SRC/Fake Shared Copy.app" "$APPS/Filed/"
ln -s "$APPS/Filed/Fake Shared Copy.app" "$APPS/Fake Shared Copy.app"
ai rm "Fake Shared Copy" --purge -y
assert_contains "removing a symlinked launcher keeps the data of the real one" "$RUN_OUT" \
  "another launcher uses the same directory: $APPS/Filed/Fake Shared Copy.app"
assert_file "and the data stays" "$DATA/fake-shared/Cookies"
assert_dir "the launcher in the folder is still there" "$APPS/Filed/Fake Shared Copy.app"

# A folder in the launcher directory that cannot be read could hold the
# other launcher. Not knowing is not "no other launcher": the data is kept.
mv "$APPS/Filed/Fake Shared Copy.app" "$APPS/"
mkdir -p "$APPS/Private"
chmod 000 "$APPS/Private"
ai rm "Fake Shared Copy" --purge -y
chmod 755 "$APPS/Private"
assert_rc_nonzero "a search that fails stops the move" "$RUN_RC" "$RUN_OUT"
assert_contains "it says why" "$RUN_OUT" "could not search all of $APPS for another launcher that uses it"
assert_contains "and where the data is" "$RUN_OUT" "its data is still at: $DATA/fake-shared"
assert_file "the data stays" "$DATA/fake-shared/Cookies"
assert_not_contains "and is never said to be moved" "$RUN_OUT" "Moved the profile data"
rmdir "$APPS/Private" "$APPS/Filed"
ai restore "Fake Shared"
ai rm "Fake Shared" --purge -y
assert_contains "once nothing else uses it, the data goes" "$RUN_OUT" "Moved the profile data to the Trash."
assert_no_dir "out of the data root" "$DATA/fake-shared"
trash_reset

group "--purge moves the data to the Trash"

trash_reset
ai add "$ELECTRON_APP" --profile Trashy
printf 'session\n' > "$DATA/fake-trashy/Cookies"
# A launcher from before restore records: purge writes the record first, so
# the folder can be restored once it is moved back.
rm -f "$DATA/fake-trashy/.aidentity-profile.plist"
ai_in "no" rm "Fake Trashy" --purge
assert_contains "the prompt says the data goes to the Trash" "$RUN_OUT" "move its data to the Trash"
assert_not_contains "and does not say it is deleted for good" "$RUN_OUT" "permanently"
assert_dir "a cancelled purge keeps the launcher" "$APPS/Fake Trashy.app"
ai rm "Fake Trashy" --purge -y
assert_rc "rm --purge exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_no_dir "the data is gone from the data root" "$DATA/fake-trashy"
assert_file "it is in the Trash of the home folder" "$SB_TRASH/fake-trashy/Cookies"
assert_eq "a Trash made for it is private" "700" "$(/usr/bin/stat -f %Lp "$SB_TRASH")"
assert_file "with a restore record written before the move" "$SB_TRASH/fake-trashy/.aidentity-profile.plist"
assert_contains "it says so" "$RUN_OUT" "Moved the profile data to the Trash."
assert_contains "and where it is now" "$RUN_OUT" "It is now at: $SB_TRASH/fake-trashy"
assert_contains "and where it came from" "$RUN_OUT" "move it back to: $DATA/fake-trashy"
assert_contains "and how to get the launcher back" "$RUN_OUT" 'then run:  aidentity restore "Fake Trashy"'
assert_not_contains "and never that it deleted it" "$RUN_OUT" "Deleted"

mv "$SB_TRASH/fake-trashy" "$DATA/fake-trashy"
ai restore "Fake Trashy"
assert_rc "following the undo hint brings the launcher back" 0 "$RUN_RC" "$RUN_OUT"
assert_dir "the launcher is there" "$APPS/Fake Trashy.app"
assert_file "still signed in" "$DATA/fake-trashy/Cookies"

# A name already taken in the Trash: "name 2", never into the folder there.
mkdir -p "$SB_TRASH/fake-trashy"
printf 'older\n' > "$SB_TRASH/fake-trashy/older.txt"
ai rm "Fake Trashy" --purge -y
assert_rc "a name taken in the Trash is no problem" 0 "$RUN_RC" "$RUN_OUT"
assert_file "the data goes to 'name 2'" "$SB_TRASH/fake-trashy 2/Cookies"
assert_contains "and it says so" "$RUN_OUT" "It is now at: $SB_TRASH/fake-trashy 2"
assert_no_dir "not into the folder of that name" "$SB_TRASH/fake-trashy/fake-trashy"
assert_eq "which is left as it was" "older" "$(cat "$SB_TRASH/fake-trashy/older.txt")"
mv "$SB_TRASH/fake-trashy 2" "$DATA/fake-trashy"
mkdir "$SB_TRASH/fake-trashy 2"
ai restore "Fake Trashy"
ai rm "Fake Trashy" --purge -y
assert_file "with 'name 2' taken too, it is 'name 3'" "$SB_TRASH/fake-trashy 3/Cookies"

# A Trash it cannot write to: nothing is moved, and the data stays.
ai add "$ELECTRON_APP" --profile Stuck
printf 'session\n' > "$DATA/fake-stuck/Cookies"
chmod 500 "$SB_TRASH"
ai rm "Fake Stuck" --purge -y
STUCK_RC=$RUN_RC; STUCK_OUT=$RUN_OUT
chmod 700 "$SB_TRASH"
assert_rc_nonzero "a purge that cannot reach the Trash exits non-zero" "$STUCK_RC" "$STUCK_OUT"
assert_file "the data stays where it was" "$DATA/fake-stuck/Cookies"
assert_no_dir "and nothing reached the Trash" "$SB_TRASH/fake-stuck"
assert_contains "it says why" "$STUCK_OUT" "Could not move $DATA/fake-stuck to the Trash"
assert_contains "and that nothing was deleted" "$STUCK_OUT" "Nothing was deleted."
assert_contains "and where the data is" "$STUCK_OUT" "its data is still at: $DATA/fake-stuck"
assert_contains "and how to use the account again" "$STUCK_OUT" 'To use this account again:  aidentity restore "Fake Stuck"'
assert_not_contains "and never that it moved it" "$STUCK_OUT" "Moved the profile data"
assert_no_dir "the launcher is gone, as the prompt said" "$APPS/Fake Stuck.app"
ai restore "Fake Stuck"
assert_rc "the account comes back through restore" 0 "$RUN_RC" "$RUN_OUT"
ai rm "Fake Stuck" --purge -y
assert_no_dir "and a later purge moves it" "$DATA/fake-stuck"

# No Trash in the home folder yet: one is made, private to its owner.
ai add "$ELECTRON_APP" --profile Fresh
mkdir -p "$SANDBOX/home-fresh"
RUN_OUT=$(HOME="$SANDBOX/home-fresh" detached "$BASH_BIN" "$AIDENTITY" rm "Fake Fresh" --purge -y 2>&1 </dev/null); RUN_RC=$?
assert_rc "a home folder with no Trash gets one" 0 "$RUN_RC" "$RUN_OUT"
assert_dir "the data is in it" "$SANDBOX/home-fresh/.Trash/fake-fresh"
assert_eq "and it is private" "700" "$(/usr/bin/stat -f %Lp "$SANDBOX/home-fresh/.Trash")"

# A profile folder that is already gone: the launcher goes, nothing to move.
ai add "$ELECTRON_APP" --profile Hollow
rm -rf "$DATA/fake-hollow"
ai rm "Fake Hollow" --purge -y
assert_rc "a purge with no data left exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "and says there was nothing to move" "$RUN_OUT" "no profile data to move"
assert_no_dir "the launcher is gone" "$APPS/Fake Hollow.app"
trash_reset

group "--purge on another volume"

# A profile folder on another volume goes to that volume's own Trash,
# .Trashes/<uid>, and only if the volume has .Trashes. A disk image stands in
# for the other volume.
VOL="$SANDBOX/volume"
if vol_attach "$VOL"; then
  AIDENTITY_DATA_ROOT="$VOL/profiles" ai add "$ELECTRON_APP" --profile Away
  printf 'session\n' > "$VOL/profiles/fake-away/Cookies"
  AIDENTITY_DATA_ROOT="$VOL/profiles" ai rm "Fake Away" --purge -y
  assert_rc_nonzero "a volume with no .Trashes is refused" "$RUN_RC" "$RUN_OUT"
  assert_file "and the data stays there" "$VOL/profiles/fake-away/Cookies"
  assert_contains "it says why" "$RUN_OUT" "has no Trash folder (.Trashes)"
  assert_contains "and that nothing was deleted" "$RUN_OUT" "Nothing was deleted."
  assert_no_dir "no .Trashes is made for it" "$VOL/.Trashes"
  assert_no_dir "and nothing went to the home folder's Trash" "$SB_TRASH/fake-away"
  # The volume's own folder cannot go into any Trash.
  libcall trash_path "$VOL"
  assert_rc_nonzero "a volume's own folder is refused" "$RUN_RC" "$RUN_OUT"
  assert_contains "as a volume of its own" "$RUN_OUT" "it is a volume of its own"
  assert_file "and all on it stays" "$VOL/profiles/fake-away/Cookies"

  mkdir "$VOL/.Trashes"
  AIDENTITY_DATA_ROOT="$VOL/profiles" ai restore "Fake Away"
  AIDENTITY_DATA_ROOT="$VOL/profiles" ai rm "Fake Away" --purge -y
  VOL_UID=$(id -u)
  assert_rc "with .Trashes it is moved" 0 "$RUN_RC" "$RUN_OUT"
  assert_file "to .Trashes/<uid> on that volume" "$VOL/.Trashes/$VOL_UID/fake-away/Cookies"
  assert_eq "the <uid> folder made for it is private" "700" "$(/usr/bin/stat -f %Lp "$VOL/.Trashes/$VOL_UID")"
  assert_no_dir "it is gone from the data root" "$VOL/profiles/fake-away"
  # The volume's folder as the system resolves it (/var is /private/var).
  VOL_REAL=$(cd -P "$VOL" && pwd -P)
  assert_contains "it says where it is" "$RUN_OUT" "It is now at: $VOL_REAL/.Trashes/$VOL_UID/fake-away"
  assert_no_dir "and the home folder's Trash is not used" "$SB_TRASH/fake-away"

  # A Trash that is a symlink to another volume is refused. mv into it would
  # copy every file and then delete the original, not rename it.
  trash_reset
  mkdir -p "$VOL/elsewhere" "$SB/tv/fake-linked"
  printf 'session\n' > "$SB/tv/fake-linked/Cookies"
  ln -s "$VOL/elsewhere" "$SB_TRASH"
  libcall trash_path "$SB/tv/fake-linked"
  assert_rc_nonzero "a home Trash linked to another volume is refused" "$RUN_RC" "$RUN_OUT"
  assert_contains "it says why" "$RUN_OUT" "is on another volume"
  assert_contains "and that nothing was deleted" "$RUN_OUT" "Nothing was deleted."
  assert_file "the data stays where it was" "$SB/tv/fake-linked/Cookies"
  assert_no_dir "and nothing was copied across" "$VOL/elsewhere/fake-linked"
  rm -f "$SB_TRASH"

  # The same for a volume's .Trashes/<uid> linked off that volume.
  mkdir -p "$VOL/fake-there" "$SB/tv/away"
  printf 'session\n' > "$VOL/fake-there/Cookies"
  mv "$VOL/.Trashes/$VOL_UID" "$VOL/.Trashes/kept"
  ln -s "$SB/tv/away" "$VOL/.Trashes/$VOL_UID"
  libcall trash_path "$VOL/fake-there"
  assert_rc_nonzero "a volume's Trash linked off the volume is refused" "$RUN_RC" "$RUN_OUT"
  assert_contains "it says why" "$RUN_OUT" "is on another volume"
  assert_file "the data stays where it was" "$VOL/fake-there/Cookies"
  assert_no_dir "and nothing was copied across" "$SB/tv/away/fake-there"
  rm -f "$VOL/.Trashes/$VOL_UID"
  mv "$VOL/.Trashes/kept" "$VOL/.Trashes/$VOL_UID"
  rm -rf "$SB/tv"
  vol_detach
  assert_eq "the disk image is detached" "$(/usr/bin/stat -f %d "$SANDBOX")" "$(/usr/bin/stat -f %d "$VOL")"
else
  vol_detach
  _skip "--purge on another volume" "hdiutil cannot make or attach a disk image here"
fi
rm -rf "$VOL"

group "trash_path on its own, and uninstall.sh's copy"

trash_reset
mkdir -p "$SB/tp/target" "$SB/tp/plain"
printf 'keep\n' > "$SB/tp/target/keep.txt"
libcall trash_path "$SB/tp/plain"
assert_rc "a folder is moved" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "it prints where it went, and nothing else" "$SB_TRASH/plain" "$RUN_OUT"
# A symlink would move on its own, and the data it points to would stay.
ln -s "$SB/tp/target" "$SB/tp/link"
libcall trash_path "$SB/tp/link"
assert_rc_nonzero "a symlink is refused" "$RUN_RC" "$RUN_OUT"
assert_contains "it says why" "$RUN_OUT" "it is a symbolic link, and the data it points to would stay where it is"
if [ -L "$SB/tp/link" ]; then _pass "the link stays"; else _fail "the link stays" "no symlink at $SB/tp/link"; fi
assert_file "and so does what it points to" "$SB/tp/target/keep.txt"
if [ -e "$SB_TRASH/link" ] || [ -L "$SB_TRASH/link" ]; then _fail "nothing goes to the Trash" "found $SB_TRASH/link"; else _pass "nothing goes to the Trash"; fi
rm -f "$SB/tp/link"
# Relative to the folder it runs in, tp/target exists: still refused.
TP_CWD=$PWD
RUN_RC=0
cd "$SB" && libcall trash_path "tp/target"
cd "$TP_CWD" || true
assert_rc_nonzero "a relative path is refused, even one that exists" "$RUN_RC" "$RUN_OUT"
assert_contains "as not a full path" "$RUN_OUT" "it is not a full path to a folder"
libcall trash_path "$SB/tp/target/"
assert_rc_nonzero "so is a path ending in /" "$RUN_RC" "$RUN_OUT"
libcall trash_path "$SB/tp/target/.."
assert_rc_nonzero "and one ending in .." "$RUN_RC" "$RUN_OUT"
assert_contains "for the same reason" "$RUN_OUT" "it is not a full path to a folder"
libcall trash_path "$SB/tp/missing"
assert_rc_nonzero "and one that does not exist" "$RUN_RC" "$RUN_OUT"
assert_contains "which it says" "$RUN_OUT" "it does not exist"
assert_file "the folder is still there after all of them" "$SB/tp/target/keep.txt"

# A symlink in the Trash that leads nowhere still takes the name.
mkdir -p "$SB/tp/fake-dangle"
ln -s "$SB/tp/nowhere" "$SB_TRASH/fake-dangle"
libcall trash_path "$SB/tp/fake-dangle"
assert_eq "a name held by a broken symlink is skipped" "$SB_TRASH/fake-dangle 2" "$RUN_OUT"
if [ -L "$SB_TRASH/fake-dangle" ]; then _pass "and the symlink is left as it was"; else _fail "and the symlink is left as it was" "it is gone"; fi

# Something takes the free name in the moment before the move. A stub mv
# makes a folder there first, then runs the real one.
RACE_BIN="$SANDBOX/stub-race"
mkdir -p "$RACE_BIN"
printf '%s\n' '#!/bin/sh' 'prev=""; last=""' 'for a in "$@"; do prev=$last; last=$a; done' \
  'mkdir "$last"' '[ -z "${RACE_INNER:-}" ] || mkdir "$last/${prev##*/}"' 'exec /bin/mv "$@"' > "$RACE_BIN/mv"
chmod +x "$RACE_BIN/mv"
mkdir -p "$SB/tp/fake-raced"
printf 'keep\n' > "$SB/tp/fake-raced/keep.txt"
PATH="$RACE_BIN:$PATH" libcall trash_path "$SB/tp/fake-raced"
assert_eq "an empty folder made at the name holds it, and that is where it says" \
  "$SB_TRASH/fake-raced/fake-raced" "$RUN_OUT"
assert_file "it is there" "$SB_TRASH/fake-raced/fake-raced/keep.txt"
mkdir -p "$SB/tp/fake-raced"
printf 'keep\n' > "$SB/tp/fake-raced/keep.txt"
RACE_INNER=1 PATH="$RACE_BIN:$PATH" libcall trash_path "$SB/tp/fake-raced"
assert_rc_nonzero "with that name inside it taken too, nothing is replaced" "$RUN_RC" "$RUN_OUT"
assert_contains "it says why" "$RUN_OUT" "was taken just before the move"
assert_file "and the data stays where it was" "$SB/tp/fake-raced/keep.txt"
rm -rf "$SB/tp/fake-raced" "$SB/tp/fake-dangle"

# A profile folder that is a symlink inside the data root: rm --purge moves
# nothing and says where the data is.
ai add "$ELECTRON_APP" --profile Linkdata
printf 'session\n' > "$DATA/fake-linkdata/Cookies"
mv "$DATA/fake-linkdata" "$DATA/fake-linkdata-real"
ln -s "$DATA/fake-linkdata-real" "$DATA/fake-linkdata"
ai rm "Fake Linkdata" --purge -y
assert_rc_nonzero "rm --purge of a symlinked profile folder exits non-zero" "$RUN_RC" "$RUN_OUT"
assert_contains "it says why" "$RUN_OUT" "$DATA/fake-linkdata to the Trash: it is a symbolic link"
assert_not_contains "and never that the data moved" "$RUN_OUT" "Moved the profile data"
assert_file "the data stays" "$DATA/fake-linkdata-real/Cookies"
if [ -L "$DATA/fake-linkdata" ]; then _pass "and so does the link"; else _fail "and so does the link" "it is gone"; fi
rm -f "$DATA/fake-linkdata"
rm -rf "$DATA/fake-linkdata-real"
# uninstall.sh runs under set -e; its copy must work there too.
RUN_OUT=$("$BASH_BIN" -c 'lib=$1; dir=$2; set --; . "$lib" >/dev/null 2>&1; trash_path "$dir"; echo "rc=$?"' \
  x "$UNINST_LIB" "$SB/tp/target" 2>&1 </dev/null)
assert_contains "uninstall.sh's copy moves a folder under set -e" "$RUN_OUT" "$SB_TRASH/target"
assert_contains "and returns 0" "$RUN_OUT" "rc=0"
assert_file "it is in the Trash" "$SB_TRASH/target/keep.txt"
rm -rf "$SB/tp"
trash_reset

group "--seed copies an existing Claude config"

FAKE_HOME="$SB/fake home"
mkdir -p "$FAKE_HOME/Library/Application Support/Claude"
printf '{"mcpServers":{"probe":{}}}\n' > "$FAKE_HOME/Library/Application Support/Claude/claude_desktop_config.json"
# --seed is gated on the target being Claude Desktop, so the fixture has to
# claim Claude's bundle id. Seeding any other app was a real bug.
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.anthropic.claudefordesktop" \
  "$ELECTRON_APP/Contents/Info.plist" >/dev/null 2>&1 || true
RUN_OUT=$(HOME="$FAKE_HOME" detached "$BASH_BIN" "$AIDENTITY" add "$ELECTRON_APP" --profile Seeded --seed 2>&1 </dev/null)
RUN_RC=$?
assert_rc "add --seed exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_file "add --seed copies the MCP config into the new profile" \
  "$DATA/fake-seeded/claude_desktop_config.json"
ai rm "Fake Seeded" --purge -y
assert_rc "the seeded profile is removed cleanly" 0 "$RUN_RC" "$RUN_OUT"

group "icon handling"

SYSTEM_ICNS="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns"
if [ -f "$SYSTEM_ICNS" ]; then
  ICON_APP="$SRC/Icony.app"
  make_electron_app "$ICON_APP"
  cp "$SYSTEM_ICNS" "$ICON_APP/Contents/Resources/app.icns"
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string app" \
    "$ICON_APP/Contents/Info.plist" >/dev/null 2>&1
  ai add "$ICON_APP" --profile Iconed --color purple --badge I
  assert_rc "add succeeds for an app that has an icon" 0 "$RUN_RC" "$RUN_OUT"
  # Either the badge was drawn or the app's own icon was copied. Both are fine;
  # what must never happen is a hard failure or a launcher with no icon at all.
  assert_file "the launcher ends up with an icon" \
    "$APPS/Icony Iconed.app/Contents/Resources/icon.icns"
  ai rm "Icony Iconed" --purge -y
  assert_rc "the icon profile is removed cleanly" 0 "$RUN_RC" "$RUN_OUT"
else
  _skip "add succeeds for an app that has an icon" "no system .icns available"
  _skip "the launcher ends up with an icon" "no system .icns available"
  _skip "the icon profile is removed cleanly" "no system .icns available"
fi

# A missing icon must not be fatal.
ai add "$ELECTRON_APP" --profile Noicon
assert_rc "an app with no icon still produces a launcher" 0 "$RUN_RC" "$RUN_OUT"
assert_dir "the icon-less launcher exists" "$APPS/Fake Noicon.app"
ai rm "Fake Noicon" --purge -y
assert_rc "the icon-less profile is removed cleanly" 0 "$RUN_RC" "$RUN_OUT"

group "injection attempts through the CLI"

assert_eq "no launchers left over before the injection cases" "0" "$(count_launchers)"

inject_case() { # name
  ai add "$ELECTRON_APP" --profile "$1"
  assert_rc_nonzero "add rejects the profile name [$1]" "$RUN_RC" "$RUN_OUT"
}
# shellcheck disable=SC2016  # unexpanded $( ) and backticks are the payload
inject_case 'Work$(touch '"$SB"'/pwned)'
inject_case 'Work`touch '"$SB"'/pwned`'
inject_case 'Work; touch '"$SB"'/pwned'
inject_case '../../../../etc/pwned'
inject_case 'Work" /><key>x</key><string>y</string><!--'

assert_no_file "no injected command ever ran" "$SB/pwned"
assert_eq "no launcher was created by any injection attempt" "0" "$(count_launchers)"

group "refusals happen for the stated reason"

# Several refusals exit non-zero for more than one possible reason. Checking only
# the exit code lets the real guard be deleted while the test still passes, so
# these pin the reason as well.

# A launcher is not a Chromium app either, so an exit code alone cannot tell
# "this is my own launcher" apart from "this is not an Electron app".
ai add "$ELECTRON_APP" --profile Selfref
assert_rc "built a launcher to aim add at" 0 "$RUN_RC" "$RUN_OUT"
ai add "$APPS/Fake Selfref.app" --profile Nested
assert_rc_nonzero "add refuses one of its own launchers as the source app" "$RUN_RC" "$RUN_OUT"
assert_contains "add refuses it for being a launcher, not for failing the Chromium check" \
  "$RUN_OUT" "is an aidentity launcher"
assert_no_dir "no launcher-of-a-launcher was created" "$APPS/Fake Selfref Nested.app"
ai rm "Fake Selfref" --purge -y
assert_rc "removed the helper launcher" 0 "$RUN_RC" "$RUN_OUT"

# Without the marker check, `open` would hand the bundle to macOS and still exit
# non-zero when macOS declined it — passing the old exit-code-only assertion.
OPEN_DECOY="$APPS/OpenDecoy.app"
make_decoy_app "$OPEN_DECOY"
ai open OpenDecoy
assert_rc_nonzero "open refuses a bundle aidentity did not create" "$RUN_RC" "$RUN_OUT"
assert_contains "open refuses on the marker key, not because macOS declined to launch it" \
  "$RUN_OUT" "not created by aidentity"
assert_dir "the decoy survives an attempted open" "$OPEN_DECOY"
rm -rf "$OPEN_DECOY"

group "a plain file at the launcher path is not collateral"

# add's collision guard uses -d, so a regular *file* at that path slips past it.
# The only thing standing between that file and `rm -rf` is build_launcher's own
# ownership check. Nothing exercised it before.
FILE_AT_PATH="$APPS/Fake Filed.app"
printf 'precious\n' > "$FILE_AT_PATH"
ai add "$ELECTRON_APP" --profile Filed
assert_file "a plain file sitting at the launcher path is never deleted" "$FILE_AT_PATH"
assert_eq "that file's contents are intact" "precious" "$(cat "$FILE_AT_PATH" 2>/dev/null)"
# Caught by create_profile's -e collision guard now, before build_launcher is
# reached at all — earlier and with a clearer message than the old -d test,
# which let a plain file slip through to assert_ours.
assert_contains "add refuses to touch it" "$RUN_OUT" "aidentity did not create"
rm -f "$FILE_AT_PATH"
rm -rf "$DATA/fake-filed"

group "a malformed Info.plist is caught, not shipped"

# Profile names are validated; app bundle names are not, and both go into the
# generated plist. An app whose name carries XML metacharacters is the reachable
# path to a broken plist, which is what the plutil -lint backstop is for.
# An app name carrying XML metacharacters must be ESCAPED into the plist, not
# left to corrupt it. "Barnes & Noble.app" is the real-world case.
XML_APP="$SRC/Ev&il<x>.app"
make_electron_app "$XML_APP"
ai add "$XML_APP" --profile Work
assert_rc "an app name with XML metacharacters is handled, not rejected" 0 "$RUN_RC" "$RUN_OUT"
assert_dir "the launcher for an XML-metacharacter app exists" "$APPS/Ev&il<x> Work.app"
if plutil -lint "$APPS/Ev&il<x> Work.app/Contents/Info.plist" >/dev/null 2>&1; then
  _pass "the generated plist is well formed despite & and <"
else
  _fail "the generated plist is well formed despite & and <" "plutil rejected it"
fi
assert_eq "the app name round-trips through the plist unescaped" \
  "$(plist_key "$APPS/Ev&il<x> Work.app" CFBundleName)" "Ev&il<x> Work"
ai rm "Ev&il<x> Work" --purge -y
assert_rc "the XML-metacharacter launcher is removable by the tool" 0 "$RUN_RC" "$RUN_OUT"
assert_no_dir "no XML-metacharacter debris is left behind" "$APPS/Ev&il<x> Work.app"

group "regressions — bugs found in review, each must stay fixed"

# A failed build must NOT report success. build_launcher used to run inside
# $(…), so its die() exited only that subshell and add printed "✓ Created".
REG_APPS="$SB/ro apps"
mkdir -p "$REG_APPS"
chmod 500 "$REG_APPS"
RUN_OUT=$(AIDENTITY_APPS_DIR="$REG_APPS" detached "$BASH_BIN" "$AIDENTITY" add "$ELECTRON_APP" --profile Blocked 2>&1 </dev/null)
RUN_RC=$?
chmod 700 "$REG_APPS"
assert_rc_nonzero "a build that cannot write exits non-zero" "$RUN_RC" "$RUN_OUT"
assert_not_contains "a failed build never claims success" "$RUN_OUT" "Created"

# data_is_ours must reject the root however it is spelled, and must not follow
# a symlink out of the root.
libcall data_is_ours "$DATA//"
assert_rc_nonzero "purge guard rejects the data root spelled with a double slash" "$RUN_RC"
libcall data_is_ours "$DATA"
assert_rc_nonzero "purge guard rejects the bare data root" "$RUN_RC"
mkdir -p "$SB/outside/keep"
ln -sfn "$SB/outside" "$DATA/escape"
libcall data_is_ours "$DATA/escape/keep"
assert_rc_nonzero "purge guard does not follow a symlink out of the root" "$RUN_RC"
rm -f "$DATA/escape"
libcall data_is_ours "$DATA/a-real-profile"
assert_rc "purge guard still accepts a genuine profile path" 0 "$RUN_RC"

# Distinct names that slugify to one directory must be refused, not merged.
ai add "$ELECTRON_APP" --profile "Coll A"
assert_rc "the first of two colliding names is created" 0 "$RUN_RC" "$RUN_OUT"
ai add "$ELECTRON_APP" --profile "Coll_A"
assert_rc_nonzero "a name colliding on slug is refused" "$RUN_RC" "$RUN_OUT"
assert_contains "the collision is explained" "$RUN_OUT" "share its profile directory"
assert_no_dir "no launcher is built for the colliding name" "$APPS/Fake Coll_A.app"
# A launcher filed into a folder counts too, as it does for rm --purge.
mkdir -p "$APPS/Filed"
mv "$APPS/Fake Coll A.app" "$APPS/Filed/"
ai add "$ELECTRON_APP" --profile "Coll_A"
assert_rc_nonzero "a name colliding with a launcher filed into a folder is refused" "$RUN_RC" "$RUN_OUT"
assert_contains "and that launcher is named by its path" "$RUN_OUT" "$APPS/Filed/Fake Coll A.app"
assert_no_dir "no launcher is built for it" "$APPS/Fake Coll_A.app"
mv "$APPS/Filed/Fake Coll A.app" "$APPS/"
rmdir "$APPS/Filed"
# A launcher still records its folder after the folder is gone. A new one
# must not take that path: the old launcher would open it as its own.
mv "$DATA/fake-coll-a" "$SANDBOX/coll-a-aside"
ai add "$ELECTRON_APP" --profile "Coll_A"
assert_rc_nonzero "a name colliding with a recorded folder that is gone is refused" "$RUN_RC" "$RUN_OUT"
assert_contains "and the reason is given" "$RUN_OUT" "share its profile directory"
mv "$SANDBOX/coll-a-aside" "$DATA/fake-coll-a"
ai rm "Fake Coll A" --purge -y

# data_is_ours must never hang. A relative path made its walk-up loop spin
# forever while the tail string grew without bound — and in `rm --purge` the
# launcher is deleted BEFORE that call, so the user was left wedged.
# Run it with a hard deadline; a hang is a failure, not a stalled suite.
bounded_libcall() { # seconds, fn, args...
  local secs="$1"; shift
  local rcfile="$SANDBOX/bounded.$$"
  rm -f "$rcfile"
  # Spawn the worker DIRECTLY so we hold its real pid. Going through libcall
  # gave us the pid of a wrapper subshell; killing that left the inner bash
  # spinning, so a hang in the code under test hung the suite instead of
  # failing it.
  "$BASH_BIN" -c '. "$1" >/dev/null 2>&1 || exit 99; shift; "$@" >/dev/null 2>&1' \
       aidentity-lib "$LIB" "$@" &
  local pid=$!
  ( sleep "$secs"; kill -9 "$pid" 2>/dev/null ) &
  local watchdog=$!
  if wait "$pid" 2>/dev/null; then BOUNDED_RC=0; else BOUNDED_RC=$?; fi
  kill "$watchdog" 2>/dev/null
  wait "$watchdog" 2>/dev/null
  # kill -9 surfaces as 137; report it as a timeout rather than a plain failure.
  [ "$BOUNDED_RC" = "137" ] && BOUNDED_RC="TIMEOUT"
  rm -f "$rcfile"
  return 0
}

bounded_libcall 5 data_is_ours "reldata/some-profile"
assert_ne "a relative data dir does not hang the purge guard" "TIMEOUT" "$BOUNDED_RC"
assert_ne "a relative data dir is not accepted" "0" "$BOUNDED_RC"

bounded_libcall 5 data_is_ours "nope/a/b/c"
assert_ne "a deep relative path does not hang the purge guard" "TIMEOUT" "$BOUNDED_RC"

libcall data_is_ours "$DATA/../$(basename "$DATA")/x"
assert_rc_nonzero "purge guard rejects a path containing .. even if it would land inside" "$RUN_RC"

# The running check must be anchored, and must never match on an empty path.
libcall running_on_profile ""
assert_rc_nonzero "an empty data dir never reports as running" "$RUN_RC"


group "rename, set, prune and rebuild"

ai add "$ELECTRON_APP" --profile Renameable
assert_rc "a profile to rename is created" 0 "$RUN_RC" "$RUN_OUT"
RN_DATA="$DATA/fake-renameable"
assert_dir "its data directory exists" "$RN_DATA"
printf 'signed-in\n' > "$RN_DATA/session.marker"

ai rename "Fake Renameable" "Renamed"
assert_rc "rename succeeds" 0 "$RUN_RC" "$RUN_OUT"
assert_dir "the renamed launcher exists" "$APPS/Fake Renamed.app"
assert_no_dir "the old launcher is gone" "$APPS/Fake Renameable.app"
assert_file "the signed-in session moved with it" "$DATA/fake-renamed/session.marker"
assert_no_dir "the old data directory is gone" "$RN_DATA"
assert_eq "the launcher records the new data dir" \
  "$DATA/fake-renamed" "$(plist_key "$APPS/Fake Renamed.app" AIdentityDataDir)"

ai rename "Fake Renamed" "../evil"
assert_rc_nonzero "rename rejects an invalid new name" "$RUN_RC" "$RUN_OUT"
assert_dir "a rejected rename leaves the launcher alone" "$APPS/Fake Renamed.app"
ai rename "No Such Profile" "Whatever"
assert_rc_nonzero "rename refuses an unknown profile" "$RUN_RC" "$RUN_OUT"

ai set "Fake Renamed" --color purple
assert_rc "set changes a colour" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "the new colour is recorded" "8E4EC6" "$(plist_key "$APPS/Fake Renamed.app" AIdentityColor)"
assert_file "set does not disturb the session" "$DATA/fake-renamed/session.marker"
ai set "Fake Renamed" --color nosuchcolour
assert_rc_nonzero "set rejects an unknown colour" "$RUN_RC" "$RUN_OUT"
ai set "Fake Renamed"
assert_rc_nonzero "set with nothing to change is refused" "$RUN_RC" "$RUN_OUT"
ai set "Fake Renamed" --no-badge
assert_rc "set --no-badge succeeds" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "the badge is cleared" "" "$(plist_key "$APPS/Fake Renamed.app" AIdentityBadge)"

mkdir -p "$DATA/an-orphan"
printf 'x\n' > "$DATA/an-orphan/data"
ai prune -y
assert_rc "prune succeeds" 0 "$RUN_RC" "$RUN_OUT"
assert_no_dir "an orphaned profile directory is removed" "$DATA/an-orphan"
assert_file "to the Trash" "$SB_TRASH/an-orphan/data"
assert_contains "and prune says so" "$RUN_OUT" "orphaned profile(s) to the Trash."
rm -rf "$SB_TRASH/an-orphan"
assert_dir "a claimed profile directory survives prune" "$DATA/fake-renamed"
assert_file "prune never touches a live session" "$DATA/fake-renamed/session.marker"
ai prune -y
assert_contains "a second prune reports nothing to do" "$RUN_OUT" "No orphaned profile data"

ai rebuild "Fake Renamed"
assert_rc "rebuild of one profile succeeds" 0 "$RUN_RC" "$RUN_OUT"
assert_dir "the rebuilt launcher is still there" "$APPS/Fake Renamed.app"
assert_file "rebuild does not touch profile data" "$DATA/fake-renamed/session.marker"
assert_eq "rebuild preserves the recorded data dir" \
  "$DATA/fake-renamed" "$(plist_key "$APPS/Fake Renamed.app" AIdentityDataDir)"
ai rebuild --all
assert_rc "rebuild --all succeeds" 0 "$RUN_RC" "$RUN_OUT"
ai rebuild "No Such Profile"
assert_rc_nonzero "rebuild refuses an unknown profile" "$RUN_RC" "$RUN_OUT"

# None of these may act on a bundle aidentity did not create.
DECOY4="$APPS/Decoy Four.app"
mkdir -p "$DECOY4/Contents"
write_min_plist "$DECOY4" "com.example.decoyfour"
for sub in rename set rebuild; do
  case "$sub" in
    rename) ai rename "Decoy Four" "Hijacked" ;;
    set)    ai set "Decoy Four" --color red ;;
    rebuild) ai rebuild "Decoy Four" ;;
  esac
  assert_rc_nonzero "$sub refuses a bundle aidentity did not create" "$RUN_RC" "$RUN_OUT"
done
assert_dir "the decoy survives all three" "$DECOY4"
rm -rf "$DECOY4"

ai rm "Fake Renamed" --purge -y
assert_rc "the renamed profile is removed cleanly" 0 "$RUN_RC" "$RUN_OUT"
