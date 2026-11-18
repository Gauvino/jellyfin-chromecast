#!/usr/bin/env bash
# Tests of the release scripts. Each test_* function runs in its own subshell, with
# T (a new temporary folder, removed afterwards) and S (this folder).
# They and their helpers are called by name, from the runner at the bottom.
# shellcheck disable=SC2317,SC2329
set -euo pipefail

S=$(cd "$(dirname "$0")" && pwd)

expect_eq()   { [ "$1" = "$2" ] || { echo "  expected: $2" >&2; echo "  got:      $1" >&2; return 1; }; }
expect_fail() { if "$@" >/dev/null 2>&1; then echo "  should have failed: $*" >&2; return 1; fi; }
mkbuild()     { mkdir -p "$1/img" && echo '<html>' > "$1/index.html" && echo 'js' > "$1/index-abc.js" \
                && echo '<svg/>' > "$1/img/logo.svg"; }   # a build of three files
C40=0123456789abcdef0123456789abcdef01234567

# channel-dir.sh

test_channel_dir_lists_every_file() {
    mkbuild "$T/dist"
    "$S/channel-dir.sh" "$T/dist" "$T/out" beta 39be341 "$C40"
    ( cd "$T/out" && sha256sum -c --quiet SHA256SUMS )
    expect_eq "$(wc -l < "$T/out/SHA256SUMS" | tr -d ' ')" 4          # the 3 files of the build + version.json
    expect_eq "$(cut -c67- "$T/out/SHA256SUMS" | tr '\n' ' ')" "img/logo.svg index-abc.js index.html version.json "
    expect_eq "$(jq -c -S . "$T/out/version.json")" "{\"channel\":\"beta\",\"commit\":\"$C40\",\"version\":\"39be341\"}"
}
test_channel_dir_takes_a_release_version() {
    mkbuild "$T/dist"; "$S/channel-dir.sh" "$T/dist" "$T/out" release 0.1.0 "$C40"
    expect_eq "$(jq -r .version "$T/out/version.json")" 0.1.0
}
test_channel_dir_refuses_a_build_without_a_page() {
    mkdir -p "$T/dist"; echo js > "$T/dist/index-abc.js"
    expect_fail "$S/channel-dir.sh" "$T/dist" "$T/out" beta 39be341 "$C40"
    expect_eq "$(find "$T/out" -mindepth 1 2>/dev/null | wc -l | tr -d ' ')" 0
}
test_channel_dir_refuses_bad_arguments() {
    mkbuild "$T/dist"
    expect_fail "$S/channel-dir.sh" "$T/dist" "$T/o1" nightly 39be341 "$C40"      # unknown channel
    expect_fail "$S/channel-dir.sh" "$T/dist" "$T/o2" release 39be341 "$C40"      # a commit is not a stable version
    expect_fail "$S/channel-dir.sh" "$T/dist" "$T/o3" beta 0.1.0 "$C40"           # and the other way round
    expect_fail "$S/channel-dir.sh" "$T/dist" "$T/o4" release 01.2.3 "$C40"       # leading zero
    expect_fail "$S/channel-dir.sh" "$T/dist" "$T/o5" beta 39be341 39be341        # short commit
    mkdir "$T/o6" && touch "$T/o6/old"
    expect_fail "$S/channel-dir.sh" "$T/dist" "$T/o6" beta 39be341 "$C40"         # output not empty
    touch "$T/dist/SHA256SUMS"
    expect_fail "$S/channel-dir.sh" "$T/dist" "$T/o7" beta 39be341 "$C40"         # the build already has this name
}

# site-replace.sh

mksite()    { git init -q -b site "$T/site"; }
mkchannel() { local d; d=$(mktemp -d "$T/build.XXXXXX"); mkbuild "$d" && "$S/channel-dir.sh" "$d" "$3" "$1" "$2" "$C40"; }

