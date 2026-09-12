#!/usr/bin/env bash
# Pack the module, taking the apk from a Soong out directory.
#
#   ./pack.sh [<path to PdInfoRoot.apk>]
#
# The apk is not kept in the module directory: it is a build artefact, and the
# zip is the only place the two belong together.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
apk=${1:-}

if [ -z "$apk" ]; then
	# Wherever the last local build put it.
	apk=$(find "${ANDROID_BUILD_TOP:-$HOME/witaqua/15.2}/out/soong/.intermediates" \
		-name PdInfoRoot.apk -print -quit 2>/dev/null || true)
fi

if [ ! -f "$apk" ]; then
	echo "pack.sh: no PdInfoRoot.apk (pass one, or build it first)" >&2
	exit 1
fi

version=$(sed -n 's/^version=//p' "$here/module.prop")
out=$here/out
zip=$out/qcom_pd_info-$version.zip

rm -rf "$out/stage" "$zip"
mkdir -p "$out/stage"
cp "$here"/module.prop "$here"/customize.sh "$here"/post-fs-data.sh \
   "$here"/uninstall.sh "$out/stage/"
cp "$apk" "$out/stage/PdInfoRoot.apk"

# The zip is the directory's contents at its root, which is what the installer
# expects - not the directory itself.
( cd "$out/stage" && zip -q -r "$zip" . )
rm -rf "$out/stage"

echo "$zip"
unzip -Z1 "$zip" | sed 's/^/  /'
