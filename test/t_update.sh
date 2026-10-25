# shellcheck shell=bash
# SC2016: single-quoted scripts are handed to "$BASH_BIN" -c and to generated
# stubs, which expand them later, on purpose. shellcheck only recognises that
# when the interpreter is spelled literally as `bash -c`.
# shellcheck disable=SC2016
#
# Area "update": aidentity update: version and tag checks, a run against a stub curl, and a
# broken release refused by install.sh and update alike.
# Sourced by test/run_tests.sh after test/lib.sh. Run it alone with:
#   bash test/run_tests.sh update

group "update — version and tag checks"

for t in v1.4.0 v10.0.123 v0.0.1; do
  libcall is_release_tag "$t"
  assert_rc "accepts the tag $t" 0 "$RUN_RC" "$RUN_OUT"
done
for t in 1.4.0 v1.4 v1.4.0-rc1 V1.4.0 "v1.4.0 " "v1.4.0/../../x" "v1.4.0
v" v1234567890.0.0 ""; do
  libcall is_release_tag "$t"
  assert_rc_nonzero "rejects the tag [$t]" "$RUN_RC" "$RUN_OUT"
done

newer() { # a b expected-rc description
  libcall version_newer "$1" "$2"
  assert_rc "$4" "$3" "$RUN_RC" "$RUN_OUT"
}
newer 1.10.0 1.9.0 0 "1.10.0 is newer than 1.9.0 (numbers, not text)"
newer 2.0.0 1.99.99 0 "2.0.0 is newer than 1.99.99"
newer 1.4.0 1.4.0 1 "a version is not newer than itself"
newer 1.3.9 1.4.0 1 "1.3.9 is not newer than 1.4.0"
newer 1.08.0 1.7.0 0 "a leading zero is not read as octal"

UPD_JSON="$SANDBOX/release.json"
printf '{"url":"x","tag_name":"v1.4.0","body":"see \\"tag_name\\":\\"v9.9.9\\""}' > "$UPD_JSON"
libcall latest_tag "$UPD_JSON"
assert_eq "the tag is read from one-line JSON, not from the notes" "v1.4.0" "$RUN_OUT"
printf '{\n  "tag_name" : "v2.10.3",\n  "name": "x"\n}\n' > "$UPD_JSON"
libcall latest_tag "$UPD_JSON"
assert_eq "and from indented JSON" "v2.10.3" "$RUN_OUT"
printf '{"message":"Not Found"}' > "$UPD_JSON"
libcall latest_tag "$UPD_JSON"
assert_rc_nonzero "an answer with no tag is refused" "$RUN_RC" "$RUN_OUT"

# The caller always names the version to expect: x.y.z, or - for a branch or
# commit. A missing version is a refusal, never a skipped check.
VRF_DIR="$SANDBOX/verify"
mkdir -p "$VRF_DIR/bin"
sed 's/^AIDENTITY_VERSION=.*/AIDENTITY_VERSION="2.0.0"/' "$AIDENTITY" > "$VRF_DIR/bin/aidentity"
( cd "$VRF_DIR" && shasum -a 256 bin/aidentity > SHA256SUMS )
vrf() { # version: check the file against it, and print the checksum kept
  libcall eval "verify_release_file $(printf '%q ' "$VRF_DIR/bin/aidentity" "$VRF_DIR/SHA256SUMS" "$1")"' && printf "%s" "$VERIFIED_SUM"'
}
vrf 2.0.0
assert_rc "a matching file with its version passes" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "and the checksum it passed is kept for the install" \
  "$(awk '{print $1}' "$VRF_DIR/SHA256SUMS")" "$RUN_OUT"
vrf -
assert_rc "with - for the version, the checksum alone decides" 0 "$RUN_RC" "$RUN_OUT"
vrf 2.0.1
assert_rc_nonzero "another version is refused" "$RUN_RC" "$RUN_OUT"
vrf ""
assert_rc_nonzero "no version at all is refused" "$RUN_RC" "$RUN_OUT"
assert_contains "and says so" "$RUN_OUT" "No version was given"


group "update end to end, against a stub curl"

# A stub curl that plays GitHub. It serves files from UPD_SRV by the part of
# the URL after the repository name, so the real URLs work unchanged, and it
# logs every call. UPD_NET=down makes it fail the way a dead network does.
UPD_STUB="$SANDBOX/stub-curl-update"
UPD_SRV="$SANDBOX/update-server"
UPD_LOG="$SANDBOX/update-curl.log"
UPD_TMP="$SANDBOX/update-tmp"
mkdir -p "$UPD_STUB" "$UPD_SRV/releases" "$UPD_TMP"
cat > "$UPD_STUB/curl" <<STUB
#!/bin/sh
out="" url=""
printf '%s\n' "\$*" >> '$UPD_LOG'
if [ "\${UPD_NET:-up}" = down ]; then
  echo "curl: (6) Could not resolve host: api.github.com" >&2; exit 6
