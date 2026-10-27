# The product film

The source of the 19.5-second film on the site, with its sound, its two
posters and the card shown when a link to the site is shared. It is a build
tool for the repository, not part of the installed tool: `aidentity`,
`install.sh` and the Homebrew formula never fetch or run anything from this
folder.

## Rebuild it

You need Docker.

```sh
bash assets/film/build.sh
```

The first run builds the image `aidentity-film` (needs the network, takes a few
minutes, about 3 GB on disk). Every run after that makes the film with the
network off. The script copies the results into place:

| File | Used by |
|---|---|
| `site/assets/film.mp4`, `film.webm` | the site player |
| `site/assets/film-poster.jpg` | the site, before play |
| `site/assets/og.png` | the card shown when a link to the site is shared |
| `assets/film-poster.jpg` | the README, with a play button drawn on it |

Watch the film with sound and look at both posters and the card before you
commit them.

- `--rebuild` builds the image again first.
- `FILM_KEEP=some/folder bash assets/film/build.sh` also keeps every output
  there, including `film-mix.wav`, the finished sound.
- Only the sound, which takes seconds:

  ```sh
  mkdir -p /tmp/film-sound
  docker run --rm --network none -v "$PWD:/repo:ro" -v /tmp/film-sound:/out \
    aidentity-film bash /repo/assets/film/render.sh audio
  ```

## What is here

| File | What it does |
|---|---|
| `index.html` | The film: a 1280x720 page, animated with a GSAP timeline |
| `og.html` | The card for shared links: a 1200x630 page |
| `narration.py` | The six spoken lines, made with Kokoro, offline |
| `music.py` | The music, written in code from fixed seeds, and the mix with the narration |
| `master.py` | Gain and a true-peak limiter |
| `render.sh` | Runs in the container: all the steps below |
| `build.sh` | Runs on your Mac: builds the image, runs `render.sh`, copies the results |
| `Dockerfile`, `package.json`, `package-lock.json`, `requirements.txt` | The image |

The logo is `assets/logo.svg`. The Inter fonts and `gsap.min.js` are not in the
repository: `render.sh` takes them from the image and puts them next to the
page.

The steps in `render.sh`:

1. Narration: six lines with Kokoro, 24 kHz.
2. Voice chain, per line, with ffmpeg: de-ess, resample to 48 kHz, cut the low
   end a laptop speaker cannot play, a little more clarity, band-limit, light
   compression, short fades, 0.3 s of silence at the end.
3. Music and mix: the music, ducked under the narration. It has no kick and
   nothing below about 110 Hz, so small speakers play it cleanly.
4. Loudness: lift the mix to -16 LUFS, with a true-peak limit of -2 dBTP.
5. Render the page to video with HyperFrames, 30 frames per second.
6. Encode: MP4 (H.264 and AAC) and WebM (VP9 and Opus), with no encoder
   settings, versions or dates.
7. The site poster: the frame at 8.9 s.
8. The README poster: the frame at 8.9 s, with a play button on it.
9. The card for shared links: `og.html`, drawn by the same Chromium.

## What is pinned, and why

So the film can be rebuilt later from the same inputs, and a download cannot
change under it.

- The base image, `node:22-bookworm-slim`, by digest. The digest is of the
  multi-platform index, so it works on Intel and Apple silicon. The Dockerfile
  frontend that `ADD --checksum` needs is pinned the same way.
- npm: `package-lock.json`, installed with `npm ci`. `package.json` names exact
  versions (HyperFrames 0.8.207, GSAP 3.15.0).
- pip: `requirements.txt`, exact versions, installed with `--no-deps`, so the
  file is the whole list.
- The two Kokoro model files, by SHA-256 (`ADD --checksum`). A different file
  fails the build.
- The music uses fixed seeds.

Not pinned: the Debian packages (ffmpeg 5.1.9, Chromium 156, Inter 4.0~beta7,
librsvg 2.54.7 when this was written). They come from Debian 12 when the image
is built, so a later build can take newer security updates, and the video bytes
can then differ. Even with the same image, the video bytes change a little from
run to run: Chromium's drawing is not bit-exact, though the difference cannot
be seen. The sound comes out the same, sample for sample.

## No network while rendering

- `build.sh` runs the container with `--network none`, and `render.sh` stops if
  a network device is up.
- The model files are downloaded when the image is built, never at render time.
- Every phone-home switch is set in the Dockerfile `ENV`: HyperFrames telemetry,
  update check and auto-install, the npm update notice, the pip version check,
  and Hugging Face offline mode.
- The container runs as a normal user, not root, and the repository is mounted
  read-only.

## Licences

What the image downloads and uses, with the licence as the installed package or
the Debian package says it. Read the licence before you reuse any of it. None
of this is part of aidentity or shipped with it: the repository holds the
scripts, this page and the film they make, not the tools.

| Part | Licence | Stated in |
|---|---|---|
| Kokoro model files (`kokoro-v1.0.onnx`, `voices-v1.0.bin`) | Apache-2.0 | the kokoro-onnx package description; the files carry no licence text |
| kokoro-onnx 0.6.1 | MIT | its `LICENSE` file |
| phonemizer 3.4.0 (needed by kokoro-onnx) | GPL-3.0-or-later | its `LICENSE` file and metadata |
| espeakng-loader 0.2.4 (bundles an eSpeak NG library) | none stated in the package | its metadata |
| soundfile 0.14.0 | BSD-3-Clause; bundles libsndfile and codec libraries under LGPL and BSD licences | its `LICENSE`, `COPYING` and licence notes |
| onnxruntime 1.31.1, numpy 2.4.6, and the other pip packages | MIT, BSD-3-Clause, Apache-2.0, PSF-2.0 and similar; numpy also carries 0BSD, Zlib and CC0 parts | each package's metadata and licence files |
| HyperFrames 0.8.207 | Apache-2.0 | its `package.json`; the package has no licence file |
| GSAP 3.15.0 | "Standard 'no charge' license", https://gsap.com/standard-license | its `package.json`; the package has no licence file |
| HyperFrames' other npm packages (124 in the lock file) | mostly MIT and Apache-2.0; the optional image libraries `@img/sharp-libvips-*` are LGPL-3.0-or-later | `package-lock.json` |
| Node.js 22 | MIT, with the licences of its bundled parts | `/usr/local/LICENSE` in the image |
| Inter (`fonts-inter`) | OFL-1.1 and Apache-2.0 | its Debian copyright file |
| DejaVu Sans Mono (`fonts-dejavu-core`) | Bitstream Vera licence; the DejaVu changes are public domain | its Debian copyright file |
| ffmpeg 5.1.9 (Debian) | LGPL-2.1+ and GPL-2+; this build includes the GPL parts, such as x264 | its Debian copyright file |
| Chromium 156 (Debian) | many licences, mostly BSD-3-Clause and Apache-2.0 | `/usr/share/doc/chromium/copyright` in the image |
| librsvg 2.54.7 (`rsvg-convert`, Debian) | LGPL-2+ and others | its Debian copyright file |