test_site_replace_creates_the_first_channel() {
    mksite; mkchannel beta 39be341 "$T/b1"
    "$S/site-replace.sh" "$T/site" beta "$T/b1"
    expect_eq "$(git -C "$T/site" log -1 --format=%s)" "beta: 39be341"
    expect_eq "$(git -C "$T/site" ls-tree --name-only HEAD | tr '\n' ' ')" "beta "
    expect_eq "$(git -C "$T/site" log -1 --format=%an)" "github-actions[bot]"
}
test_site_replace_leaves_the_other_channel() {
    mksite; mkchannel release 0.1.0 "$T/r1"; mkchannel beta 39be341 "$T/b1"
    "$S/site-replace.sh" "$T/site" release "$T/r1"
    before=$(git -C "$T/site" rev-parse HEAD:release)
    "$S/site-replace.sh" "$T/site" beta "$T/b1"
    expect_eq "$(git -C "$T/site" rev-parse HEAD:release)" "$before"
    expect_eq "$(git -C "$T/site" diff --name-only HEAD~1 HEAD | grep -vc '^beta/')" 0
}
test_site_replace_drops_the_files_of_the_previous_build() {
    mksite; mkchannel beta 39be341 "$T/b1"; "$S/site-replace.sh" "$T/site" beta "$T/b1"
    mkdir -p "$T/d2" && echo '<html>' > "$T/d2/index.html" && echo js2 > "$T/d2/index-def.js"
    "$S/channel-dir.sh" "$T/d2" "$T/b2" beta 4ac597d "$C40"
    "$S/site-replace.sh" "$T/site" beta "$T/b2"
    expect_eq "$(git -C "$T/site" ls-tree -r --name-only HEAD | tr '\n' ' ')" \
              "beta/SHA256SUMS beta/index-def.js beta/index.html beta/version.json "
}
test_site_replace_is_a_no_op_when_nothing_changes() {
    mksite; mkchannel beta 39be341 "$T/b1"; "$S/site-replace.sh" "$T/site" beta "$T/b1"
    head=$(git -C "$T/site" rev-parse HEAD)
    out=$("$S/site-replace.sh" "$T/site" beta "$T/b1")
    expect_eq "$out" unchanged
    expect_eq "$(git -C "$T/site" rev-parse HEAD)" "$head"
}
test_site_replace_refuses_the_wrong_channel() {
    mksite; mkchannel beta 39be341 "$T/b1"
    expect_fail "$S/site-replace.sh" "$T/site" release "$T/b1"       # a beta zip does not go in release/
    expect_fail "$S/site-replace.sh" "$T/site" nightly "$T/b1"
    expect_eq "$(git -C "$T/site" rev-list --all --count)" 0
}
test_site_replace_refuses_a_damaged_dir() {
    mksite; mkchannel beta 39be341 "$T/b1"; echo tampered >> "$T/b1/index-abc.js"
    expect_fail "$S/site-replace.sh" "$T/site" beta "$T/b1"          # no longer matches SHA256SUMS
    mkchannel beta 39be341 "$T/b2"; echo extra > "$T/b2/extra.js"
    expect_fail "$S/site-replace.sh" "$T/site" beta "$T/b2"          # a file the list does not know
    expect_eq "$(git -C "$T/site" rev-list --all --count)" 0
}
test_site_replace_reads_its_commit_back() {
    mksite; mkchannel release 0.1.0 "$T/r1"; mkchannel beta 39be341 "$T/b1"
    "$S/site-replace.sh" "$T/site" release "$T/r1"
    echo staged >> "$T/site/release/index.html" && git -C "$T/site" add release
    expect_fail "$S/site-replace.sh" "$T/site" beta "$T/b1"          # the commit would take release/ along
    rm -rf "$T/site"; mksite; echo x > "$T/site/README"
    git -C "$T/site" add README && git -C "$T/site" -c user.name=t -c user.email=t@t.invalid commit -qm README
    expect_fail "$S/site-replace.sh" "$T/site" beta "$T/b1"          # the root holds more than the two channels
}
# relist <dir>: writes the SHA256SUMS of a folder again, after a test changed it.
relist() {
    local list
    list=$(cd "$1" && find . -type f ! -path ./SHA256SUMS | sed 's#^\./##' | LC_ALL=C sort | while IFS= read -r f; do
        printf '%s  %s\n' "$(sha256sum < "$f" | cut -d' ' -f1)" "$f"
    done)
    printf '%s\n' "$list" > "$1/SHA256SUMS"
}
test_site_replace_refuses_an_incomplete_folder() {
    mksite; mkdir "$T/e"
    expect_fail "$S/site-replace.sh" "$T/site" beta "$T/e"           # empty
    mkchannel beta 39be341 "$T/b1"; rm "$T/b1/img/logo.svg"
    expect_fail "$S/site-replace.sh" "$T/site" beta "$T/b1"          # a listed file is missing
    mkchannel beta 39be341 "$T/b2"; rm "$T/b2/index.html"; relist "$T/b2"
    expect_fail "$S/site-replace.sh" "$T/site" beta "$T/b2"          # no page, though the list matches
    expect_eq "$(git -C "$T/site" rev-list --all --count)" 0
}
test_site_replace_refuses_a_version_that_does_not_fit_the_channel() {
    mksite; mkchannel beta 39be341 "$T/b1"
    jq '.version = "0.1.0"' "$T/b1/version.json" > "$T/v" && mv "$T/v" "$T/b1/version.json"; relist "$T/b1"
    expect_fail "$S/site-replace.sh" "$T/site" beta "$T/b1"
    mkchannel release 0.1.0 "$T/r1"
    jq 'del(.version)' "$T/r1/version.json" > "$T/v" && mv "$T/v" "$T/r1/version.json"; relist "$T/r1"
    expect_fail "$S/site-replace.sh" "$T/site" release "$T/r1"
    expect_eq "$(git -C "$T/site" rev-list --all --count)" 0
}
test_site_replace_refuses_a_link() {
    mksite; mkchannel beta 39be341 "$T/b1"; ln -s /etc/hosts "$T/b1/hosts"
    expect_fail "$S/site-replace.sh" "$T/site" beta "$T/b1"          # Pages would serve what it points to
    expect_eq "$(git -C "$T/site" rev-list --all --count)" 0
}
test_site_replace_keeps_the_files_a_gitignore_would_drop() {
    mksite; d=$(mktemp -d "$T/build.XXXXXX"); mkbuild "$d"; echo '*.map' > "$d/.gitignore"; echo map > "$d/keep.map"
    "$S/channel-dir.sh" "$d" "$T/b1" beta 39be341 "$C40"
    "$S/site-replace.sh" "$T/site" beta "$T/b1"
    expect_eq "$(git -C "$T/site" ls-tree -r --name-only HEAD | tr '\n' ' ')" \
              "beta/.gitignore beta/SHA256SUMS beta/img/logo.svg beta/index-abc.js beta/index.html beta/keep.map beta/version.json "
}