fi
while [ \$# -gt 0 ]; do
  case "\$1" in
    -o) out="\$2"; shift 2 ;;
    --proto|--proto-redir|--connect-timeout|--max-time|--retry|--max-filesize|-H) shift 2 ;;
    -*) shift ;;
    *) url="\$1"; shift ;;
  esac
done
case "\$url" in
  https://*/PiniShv/aidentity/*) rest="\${url#https://*/PiniShv/aidentity/}" ;;
  *) rest="" ;;
esac
case "\$rest" in
  ''|*..*|/*) echo "curl: (22) The requested URL returned error: 404" >&2; exit 22 ;;
esac
if [ ! -f '$UPD_SRV'/"\$rest" ]; then
  echo "curl: (22) The requested URL returned error: 404" >&2; exit 22
fi
cat '$UPD_SRV'/"\$rest" > "\$out"
STUB
chmod +x "$UPD_STUB/curl"
# update must never run sudo. If it ever does, this stub leaves a trace.
UPD_SUDO_LOG="$SANDBOX/upd-sudo.log"
cat > "$UPD_STUB/sudo" <<STUB
#!/bin/sh
printf '%s\n' "\$*" >> '$UPD_SUDO_LOG'
exit 1
STUB
chmod +x "$UPD_STUB/sudo"

# A copy of the script at path $1 that says it is version $2.
upd_copy() { # path, version
  mkdir -p "$(dirname "$1")"
  sed "s/^AIDENTITY_VERSION=.*/AIDENTITY_VERSION=\"$2\"/" "$AIDENTITY" > "$1"
  chmod 755 "$1"
}
# Publish a release on the stub server: its tag, and the version its script
# says (the tag's own by default). The checksum file matches what is served.
upd_release() { # tag, [version in the file]
  upd_copy "$UPD_SRV/$1/bin/aidentity" "${2:-${1#v}}"
  ( cd "$UPD_SRV/$1" && shasum -a 256 bin/aidentity > SHA256SUMS )
}
# What the API names as the latest release: any text at all. The notes carry
# a look-alike key, which must never be read as the tag.
upd_latest() { # tag
  printf '{\n  "url": "https://api.github.com/repos/PiniShv/aidentity/releases/1",\n  "tag_name": "%s",\n  "body": "Notes: \\"tag_name\\": \\"v99.0.0\\""\n}\n' \
    "$1" > "$UPD_SRV/releases/latest"
}
# Run `update` from the copy at $1, with the stub curl first on PATH, TMPDIR
# inside the sandbox and no Homebrew variables from the developer's shell.
# VAR=value arguments after the path are set for the run; the rest go to
# update itself.
upd() { # script, [VAR=value …], [update's arguments]
  local script="$1" envs=()
  shift
  while [ $# -gt 0 ]; do
    case "$1" in [A-Z]*=*) envs+=("$1"); shift ;; *) break ;; esac
  done
  : > "$UPD_LOG"
  RUN_OUT=$(env -u HOMEBREW_PREFIX -u HOMEBREW_CELLAR \
      HOME="$SANDBOX/upd-home" TMPDIR="$UPD_TMP" PATH="$UPD_STUB:/usr/bin:/bin:/usr/sbin:/sbin" \
      ${envs[@]+"${envs[@]}"} /usr/bin/perl -MPOSIX -e '
      my $pid = fork; die "fork: $!\n" unless defined $pid;
      if ($pid) { waitpid($pid, 0); exit($? & 127 ? 128 + ($? & 127) : $? >> 8) }
      POSIX::setsid(); exec @ARGV or exit 127' -- "$BASH_BIN" "$script" update "$@" 2>&1 </dev/null)
  RUN_RC=$?
  return 0
}
calls() { grep -c . "$UPD_LOG" | tr -d ' '; }
same_file() { # description, file, saved copy
  if cmp -s "$2" "$3"; then _pass "$1"; else _fail "$1" "$2 changed"; fi
}
only_script_in() { # folder: nothing but the script is left there
  assert_eq "no staged file is left in the folder" "aidentity" "$(ls -A "$1")"
  assert_eq "no download folder is left behind" "" "$(ls -A "$UPD_TMP")"
}

ai help
assert_contains "help documents update" "$RUN_OUT" "update"

