#!/usr/bin/env bash
#
# Builds the film, inside the aidentity-film image. build.sh runs this; see
# README.md. It needs no network and refuses to run with one.
#   render.sh          narration, music, render, encode, posters
#   render.sh audio    only the narration and the music: writes film-mix.wav
#
# Reads this folder and ../logo.svg (the repository is mounted read-only).
# Writes to /out (or $OUT):
#   film.mp4  film.webm        the film, 1280x720, 31.4 s, with sound
#   film-poster.jpg            the poster the site shows before play
#   readme-poster.jpg          the README poster, with a play button
#   og.png                     the card shown when a link to the site is shared
#   film-mix.wav               the finished sound, for checking by ear
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${OUT:-/out}
mode=${1:-all}
case "$mode" in all|audio) ;; *) echo "usage: $0 [all|audio]" >&2; exit 2 ;; esac

# The container must have no network: no device but the loopback may be up.
for nic in /sys/class/net/*; do
  [ "${nic##*/}" = lo ] && continue
  if [ "$(cat "$nic/operstate" 2>/dev/null)" = up ]; then
    echo "The network device ${nic##*/} is up. Run this with: docker run --network none" >&2
    exit 1
  fi
done
[ -d "$OUT" ] && [ -w "$OUT" ] || { echo "$OUT is not a writable folder." >&2; exit 1; }

export PYTHONDONTWRITEBYTECODE=1
PY=/opt/tts/bin/python
HF=/opt/hf/node_modules/.bin/hyperframes
LENGTH=31.4
step() { printf '\n== %s\n' "$*"; }
ff() { ffmpeg -nostdin -hide_banner -y -loglevel error "$@"; }

W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT
# As the container's first process, bash ignores Ctrl-C unless it traps it.
# Stop on it, so build.sh fails and copies nothing.
trap 'exit 130' INT TERM
A=$W/audio     # the sound
P=$W/film      # the composition, with the files it loads
mkdir -p "$A" "$P/fonts" "$P/vendor"

echo "ffmpeg: $(ffmpeg -version | head -n 1)"
echo "hyperframes: $("$HF" --version)"

# 1. Narration: Kokoro, one file per line, 24 kHz.
step "Narration"
"$PY" "$HERE/narration.py" "$A"

# 2. The voice chain, line by line: de-ess, resample to 48 kHz, take out the
# low end a laptop speaker cannot play (below 120 Hz, and a little at 220 Hz),
# add a little clarity at 3 kHz, band-limit, compress lightly, a short fade in,
# a short fade out, then 0.3 s of silence.
step "Voice chain"
for raw in "$A"/vo[0-9]*-raw.wav; do
  ff -i "$raw" \
    -af "deesser=i=0.36:m=0.5:f=0.5,aresample=48000:filter_size=64:phase_shift=10:cutoff=0.95,highpass=f=120:p=2,highpass=f=120:p=2,equalizer=f=220:t=q:w=1:g=-3,equalizer=f=3000:t=q:w=1:g=2,lowpass=f=10500:p=2,acompressor=threshold=-24dB:ratio=2:attack=15:release=220:makeup=1.5,afade=t=in:d=0.012,areverse,afade=t=in:d=0.04,areverse,apad=pad_dur=0.3" \
    -ar 48000 -ac 1 "${raw%-raw.wav}.wav"
done

# 3. Music, and the narration laid over it.
step "Music and mix"
"$PY" "$HERE/music.py" "$A"

# 4. Loudness: measure the mix, then lift it to -16 LUFS with a true-peak
# limiter at -2 dBTP. master.py is gain plus limiter, nothing else.
step "Loudness"
I=$(ffmpeg -nostdin -hide_banner -nostats -i "$A/mix.wav" -af ebur128 -f null - 2>&1 \
    | awk '/^ *I: / { v = $2 } END { print v }')
case "$I" in
  -[0-9]*.[0-9]*) ;;
  *) echo "Could not read the integrated loudness (got '$I')." >&2; exit 1 ;;
esac
GAIN=$(awk -v i="$I" 'BEGIN { printf "%.1f", -16 - i }')
echo "integrated loudness $I LUFS, gain $GAIN dB, ceiling -2.0 dBTP"
"$PY" "$HERE/master.py" "$A/mix.wav" "$A/film-mix.wav" "$GAIN" -2.0
cp "$A/film-mix.wav" "$OUT/film-mix.wav"