# verify-served.sh

test_verify_served_passes_on_identical_files() {
    mkchannel beta 39be341 "$T/site/beta"; cp -R "$T/site" "$T/served"
    mkdir "$T/site/.git" && echo x > "$T/site/.git/HEAD"              # .git is not compared
    "$S/verify-served.sh" "file://$T/served/" "$T/site" 1 0           # the trailing slash is fine
}
test_verify_served_names_a_file_that_differs() {
    mkchannel beta 39be341 "$T/site/beta"; cp -R "$T/site" "$T/served"; echo old > "$T/served/beta/index-abc.js"
    expect_fail "$S/verify-served.sh" "file://$T/served" "$T/site" 1 0
    expect_eq "$("$S/verify-served.sh" "file://$T/served" "$T/site" 1 0 2>&1 >/dev/null | grep -c '^differs: beta/index-abc.js$')" 1
}
test_verify_served_names_a_missing_file() {
    mkchannel beta 39be341 "$T/site/beta"; cp -R "$T/site" "$T/served"; rm "$T/served/beta/img/logo.svg"
    expect_eq "$("$S/verify-served.sh" "file://$T/served" "$T/site" 1 0 2>&1 >/dev/null | grep -c '^missing: beta/img/logo.svg$')" 1
}
test_verify_served_retries_until_the_files_arrive() {
    mkchannel beta 39be341 "$T/site/beta"; mkdir "$T/served"
    ( sleep 2; cp -R "$T/site/beta" "$T/served/beta" ) &
    "$S/verify-served.sh" "file://$T/served" "$T/site" 5 1; wait
}
test_verify_served_refuses_a_strange_file_name() {
    mkchannel beta 39be341 "$T/site/beta"; touch "$T/site/beta/a+b.js"; cp -R "$T/site" "$T/served"
    expect_fail "$S/verify-served.sh" "file://$T/served" "$T/site" 1 0    # outside [A-Za-z0-9._/-]
}

