#!/usr/bin/env bash

# Configuration

PHOTOS="$HOME"/Downloads/
OUTPUT="$HOME"/working/tmp/gallery
MAX_PHOTOS=500

# Script

set -e
set -o pipefail
shopt -s expand_aliases

ROOT="$( dirname "$( realpath "${BASH_SOURCE[0]}" )" )"

case $OSTYPE in
  darwin*)
    alias find=gfind
    alias md5sum='md5 -r'
    required=( rsync identify sed gfind renice )
    ;;
  *)
    required=( rsync identify sed find renice )
    ;;
esac

if command -v magick >/dev/null; then
  :
elif command -v convert >/dev/null; then
  alias magick=convert
else
  die "Missing required utility: magick (ImageMagick)"
fi

report() { echo "$@" >&2; }
die()    { report "$@"; exit 1; }

discover_images() {
  [[ -d $PHOTOS ]] || die "$PHOTOS does not exist!"

  find "$PHOTOS" -type f \( -iname '*.jpg' -o -iname '*.png' \) -printf "%T+ %p\n" \
    | sort -r \
    | head -n "$MAX_PHOTOS" \
    | cut -d ' ' -f 2-
}

generate_image_hashes() {
  while IFS= read -r file; do
    md5sum "$file"
  done < <( discover_images )
}

generate_image_thumbnail() {
  magick \
    "$1" \
    -auto-orient \
    -strip \
    -interlace plane \
    -resize 300 \
    -quality 60% \
    "$2"
  report "small $( basename "$1" )"
}

generate_image_fullsize() {
  magick \
    "$1" \
    -auto-orient \
    -strip \
    -quality 35 \
    "$2"
  report "large $( basename "$1" )"
}

generate_image_json() {
  local ihash="$1"

  local width height
  read -r width height < <( identify -format '%w %h\n' "small/$1.webp" )

  local alt=""
  printf \
    '{"s":"%s","w":%d,"h":%d,"a":"%s"},' \
    "$ihash" \
    "$width" \
    "$height" \
    "$alt"
}

generate_gallery_json() {
  echo 'var images = ['

  ihashes=()
  while read -r ihash path; do
    local small="small/$ihash.webp"
    local large="large/$ihash.webp"

    [[ -f "$small" ]] || generate_image_thumbnail "$path" "$small"
    [[ -f "$large" ]] || generate_image_fullsize  "$path" "$large"

    ihashes+=( "$ihash" )
    (( i++ % 20 )) || printf '.' >&2
  done < <( generate_image_hashes )
  report " $i thumbnails processed"

  for ihash in "${ihashes[@]}"; do
    generate_image_json "$ihash"
    (( h++ % 20 )) || printf '.' >&2
  done

  echo '];'
  report " $h images processed"
}

generate_site() {
  rsync --archive "$ROOT"/web/* .
  generate_gallery_json > images.js

  ihash="$( md5sum images.js | cut -c 1-10 )"
  cp images.js "images.$ihash.js"

  sed -i'' -e 's/images.js/images.'"$ihash"'.js/' index.html
  find . -name 'images.*.js' -mtime +7 -delete
}

check_requirements() {
  grep -q EXAMPLE "$ROOT"/web/index.html &&
    die "Please update web/index.html with your information. Look for 'EXAMPLE'"

  missing=( )
  for cmd in "${required[@]}"; do
    command -v "$cmd" > /dev/null || missing+=( "$cmd" )
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    die "Missing required utilities: ${missing[*]}"
  fi
}

main() {
  check_requirements

  renice -n 5 $$ > /dev/null 2>&1
  mkdir -p "$OUTPUT" "$OUTPUT"/large "$OUTPUT"/small
  cd "$OUTPUT"
  generate_site
}

"${@:-main}"
