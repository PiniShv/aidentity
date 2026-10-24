#!/usr/bin/env bash
#
# Checks that a commit is ready to be released as a tag, before anything is
# signed or published. The release workflow runs it first. You can run it too,
# on the commit you are about to tag:
#
#   bash scripts/release-check.sh v1.4.0
#
# TAG is "v" and the version, as in the tag you push. It fails unless:
#
#   - the tag is "v" and the version in bin/aidentity,
#   - SHA256SUMS has the current checksum of bin/aidentity (the installer
#     refuses a script it does not match),
#   - install.sh installs this tag by default. scripts/guards.sh also allows
#     main there, so a release made without `make release` would pass the
#     guards and ship an installer that installs main, not the tag,
#   - CHANGELOG.md has notes for the version (see release-notes.sh),
#   - scripts/guards.sh passes.
#
# It reads files only. It stops at the first failure.

set -uo pipefail

tag="${1:-}"
if [ -z "$tag" ]; then
  printf 'Usage: scripts/release-check.sh vX.Y.Z\n' >&2
  exit 2
fi

# The repository this script is in, wherever you run it from.
cd "$(dirname "$0")/.." || exit 1

die() { printf '::error::%s\n' "$1" >&2; exit 1; }

# The same shape make release accepts. It keeps odd text out of the comparisons
# and messages below.
version=$(sed -n 's/^AIDENTITY_VERSION="\(.*\)"$/\1/p' bin/aidentity 2>/dev/null)
case "$version" in
  ''|*[!0-9.]*|.*|*.|*..*|*.*.*.*) version='' ;;
  *.*.*) ;;
  *) version='' ;;
esac
[ -n "$version" ] || die "Could not read a version (x.y.z) from AIDENTITY_VERSION in bin/aidentity."

if [ "$tag" != "v$version" ]; then
  die "The tag is $tag but bin/aidentity is version $version. Nothing was released."
fi

want=$(awk '$2 == "bin/aidentity" { print $1; exit }' SHA256SUMS 2>/dev/null)
got=$(shasum -a 256 bin/aidentity | awk '{print $1}')
if [ -z "$want" ] || [ "$want" != "$got" ]; then
  die "SHA256SUMS does not match bin/aidentity (expected ${want:-nothing}, got $got). Run: make checksums"
fi

# shellcheck disable=SC2016  # the $ is part of the text matched, not expanded
ref=$(sed -n 's/^REF="\${AIDENTITY_REF:-\(.*\)}"$/\1/p' install.sh 2>/dev/null)
if [ "$ref" != "v$version" ]; then
  die "install.sh installs '${ref:-nothing}' by default; for this release it must install v$version. Run: make release VERSION=$version"
fi

bash scripts/release-notes.sh "$version" > /dev/null \
  || die "CHANGELOG.md has no notes for $version. Nothing was released."

bash scripts/guards.sh || die "scripts/guards.sh failed. Its errors are above."

printf 'Tag %s matches version %s.\n' "$tag" "$version"
