# Streamyfin Cast receiver

The Cast receiver of [Streamyfin](https://github.com/streamyfin/streamyfin): the page a Google Cast device
loads when the app casts to it. It plays media from your Jellyfin server on the TV and reports playback to
the server.

This is a web receiver, as the [Google Cast documentation](https://developers.google.com/cast/docs/overview)
calls it. Nothing is installed on the TV: the device opens this page when a cast session starts.

## Two channels

| Channel | Address                                                 | What it serves                                                               |
| ------- | ------------------------------------------------------- | ---------------------------------------------------------------------------- |
| Stable  | `https://streamyfin.github.io/streamyfin-cast/release/` | The latest release: a signed tag, approved by an admin before it goes online |
| Beta    | `https://streamyfin.github.io/streamyfin-cast/beta/`    | The head of `main`, a few minutes after every merge, without a second review |

The Streamyfin app chooses the channel. Each address serves a `version.json` that says which build is online
and a `SHA256SUMS` that lists every file of the build. `RELEASING.md` explains how a build gets there and how
to check it.

## Where it comes from

This receiver is based on [jellyfin-chromecast](https://github.com/jellyfin/jellyfin-chromecast) v1.3.2, the
Cast receiver of the [Jellyfin project](https://jellyfin.org). It keeps the same license, GPL-2.0-or-later
(see `LICENSE.md`). What Streamyfin changed is in the git history, on top of the `upstream-v1.3.2` tag.
The versions of this repository start at `v0.1.0`.

## Build and test

You need Node 24 (see `.nvmrc`) and npm.

```sh
npm ci
npm run test -- --run
npm run build
npm run lint
```

`npm start` serves a development build on port 9000. `CONTRIBUTING.md` explains how to try a build on a real
device.

## Something not working?

Open an issue in the [Streamyfin repository](https://github.com/streamyfin/streamyfin/issues), and say which
device you cast to. To report a vulnerability, see `SECURITY.md`.
