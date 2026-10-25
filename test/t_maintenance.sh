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
assert_contains "rm points at prune for moving the data to the Trash" "$RUN_OUT" "To move the data to the Trash: aidentity prune"
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

# prune moves what it finds to the Trash, and says so.
trash_reset
mkdir -p "$DATA/fake-orphan-a" "$DATA/fake-orphan-b"
printf 'session\n' > "$DATA/fake-orphan-a/Cookies"
ai_in "no" prune
assert_contains "prune asks to move them to the Trash" "$RUN_OUT" "Move 2 orphaned profile(s) to the Trash?"
assert_contains "a cancelled prune says nothing was moved" "$RUN_OUT" "Cancelled. Nothing was moved."
assert_file "and moves nothing" "$DATA/fake-orphan-a/Cookies"
mkdir -p "$SB_TRASH/fake-orphan-a"
ai prune -y
assert_rc "prune -y moves them" 0 "$RUN_RC" "$RUN_OUT"
assert_file "one to 'name 2', as its name is taken in the Trash" "$SB_TRASH/fake-orphan-a 2/Cookies"
assert_dir "the other under its own name" "$SB_TRASH/fake-orphan-b"
assert_no_dir "both are gone from the data root" "$DATA/fake-orphan-a"
assert_contains "it counts them" "$RUN_OUT" "Moved 2 orphaned profile(s) to the Trash."
assert_contains "and says where each went" "$RUN_OUT" "fake-orphan-a is now at: $SB_TRASH/fake-orphan-a 2"
assert_contains "and how to undo it" "$RUN_OUT" "To undo, move a folder back into $DATA"
assert_contains "neither has a restore record, so the hint is add" "$RUN_OUT" "aidentity add <app> --profile <name>"
assert_not_contains "and not restore" "$RUN_OUT" "run: aidentity restore"
assert_not_contains "and never that it removed or deleted them" "$RUN_OUT" "Removed"

# One with a restore record and one without: the hint names restore for the
# first and add for the second.
ai add "$ELECTRON_APP" --profile Kept
ai rm "Fake Kept" -y
mkdir -p "$DATA/fake-orphan-d"
ai prune -y
assert_rc "a prune with both kinds exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "restore, for the one marked so" "$RUN_OUT" 'Then, for one marked "can be restored" above, run: aidentity restore'
assert_contains "and add, for the other" "$RUN_OUT" "For one without that mark, add the profile again"
mv "$SB_TRASH/fake-kept" "$DATA/fake-kept"
ai restore "Fake Kept"
assert_rc "following the restore hint brings it back" 0 "$RUN_RC" "$RUN_OUT"
ai rm "Fake Kept" --purge -y
trash_reset

mkdir -p "$DATA/fake-orphan-c"
mkdir -p "$SB_TRASH"
chmod 500 "$SB_TRASH"
ai prune -y
chmod 700 "$SB_TRASH"
assert_rc_nonzero "a prune whose move failed exits non-zero" "$RUN_RC" "$RUN_OUT"
assert_dir "a Trash prune cannot write to leaves the folder in place" "$DATA/fake-orphan-c"
assert_contains "it says why" "$RUN_OUT" "Could not move $DATA/fake-orphan-c to the Trash"
assert_contains "and ends with a warning that counts nothing as moved" "$RUN_OUT" \
  "! Moved 0 orphaned profile(s) to the Trash. 1 could not be moved and stayed in $DATA."
assert_not_contains "never with a tick" "$RUN_OUT" "✓ Moved"
assert_not_contains "and gives no undo hint for nothing" "$RUN_OUT" "To undo"
rm -rf "$DATA/fake-orphan-c"
trash_reset


group "prune and rm --purge check again before each move"

# Answer the question only once it is on screen, after running a command:
# what a user can do in another window while the question waits.
# SC2094: the loop reads the output file while the command writes it, on
# purpose: that is how it sees the question.
# shellcheck disable=SC2094
answer_late() { # command to run first, answer, then aidentity's arguments
  local act="$1" answer="$2" out="$SANDBOX/late.out" n=0
  shift 2
  : > "$out"
  { while ! grep -q 'Type yes to confirm' "$out" && [ "$n" -lt 100 ]; do sleep 0.1; n=$((n + 1)); done
    eval "$act"; printf '%s\n' "$answer"; } \
    | detached "$BASH_BIN" "$AIDENTITY" "$@" > "$out" 2>&1
  RUN_RC=${PIPESTATUS[1]}
  RUN_OUT=$(cat "$out")
  return 0
}

