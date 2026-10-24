#!/usr/bin/env bash
#
# Prints the notes for one release: a short install header, then that
# version's section from CHANGELOG.md. The release workflow uses it, and so can
# you, to see what a release page will say before you push the tag.
#
#   bash scripts/release-notes.sh 1.4.0
#   bash scripts/release-notes.sh 1.4.0 path/to/CHANGELOG.md
#
# VERSION is x.y.z, with no leading "v". The section is everything under the
# "## [x.y.z] - date" heading, up to the next "## [" heading or the link list
# at the bottom of the file. The heading itself is left out: the release has its
# own title. A version with no section, or an empty one, is an error, so a
# release is never published with blank notes.

set -uo pipefail

version="${1:-}"
# The default is the repository's own file, wherever you run this from. A path
# you pass is used as given.
repo=$(cd "$(dirname "$0")/.." && pwd) || exit 1
changelog="${2:-$repo/CHANGELOG.md}"

# The same shape make release accepts. It also keeps odd text out of the
# search below and out of the install line.
case "$version" in
  ''|*[!0-9.]*|.*|*.|*..*|*.*.*.*) version='' ;;
  *.*.*) ;;
  *) version='' ;;
esac
if [ -z "$version" ]; then
  printf 'Usage: scripts/release-notes.sh x.y.z [CHANGELOG.md]\n' >&2
  exit 2
fi

[ -f "$changelog" ] || { printf 'Cannot read %s\n' "$changelog" >&2; exit 1; }

# awk prints the section's lines. Blank lines are held back and printed only
# when more text follows, so the section has no blank line at either end.
section=$(awk -v v="$version" '
  index($0, "## [" v "]") == 1 { inside = 1; next }
  inside && (/^## \[/ || /^\[[^]]+\]: /) { exit }
  inside {
    if ($0 ~ /^[[:space:]]*$/) { blanks = blanks "\n"; next }
    if (started) printf "%s", blanks
    blanks = ""; started = 1; print
  }
' "$changelog")

if [ -z "$section" ]; then
  printf 'No notes for %s in %s. Add a "## [%s]" section with content.\n' \
    "$version" "$changelog" "$version" >&2
  exit 1
fi

cat <<EOF
**Install or upgrade**

\`\`\`bash
curl -fsSL https://raw.githubusercontent.com/PiniShv/aidentity/v${version}/install.sh | bash
\`\`\`

or with Homebrew: \`brew install pinishv/tap/aidentity\` (\`brew update && brew upgrade aidentity\` to upgrade).

The four release files, \`aidentity\`, \`install.sh\`, \`uninstall.sh\` and \`SHA256SUMS\`, have signed build provenance. The "Source code" archives that GitHub adds to every release are not signed. To check a file, see [Verifying a release](https://github.com/PiniShv/aidentity/blob/main/SECURITY.md#verifying-a-release).

EOF
printf '%s\n' "$section"
