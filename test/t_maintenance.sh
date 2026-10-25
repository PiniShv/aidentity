# shellcheck shell=bash
# SC2016: single-quoted scripts are handed to "$BASH_BIN" -c and to generated
# stubs, which expand them later, on purpose. shellcheck only recognises that
# when the interpreter is spelled literally as `bash -c`.
# shellcheck disable=SC2016
#
# Area "maintenance": rm hints, locked launchers and prune; rename and rebuild edge cases;
# launcher discovery; interrupts, aliases and symlinks.
# Sourced by test/run_tests.sh after test/lib.sh. Run it alone with:
#   bash test/run_tests.sh maintenance

group "rm hints, locked launchers and prune"

ai add "$ELECTRON_APP" --profile Hint
printf 'session\n' > "$DATA/fake-hint/Cookies"
ai rm "Fake Hint" -y
assert_contains "rm prints the restore line that reattaches the data" "$RUN_OUT" 'aidentity restore "Fake Hint"'
assert_contains "rm points at prune for deleting it" "$RUN_OUT" "aidentity prune"
assert_not_contains "rm no longer suggests a command that cannot work" "$RUN_OUT" 'rm "Fake Hint" --purge'
ai restore "Fake Hint"
assert_rc "following the hint brings the launcher back" 0 "$RUN_RC" "$RUN_OUT"
assert_file "and the session with it" "$DATA/fake-hint/Cookies"

chflags uchg "$APPS/Fake Hint.app"
ai rm "Fake Hint" --purge -y
LOCK_RC=$RUN_RC; LOCK_OUT=$RUN_OUT
chflags nouchg "$APPS/Fake Hint.app"
assert_rc_nonzero "rm fails on a locked launcher" "$LOCK_RC" "$LOCK_OUT"
assert_not_contains "and does not claim it removed it" "$LOCK_OUT" "Removed launcher"
assert_file "and does not delete the data" "$DATA/fake-hint/Cookies"

# A launcher filed into a folder still claims its data.
mkdir -p "$APPS/Accounts"
mv "$APPS/Fake Hint.app" "$APPS/Accounts/"
ai prune -y
assert_file "prune keeps the data of a launcher moved into a folder" "$DATA/fake-hint/Cookies"
mv "$APPS/Accounts/Fake Hint.app" "$APPS/"
rmdir "$APPS/Accounts"

# The same root spelled through a symlink is the same directory.
ln -s "$DATA" "$SB/data-link"
AIDENTITY_DATA_ROOT="$SB/data-link" ai add "$ELECTRON_APP" --profile Linked
assert_eq "the launcher records the symlinked spelling" \
  "$SB/data-link/fake-linked" "$(plist_key "$APPS/Fake Linked.app" AIdentityDataDir)"
printf 'session\n' > "$DATA/fake-linked/Cookies"
ai prune -y
assert_file "prune matches directories, not spellings" "$DATA/fake-linked/Cookies"
AIDENTITY_DATA_ROOT="$SB/data-link" ai rm "Fake Linked" --purge -y
rm -f "$SB/data-link"
ai rm "Fake Hint" --purge -y


group "rename and rebuild edge cases"