if [ "$mode" = audio ]; then
  echo "Wrote $OUT/film-mix.wav"
  exit 0
fi

# 5. The composition and everything it loads, in one folder: the logo from the
# repository, the Inter faces from the fonts-inter package, GSAP from npm.
step "Render"
cp "$HERE/index.html" "$P/index.html"
cp "$HERE/../logo.svg" "$P/logo.svg"
for w in Regular Medium SemiBold Bold; do
  cp "/usr/share/fonts/opentype/inter/Inter-$w.otf" "$P/fonts/"
done
cp /opt/hf/node_modules/gsap/dist/gsap.min.js "$P/vendor/gsap.min.js"
( cd "$P" && "$HF" render -o film-silent.mp4 --fps 30 --quality high )
[ -s "$P/film-silent.mp4" ] || { echo "The render wrote no film-silent.mp4." >&2; exit 1; }

# 6. Encode. No metadata goes in: no encoder settings, versions or dates.
step "Encode"
clean=(-map_metadata -1 -map_chapters -1 -fflags +bitexact -flags:v +bitexact -flags:a +bitexact)
vf="scale=trunc(iw/2)*2:trunc(ih/2)*2,setsar=1"
cd "$W"

# MP4: H.264 and AAC. filter_units drops the encoder's settings note.
ff -i "$P/film-silent.mp4" "${clean[@]}" -an -pix_fmt yuv420p -c:v libx264 -preset veryslow \
  -tune animation -crf 23 -bsf:v filter_units=remove_types=6 -vf "$vf" -t "$LENGTH" video.mp4
ff -i video.mp4 -i "$A/film-mix.wav" "${clean[@]}" -map 0:v -map 1:a -c:v copy -c:a aac \
  -b:a 160k -ar 48000 -movflags +faststart -t "$LENGTH" film.mp4

# WebM: VP9 and Opus. The Opus is encoded on its own and then copied in, so the
# file carries no "encoder" tag on the audio stream.
ff -i "$P/film-silent.mp4" "${clean[@]}" -an -pix_fmt yuv420p -c:v libvpx-vp9 -b:v 0 -crf 34 \
  -row-mt 1 -vf "$vf" -t "$LENGTH" video.webm
ff -i "$A/film-mix.wav" "${clean[@]}" -c:a libopus -b:a 128k -ar 48000 audio.opus
ff -i video.webm -i audio.opus "${clean[@]}" -map 0:v -map 1:a -c copy -t "$LENGTH" film.webm

# 7. The site poster: the frame at 20.8 s, with both lines and both windows on screen.
step "Posters"
ff -ss 20.8 -i film.mp4 "${clean[@]}" -frames:v 1 -q:v 4 film-poster.jpg

# 8. The README poster: the frame at 20.8 s with a play button over it.
cat > play.svg <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="1280" height="720" viewBox="0 0 1280 720">
  <circle cx="640" cy="560" r="46" fill="rgba(255,255,255,0.16)" stroke="rgba(255,255,255,0.55)" stroke-width="2"/>
  <path d="M628 538 L 660 560 L 628 582 Z" fill="#ffffff"/>
</svg>
SVG
rsvg-convert -w 1280 -h 720 play.svg -o play.png
ff -ss 20.8 -i film.mp4 -i play.png -filter_complex "overlay=0:0" "${clean[@]}" \
  -frames:v 1 -q:v 3 readme-poster.jpg

# 9. The card shown when a link to the site is shared: og.html at 1200x630,
# drawn by the same Chromium with the same fonts and logo as the film.
step "Social card"
cp "$HERE/og.html" "$P/og.html"
chromium --headless --no-sandbox --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
  --virtual-time-budget=4000 --window-size=1200,630 --screenshot="$W/og.png" "file://$P/og.html" \
  >/dev/null 2>&1
[ -s og.png ] || { echo "Chromium wrote no og.png." >&2; exit 1; }

cp film.mp4 film.webm film-poster.jpg readme-poster.jpg og.png "$OUT/"

step "Done"
for f in film.mp4 film.webm film-poster.jpg readme-poster.jpg og.png film-mix.wav; do
  printf '  %-18s %s bytes\n' "$f" "$(wc -c < "$OUT/$f" | tr -d ' ')"
done
for f in film.mp4 film.webm; do
  printf '  %-18s %s s\n' "$f" "$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT/$f")"
done