# check-tag.sh

# A repository with commit A on origin/main and commit B on a branch of its own, and a fake gh
# that answers for the tag from ref.json and tag.json.
mkrepo() {
    git init -q -b main "$T/repo"
    git -C "$T/repo" -c user.name=t -c user.email=t@t.invalid commit -q --allow-empty -m A
    A=$(git -C "$T/repo" rev-parse HEAD)
    git -C "$T/repo" update-ref refs/remotes/origin/main "$A"
    git -C "$T/repo" switch -q -c aside
    git -C "$T/repo" -c user.name=t -c user.email=t@t.invalid commit -q --allow-empty -m B
    B=$(git -C "$T/repo" rev-parse HEAD)
    mkdir "$T/bin"
    cat > "$T/bin/gh" <<FAKE
#!/usr/bin/env bash
case "\$*" in
    "api repos/o/r/git/ref/tags/"*) cat "$T/ref.json" ;;
    "api repos/o/r/git/tags/"*) cat "$T/tag.json" ;;
    *) echo "unexpected: gh \$*" >&2; exit 1 ;;
esac
FAKE
    chmod +x "$T/bin/gh"
    PATH="$T/bin:$PATH"
}
# mktag <type> <verified> <commit>: a tag object of this type, signed or not, on this commit.
mktag() {
    local object=$C40
    [ "$1" = tag ] || object=$3
    printf '{"object":{"type":"%s","sha":"%s"}}\n' "$1" "$object" > "$T/ref.json"
    printf '{"object":{"sha":"%s"},"verification":{"verified":%s,"reason":"%s"}}\n' \
        "$3" "$2" "$( [ "$2" = true ] && echo valid || echo unsigned )" > "$T/tag.json"
}

test_check_tag_accepts_a_signed_tag_on_main() {
    mkrepo; mktag tag true "$A"
    version=$(cd "$T/repo" && GITHUB_REPOSITORY=o/r GH_TOKEN=x "$S/check-tag.sh" v0.1.0)   # an assignment, so set -e sees a failure
    expect_eq "$version" 0.1.0
}
test_check_tag_refuses_a_name_that_is_not_a_version() {
    mkrepo; mktag tag true "$A"
    for t in v1.3.2-streamyfin.1 upstream-v1.3.2 v01.2.3 v1.2 1.2.3 v1.2.3.4; do
        ( cd "$T/repo" && GITHUB_REPOSITORY=o/r GH_TOKEN=x expect_fail "$S/check-tag.sh" "$t" )
    done
}
test_check_tag_refuses_a_lightweight_tag() { mkrepo; mktag commit true  "$A"; ( cd "$T/repo" && GITHUB_REPOSITORY=o/r GH_TOKEN=x expect_fail "$S/check-tag.sh" v0.1.0 ); }
test_check_tag_refuses_an_unverified_tag() { mkrepo; mktag tag    false "$A"; ( cd "$T/repo" && GITHUB_REPOSITORY=o/r GH_TOKEN=x expect_fail "$S/check-tag.sh" v0.1.0 ); }
test_check_tag_refuses_a_commit_outside_main() { mkrepo; mktag tag true "$B"; ( cd "$T/repo" && GITHUB_REPOSITORY=o/r GH_TOKEN=x expect_fail "$S/check-tag.sh" v0.1.0 ); }

# Runner

# The tests make their own repositories: the git settings of the machine (signing, hooks) stay out.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

tests=$(declare -F | awk '$3 ~ /^test_/ { print $3 }')
[ -n "$tests" ] || { echo "no test found" >&2; exit 1; }

failed=0
for name in $tests; do
    T=$(mktemp -d)
    # Not inside an `if`: there, bash would ignore the `set -e` of the subshell.
    set +e
    ( set -e; "$name" ) > "$T.log" 2>&1
    status=$?
    set -e
    if [ "$status" -eq 0 ]; then
        echo "ok $name"
    else
        echo "FAIL $name"
        sed 's/^/    /' "$T.log"
        failed=1
    fi
    rm -rf "$T" "$T.log"
done
exit "$failed"