U_DIR="$SB/upd bin"
U="$U_DIR/aidentity"
U_SAVED="$SANDBOX/upd-saved"
upd_copy "$U" 1.0.0
cp "$U" "$U_SAVED"

upd_release v1.0.0
upd_latest v1.0.0
upd "$U" --check
assert_rc "--check exits 0 when up to date" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "and says so" "$RUN_OUT" "1.0.0 is up to date"
upd "$U"
assert_rc "update exits 0 when up to date" 0 "$RUN_RC" "$RUN_OUT"
assert_eq "and downloads nothing beyond the release info" "1" "$(calls)"
same_file "and leaves the file alone" "$U" "$U_SAVED"

upd_release v2.0.0
upd_latest v2.0.0
upd "$U" --check
assert_rc "--check exits 0 when a new release is out" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "and names both versions" "$RUN_OUT" "1.0.0 → 2.0.0 is available"
assert_contains "and how to update" "$RUN_OUT" "aidentity update"
assert_eq "--check downloads nothing beyond the release info" "1" "$(calls)"
same_file "--check installs nothing" "$U" "$U_SAVED"
UPD_CALLS=$(cat "$UPD_LOG")
assert_contains "curl is held to HTTPS" "$UPD_CALLS" "--proto =https"
assert_contains "redirects too" "$UPD_CALLS" "--proto-redir =https"
assert_contains "with TLS 1.2 or later" "$UPD_CALLS" "--tlsv1.2"
assert_contains "and a time limit" "$UPD_CALLS" "--max-time"
assert_contains "the release info comes from the GitHub API" "$UPD_CALLS" \
  "https://api.github.com/repos/PiniShv/aidentity/releases/latest"

upd "$U"
assert_rc "update installs a new release and exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "it says what it updated" "$RUN_OUT" "Updated 1.0.0 → 2.0.0"
assert_contains "it says the checksum was verified" "$RUN_OUT" "checksum verified"
assert_contains "it suggests rebuilding the launchers" "$RUN_OUT" "aidentity doctor --fix"
assert_contains "the script comes from the release tag" "$(cat "$UPD_LOG")" \
  "https://raw.githubusercontent.com/PiniShv/aidentity/v2.0.0/bin/aidentity"
assert_eq "an update makes three downloads" "3" "$(calls)"
# -q works only as curl's first argument. Anywhere else, curl still reads the
# user's .curlrc, where "insecure" would turn off certificate checks.
assert_eq "every curl call starts with -q, so ~/.curlrc is never read" "0" \
  "$(grep -vc '^-q ' "$UPD_LOG")"
same_file "the file is now the release's script" "$U" "$UPD_SRV/v2.0.0/bin/aidentity"
assert_exec "and stays executable" "$U"
assert_eq "with mode 755" "755" "$(/usr/bin/stat -f %Lp "$U")"
only_script_in "$U_DIR"
RUN_OUT=$("$BASH_BIN" "$U" version 2>&1)
assert_eq "the new copy runs" "aidentity 2.0.0" "$RUN_OUT"

# Through a symlink, the real file is replaced and the link stays a link.
upd_copy "$SB/upd real/aidentity" 1.0.0
mkdir -p "$SB/upd link"
ln -s "$SB/upd real/aidentity" "$SB/upd link/aidentity"
upd "$SB/upd link/aidentity"
assert_rc "update through a symlink exits 0" 0 "$RUN_RC" "$RUN_OUT"
same_file "the file the link points at is replaced" "$SB/upd real/aidentity" "$UPD_SRV/v2.0.0/bin/aidentity"
if [ -L "$SB/upd link/aidentity" ]; then _pass "the link is still a link"
else _fail "the link is still a link" "it was replaced by a file"; fi

# The file found must carry this copy's exact version line, or update cannot
# be sure it found itself. Here the line has a comment added by hand.
upd_copy "$SB/upd odd/aidentity" 1.0.0
/usr/bin/sed -i '' 's/^AIDENTITY_VERSION="1.0.0"$/AIDENTITY_VERSION="1.0.0"  # edited/' "$SB/upd odd/aidentity"
cp "$SB/upd odd/aidentity" "$SANDBOX/upd-saved-odd"
upd "$SB/upd odd/aidentity"
assert_rc_nonzero "a file without this copy's exact version line is refused" "$RUN_RC" "$RUN_OUT"
assert_contains "as a file it cannot find" "$RUN_OUT" "Could not find the file"
assert_eq "before any network call" "0" "$(calls)"
same_file "and the file is kept" "$SB/upd odd/aidentity" "$SANDBOX/upd-saved-odd"

