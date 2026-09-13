#!/usr/bin/env bash
# Generate the raster assets from assets/img/mark.svg.
#
# The mark itself is served as SVG - it is flat vector art, so rasterising it
# for the page would be strictly worse. These three outputs are the ones that
# genuinely cannot be vector: favicons and the Open Graph card.
set -euo pipefail

src="assets/img/mark.svg"
out="assets/img"

[ -f "$src" ] || { echo "missing $src" >&2; exit 1; }
command -v magick       >/dev/null || { echo "need imagemagick" >&2; exit 1; }
command -v rsvg-convert >/dev/null || { echo "need librsvg (rsvg-convert)" >&2; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# rsvg-convert rather than magick's own renderer - it handles gradients
# correctly where MSVG does not.
rsvg-convert -w 512 "$src" -o "$tmp/mark512.png"
rsvg-convert -w 128 "$src" -o "$tmp/mark128.png"

magick "$tmp/mark128.png" -resize 32x32 -background none -gravity center \
  -extent 32x32 -define png:compression-level=9 "$out/favicon.png"

# iOS ignores alpha on touch icons and fills it black, so flatten onto the
# page background instead of shipping transparency it will not honour.
magick "$tmp/mark512.png" -resize 148x148 -background none -gravity center \
  -extent 180x180 -background "#0b0f1c" -flatten -alpha off \
  -colors 256 -dither None -define png:compression-level=9 "$out/apple-touch-icon.png"

# Open Graph card. 1200x630 is what the scrapers crop to.
magick -size 1200x630 radial-gradient:"#1d2747"-"#080b16" \
  \( "$tmp/mark512.png" -resize x420 \) -gravity center -compose over -composite \
  -quality 82 -interlace Plane -strip "$out/og.jpg"

magick identify -format '%f  %wx%h  %b\n' "$out"/favicon.png "$out"/apple-touch-icon.png "$out"/og.jpg
