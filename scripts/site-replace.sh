#!/usr/bin/env bash
# Replaces the folder of one channel in a working copy of the site branch, and commits it.
# The other channel must come out untouched. Pushes nothing.
# Usage: site-replace.sh <site> <channel> <dir>
set -euo pipefail

die() { echo "$*" >&2; exit 1; }

[ "$#" -eq 3 ] || die "usage: site-replace.sh <site> <channel> <dir>"
site=$1 channel=$2 dir=$3

case "$channel" in
    beta) other=release ;;
    release) other=beta ;;
    *) die "The channel is beta or release, not '$channel'." ;;
esac
[ -f "$dir/SHA256SUMS" ] && [ -f "$dir/version.json" ] && [ -f "$dir/index.html" ] \
    || die "Not the folder of a channel, with its page, version.json and SHA256SUMS: $dir"
[ "$(jq -r .channel "$dir/version.json")" = "$channel" ] || die "This folder is not for the $channel channel: $dir"
version=$(jq -r .version "$dir/version.json")
case "$channel" in
    beta) [[ "$version" =~ ^[0-9a-f]{7}$ ]] || die "Not a beta version: '$version'." ;;
    release) [[ "$version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || die "Not a release version: '$version'." ;;
esac

# The folder must be exactly what its list says: every file matches, and no file is missing or extra.
( cd "$dir" && sha256sum -c --quiet SHA256SUMS ) >&2 || die "A file no longer matches SHA256SUMS in $dir"
listed=$(cut -c67- "$dir/SHA256SUMS" | LC_ALL=C sort)
present=$(cd "$dir" && find . -type f ! -path ./SHA256SUMS | sed 's#^\./##' | LC_ALL=C sort)
[ "$listed" = "$present" ] || die "The files of $dir are not the ones its SHA256SUMS lists."
# Only files and folders: Pages would serve whatever a link points to.
odd=$(cd "$dir" && find . ! -type f ! -type d)
[ -z "$odd" ] || die "The folder holds something that is neither a file nor a folder: $odd"

other_before=$(git -C "$site" rev-parse -q --verify "HEAD:$other" || true)

rm -rf "${site:?}/$channel"
cp -R "$dir" "$site/$channel"
# -f: a .gitignore that came with the build must not leave a listed file out of the commit.
git -C "$site" add -A -f -- "$channel"
if git -C "$site" diff --cached --quiet; then
    echo unchanged
    exit 0
fi
git -C "$site" -c user.name='github-actions[bot]' \
    -c user.email='41898282+github-actions[bot]@users.noreply.github.com' \
    commit -q -m "$channel: $version"

# Read the commit back before anyone pushes it.
[ "$(git -C "$site" rev-parse -q --verify "HEAD:$other" || true)" = "$other_before" ] \
    || die "The commit changed the $other folder."
outside=$(git -C "$site" diff-tree --root --no-commit-id --name-only -r HEAD | grep -v "^$channel/" || true)
[ -z "$outside" ] || die "The commit changed files outside $channel/: $outside"
root=$(git -C "$site" ls-tree --name-only HEAD | grep -vx -e beta -e release || true)
[ -z "$root" ] || die "The site branch holds something else than beta and release: $root"