# A broken release (checksum, SHA256SUMS, version, network) is refused by one
# table that runs against update and install.sh alike: see the group "a broken
# release is refused" below. Whether a release is a complete, valid script is
# not checked here: the checksum proves the download is the published file,
# and the release gate (scripts/guards.sh, tested in "release check") checks
# the published file.
upd_copy "$U" 1.0.0

for t in 2.0.0 v2.0 v2.0.0-rc1 "v2.0.0/../../../evil/repo/v9.9.9" "v2.0.0\$(touch $SANDBOX/pwned)"; do
  upd_latest "$t"
  upd "$U"
  assert_rc_nonzero "a malformed tag is refused: $t" "$RUN_RC" "$RUN_OUT"
  assert_eq "and nothing is downloaded for it" "1" "$(calls)"
  case "$t" in
    *evil*) assert_not_contains "and the tag is never echoed" "$RUN_OUT" "evil" ;;
  esac
done
upd "$U" --check
assert_rc_nonzero "--check refuses a malformed tag too" "$RUN_RC" "$RUN_OUT"
assert_contains "and says the answer was not a valid release" "$RUN_OUT" "valid release"
same_file "the old file is kept" "$U" "$U_SAVED"
assert_no_file "and nothing in the tag ran" "$SANDBOX/pwned"
upd_latest v2.0.0

# Never a downgrade: a copy newer than the latest release stays as it is.
upd_copy "$U" 3.0.0
cp "$U" "$SANDBOX/upd-saved-3"
upd "$U"
assert_rc "a copy newer than the latest release exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "and says it is newer" "$RUN_OUT" "newer than the latest release (2.0.0)"
assert_eq "and downloads nothing" "1" "$(calls)"
same_file "it is never downgraded" "$U" "$SANDBOX/upd-saved-3"
upd_copy "$U" 1.0.0

upd "$U" UPD_NET=down --check
assert_rc_nonzero "--check with no network exits non-zero" "$RUN_RC" "$RUN_OUT"
assert_contains "with a clear error" "$RUN_OUT" "Could not get the latest release"

# Homebrew's copy belongs to brew. Refused before any network call.
upd_copy "$SB/brew/Cellar/aidentity/1.0.0/bin/aidentity" 1.0.0
mkdir -p "$SB/brew/bin"
ln -s ../Cellar/aidentity/1.0.0/bin/aidentity "$SB/brew/bin/aidentity"
upd "$SB/brew/bin/aidentity"
assert_rc_nonzero "a Homebrew copy is refused" "$RUN_RC" "$RUN_OUT"
assert_contains "with the brew command" "$RUN_OUT" "brew upgrade aidentity"
assert_eq "before any network call" "0" "$(calls)"
same_file "the Homebrew file is kept" "$SB/brew/Cellar/aidentity/1.0.0/bin/aidentity" "$U_SAVED"
upd "$SB/brew/bin/aidentity" --check
assert_rc "--check still works for a Homebrew copy" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "and points at brew" "$RUN_OUT" "To update:    brew upgrade aidentity"
upd_copy "$SB/hb prefix/bin/aidentity" 1.0.0
upd "$SB/hb prefix/bin/aidentity" "HOMEBREW_PREFIX=$SB/hb prefix"
assert_rc_nonzero "a copy inside HOMEBREW_PREFIX is refused" "$RUN_RC" "$RUN_OUT"
assert_contains "with the brew command" "$RUN_OUT" "brew upgrade aidentity"
upd_copy "$SB/hb store/aidentity/1.0.0/bin/aidentity" 1.0.0
upd "$SB/hb store/aidentity/1.0.0/bin/aidentity" "HOMEBREW_CELLAR=$SB/hb store"
assert_rc_nonzero "a copy inside HOMEBREW_CELLAR is refused" "$RUN_RC" "$RUN_OUT"
assert_contains "with the brew command" "$RUN_OUT" "brew upgrade aidentity"
assert_eq "before any network call" "0" "$(calls)"
same_file "and the file is kept" "$SB/hb store/aidentity/1.0.0/bin/aidentity" "$U_SAVED"

