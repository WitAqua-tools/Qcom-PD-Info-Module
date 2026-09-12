#!/usr/bin/env bash
# Check the module for the mistakes that would install cleanly and then do
# nothing. Run by CI, and worth running before tagging.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
fail=0

note() { echo "::error::$*"; fail=1; }

prop=$here/module.prop
for field in id name version versionCode author description; do
	if ! grep -q "^$field=" "$prop"; then
		note "module.prop has no $field"
	fi
done

id=$(sed -n 's/^id=//p' "$prop")
version=$(sed -n 's/^version=//p' "$prop")
code=$(sed -n 's/^versionCode=//p' "$prop")

# ksud reads the id as a directory name, and the manager sorts on versionCode.
case $id in
	*[^a-zA-Z0-9_]*) note "id '$id' has characters outside [a-zA-Z0-9_]" ;;
esac
case $code in
	''|*[^0-9]*) note "versionCode '$code' is not a number" ;;
esac
case $version in
	v*) ;;
	*) note "version '$version' does not start with v" ;;
esac

# The changelog is what a release body comes from, so a version with no entry
# ships a release that says nothing.
if ! grep -q "^## $version\$" "$here/changelog.md"; then
	note "changelog.md has no '## $version' section"
fi

# update.json is how the manager offers an update, and it is fetched from the
# branch rather than from the release - so it is the one file that can be
# wrong without anything failing to build. A stale version here means the
# manager either never offers the update or offers one and installs the old
# zip, which is worse.
u=$here/update.json
if [ ! -f "$u" ]; then
	note "no update.json, so the manager has nothing to check for updates"
else
	json_string() { sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$u"; }
	json_number() { sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p" "$u"; }

	[ "$(json_string version)" = "$version" ] ||
		note "update.json says version $(json_string version), module.prop says $version"
	[ "$(json_number versionCode)" = "$code" ] ||
		note "update.json says versionCode $(json_number versionCode), module.prop says $code"

	# releases/latest/download only resolves for a name that does not change,
	# and pack.sh names the zip after the id. If these drift the manager
	# downloads a 404.
	zip_name=$(basename "$(json_string zipUrl)")
	[ "$zip_name" = "$id.zip" ] ||
		note "update.json points at $zip_name; pack.sh builds $id.zip"

	# module.prop has to name update.json, or none of the above is ever read.
	declared=$(sed -n 's/^updateJson=//p' "$prop")
	case $declared in
		*/update.json) ;;
		"") note "module.prop has no updateJson, so updates are never offered" ;;
		*) note "updateJson does not end in update.json: $declared" ;;
	esac
fi

# These run in ksud's shell as root before the framework is up. sh -n catches
# only syntax, which is still the failure that would hurt most.
for script in "$here"/customize.sh "$here"/post-fs-data.sh "$here"/uninstall.sh; do
	if ! sh -n "$script"; then
		note "$(basename "$script") does not parse"
	fi
done

[ "$fail" -eq 0 ] && echo "module.prop and scripts look right: $id $version ($code)"
exit "$fail"
