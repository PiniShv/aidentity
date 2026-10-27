#!/usr/bin/env bash
#
# Rebuild the product film, its posters and the social card:
#   bash assets/film/build.sh             build the image if it is missing, then the film
#   bash assets/film/build.sh --rebuild   build the image again first
#   FILM_KEEP=some/folder bash assets/film/build.sh
#                                         also keep every output there, including
#                                         film-mix.wav, the finished sound
#
# The film is made inside a Docker image (assets/film/Dockerfile). Building the
# image needs the network, once. Making the film does not: the container runs
# with --network none, the repository mounted read-only, and writes only to a
# throwaway folder. Then the results are copied into place:
#   site/assets/film.mp4, film.webm, film-poster.jpg   what the site plays
#   site/assets/og.png                                 the card for shared links
#   assets/film-poster.jpg                             the README poster
# The script runs under /bin/bash, the 3.2 every Mac has.
#
# Requires: docker (Docker Desktop or any engine that runs Linux containers).
set -euo pipefail

REPO=$(cd "$(dirname "$0")/../.." && pwd)
IMAGE=aidentity-film

rebuild=0
case "${1:-}" in
  "") ;;
  --rebuild) rebuild=1 ;;
  *) echo "usage: $0 [--rebuild]" >&2; exit 2 ;;
esac

command -v docker >/dev/null || { echo "docker is required (see the header of this script)." >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "docker is installed but not running. Start it and try again." >&2; exit 1; }

if [ "$rebuild" = 1 ] || ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "Building the $IMAGE image. This needs the network and takes a few minutes."
  docker build -t "$IMAGE" "$REPO/assets/film"
fi

# A fresh folder each run, removed on exit.
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT

echo "Making the film. No network is used, and the repository is read-only."
docker run --rm --network none --shm-size=1g \
  -v "$REPO:/repo:ro" -v "$out:/out" \
  "$IMAGE" bash /repo/assets/film/render.sh

# The container wrote to $out, so anything there could be a symlink to any
# file on this Mac, and copying through it would put that file in the
# repository. Only plain, non-empty files with these names are copied.
outputs="film.mp4 film.webm film-poster.jpg readme-poster.jpg og.png film-mix.wav"
for f in $outputs; do
  if [ -L "$out/$f" ] || [ ! -f "$out/$f" ] || [ ! -s "$out/$f" ]; then
    echo "The build did not make $f as a plain file. Nothing was copied." >&2
    exit 1
  fi
done
[ -z "${FILM_KEEP:-}" ] || mkdir -p "$FILM_KEEP"

mkdir -p "$REPO/site/assets"
cp "$out/film.mp4" "$out/film.webm" "$out/film-poster.jpg" "$out/og.png" "$REPO/site/assets/"
cp "$out/readme-poster.jpg" "$REPO/assets/film-poster.jpg"
if [ -n "${FILM_KEEP:-}" ]; then
  for f in $outputs; do cp "$out/$f" "$FILM_KEEP/"; done
fi

echo
echo "Wrote:"
for f in site/assets/film.mp4 site/assets/film.webm site/assets/film-poster.jpg site/assets/og.png assets/film-poster.jpg; do
  printf '  %-28s %s bytes\n' "$f" "$(wc -c < "$REPO/$f" | tr -d ' ')"
done
echo "Watch the film with sound and look at both posters and the card before committing."
