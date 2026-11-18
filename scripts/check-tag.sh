#!/usr/bin/env bash
# Accepts a tag only if it is a release: named vX.Y.Z, annotated, signed with a signature GitHub
# verified, on a commit of main. Prints the version (0.1.0 for v0.1.0).
# Reads GITHUB_REPOSITORY and GH_TOKEN, and runs in a clone that has origin/main.
# Usage: check-tag.sh <tag>
set -euo pipefail

die() { echo "$*" >&2; exit 1; }

[ "$#" -eq 1 ] || die "usage: check-tag.sh <tag>"
tag=$1
[[ "$tag" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] \
    || die "A release tag is vX.Y.Z, without a leading zero: '$tag' is not."
: "${GITHUB_REPOSITORY:?}" "${GH_TOKEN:?}"

ref=$(gh api "repos/$GITHUB_REPOSITORY/git/ref/tags/$tag")
[ "$(jq -r .object.type <<< "$ref")" = tag ] || die "$tag is a lightweight tag: a release tag is annotated and signed."
object=$(gh api "repos/$GITHUB_REPOSITORY/git/tags/$(jq -r .object.sha <<< "$ref")")
[ "$(jq -r .verification.verified <<< "$object")" = true ] \
    || die "GitHub does not verify the signature of $tag: $(jq -r .verification.reason <<< "$object")."
commit=$(jq -r .object.sha <<< "$object")
git merge-base --is-ancestor "$commit" origin/main 2> /dev/null || die "$tag is on $commit, which is not in main."

echo "${tag#v}"