# A source checkout is updated with git, not by replacing its file.
U_CO="$SB/checkout"
upd_copy "$U_CO/bin/aidentity" 1.0.0
touch "$U_CO/install.sh" "$U_CO/uninstall.sh" "$U_CO/LICENSE"
mkdir -p "$U_CO/.git"
upd "$U_CO/bin/aidentity"
assert_rc_nonzero "a copy in a git checkout is refused" "$RUN_RC" "$RUN_OUT"
# The script names folders by their real path: /var is /private/var on macOS.
assert_contains "with git pull for that folder" "$RUN_OUT" "git -C '$(cd -P "$U_CO" && pwd -P)' pull"
assert_eq "before any network call" "0" "$(calls)"
same_file "the checkout's file is kept" "$U_CO/bin/aidentity" "$U_SAVED"
upd "$U_CO/bin/aidentity" --check
assert_rc "--check works in a git checkout" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "and points at git pull" "$RUN_OUT" "To update:    git -C '$(cd -P "$U_CO" && pwd -P)' pull"
# Unpacked source code with no .git: there is nothing to pull from.
rm -rf "$U_CO/.git"
upd "$U_CO/bin/aidentity"
assert_rc_nonzero "a copy in unpacked source code is refused" "$RUN_RC" "$RUN_OUT"
assert_contains "and says to download the new release" "$RUN_OUT" \
  "Update the source code instead: download the new release from https://github.com/PiniShv/aidentity"
assert_not_contains "and does not suggest git" "$RUN_OUT" "git -C"
assert_eq "before any network call" "0" "$(calls)"
same_file "the file is kept" "$U_CO/bin/aidentity" "$U_SAVED"
upd "$U_CO/bin/aidentity" --check
assert_rc "--check works in unpacked source code" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "and points at the release page" "$RUN_OUT" \
  "To update:    download the new release from https://github.com/PiniShv/aidentity"

if [ "$(id -u)" = "0" ]; then
  _skip "a folder the user cannot write to is refused" "running as root, every folder is writable"
else
  U_RO="$SB/upd ro"
  upd_copy "$U_RO/aidentity" 1.0.0
  chmod 555 "$U_RO"
  upd "$U_RO/aidentity"
  chmod 755 "$U_RO"
  assert_rc_nonzero "a folder the user cannot write to is refused" "$RUN_RC" "$RUN_OUT"
  assert_contains "with the exact command to run" "$RUN_OUT" "sudo '$(cd -P "$U_RO" && pwd -P)/aidentity' update"
  assert_eq "before anything is downloaded" "1" "$(calls)"
  same_file "the file is kept" "$U_RO/aidentity" "$U_SAVED"
fi

# A sticky folder (like /tmp): anyone may write there, but only the owner of
# a file, or of the folder, may replace it.
U_ST="$SB/upd sticky"
upd_copy "$U_ST/aidentity" 1.0.0
chmod 1777 "$U_ST"
libcall can_replace "$U_ST/aidentity"
assert_rc "in a sticky folder, your own file can be replaced" 0 "$RUN_RC" "$RUN_OUT"
upd "$U_ST/aidentity"
assert_rc "and update replaces it there" 0 "$RUN_RC" "$RUN_OUT"
same_file "with the release's script" "$U_ST/aidentity" "$UPD_SRV/v2.0.0/bin/aidentity"
only_script_in "$U_ST"
chmod 755 "$U_ST"
# /private/tmp is sticky, writable by all and owned by root. A file there that
# is not yours (here: one that does not exist) cannot be replaced. Only looked
# at, never written.
if [ -k /private/tmp ] && [ -w /private/tmp ] && [ ! -O /private/tmp ]; then
  libcall can_replace "/private/tmp/aidentity-not-yours.$$"
  assert_rc_nonzero "in a sticky folder that is not yours, a file that is not yours cannot be replaced" "$RUN_RC" "$RUN_OUT"
else
  _skip "in a sticky folder that is not yours, a file that is not yours cannot be replaced" \
    "/private/tmp is not a sticky folder owned by someone else here"
fi

# The script read from stdin has no file to replace. $0 is then the shell,
# which must never be taken for the script.
: > "$UPD_LOG"
RUN_OUT=$(env -u HOMEBREW_PREFIX -u HOMEBREW_CELLAR HOME="$SANDBOX/upd-home" TMPDIR="$UPD_TMP" \
  PATH="$UPD_STUB:/usr/bin:/bin:/usr/sbin:/sbin" "$BASH_BIN" -s update < "$U" 2>&1); RUN_RC=$?
assert_rc_nonzero "a script read from stdin refuses to update" "$RUN_RC" "$RUN_OUT"
assert_contains "and says it cannot find its file" "$RUN_OUT" "Could not find the file"
assert_eq "before any network call" "0" "$(calls)"

# No setting points update anywhere but GitHub.
upd "$U" AIDENTITY_UPDATE_URL=https://example.invalid/r --check
assert_rc "a leftover AIDENTITY_UPDATE_URL changes nothing" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "the release info still comes from GitHub" "$(cat "$UPD_LOG")" \
  "https://api.github.com/repos/PiniShv/aidentity/releases/latest"
