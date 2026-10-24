#!/usr/bin/env bash
#
# Regenerate the demos in a throwaway sandbox:
#   bash assets/record-demo.sh        both
#   bash assets/record-demo.sh main   the command-line demo (assets/demo.tape)
#   bash assets/record-demo.sh ui     the menu demo (assets/demo-ui.tape)
#
# HOME, the app search path, the launcher directory and the data root are all
# redirected into a fresh temporary directory seeded with fixture .app bundles.
# The real /Applications is never read, and the tape records no command that
# prints machine details (such as `doctor`), so the recording cannot show an
# app list, a username, a hostname, a real path or a version. The script runs
# under /bin/bash, the 3.2 every Mac has.
#
# Requires: vhs (brew install vhs), rsvg-convert (brew install librsvg), ffmpeg.
set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
which="${1:-all}"
case "$which" in main|ui|all) ;; *) echo "usage: $0 [main|ui|all]" >&2; exit 2 ;; esac

for tool in vhs rsvg-convert ffmpeg iconutil; do
  command -v "$tool" >/dev/null || { echo "$tool is required (see the header of this script)." >&2; exit 1; }
done

# A fresh directory each run, removed on exit. A fixed /tmp path that is
# rm -rf'd first would delete whatever someone else had put there. It sits in
# /tmp, not $TMPDIR: the recording prints these paths, and $TMPDIR is a
# per-user folder whose name is specific to this machine.
D=$(mktemp -d /tmp/aidentity-demo.XXXXXX)
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
cp "$REPO/assets/demo.tape" "$REPO/assets/demo-ui.tape" "$D/"

cd "$D"
record() { # tape
  HOME="$D" PATH="$D:/bin:/usr/bin:$PATH" \
    AIDENTITY_APP_DIRS="$D/Apps" \
    AIDENTITY_APPS_DIR="$D/Applications" \
    AIDENTITY_DATA_ROOT="$D/data" \
    vhs "$1"
}

# Both videos are stripped of metadata, including x264's settings note, which
# names the encoder options used on this machine.
vf="scale=trunc(iw/2)*2:trunc(ih/2)*2,setsar=1"
clean=(-map_metadata -1 -fflags +bitexact -flags:v +bitexact)

if [ "$which" != ui ]; then
record demo.tape

# Halve the file size; a README GIF should not be megabytes.
ffmpeg -y -loglevel error -i aidentity-demo.gif \
  -vf "fps=11,scale=920:-1:flags=lanczos,palettegen=max_colors=64:stats_mode=diff" palette.png
ffmpeg -y -loglevel error -i aidentity-demo.gif -i palette.png \
  -lavfi "fps=11,scale=920:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=4" \
  "$REPO/assets/demo.gif"

# The site plays a video instead: it can pause and resume in place, which a
# GIF cannot, and it is half the size. Same frames, made from the GIF above.
# The poster is the frame at 20 s.
# Keyframes sit exactly at the chapter times in site/index.html (data-t), so a
# browser that seeks only to keyframes still lands on each chapter. Keep the
# two lists the same when the tape changes.
chapters="0,32,41,49,57"
ffmpeg -y -loglevel error -i "$REPO/assets/demo.gif" "${clean[@]}" -movflags +faststart \
  -pix_fmt yuv420p -c:v libx264 -preset veryslow -tune animation -crf 24 \
  -force_key_frames "$chapters" \
  -bsf:v filter_units=remove_types=6 -vf "$vf" "$REPO/site/assets/demo.mp4"
ffmpeg -y -loglevel error -i "$REPO/assets/demo.gif" "${clean[@]}" -pix_fmt yuv420p \
  -c:v libvpx-vp9 -b:v 0 -crf 36 -row-mt 1 -force_key_frames "$chapters" -vf "$vf" "$REPO/site/assets/demo.webm"
ffmpeg -y -loglevel error -ss 20 -i "$REPO/site/assets/demo.mp4" "${clean[@]}" \
  -frames:v 1 -q:v 4 "$REPO/site/assets/demo-poster.jpg"

echo "Wrote $REPO/assets/demo.gif and site/assets/demo.mp4, demo.webm, demo-poster.jpg"
fi

if [ "$which" != main ]; then
# A fresh data root, so the menu demo starts with only the profiles its tape makes.
rm -rf "$D/data" "$D/Applications"; mkdir -p "$D/data" "$D/Applications"
record demo-ui.tape
ffmpeg -y -loglevel error -i aidentity-ui-demo.gif \
  -vf "fps=11,scale=920:-1:flags=lanczos,palettegen=max_colors=64:stats_mode=diff" palette-ui.png
ffmpeg -y -loglevel error -i aidentity-ui-demo.gif -i palette-ui.png \
  -lavfi "fps=11,scale=920:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=4" \
  "$REPO/assets/demo-ui.gif"
# As with the main video, keyframes sit exactly at the chapter times in
# site/index.html (data-t of the menu player), so a browser that seeks only to
# keyframes still lands on each chapter. Keep the two lists the same when the
# tape changes.
ui_chapters="0,5,13,20,24"
ffmpeg -y -loglevel error -i "$REPO/assets/demo-ui.gif" "${clean[@]}" -movflags +faststart \
  -pix_fmt yuv420p -c:v libx264 -preset veryslow -tune animation -crf 24 \
  -force_key_frames "$ui_chapters" \
  -bsf:v filter_units=remove_types=6 -vf "$vf" "$REPO/site/assets/demo-ui.mp4"
ffmpeg -y -loglevel error -i "$REPO/assets/demo-ui.gif" "${clean[@]}" -pix_fmt yuv420p \
  -c:v libvpx-vp9 -b:v 0 -crf 36 -row-mt 1 -force_key_frames "$ui_chapters" -vf "$vf" "$REPO/site/assets/demo-ui.webm"
# The poster shows the menu with every profile, before the first key.
ffmpeg -y -loglevel error -ss 4 -i "$REPO/site/assets/demo-ui.mp4" "${clean[@]}" \
  -frames:v 1 -q:v 4 "$REPO/site/assets/demo-ui-poster.jpg"
echo "Wrote $REPO/assets/demo-ui.gif and site/assets/demo-ui.mp4, demo-ui.webm, demo-ui-poster.jpg"
fi

echo "Check them for anything machine-specific before committing."
