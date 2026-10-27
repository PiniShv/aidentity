# syntax=docker/dockerfile:1.20@sha256:26147acbda4f14c5add9946e2fd2ed543fc402884fd75146bd342a7f6271dc1d
#
# The tools that build the product film (see README.md). Build it once, with
# the network on; render.sh then runs in it with the network off:
#   docker build -t aidentity-film assets/film
#
# The first line pins the Dockerfile frontend, which ADD --checksum needs.

# node:22-bookworm-slim, pinned by digest (the index, so it works on both Intel
# and Apple silicon).
FROM node:22-bookworm-slim@sha256:de170b39439eb0e5a3444ad7d60b015614a381e10fecae2e30ec9e735122f38d

# Every phone-home switch off, for every process in the image.
ENV HYPERFRAMES_NO_TELEMETRY=1 DO_NOT_TRACK=1 HYPERFRAMES_NO_UPDATE_CHECK=1 \
    HYPERFRAMES_NO_AUTO_INSTALL=1 HYPERFRAMES_SKIP_SKILLS=1 HYPERFRAMES_BROWSER_PATH=/usr/bin/chromium \
    NPM_CONFIG_UPDATE_NOTIFIER=false NPM_CONFIG_FUND=false NPM_CONFIG_AUDIT=false \
    PIP_DISABLE_PIP_VERSION_CHECK=1 HF_HUB_OFFLINE=1

# ffmpeg and chromium render and encode; fonts-inter is the film's typeface;
# fonts-dejavu-core is its monospace; librsvg2-bin (rsvg-convert) draws the play
# button on the README poster; python3 is for the narration and music.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ffmpeg chromium fonts-inter fonts-dejavu-core ca-certificates librsvg2-bin \
      python3 python3-venv \
      libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 libxkbcommon0 libxcomposite1 \
      libxdamage1 libxfixes3 libxrandr2 libgbm1 libasound2 libpango-1.0-0 libcairo2 libxshmfence1 \
    && rm -rf /var/lib/apt/lists/*

# HyperFrames and GSAP, exactly as package-lock.json lists them.
WORKDIR /opt/hf
COPY package.json package-lock.json ./
RUN npm ci

# Narration: Kokoro through kokoro-onnx, run offline. The model files are
# fetched now, while the network is allowed, and checked against their hashes.
# Nothing is fetched at render time.
COPY requirements.txt /tmp/requirements.txt
RUN python3 -m venv /opt/tts \
    && /opt/tts/bin/pip install --no-cache-dir --no-deps -r /tmp/requirements.txt \
    && /opt/tts/bin/pip check \
    && rm /tmp/requirements.txt \
    && mkdir -m 755 /opt/tts/models
ADD --chmod=644 --checksum=sha256:7d5df8ecf7d4b1878015a32686053fd0eebe2bc377234608764cc0ef3636a6c5 \
    https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.onnx /opt/tts/models/
ADD --chmod=644 --checksum=sha256:bca610b8308e8d99f32e6fe4197e7ec01679264efed0cac9140fe9c29f1fbf7d \
    https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin /opt/tts/models/

# Run as a normal user. render.sh makes its own work folder under /tmp.
USER node
WORKDIR /work
