#!/usr/bin/env bash
#
# Regenerate assets/demo.gif in a throwaway sandbox.
#
# HOME, the app search path, the launcher directory and the data root are all
# redirected into a fresh temporary directory seeded with fixture .app bundles.
# The real /Applications is never read, so the recording cannot show an app
# list, a username, a hostname or a real path. Two facts about the machine do
# appear, because `aidentity doctor` prints them: the macOS version and the
# bash version. The script runs under /bin/bash, the 3.2 every Mac has.
#
# Requires: vhs (brew install vhs), rsvg-convert (brew install librsvg), ffmpeg.
set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)

for tool in vhs rsvg-convert ffmpeg iconutil; do
  command -v "$tool" >/dev/null || { echo "$tool is required (see the header of this script)." >&2; exit 1; }
done

# A fresh directory each run, removed on exit. A fixed /tmp path that is
# rm -rf'd first would delete whatever someone else had put there.
D=$(mktemp -d "${TMPDIR:-/tmp}/aidentity-demo.XXXXXX")
trap 'rm -rf "$D"' EXIT

mkdir -p "$D/Apps" "$D/Applications" "$D/data" "$D/f.iconset"

# Fixture apps need an icon only so the tool takes its normal path; icons never
# appear in a terminal recording.
for s in 16 32 128 256 512; do
  rsvg-convert -w "$s"  -h "$s"  "$REPO/assets/icon.svg" -o "$D/f.iconset/icon_${s}x${s}.png"
  rsvg-convert -w $((s*2)) -h $((s*2)) "$REPO/assets/icon.svg" -o "$D/f.iconset/icon_${s}x${s}@2x.png"
done
iconutil -c icns "$D/f.iconset" -o "$D/fixture.icns"

for n in Claude ChatGPT Slack; do
  mkdir -p "$D/Apps/$n.app/Contents/Frameworks/Electron Framework.framework" \
           "$D/Apps/$n.app/Contents/Resources"
  cp "$D/fixture.icns" "$D/Apps/$n.app/Contents/Resources/app.icns"
  printf '<?xml version="1.0"?><!DOCTYPE plist><plist version="1.0"><dict><key>CFBundleIdentifier</key><string>com.example.%s</string><key>CFBundleName</key><string>%s</string><key>CFBundleIconFile</key><string>app</string></dict></plist>' \
    "$n" "$n" > "$D/Apps/$n.app/Contents/Info.plist"
done
rm -rf "$D/f.iconset"

install -m 755 "$REPO/bin/aidentity" "$D/aidentity"
cp "$REPO/assets/demo.tape" "$D/demo.tape"

cd "$D"
HOME="$D" PATH="$D:/bin:/usr/bin:$PATH" \
  AIDENTITY_APP_DIRS="$D/Apps" \
  AIDENTITY_APPS_DIR="$D/Applications" \
  AIDENTITY_DATA_ROOT="$D/data" \
  vhs demo.tape

# Halve the file size; a README GIF should not be megabytes.
ffmpeg -y -loglevel error -i aidentity-demo.gif \
  -vf "fps=11,scale=920:-1:flags=lanczos,palettegen=max_colors=64:stats_mode=diff" palette.png
ffmpeg -y -loglevel error -i aidentity-demo.gif -i palette.png \
  -lavfi "fps=11,scale=920:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=4" \
  "$REPO/assets/demo.gif"

echo "Wrote $REPO/assets/demo.gif"
echo "Check it for anything machine-specific before committing."
