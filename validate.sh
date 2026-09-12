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

# These run in ksud's shell as root before the framework is up. sh -n catches
# only syntax, which is still the failure that would hurt most.
for script in "$here"/customize.sh "$here"/post-fs-data.sh "$here"/uninstall.sh; do
	if ! sh -n "$script"; then
		note "$(basename "$script") does not parse"
	fi
done

[ "$fail" -eq 0 ] && echo "module.prop and scripts look right: $id $version ($code)"
exit "$fail"
