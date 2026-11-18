# Releasing

What a Cast device loads comes from the `site` branch of this repository, and from nowhere else. The branch
has two folders, `release/` and `beta/`, served at the two public addresses. A deployment replaces one folder
by a commit, publishes the branch, then reads the public address back and compares every file.

## Beta

Every merge into `main` is tested, built and put online in `beta/` by the `Beta` workflow, without a second
review. Its version is the first seven characters of the commit.

## Stable

1. Create a signed tag `vX.Y.Z` on a commit of `main` and push it. Versions are `v0.X.Y` until the Streamyfin
   app ships this receiver to everyone, which will be `v1.0.0`.
2. The `Release` workflow checks the name of the tag, its signature and that the commit is in `main`. Then it
   tests, builds and makes `streamyfin-cast-X.Y.Z.zip`.
3. It waits for the approval of an admin, in the `release` environment.
4. Once approved, it creates the release with the zip, replaces `release/` by the content of the zip, and
   reads the public address back. A release cannot be changed afterwards: its zip and its tag are locked.

A TV takes the new version the next time the receiver starts.

### When to approve

The stable receiver follows the releases of the Streamyfin app. When the release job of the app is started,
the admin who approves it approves the waiting receiver release first, then the app: the receiver always
understands the versions of the app that are already out, and the reverse is not guaranteed. A fix of the
receiver alone goes out by the same approval, without waiting for a release of the app.

## Putting an earlier release back

Start the `Put a release back online` workflow from `main`, with the tag of the release to restore. It builds
nothing: it takes the zip of that release, waits for the same approval, and replaces `release/`. Running it
again asks for the approval again. A beta is corrected by a new merge. Do not re-run an old `Beta` run: it
would put an older build back online.

## Checking what is online

Each address serves `version.json` (channel, version, commit) and `SHA256SUMS` (every file of the folder).
Every day the `Watch` workflow compares the public addresses with the `site` branch, and `release/` with the
zip of the release it announces. It fails when they differ. GitHub turns a scheduled workflow off after 60
days without activity in the repository: turn `Watch` back on when that happens.

## The test address

The `Streamyfin` workflow deploys a build to the Pages address of a fork. It never deploys here.
`CONTRIBUTING.md` explains how to use it.
