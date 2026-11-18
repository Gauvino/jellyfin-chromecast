# Security

The receiver runs on the TV with the access token of the Jellyfin user who casts. A flaw in it, or in the way
it is put online, can expose that user's server.

## Reporting a vulnerability

Do not open a public issue. Use "Report a vulnerability" in the Security tab of this repository: the report
stays private until a fix is out. Say which channel (stable or beta), which version (`version.json` at the
address of the channel) and which device.

## What is covered

- The receiver served at `https://streamyfin.github.io/streamyfin-cast/release/` and
  `https://streamyfin.github.io/streamyfin-cast/beta/`.
- The workflows and scripts of this repository that put it online.

A problem in the Streamyfin app goes to the [Streamyfin repository](https://github.com/streamyfin/streamyfin).
A problem in a Jellyfin server goes to the Jellyfin project.

## Supported versions

The latest release and the current beta. Older releases are not fixed: the fix is a new release.