assert_not_contains "and never from the setting" "$(cat "$UPD_LOG")" "example.invalid"

# No curl on PATH: a clear message, and nothing else happens. uname stays,
# because the script checks it is on macOS before anything else.
mkdir -p "$SANDBOX/upd-no-curl"
ln -sf /usr/bin/uname "$SANDBOX/upd-no-curl/uname"
upd "$U" "PATH=$SANDBOX/upd-no-curl"
assert_rc_nonzero "update without curl exits non-zero" "$RUN_RC" "$RUN_OUT"
assert_contains "and says it needs curl" "$RUN_OUT" "needs curl"
assert_eq "and nothing is downloaded" "0" "$(calls)"
same_file "and the file is kept" "$U" "$U_SAVED"

# Stopped part way: the download folder and the staged copy are both removed.
# update runs in its own process group with a slow stub; once the stub says it
# is busy, the signal goes to that group: update and the stub it waits on,
# all started here. A job started with & ignores SIGINT, and a shell cannot
# trap a signal ignored when it starts, so the wrapper restores it first, as
# a terminal's Ctrl-C would find it.
UPD_READY="$SANDBOX/upd-ready"
UPD_SLOW_NET="$SANDBOX/stub-upd-slow-net"
UPD_SLOW_SUM="$SANDBOX/stub-upd-slow-sum"
mkdir -p "$UPD_SLOW_NET" "$UPD_SLOW_SUM"
cat > "$UPD_SLOW_NET/curl" <<STUB
#!/bin/sh
ps -o pgid= -p \$\$ | tr -d ' ' > '$UPD_READY'
sleep 20
exit 28
STUB
# Slow only when it checks the staged copy, the moment it sits beside the
# old file.
cat > "$UPD_SLOW_SUM/shasum" <<STUB
#!/bin/sh
for a in "\$@"; do
  case "\$a" in
    */.aidentity.*) ps -o pgid= -p \$\$ | tr -d ' ' > '$UPD_READY'; sleep 20 ;;
  esac
done
exec /usr/bin/shasum "\$@"
STUB
chmod +x "$UPD_SLOW_NET/curl" "$UPD_SLOW_SUM/shasum"
upd_signal() { # signal, stub folder, script
  local pid pg="" i=0
  rm -f "$UPD_READY"
  env -u HOMEBREW_PREFIX -u HOMEBREW_CELLAR \
      HOME="$SANDBOX/upd-home" TMPDIR="$UPD_TMP" PATH="$2:$UPD_STUB:/usr/bin:/bin:/usr/sbin:/sbin" \
      /usr/bin/perl -MPOSIX -e '
      my $pid = fork; die "fork: $!\n" unless defined $pid;
      if ($pid) { waitpid($pid, 0); exit($? & 127 ? 128 + ($? & 127) : $? >> 8) }
      $SIG{INT} = "DEFAULT"; POSIX::setsid(); exec @ARGV or exit 127' -- "$BASH_BIN" "$3" update \
      >"$SANDBOX/upd-signal.out" 2>&1 </dev/null &
  pid=$!
  while [ ! -s "$UPD_READY" ] && [ "$i" -lt 100 ]; do sleep 0.1; i=$((i+1)); done
  pg=$(cat "$UPD_READY" 2>/dev/null)
  UPD_BUSY_DIR=$(ls -A "$(dirname "$3")")
  UPD_BUSY_TMP=$(ls -A "$UPD_TMP")
  case "$pg" in ''|*[!0-9]*) ;; *) kill -"$1" -- "-$pg" 2>/dev/null ;; esac
  wait "$pid"; RUN_RC=$?
  RUN_OUT=$(cat "$SANDBOX/upd-signal.out")
  return 0
}
upd_signal TERM "$UPD_SLOW_NET" "$U"
assert_ne "a download folder existed while curl ran" "" "$UPD_BUSY_TMP"
assert_rc "TERM during the download exits 143" 143 "$RUN_RC" "$RUN_OUT"
same_file "and the old file is kept" "$U" "$U_SAVED"
only_script_in "$U_DIR"
upd_signal INT "$UPD_SLOW_SUM" "$U"
assert_contains "a staged copy sat beside the old file" "$UPD_BUSY_DIR" ".aidentity."
assert_rc "Ctrl-C while the new copy is staged exits 130" 130 "$RUN_RC" "$RUN_OUT"
same_file "and the old file is kept" "$U" "$U_SAVED"
only_script_in "$U_DIR"