# A launcher made for a listed folder while prune waits — the list says to
# restore an account first — keeps that folder out of the Trash.
trash_reset
ai add "$ELECTRON_APP" --profile Back
printf 'session\n' > "$DATA/fake-back/Cookies"
ai rm "Fake Back" -y
mkdir -p "$DATA/fake-orphan-e"
answer_late 'ai restore "Fake Back"' yes prune
assert_rc "prune exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "the folder was listed" "$RUN_OUT" 'can be restored: aidentity restore "Fake Back"'
assert_contains "and is skipped, with the reason" "$RUN_OUT" "Skipping fake-back — a launcher uses it now: Fake Back"
assert_file "its data stays" "$DATA/fake-back/Cookies"
assert_eq "for the launcher made while prune waited" "$DATA/fake-back" \
  "$(plist_key "$APPS/Fake Back.app" AIdentityDataDir)"
assert_contains "the other folder is still moved" "$RUN_OUT" "Moved 1 orphaned profile(s) to the Trash."
assert_dir "to the Trash" "$SB_TRASH/fake-orphan-e"
ai rm "Fake Back" --purge -y
trash_reset

# Not knowing is not "no launcher": a folder in the launcher directory that
# cannot be read could hold one.
mkdir -p "$DATA/fake-unsure" "$APPS/Private"
chmod 000 "$APPS/Private"
ai prune -y
chmod 755 "$APPS/Private"
assert_rc_nonzero "a search that fails makes prune exit non-zero" "$RUN_RC" "$RUN_OUT"
assert_contains "it says why" "$RUN_OUT" "Skipping fake-unsure — could not search all of $APPS for a launcher that uses it."
assert_dir "and keeps the folder" "$DATA/fake-unsure"
rmdir "$APPS/Private" "$DATA/fake-unsure"

# Opened while the question waits: a pgrep that reports the profile only once
# the flag file is there.
LATE_BIN="$SANDBOX/stub-late"
LATE_FLAG="$SANDBOX/late-opened"
mkdir -p "$LATE_BIN"
printf '%s\n' '#!/bin/sh' "[ -f \"$LATE_FLAG\" ] || exit 1" \
  "printf '%s\\n' '101 /Apps/Fake.app/Contents/MacOS/Fake --user-data-dir=$DATA/fake-late'" > "$LATE_BIN/pgrep"
chmod +x "$LATE_BIN/pgrep"
ai add "$ELECTRON_APP" --profile Late
printf 'session\n' > "$DATA/fake-late/Cookies"
rm -f "$LATE_FLAG"
PATH="$LATE_BIN:$PATH" answer_late 'touch "$LATE_FLAG"' yes rm "Fake Late" --purge
rm -f "$LATE_FLAG"
assert_rc_nonzero "rm --purge of a profile opened while it asked exits non-zero" "$RUN_RC" "$RUN_OUT"
assert_contains "it says why" "$RUN_OUT" "The profile was opened while waiting for confirmation"
assert_file "and keeps the data" "$DATA/fake-late/Cookies"
assert_no_dir "nothing went to the Trash" "$SB_TRASH/fake-late"
ai restore "Fake Late"
ai rm "Fake Late" --purge -y
# prune asks too, before each folder.
make_pgrep_stubs
mkdir -p "$BUSY_DATA"
PATH="$PGREP_STUB:$PATH" ai prune -y
assert_contains "prune skips a folder something runs on" "$RUN_OUT" "Skipping fake-busy — something is running on it."
assert_dir "and keeps it" "$BUSY_DATA"
rmdir "$BUSY_DATA"

# With no terminal to answer on, prune moves nothing.
mkdir -p "$DATA/fake-noterm"
ai prune
assert_rc_nonzero "prune with no terminal exits non-zero" "$RUN_RC" "$RUN_OUT"
assert_contains "it says why" "$RUN_OUT" "Nothing to confirm with."
assert_dir "and moves nothing" "$DATA/fake-noterm"
rmdir "$DATA/fake-noterm"

# A symlink in the data root that leads out of it is never followed out.
mkdir -p "$SB/outside-prune"
printf 'keep\n' > "$SB/outside-prune/keep.txt"
ln -s "$SB/outside-prune" "$DATA/fake-pointer"
ai prune -y
assert_rc "prune with a symlink out of the data root exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "it skips it, and says why" "$RUN_OUT" "Skipping fake-pointer — outside the aidentity data root."
assert_file "what it points to stays" "$SB/outside-prune/keep.txt"
if [ -L "$DATA/fake-pointer" ]; then _pass "and so does the link"; else _fail "and so does the link" "it is gone"; fi
rm -f "$DATA/fake-pointer"
rm -rf "$SB/outside-prune"
trash_reset


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
