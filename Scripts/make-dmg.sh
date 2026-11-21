#!/bin/bash
# Builds Spindle's installer disk image: a .dmg whose window shows the app, an arrow and Applications.
#
#   Scripts/make-dmg.sh path/to/Spindle.app [output.dmg]
#
# The output defaults to .build/Spindle-<version>.dmg. Needs Xcode's command line tools (swiftc,
# iconutil, tiffutil) and python3. The first run installs dmgbuild into .build/dmg/venv.
set -euo pipefail

here=$(cd "$(dirname "$0")/.." && pwd)
source_app=${1:?usage: Scripts/make-dmg.sh path/to/Spindle.app [output.dmg]}
[[ -d $source_app ]] || { echo "No such app: $source_app" >&2; exit 1; }
app=$(cd "$(dirname "$source_app")" && pwd)/$(basename "$source_app")

work="$here/.build/dmg"
version=$(defaults read "$app/Contents/Info" CFBundleShortVersionString)
output=${2:-"$here/.build/Spindle-$version.dmg"}
mkdir -p "$work" "$(dirname "$output")"

# dmgbuild writes the window layout without driving Finder. Pinned, in a private virtualenv.
if [[ ! -x $work/venv/bin/dmgbuild ]]; then
    python3 -m venv "$work/venv"
    "$work/venv/bin/pip" install --quiet "dmgbuild==2.0.0"
fi

# The background picture, at 1x and 2x, in one TIFF.
swiftc -O "$here/Scripts/dmg/background.swift" -o "$work/background"
"$work/background" "$work" "$version"
tiffutil -cat "$work/background.tiff" "$work/background@2x.tiff" -out "$work/background-combined.tiff" >/dev/null 2>&1

# The disk's own icon: the app icon.
icons="$here/Spindle/Assets.xcassets/AppIcon.appiconset"
rm -rf "$work/icon.iconset"
mkdir "$work/icon.iconset"
for entry in 16:16x16 32:16x16@2x 32:32x32 64:32x32@2x 128:128x128 256:128x128@2x \
             256:256x256 512:256x256@2x 512:512x512 1024:512x512@2x; do
    cp "$icons/icon_${entry%%:*}.png" "$work/icon.iconset/icon_${entry#*:}.png"
done
iconutil -c icns "$work/icon.iconset" -o "$work/volume.icns"

rm -f "$output"
"$work/venv/bin/dmgbuild" -s "$here/Scripts/dmg/settings.py" -D app="$app" -D art="$work" Spindle "$output"

echo
echo "Built $output"
shasum -a 256 "$output"
