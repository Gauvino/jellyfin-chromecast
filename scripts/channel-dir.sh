#!/usr/bin/env bash
# Makes the folder of a channel from a build: the built files, version.json and SHA256SUMS.
# Usage: channel-dir.sh <dist> <out> <channel> <version> <commit>
set -euo pipefail

die() { echo "$*" >&2; exit 1; }

[ "$#" -eq 5 ] || die "usage: channel-dir.sh <dist> <out> <channel> <version> <commit>"
dist=$1 out=$2 channel=$3 version=$4 commit=$5

case "$channel" in
    beta) [[ "$version" =~ ^[0-9a-f]{7}$ ]] || die "A beta version is the 7 first characters of its commit, not '$version'." ;;
    release) [[ "$version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] \
        || die "A release version is X.Y.Z, not '$version'." ;;
    *) die "The channel is beta or release, not '$channel'." ;;
esac
[[ "$commit" =~ ^[0-9a-f]{40}$ ]] || die "The commit is 40 hexadecimal characters, not '$commit'."
[ -f "$dist/index.html" ] || die "The build has no index.html: $dist"
for reserved in version.json SHA256SUMS; do
    [ ! -e "$dist/$reserved" ] || die "The build already has a file named $reserved."
done
if [ -e "$out" ] && [ -n "$(ls -A "$out")" ]; then
    die "The output folder is not empty: $out"
fi

mkdir -p "$out"
cp -R "$dist/." "$out/"
jq -n -S --arg channel "$channel" --arg commit "$commit" --arg version "$version" \
    '{channel: $channel, commit: $commit, version: $version}' > "$out/version.json"

# One line per file, sorted bytewise, so the same build always gives the same list.
(
    cd "$out"
    find . -type f ! -path ./SHA256SUMS | sed 's#^\./##' | LC_ALL=C sort | while IFS= read -r file; do
        printf '%s  %s\n' "$(sha256sum < "$file" | cut -d' ' -f1)" "$file"
    done
) > "$out/SHA256SUMS"
