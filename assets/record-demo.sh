#!/usr/bin/env bash
#
# Regenerate the demos and the pictures of the window in a throwaway sandbox:
#   bash assets/record-demo.sh          all three
#   bash assets/record-demo.sh main     the command-line demo (assets/demo.tape)
#   bash assets/record-demo.sh ui       the menu demo (assets/demo-ui.tape)
#   bash assets/record-demo.sh window   the pictures of `aidentity ui --window`
#
# HOME, the app search path, the launcher directory and the data root are all
# redirected into a fresh temporary directory seeded with fixture .app bundles.
# The real /Applications is never read, and the tapes record no command that
# prints machine details (such as `doctor`), so a recording cannot show an app
# list, a username, a hostname or a real path. The script runs under
# /bin/bash, the 3.2 every Mac has.
#
# Requires: rsvg-convert (brew install librsvg). The demos also need vhs
# (brew install vhs) and ffmpeg. The pictures need Google Chrome, to draw the
# page.
set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
case "${1:-all}" in
  main|ui|window) steps=("$1") ;;
  all) steps=(main ui window) ;;
  *) echo "usage: $0 [main|ui|window|all]" >&2; exit 2 ;;
esac

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
need() { # tools
  local tool
  for tool in "$@"; do
    command -v "$tool" >/dev/null || { echo "$tool is required (see the header of this script)." >&2; exit 1; }
  done
}
# Every step's tools are checked before anything is recorded.
need rsvg-convert
for step in "${steps[@]}"; do
  case "$step" in
    window) [ -x "$CHROME" ] || { echo "Google Chrome is required for the window pictures." >&2; exit 1; } ;;
    *) need vhs ffmpeg ;;
  esac
done

# A fresh directory each run, removed on exit. The menu prints a profile's
# folder when it renames one, so the path appears in the recording. It is a
# short fixed name in /tmp: a random suffix, or $TMPDIR (a per-user folder whose
# name is specific to this machine), would show in the video. mkdir makes it
# only when it does not exist yet, so the script never removes a folder it did
# not create. The trap is set after that check, for the same reason.
D=/tmp/aidentity-demo
mkdir "$D" 2>/dev/null || {
  echo "$D already exists. Move or remove it, then run this again." >&2
  exit 1
}
trap 'rm -rf "$D"' EXIT

mkdir -p "$D/Apps" "$D/Applications" "$D/data" "$D/f.iconset"

# The fixture apps carry the stand-in icon the site shows (site/assets/app.svg):
# no real product's mark. The window pictures show it, with the badge
# aidentity draws.
for s in 16 32 128 256 512; do
  rsvg-convert -w "$s"  -h "$s"  "$REPO/site/assets/app.svg" -o "$D/f.iconset/icon_${s}x${s}.png"
  rsvg-convert -w $((s*2)) -h $((s*2)) "$REPO/site/assets/app.svg" -o "$D/f.iconset/icon_${s}x${s}@2x.png"
done
iconutil -c icns "$D/f.iconset" -o "$D/fixture.icns"

fixture() { # name of a stand-in app
  mkdir -p "$D/Apps/$1.app/Contents/Frameworks/Electron Framework.framework" \
           "$D/Apps/$1.app/Contents/Resources"
  cp "$D/fixture.icns" "$D/Apps/$1.app/Contents/Resources/app.icns"
  printf '<?xml version="1.0"?><!DOCTYPE plist><plist version="1.0"><dict><key>CFBundleIdentifier</key><string>com.example.%s</string><key>CFBundleName</key><string>%s</string><key>CFBundleIconFile</key><string>app</string></dict></plist>' \
    "$1" "$1" > "$D/Apps/$1.app/Contents/Info.plist"
}
for n in Claude ChatGPT Slack; do fixture "$n"; done
rm -rf "$D/f.iconset"

install -m 755 "$REPO/bin/aidentity" "$D/aidentity"
cd "$D"

sandboxed() { # command and its words, run inside the sandbox
  HOME="$D" PATH="$D:/bin:/usr/bin:$PATH" \
    AIDENTITY_APP_DIRS="$D/Apps" \
    AIDENTITY_APPS_DIR="$D/Applications" \
    AIDENTITY_DATA_ROOT="$D/data" \
    "$@"
}
# Every step starts with no profiles.
fresh() { rm -rf "$D/data" "$D/Applications"; mkdir -p "$D/data" "$D/Applications"; }

