#!/usr/bin/env bash
# Checks that every file of a folder is served, byte for byte, under a public address.
# Tries again while the address still serves something else, then names each file that is wrong.
# Usage: verify-served.sh <base-url> <dir> [<tries> [<pause>]]
set -euo pipefail

die() { echo "$*" >&2; exit 1; }

[ "$#" -ge 2 ] && [ "$#" -le 4 ] || die "usage: verify-served.sh <base-url> <dir> [<tries> [<pause>]]"
base=${1%/} dir=$2 tries=${3:-20} pause=${4:-15}
[ -d "$dir" ] || die "No such folder: $dir"

files=$(cd "$dir" && find . -path ./.git -prune -o -type f -print | sed 's#^\./##' | LC_ALL=C sort)
[ -n "$files" ] || die "Nothing to compare in $dir"
# A plain name goes into a URL as it is: anything else is refused rather than escaped.
strange=$(printf '%s\n' "$files" | grep -v '^[A-Za-z0-9._/-]*$' || true)
[ -z "$strange" ] || die "A file name is outside [A-Za-z0-9._/-]: $strange"

served=$(mktemp)
trap 'rm -f "$served"' EXIT

attempt=1
while :; do
    problems=""
    for file in $files; do
        if ! curl -fsS --max-time 30 -o "$served" "$base/$file" 2>/dev/null; then
            problems="${problems}missing: $file"$'\n'
        elif [ "$(sha256sum < "$served" | cut -d' ' -f1)" != "$(sha256sum < "$dir/$file" | cut -d' ' -f1)" ]; then
            problems="${problems}differs: $file"$'\n'
        fi
    done
    [ -n "$problems" ] || exit 0
    [ "$attempt" -lt "$tries" ] || break
    echo "Attempt $attempt of $tries: $(printf '%s' "$problems" | wc -l | tr -d ' ') files are not served yet." >&2
    attempt=$((attempt + 1))
    sleep "$pause"
done
printf '%s' "$problems" >&2
exit 1