upd "$U" --no-such-flag
assert_rc_nonzero "an unknown option for update exits non-zero" "$RUN_RC" "$RUN_OUT"
upd "$U" now
assert_rc_nonzero "an extra argument for update exits non-zero" "$RUN_RC" "$RUN_OUT"
same_file "and neither touches the file" "$U" "$U_SAVED"
only_script_in "$U_DIR"
assert_no_file "update never ran sudo, in any run above" "$UPD_SUDO_LOG"


group "a broken release is refused, by install.sh and update alike"

# One table of broken releases, run against both ways a release reaches a
# Mac: install.sh with AIDENTITY_REF set to the tag, and update with the tag
# as the latest release. Both use the stub curl above that plays GitHub. Each
# row publishes v2.0.0 and breaks it in one way. Both must refuse, say why,
# and leave the copy installed before exactly as it was.
#   row|text both print
REFUSALS='bad-sum|Checksum mismatch
no-line|no valid line for bin/aidentity
no-sums|cannot be checked
wrong-version|does not say it is version 2.0.0
net-down|Check your internet connection'
break_release() { # row
  upd_release v2.0.0
  case "$1" in
    bad-sum) printf '%064d  bin/aidentity\n' 0 > "$UPD_SRV/v2.0.0/SHA256SUMS" ;;
    no-line) printf 'abc123  install.sh\n' > "$UPD_SRV/v2.0.0/SHA256SUMS" ;;
    no-sums) rm -f "$UPD_SRV/v2.0.0/SHA256SUMS" ;;
    wrong-version) upd_release v2.0.0 2.0.1 ;;
  esac
}
R_DIR="$SB/refusal bin"
R_ENV=("PATH=$UPD_STUB:/usr/bin:/bin:/usr/sbin:/sbin" "TMPDIR=$UPD_TMP")
upd_latest v2.0.0
while IFS='|' read -r row says; do
  break_release "$row"
  net=up; [ "$row" = net-down ] && net=down
  upd_copy "$R_DIR/aidentity" 1.0.0
  inst "$R_DIR" "${R_ENV[@]}" "UPD_NET=$net" AIDENTITY_REF=v2.0.0
  assert_rc_nonzero "install.sh refuses: $row" "$RUN_RC" "$RUN_OUT"
  assert_contains "and says why" "$RUN_OUT" "$says"
  assert_contains "and names the ref it tried" "$RUN_OUT" "AIDENTITY_REF=v2.0.0"
  assert_contains "and that nothing was installed" "$RUN_OUT" "Nothing was installed"
  if [ "$row" = net-down ]; then
    assert_contains "and how to set a proxy, since ~/.curlrc is not read" "$RUN_OUT" \
      "https_proxy or CURL_CA_BUNDLE instead"
  fi
  same_file "the copy installed before is kept byte for byte" "$R_DIR/aidentity" "$U_SAVED"
  only_script_in "$R_DIR"
  upd "$U" "UPD_NET=$net"
  assert_rc_nonzero "update refuses: $row" "$RUN_RC" "$RUN_OUT"
  assert_contains "and says why" "$RUN_OUT" "$says"
  assert_contains "and that nothing changed" "$RUN_OUT" "Nothing was changed"
  same_file "the old file is kept byte for byte" "$U" "$U_SAVED"
  only_script_in "$U_DIR"
done <<ROWS
$REFUSALS
ROWS

# The same release unbroken: install.sh installs it, over the old copy.
upd_release v2.0.0
: > "$UPD_LOG"
inst "$R_DIR" "${R_ENV[@]}" AIDENTITY_REF=v2.0.0
assert_rc "install.sh installs a release that passes every check" 0 "$RUN_RC" "$RUN_OUT"
same_file "with the release's script" "$R_DIR/aidentity" "$UPD_SRV/v2.0.0/bin/aidentity"
assert_contains "and says what it upgraded" "$RUN_OUT" "Upgraded aidentity 1.0.0 → 2.0.0"
only_script_in "$R_DIR"
assert_eq "install.sh downloads two files" "2" "$(calls)"
assert_eq "every curl call of install.sh starts with -q, so ~/.curlrc is never read" "0" \
  "$(grep -vc '^-q ' "$UPD_LOG")"