# A tape is the settings both demos share, then its own lines.
record() { # tape
  cat "$REPO/assets/demo-common.tape" "$REPO/assets/$1" > "$D/$1"
  sandboxed vhs "$1"
}

# The site plays a video: it can pause and resume in place, which a GIF
# cannot, and it is far smaller. The poster is the frame at the given time.
# Videos are stripped of metadata, including x264's settings note, which names
# the encoder options used on this machine.
site_video() { # recording, name, poster time in seconds
  local vf="scale=trunc(iw/2)*2:trunc(ih/2)*2,setsar=1"
  local clean=(-map_metadata -1 -fflags +bitexact -flags:v +bitexact)
  ffmpeg -y -loglevel error -i "$1" "${clean[@]}" -an -movflags +faststart \
    -pix_fmt yuv420p -c:v libx264 -preset veryslow -tune animation -crf 22 \
    -bsf:v filter_units=remove_types=6 -vf "$vf" "$REPO/site/assets/$2.mp4"
  ffmpeg -y -loglevel error -i "$1" "${clean[@]}" -an -pix_fmt yuv420p \
    -c:v libvpx-vp9 -b:v 0 -crf 34 -row-mt 1 -vf "$vf" "$REPO/site/assets/$2.webm"
  ffmpeg -y -loglevel error -ss "$3" -i "$REPO/site/assets/$2.mp4" "${clean[@]}" \
    -frames:v 1 -q:v 3 "$REPO/site/assets/$2-poster.jpg"
}

# Chrome draws one page of the sandbox into a picture, at two pixels a point.
shot() { # page, picture, width, height, further Chrome options
  local page="$1" out="$2" w="$3" h="$4"
  shift 4
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --no-first-run \
    --user-data-dir="$D/chrome" --force-device-scale-factor=2 --window-size="$w,$h" \
    --virtual-time-budget=3000 "$@" --screenshot="$out" "file://$D/$page" >/dev/null 2>&1
  [ -s "$out" ] || { echo "Chrome wrote no $out." >&2; exit 1; }
}

step_main() {
  fresh
  record demo.tape
  # The poster shows the first command with its answer. The tape types it,
  # waits for it and then pauses 3.5 s, so 5 s is inside that pause.
  site_video aidentity-demo.mp4 demo 5
  # The README shows the same recording as a GIF, smaller and slower in frames.
  ffmpeg -y -loglevel error -i aidentity-demo.mp4 \
    -vf "fps=12,scale=900:-1:flags=lanczos,palettegen=max_colors=48:stats_mode=diff" palette.png
  ffmpeg -y -loglevel error -i aidentity-demo.mp4 -i palette.png \
    -lavfi "fps=12,scale=900:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=none" \
    "$REPO/assets/demo.gif"
  echo "Wrote assets/demo.gif and site/assets/demo.mp4, demo.webm, demo-poster.jpg"
}

step_ui() {
  fresh
  record demo-ui.tape
  # The poster shows the menu with every profile, before the first key. The
  # menu is up one to three seconds in, by the machine's speed, and the tape
  # then pauses 2.2 s, so 3 s is inside that pause on most runs. Look at the
  # poster after every recording.
  site_video aidentity-ui-demo.mp4 demo-ui 3
  echo "Wrote site/assets/demo-ui.mp4, demo-ui.webm, demo-ui-poster.jpg"
}

# The window's own page, answered from this sandbox: window.html. The real
# window asks aidentity for the list and gets the icons from the program that
# hosts the page; here a few lines of script answer in the host's place, with
# the same list and the same icons. Some profiles are shown as running, a state
# the sandbox cannot make, because its stand-in apps cannot start.
window_page() { # app, its launchers, the ones shown as running
  local app="$1" all="$2" running="$3" n mark='<script nonce="__AIDENTITY_NONCE__">'

  # The page, with one more line in front of its own script: the script that
  # answers. That line carries the page's nonce, so the page's content policy
  # lets it run.
  sandboxed aidentity __window page > page.html
  [ "$(grep -cxF "$mark" page.html)" = 1 ] || {
    echo "The window's page has changed: this script no longer knows where to add its answer." >&2
    exit 1
  }
  awk -v mark="$mark" '
    $0 == mark { print "<script nonce=\"shot\" src=\"answer.js\"></script>" }
    { gsub(/__AIDENTITY_NONCE__/, "shot"); print }' page.html > window.html
  {
    printf 'var L='
    sandboxed aidentity __window state launchers
    printf ';\nvar R='
    sandboxed aidentity __window state apps restorable
    printf ';\nvar PNG={},RUNNING=" %s ";\n' "$running"
    for n in $all; do
      sips -s format png -z 96 96 "$D/Applications/$app $n.app/Contents/Resources/icon.icns" \
        --out "$D/icon.png" >/dev/null
      printf 'PNG["%s %s"]="data:image/png;base64,%s";\n' "$app" "$n" "$(base64 < "$D/icon.png" | tr -d '\n')"
    done
    cat <<'JS'
var ICONS={};
L.profiles.forEach(function(p){
  ICONS[p.icon]=PNG[p.name];
  p.status=RUNNING.indexOf(" "+p.name.split(" ").pop()+" ")<0?"not running":"running";
});
window.webkit={messageHandlers:{aid:{postMessage:function(m){setTimeout(function(){
  if(m.kind==="state")window.aidReply({id:m.id,rc:0,state:m.args.indexOf("launchers")>=0?L:R,icons:ICONS});
},0)}}}};
JS
  } > answer.js
}

