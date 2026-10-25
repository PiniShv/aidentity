# ----------------------------------------------------------------- trash --

# Profile data is never deleted outright. rm --purge, prune and uninstall.sh
# move it to the Trash, so a mistake can be undone. The move is a plain mv, not
# a request to Finder: asking Finder needs a permission prompt first, and a
# script stuck on that prompt helps nobody.
#
# trash_path PATH moves PATH into the Trash of the volume it is on and prints
# where it went. If it cannot, it says why and returns non-zero, and PATH stays
# exactly where it was. uninstall.sh carries a copy, because it cannot source
# this file; scripts/guards.sh fails when the two differ.
#
# Each volume has its own Trash: ~/.Trash on the volume that holds the home
# folder, <volume>/.Trashes/<uid> on any other. The Trash must be on the same
# volume as PATH. Then mv is a rename, which happens whole or not at all. Across
# volumes mv copies every file and then deletes the original, and stopped half
# way it leaves half of each.
trash_path() { # path -> prints where it went
  local src="$1" base parent dev uid trash mount up dest n id err moved
  base=${src##*/}
  case "$src" in /?*) ;; *) base="" ;; esac
  if [ -z "$base" ] || [ "$base" = "." ] || [ "$base" = ".." ]; then
    warn "Could not move '$src' to the Trash: it is not a full path to a folder. Nothing was deleted."
    return 1
  fi
  if [ ! -e "$src" ] && [ ! -L "$src" ]; then
    warn "Could not move $src to the Trash: it does not exist."
    return 1
  fi
  # A symlink would move on its own and leave the data it points to where it
  # is, while the caller says the data is in the Trash.
  if [ -L "$src" ]; then
    warn "Could not move $src to the Trash: it is a symbolic link, and the data it points to would stay where it is. Nothing was deleted."
    return 1
  fi
  parent=${src%/*}; [ -n "$parent" ] || parent="/"
  # Without -L: the device of the entry itself, which is what mv renames.
  dev=$(/usr/bin/stat -f %d "$src" 2>/dev/null) || dev=""
  if [ -z "$dev" ]; then
    warn "Could not move $src to the Trash: it cannot be read. Nothing was deleted."
    return 1
  fi

  if [ -n "${HOME:-}" ] && [ "$(/usr/bin/stat -L -f %d "$HOME" 2>/dev/null)" = "$dev" ]; then
    trash="$HOME/.Trash"
    if [ ! -d "$trash" ] && ! mkdir -m 700 "$trash" 2>/dev/null; then
      warn "Could not move $src to the Trash: $trash is missing and could not be created. Nothing was deleted."
      return 1
    fi
  else
    # Another volume. Its top folder is where the device changes, walking up
    # from the folder PATH is in. A PATH that is itself a volume (its folder
    # is on another device) cannot be moved anywhere.
    up=$(command cd -P "$parent" 2>/dev/null && pwd -P) || up=""
    if [ -z "$up" ] || [ "$(/usr/bin/stat -f %d "$up" 2>/dev/null)" != "$dev" ]; then
      warn "Could not move $src to the Trash: it is a volume of its own, or its folder cannot be read. Nothing was deleted."
      return 1
    fi
    mount=$up
    while [ "$mount" != "/" ]; do
      up=${mount%/*}; [ -n "$up" ] || up="/"
      [ "$(/usr/bin/stat -f %d "$up" 2>/dev/null)" = "$dev" ] || break
      mount=$up
    done
    # Finder makes .Trashes on a volume it has put things in the Trash on. A
    # volume without one may not want one (a backup disk, a network share), so
    # it is not made here.
    if [ ! -d "$mount/.Trashes" ]; then
      warn "Could not move $src to the Trash: its volume, $mount, has no Trash folder (.Trashes). Nothing was deleted."
      return 1
    fi
    uid=$(id -u 2>/dev/null) || uid=""
    trash="$mount/.Trashes/$uid"
    if [ -z "$uid" ] || { [ ! -d "$trash" ] && ! mkdir -m 700 "$trash" 2>/dev/null; }; then
      warn "Could not move $src to the Trash: $trash is missing and could not be created. Nothing was deleted."
      return 1
    fi
  fi
  # A symlinked Trash could lead to another volume, and then mv would copy.
  if [ "$(/usr/bin/stat -L -f %d "$trash" 2>/dev/null)" != "$dev" ]; then
    warn "Could not move $src to the Trash: $trash is on another volume. Nothing was deleted."
    return 1
  fi

  # mv onto a folder that exists moves INTO it, so the name must be free:
  # "name", then "name 2", "name 3", and so on, as Finder names them.
  dest="$trash/$base"; n=2
  while [ -e "$dest" ] || [ -L "$dest" ]; do
    if [ "$n" -gt 9999 ]; then
      warn "Could not move $src to the Trash: too many items named '$base' there already. Nothing was deleted."
      return 1
    fi
    dest="$trash/$base $n"; n=$((n + 1))
  done
  id=$(/usr/bin/stat -f %d:%i "$src" 2>/dev/null) || id=""
  # -n: never replace an item that took the name since the check above.
  err=$(mv -n "$src" "$dest" 2>&1) || err=${err:-mv failed}
  err=${err#mv: }
  if [ -e "$src" ] || [ -L "$src" ]; then
    warn "Could not move $src to the Trash: ${err:-$dest was taken just before the move}. Nothing was deleted."
    return 1
  fi
  # Gone from where it was, so a rename put it in the Trash, whole. The return
  # status says only that: whether PATH is still where it was.
  moved=$dest
  if [ -n "$id" ] && [ "$(/usr/bin/stat -f %d:%i "$dest" 2>/dev/null)" != "$id" ] \
     && [ "$(/usr/bin/stat -f %d:%i "$dest/$base" 2>/dev/null)" = "$id" ]; then
    # A folder made at that name in the moment before the move holds it.
    moved="$dest/$base"
  elif [ -n "$err" ] || { [ ! -e "$dest" ] && [ ! -L "$dest" ]; }; then
    # The system may keep a Trash private even from its owner's programs.
    warn "Moved $src to the Trash, but could not check it there${err:+ ($err)}. Look in: $trash"
  fi
  printf '%s\n' "$moved"
}
