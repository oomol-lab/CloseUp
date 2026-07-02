#!/bin/bash
# Regenerate Assets.xcassets/AppIcon.appiconset from the 1024 master.
# Deterministic and dependency-free (sips only), so the icon set is reproducible
# from source rather than hand-exported.
#
#   scripts/make-appicon.sh [master.png]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MASTER="${1:-$ROOT/scripts/appicon-master.png}"
SET="$ROOT/Sources/CloseUp/Assets.xcassets/AppIcon.appiconset"

# Regenerate the master from the designed artwork if it is missing. The app icon
# is a designed asset (scripts/icon-tools/appicon-art.png) re-cut to the macOS
# grid by make-master-from-art.sh, not a code render.
if [[ ! -f "$MASTER" ]]; then
  echo "Master missing; rebuilding it from the designed artwork…"
  "$ROOT/scripts/icon-tools/make-master-from-art.sh" \
    "$ROOT/scripts/icon-tools/appicon-art.png" "$MASTER"
fi

mkdir -p "$SET"
# macOS app-icon ladder: pt size × scale → pixel size.
# pairs: "filename:pixels"
pairs=(
  "icon_16x16:16" "icon_16x16@2x:32"
  "icon_32x32:32" "icon_32x32@2x:64"
  "icon_128x128:128" "icon_128x128@2x:256"
  "icon_256x256:256" "icon_256x256@2x:512"
  "icon_512x512:512" "icon_512x512@2x:1024"
)
for pair in "${pairs[@]}"; do
  name="${pair%%:*}"; px="${pair##*:}"
  sips -s format png -z "$px" "$px" "$MASTER" --out "$SET/$name.png" >/dev/null
done

cat > "$SET/Contents.json" <<'JSON'
{
  "images" : [
    { "idiom" : "mac", "scale" : "1x", "size" : "16x16", "filename" : "icon_16x16.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "16x16", "filename" : "icon_16x16@2x.png" },
    { "idiom" : "mac", "scale" : "1x", "size" : "32x32", "filename" : "icon_32x32.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "32x32", "filename" : "icon_32x32@2x.png" },
    { "idiom" : "mac", "scale" : "1x", "size" : "128x128", "filename" : "icon_128x128.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "128x128", "filename" : "icon_128x128@2x.png" },
    { "idiom" : "mac", "scale" : "1x", "size" : "256x256", "filename" : "icon_256x256.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "256x256", "filename" : "icon_256x256@2x.png" },
    { "idiom" : "mac", "scale" : "1x", "size" : "512x512", "filename" : "icon_512x512.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "512x512", "filename" : "icon_512x512@2x.png" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON

echo "AppIcon.appiconset regenerated from $MASTER"