step_window() {
  # The page is photographed at this size, in points. site/index.html gives the
  # pictures' size in pixels, twice these numbers.
  local w=780 h=520
  # The README's picture adds a drawn title bar and room for the shadow.
  local bar=38 side=60 above=36 below=84

  fresh
  sandboxed aidentity add Claude --profile Work --color blue >/dev/null
  sandboxed aidentity add Claude --profile Personal --color green >/dev/null
  sandboxed aidentity add Claude --profile Client --color orange >/dev/null
  sandboxed aidentity add Claude --main >/dev/null
  sandboxed aidentity add Claude --profile Test --color teal >/dev/null
  sandboxed aidentity rm 'Claude Test' -y >/dev/null
  window_page Claude "Work Personal Client Main" "Work Personal"

  # The page follows the Mac's appearance, so Chrome is told which one to show:
  # 1 is light and 0 is dark.
  shot window.html "$REPO/site/assets/window-light.png" "$w" "$h" --blink-settings=preferredColorScheme=1
  shot window.html "$REPO/site/assets/window-dark.png" "$w" "$h" --blink-settings=preferredColorScheme=0

  # The README's picture: the dark page in a drawn window, on a clear ground.
  cp "$REPO/site/assets/window-dark.png" "$D/window-dark.png"
  cat > frame.html <<HTML
<!doctype html><meta charset="utf-8">
<style>
  html, body { margin: 0; background: transparent; }
  .w { width: ${w}px; margin: ${above}px ${side}px ${below}px; border-radius: 12px; overflow: hidden;
       box-shadow: 0 0 0 1px rgba(255,255,255,.16), 0 0 0 2px rgba(0,0,0,.35), 0 36px 60px -14px rgba(0,0,0,.6); }
  .b { position: relative; display: flex; align-items: center; gap: 8px; height: ${bar}px; padding: 0 14px; background: #2a2a2d; }
  .b i { width: 12px; height: 12px; border-radius: 50%; background: #ff5f57; }
  .b i:nth-child(2) { background: #febc2e; } .b i:nth-child(3) { background: #28c840; }
  .b b { position: absolute; left: 0; right: 0; text-align: center; font: 600 13px -apple-system, sans-serif; color: #98989d; }
  img { display: block; width: ${w}px; height: ${h}px; }
</style>
<div class="w"><div class="b"><i></i><i></i><i></i><b>aidentity</b></div><img src="window-dark.png" alt=""></div>
HTML
  shot frame.html "$REPO/assets/window.png" $((w + 2 * side)) $((h + bar + above + below)) \
    --default-background-color=00000000

  # The film's picture (assets/film/index.html shows it): the film's stand-in
  # app is called Chat and has three accounts, all open. The window is smaller,
  # so the page reads at the size the film shows it.
  fresh
  fixture Chat
  sandboxed aidentity add Chat --profile Work --color blue >/dev/null
  sandboxed aidentity add Chat --profile Personal --color green >/dev/null
  sandboxed aidentity add Chat --profile Client --color orange >/dev/null
  window_page Chat "Work Personal Client" "Work Personal Client"
  shot window.html "$REPO/assets/film/window.png" 630 420 --blink-settings=preferredColorScheme=0
  echo "Wrote site/assets/window-light.png, window-dark.png, assets/window.png and assets/film/window.png"
}

for step in "${steps[@]}"; do "step_$step"; done
echo "Check them for anything machine-specific before committing."