# A branch, or a tag that is not a release, names no version, so its checksum
# alone decides.
upd_release main 2.0.1
inst "$SB/refusal branch" "${R_ENV[@]}" AIDENTITY_REF=main
assert_rc "for a branch, install.sh needs only the checksum" 0 "$RUN_RC" "$RUN_OUT"
same_file "and installs the branch's script" "$SB/refusal branch/aidentity" "$UPD_SRV/main/bin/aidentity"
upd_release v2.0.0-rc1 2.0.0
inst "$SB/refusal rc" "${R_ENV[@]}" AIDENTITY_REF=v2.0.0-rc1
assert_rc "for a tag that is not a release (v2.0.0-rc1), install.sh needs only the checksum" 0 "$RUN_RC" "$RUN_OUT"
same_file "and installs that tag's script" "$SB/refusal rc/aidentity" "$UPD_SRV/v2.0.0-rc1/bin/aidentity"
printf '%064d  bin/aidentity\n' 0 > "$UPD_SRV/v2.0.0-rc1/SHA256SUMS"
inst "$SB/refusal rc2" "${R_ENV[@]}" AIDENTITY_REF=v2.0.0-rc1
assert_rc_nonzero "but still refuses it when the checksum does not match" "$RUN_RC" "$RUN_OUT"
assert_no_file "and writes nothing" "$SB/refusal rc2/aidentity"

# The download passed every check, and installing it fails: no staged file can
# be made, the staged copy does not match the checksum, mv cannot replace the
# old file (it is locked with chflags), or the file found after the move does
# not match. Stub mktemp and shasum fail on cue (AT_FAIL). Both entry points
# must stop and say why, and leave no staged file. Until the move, the old
# copy is kept byte for byte.
#   row|text both print
ATOMIC='mktemp|Could not write to
staged|does not match the download
mv|Could not replace
installed|did not leave the new copy'
AT_STUB="$SANDBOX/stub-install-fail"
mkdir -p "$AT_STUB"
cat > "$AT_STUB/mktemp" <<STUB
#!/bin/sh
case "\${AT_FAIL:-}:\$*" in mktemp:*/.aidentity.*) exit 1 ;; esac
exec /usr/bin/mktemp "\$@"
STUB
# The last argument is the file to hash. Downloads sit in '$UPD_TMP'.
cat > "$AT_STUB/shasum" <<STUB
#!/bin/sh
for f in "\$@"; do :; done
case "\${AT_FAIL:-}:\$f" in
  staged:*/.aidentity.*) ;;
  installed:'$UPD_TMP'/*) exec /usr/bin/shasum "\$@" ;;
  installed:*/aidentity) ;;
  *) exec /usr/bin/shasum "\$@" ;;
esac
printf '%064d  %s\n' 0 "\$f"
STUB
chmod +x "$AT_STUB/mktemp" "$AT_STUB/shasum"
AT_ENV=("PATH=$AT_STUB:$UPD_STUB:/usr/bin:/bin:/usr/sbin:/sbin" "TMPDIR=$UPD_TMP")
upd_release v2.0.0
upd_latest v2.0.0
while IFS='|' read -r row says; do
  upd_copy "$R_DIR/aidentity" 1.0.0
  [ "$row" = mv ] && chflags uchg "$R_DIR/aidentity"
  inst "$R_DIR" "${AT_ENV[@]}" "AT_FAIL=$row" AIDENTITY_REF=v2.0.0
  chflags nouchg "$R_DIR/aidentity"
  assert_rc_nonzero "install.sh stops when installing fails: $row" "$RUN_RC" "$RUN_OUT"
  assert_contains "and says why" "$RUN_OUT" "$says"
  assert_not_contains "and does not report an install" "$RUN_OUT" "Upgraded"
  only_script_in "$R_DIR"
  [ "$row" = mv ] && chflags uchg "$U"
  upd "$U" "${AT_ENV[@]}" "AT_FAIL=$row"
  chflags nouchg "$U"
  assert_rc_nonzero "update stops when installing fails: $row" "$RUN_RC" "$RUN_OUT"
  assert_contains "and says why" "$RUN_OUT" "$says"
  assert_not_contains "and does not report an update" "$RUN_OUT" "Updated"
  only_script_in "$U_DIR"
  if [ "$row" = installed ]; then
    # The move happened; only the check after it failed.
    same_file "the file found there is the release's" "$R_DIR/aidentity" "$UPD_SRV/v2.0.0/bin/aidentity"
    same_file "for update too" "$U" "$UPD_SRV/v2.0.0/bin/aidentity"
    upd_copy "$U" 1.0.0
  else
    same_file "install.sh kept the old copy byte for byte" "$R_DIR/aidentity" "$U_SAVED"
    same_file "update kept the old file byte for byte" "$U" "$U_SAVED"
  fi
done <<ROWS
$ATOMIC
ROWS
assert_no_file "neither install.sh nor update ran sudo, in any run in this group" "$UPD_SUDO_LOG"