ai add "$ELECTRON_APP" --profile lower
printf 'session\n' > "$DATA/fake-lower/Cookies"
ai rename "Fake lower" Lower
assert_rc "a rename that only changes capitals works" 0 "$RUN_RC" "$RUN_OUT"
ON_DISK=""
for a in "$APPS"/*.app; do
  case "$(basename "$a")" in [Ff][Aa][Kk][Ee]\ [Ll][Oo][Ww][Ee][Rr].app) ON_DISK=$(basename "$a") ;; esac
done
assert_eq "the launcher has the new capitals on disk" "Fake Lower.app" "$ON_DISK"
assert_file "the data stays where it was" "$DATA/fake-lower/Cookies"
ai rm "Fake Lower" --purge -y

ai add "$ELECTRON_APP" --profile Alpha
ai rename "Fake Alpha" Beta
assert_eq "a default badge letter follows the new name" "B" "$(plist_key "$APPS/Fake Beta.app" AIdentityBadge)"
ai rm "Fake Beta" --purge -y
ai add "$ELECTRON_APP" --profile Gamma --badge Z
ai rename "Fake Gamma" Delta
assert_eq "a badge chosen by hand is kept" "Z" "$(plist_key "$APPS/Fake Delta.app" AIdentityBadge)"
ai rm "Fake Delta" --purge -y

# A launcher as aidentity 1.0.0 wrote it: no badge or colour keys at all.
ai add "$ELECTRON_APP" --profile Legacy
/usr/libexec/PlistBuddy -c "Delete :AIdentityBadge" -c "Delete :AIdentityColor" \
  "$APPS/Fake Legacy.app/Contents/Info.plist" >/dev/null 2>&1
ai rebuild "Fake Legacy"
assert_rc "a 1.0.0 launcher rebuilds" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "it gets its default badge back instead of losing it" "L" \
  "$(plist_key "$APPS/Fake Legacy.app" AIdentityBadge)"
assert_contains "and the user is told why" "$RUN_OUT" "1.0.0"
ai rm "Fake Legacy" --purge -y

GONE_APP="$SRC/Gone.app"
make_electron_app "$GONE_APP"
ai add "$GONE_APP" --profile G
rm -rf "$GONE_APP"
ai rebuild "Gone G"
assert_rc_nonzero "rebuild exits non-zero when the app cannot be found" "$RUN_RC" "$RUN_OUT"
assert_not_contains "and prints no success tick" "$RUN_OUT" "Rebuilt 0"
ai rm "Gone G" --purge -y


group "launcher discovery and input edge cases"

# A launcher filed into a folder of a SYMLINKED launcher directory. find without
# -H does not follow the symlinked start, so prune saw no launcher and deleted
# the profile behind it.
mkdir -p "$APPS/Filed"
ln -s "$APPS" "$SB/apps-link"
ai add "$ELECTRON_APP" --profile Linkapps
printf 'session\n' > "$DATA/fake-linkapps/Cookies"
mv "$APPS/Fake Linkapps.app" "$APPS/Filed/"
AIDENTITY_APPS_DIR="$SB/apps-link" ai prune -y
assert_file "prune follows a symlinked launcher directory into its folders" "$DATA/fake-linkapps/Cookies"
mv "$APPS/Filed/Fake Linkapps.app" "$APPS/"
rm -f "$SB/apps-link"

# uninstall.sh must find the same launchers, or it calls their data orphaned
# and deletes it while the launcher stays. Only scan_launchers runs here; the
# removal functions are never called by the suite.
mv "$APPS/Fake Linkapps.app" "$APPS/Filed/"
mkdir -p "$DATA/left-behind"
# `set --` first: a sourced file sees the caller's arguments, and uninstall.sh
# reads $1 as an option.
SCAN=$(HOME="$SANDBOX/tty-home" "$BASH_BIN" -c 'lib=$1; set --; . "$lib" >/dev/null 2>&1; scan_launchers
  for a in ${LAUNCHERS[@]+"${LAUNCHERS[@]}"}; do printf "L %s\n" "$a"; done
  for o in ${ORPHANS[@]+"${ORPHANS[@]}"}; do printf "O %s\n" "$o"; done' x "$UNINST_LIB" 2>&1)
assert_contains "uninstall lists a launcher kept in a folder" "$SCAN" "L $APPS/Filed/Fake Linkapps.app"
assert_not_contains "and does not call its data orphaned" "$SCAN" "O $DATA/fake-linkapps"
assert_contains "real orphaned data is still listed" "$SCAN" "O $DATA/left-behind"
# A launcher that is itself a symlink in the launcher folder, pointing outside.
mkdir -p "$SB/apps-elsewhere"
mv "$APPS/Filed/Fake Linkapps.app" "$SB/apps-elsewhere/"
ln -s "$SB/apps-elsewhere/Fake Linkapps.app" "$APPS/Fake Linkapps.app"
SCAN=$(HOME="$SANDBOX/tty-home" "$BASH_BIN" -c 'lib=$1; set --; . "$lib" >/dev/null 2>&1; scan_launchers
  for a in ${LAUNCHERS[@]+"${LAUNCHERS[@]}"}; do printf "L %s\n" "$a"; done
  for o in ${ORPHANS[@]+"${ORPHANS[@]}"}; do printf "O %s\n" "$o"; done' x "$UNINST_LIB" 2>&1)
assert_contains "uninstall lists a launcher that is a symlink" "$SCAN" "L $APPS/Fake Linkapps.app"
assert_not_contains "and does not call its data orphaned" "$SCAN" "O $DATA/fake-linkapps"
rm -f "$APPS/Fake Linkapps.app"
mv "$SB/apps-elsewhere/Fake Linkapps.app" "$APPS/Filed/"
rmdir "$SB/apps-elsewhere"
mv "$APPS/Filed/Fake Linkapps.app" "$APPS/"
rmdir "$APPS/Filed" "$DATA/left-behind"
ai rm "Fake Linkapps" --purge -y

# Folder lists are split on ':' only. A * or ? in a folder name used to be
# expanded against the current directory.
mkdir -p "$SB/glob-cwd/match-a" "$SB/bin-real"
SPLIT=$(cd "$SB/glob-cwd" && "$BASH_BIN" -c 'lib=$1; list=$2; set --; . "$lib" >/dev/null 2>&1
  split_dirs "$list"; printf "[%s]\n" "${DIRS[@]}"
  case $- in *f*) echo "globbing left off" ;; esac' x "$UNINST_LIB" "/one:match-*::/two words" 2>&1)
assert_eq "split_dirs keeps * literal and spaces inside a folder" \
  "$(printf '[/one]\n[match-*]\n[]\n[/two words]')" "$SPLIT"
cp "$REPO_DIR/bin/aidentity" "$SB/bin-real/aidentity"
RUN_OUT=$(AIDENTITY_BIN_DIRS="$SB/bin-*" "$BASH_BIN" -c 'lib=$1; set --; . "$lib" >/dev/null 2>&1
  remove_binary' x "$UNINST_LIB" 2>&1 </dev/null)
assert_contains "a * in AIDENTITY_BIN_DIRS is not expanded to other folders" "$RUN_OUT" "not installed anywhere obvious"
assert_file "and the copy it would have matched stays" "$SB/bin-real/aidentity"
rm -rf "$SB/glob-cwd" "$SB/bin-real"

ai add "$ELECTRON_APP" --profile Latin --badge "$(printf '\351')"
assert_rc "a badge that is not text still builds" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "and says it used the default" "$RUN_OUT" "not a character"
assert_eq "the default badge is used" "L" "$(plist_key "$APPS/Fake Latin.app" AIdentityBadge)"
ai rm "Fake Latin" --purge -y

libcall list_compatible_apps
IDX=$(printf '%s\n' "$RUN_OUT" | grep -n -x -F "$ELECTRON_APP" | cut -d: -f1)
ai_tty "18446744073709551617\n${IDX}\nDigits\n" add
assert_contains "a 20-digit menu answer is refused, not wrapped around" "$RUN_OUT" "Please enter a number"
assert_dir "the next valid answer is used" "$APPS/Fake Digits.app"
ai rm "Fake Digits" --purge -y

ai_tty "y\n${IDX}\nDecl One\nn\ny\n${IDX}\nDecl Two\nn\nn\n" setup
assert_rc "setup with two accounts for one app finishes" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "a declined Main launcher is offered only once" "1" \
  "$(printf '%s\n' "$RUN_OUT" | grep -c "Add a 'Fake Main' launcher")"
assert_dir "both accounts were created" "$APPS/Fake Decl Two.app"
ai rm "Fake Decl One" --purge -y
ai rm "Fake Decl Two" --purge -y


group "interrupts, aliases and symlinks"

# An interrupt while rename builds the new launcher. The data has already
# moved; the old launcher still points at the old path. The handler must move
# the data back. A stub codesign slows the build so the signal lands inside it.
SLOW_STUB="$SANDBOX/stub-slow"
mkdir -p "$SLOW_STUB"
printf '#!/bin/sh\nsleep 4\nexit 0\n' > "$SLOW_STUB/codesign"
# Signing runs only when xcode-select answers, so answer it here too: the
# pause must not depend on the developer's toolchain.
printf '#!/bin/sh\necho /Library/Developer/CommandLineTools\n' > "$SLOW_STUB/xcode-select"
chmod +x "$SLOW_STUB/codesign" "$SLOW_STUB/xcode-select"
ai add "$ELECTRON_APP" --profile Intr
printf 'session\n' > "$DATA/fake-intr/Cookies"
PATH="$SLOW_STUB:$PATH" "$BASH_BIN" "$AIDENTITY" rename "Fake Intr" Gone </dev/null >"$SANDBOX/intr.out" 2>&1 &
INTR_PID=$!
sleep 1.5
kill -TERM "$INTR_PID" 2>/dev/null
wait "$INTR_PID" 2>/dev/null
assert_file "an interrupted rename puts the session back" "$DATA/fake-intr/Cookies"
assert_no_dir "and leaves no moved copy" "$DATA/fake-gone"
assert_dir "the old launcher is still there" "$APPS/Fake Intr.app"
assert_eq "and still points at the session" "$DATA/fake-intr" "$(plist_key "$APPS/Fake Intr.app" AIdentityDataDir)"
assert_no_dir "no half-built launcher is left" "$APPS/Fake Gone.app"
assert_eq "no staging folder is left" "0" "$(find "$APPS" -maxdepth 1 -name '.aidentity-*' | wc -l | tr -d ' ')"
ai rm "Fake Intr" --purge -y

# Stopped between the two moves of a swap: the old launcher is set aside in the
# stage, the new one not yet in place. Cleanup must put the old one back.
mkdir -p "$SANDBOX/swapstage/.previous/Contents"
printf 'old\n' > "$SANDBOX/swapstage/.previous/Contents/marker"
RUN_OUT=$("$BASH_BIN" -c '. "$1" >/dev/null 2>&1
  BUILD_STAGE="$2"; SWAP_PREV="$2/.previous"; SWAP_DST="$3"; _cleanup_stage' x "$LIB" \
  "$SANDBOX/swapstage" "$APPS/Swap Target.app" 2>&1)
assert_file "cleanup puts a set-aside launcher back" "$APPS/Swap Target.app/Contents/marker"
assert_no_dir "and then removes the stage" "$SANDBOX/swapstage"
rm -rf "$APPS/Swap Target.app"

# A symlink to a launcher must not be mistaken for it.
ai add "$ELECTRON_APP" --profile Aliased
ln -s "$APPS/Fake Aliased.app" "$APPS/A Alias.app"
ai set "Fake Aliased" --color red
assert_eq "set acts on the launcher, not on a symlink to it" "E5484D" \
  "$(plist_key "$APPS/Fake Aliased.app" AIdentityColor)"
if [ -L "$APPS/A Alias.app" ]; then _pass "the symlink is left as it was"; else _fail "the symlink is left as it was" "it was replaced"; fi
rm -f "$APPS/A Alias.app"
ai rm "Fake Aliased" --purge -y

# A launcher renamed to "previous" in Finder: its replacement must not end up
# with the old bundle nested inside it.
ai add "$ELECTRON_APP" --profile Prev
mv "$APPS/Fake Prev.app" "$APPS/previous.app"
ai set previous --color teal
assert_rc "a launcher called previous can be rebuilt" 0 "$RUN_RC" "$RUN_OUT"
assert_no_dir "with nothing nested inside it" "$APPS/previous.app/previous.app"
rm -rf "$APPS/previous.app" "$DATA/fake-prev"

# A recorded profile path that is a symlink: its target is claimed, not orphaned.
mkdir -p "$DATA/moved-here"
printf 'session\n' > "$DATA/moved-here/Cookies"
ai add "$ELECTRON_APP" --profile Linked2
rm -rf "$DATA/fake-linked2"
ln -s "$DATA/moved-here" "$DATA/fake-linked2"
ai prune -y
assert_file "prune keeps the folder a profile's symlink points at" "$DATA/moved-here/Cookies"
ai rm "Fake Linked2" -y
rm -f "$DATA/fake-linked2"
rm -rf "$DATA/moved-here"
