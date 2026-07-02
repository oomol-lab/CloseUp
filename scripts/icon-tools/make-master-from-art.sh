#!/bin/bash
# Turn a designed 1:1 app-icon artwork (a rounded "squircle" tile sitting on a
# plain light background) into a clean macOS app-icon master: the tile re-cut to
# the macOS grid, centered on a TRANSPARENT 1024 canvas with a freshly drawn soft
# drop shadow. This discards the artwork's own baked outer background/shadow so
# the Dock renders a proper squircle (no opaque corners). ImageMagick only.
#
#   scripts/icon-tools/make-master-from-art.sh <art.png> <out-master.png>
#
# Tunables (env): CANVAS (1024) TILE (836) RAD (187) TRIMFUZZ (18)
set -euo pipefail

SRC="${1:?usage: make-master-from-art.sh <art.png> <out.png>}"
OUT="${2:?usage: make-master-from-art.sh <art.png> <out.png>}"
CANVAS="${CANVAS:-1024}"   # final master side
TILE="${TILE:-836}"        # tile side (gutter = (CANVAS-TILE)/2 ≈ 9% inset)
RAD="${RAD:-187}"          # corner radius ≈ TILE*0.2237 (matches legacy master)
TRIMFUZZ="${TRIMFUZZ:-18}" # %% fuzz to trim the light background + soft halo

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# 1) Normalize the artwork to a CANVAS-square working image.
magick "$SRC" -resize "${CANVAS}x${CANVAS}" "$tmp/norm.png"

# 2) Trim the light gutter (and most of the soft shadow halo) down to the solid
#    tile. A white border gives -trim a uniform reference even if the tile bleeds
#    to an edge.
magick "$tmp/norm.png" -bordercolor white -border 4 -fuzz "${TRIMFUZZ}%" -trim +repage "$tmp/tile.png"

# 3) Pad the trimmed tile to a centered transparent square, then size to TILE.
read -r w h < <(magick identify -format "%w %h\n" "$tmp/tile.png") || true
S=$(( w > h ? w : h ))
magick "$tmp/tile.png" -background none -gravity center -extent "${S}x${S}" \
       -resize "${TILE}x${TILE}!" "$tmp/sq.png"

# 4) Rounded-rect mask → transparent corners (clean macOS squircle-ish tile).
#    Mask = opaque rounded-rect on a transparent canvas; DstIn keeps the tile only
#    where the mask is opaque (do NOT use -alpha off here — it wipes the alpha and
#    yields a fully transparent result).
magick -size "${TILE}x${TILE}" xc:none -fill white \
       -draw "roundrectangle 0,0,$((TILE-1)),$((TILE-1)),${RAD},${RAD}" "$tmp/mask.png"
magick "$tmp/sq.png" -alpha set "$tmp/mask.png" -compose DstIn -composite "$tmp/rounded.png"

# 5) Draw a fresh soft drop shadow and center the tile on the transparent canvas.
magick "$tmp/rounded.png" \
       \( +clone -background black -shadow 40x18+0+16 \) +swap \
       -background none -layers merge +repage \
       -gravity center -background none -extent "${CANVAS}x${CANVAS}" \
       "$OUT"

echo "wrote $OUT (${CANVAS}x${CANVAS}, transparent gutter) from $SRC"
