#!/usr/bin/env bash
# Regenerate the responsive hero images from the full-size source art.
#
# The source art is not tracked (see .gitignore) - it is a 19MB png that has
# no business being in a git repo. Drop it at assets/src/hero.png and run this
# if the artwork ever changes.
set -euo pipefail

src="assets/src/hero.png"
out="assets/img"
widths=(240 480 720)

[ -f "$src" ] || { echo "missing $src - see comment at top of this file" >&2; exit 1; }
command -v magick  >/dev/null || { echo "need imagemagick" >&2; exit 1; }
command -v avifenc >/dev/null || { echo "need libavif (avifenc)" >&2; exit 1; }

mkdir -p "$out"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# The source has ~80px of empty transparent margin baked in. Drop it so the
# art fills its box and the widths below mean what they say.
magick "$src" -trim +repage -strip "$tmp/base.png"

# CSS caps the display size at 240px, so 720 covers a 3x screen.
for w in "${widths[@]}"; do
  magick "$tmp/base.png" -resize "${w}x" -strip PNG32:"$tmp/$w.png"
  magick "$tmp/$w.png" -quality 80 -define webp:method=6 "$out/hero-$w.webp"
  avifenc -q 60 -s 2 --jobs "$(nproc)" "$tmp/$w.png" "$out/hero-$w.avif" >/dev/null
done

# Last-resort fallback for browsers with neither format. Only 1x - they are
# not running on high-DPI screens either.
magick "$tmp/240.png" -colors 256 -dither None \
  -define png:compression-level=9 "$out/hero-240.png"

# Favicons, squared off the same art.
magick "$tmp/base.png" -resize 32x32 -background none -gravity center \
  -extent 32x32 -colors 256 -dither None "$out/favicon.png"
# iOS ignores alpha on touch icons and fills it black, so flatten onto the
# page background instead of shipping transparency it will not honour.
magick "$tmp/base.png" -resize 148x148 -background none -gravity center \
  -extent 180x180 -background "#0b0f1c" -flatten -alpha off \
  -colors 256 -dither None -define png:compression-level=9 "$out/apple-touch-icon.png"

magick identify -format '%f  %wx%h  %b\n' "$out"/hero-* "$out"/favicon.png "$out"/apple-touch-icon.png
