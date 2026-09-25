# ocelot

Improvements for [OpenCode](https://github.com/anomalyco/opencode) v2, kept as a small
set of patches on top of official OpenCode releases.

Each ocelot release is an upstream OpenCode release plus the patches in
[`patches/`](patches/series). Everything else (config, plugins, providers, the TUI
and the web UI) works the same as in OpenCode.

## Install

Linux (x64) and macOS (Apple Silicon):

```bash
curl -fsSL https://github.com/rumisle/ocelot/releases/latest/download/install | bash
```

This installs `ocelot` to `~/.ocelot/bin` and adds that to your shell's `PATH`.
For a specific release, append `-s -- --version 2.0.16-1` to `bash`. The archives are also on the
[Releases](https://github.com/rumisle/ocelot/releases) page.

Then use `ocelot` wherever you would use `opencode`:

```bash
ocelot                  # TUI
ocelot service status   # background server, also serves the web UI
ocelot pair             # sign-in link for the web UI
```

## Alongside OpenCode

Ocelot reads the same config (`~/.config/opencode`), plugins and provider logins as
OpenCode, so there is nothing to set up again.

It runs its own background server with its own port and session database
(`~/.local/share/opencode/opencode-ocelot.db`), so it can be installed next to stock
OpenCode without the two interfering. Sessions from one don't show up in the other.

## Updating

```bash
ocelot upgrade
```

Updates come from this repo's releases, never from upstream OpenCode. As in OpenCode,
the `autoupdate` config option decides what happens when a new release is out:
`"notify"` (the default) tells you, `true` installs it, `false` does nothing.

## Versions

Versions are `<upstream version>-<revision>`: `2.0.16-1` is the first ocelot release on
OpenCode 2.0.16. The revision goes back to 1 when ocelot moves to a new upstream
release, and goes up for releases that only change our patches.

## Development

Requirements: git and curl. The scripts download the bun version upstream uses.

```bash
scripts/apply.sh                           # build/src = upstream release + our patches
scripts/build.sh                           # build for this machine
scripts/build.sh linux-x64 darwin-arm64    # both release targets, cross-compiled
scripts/install.sh                         # install to ~/.ocelot/bin/ocelot
```

To check UI changes without real models or your own sessions, `scripts/dev-server.sh start`
runs the built binary on throwaway data against a fake Anthropic API (`test/fake-anthropic.ts`),
with the web UI at http://127.0.0.1:4852 (username `opencode`, password `test`).

### Changing patches

`scripts/apply.sh` checks out the upstream release in `build/src` and applies every
patch as its own commit on the `ocelot` branch. Work there with normal git (new commits,
`rebase -i`, `commit --fixup`), then write the result back:

```bash
scripts/export.sh   # updates patches/ and patches/series from the commits
```

Each commit becomes one patch file. It needs an `Ocelot-Patch:` trailer naming that file:

```bash
git commit -m "web/markdown: render \$…\$ math" --trailer "Ocelot-Patch: web/math-delimiters"
```

- One change per patch, so each can be updated or dropped on its own.
- Commit titles start with the area they touch (`web/timeline: …`, `cli/updater: …`).
- If the change is also proposed upstream, link the PR in the message. Once upstream
  merges it, the patch is dropped.

### Moving to a new upstream release

```bash
scripts/bump.sh           # latest upstream release, or: scripts/bump.sh v2.0.17
```

This updates `upstream.txt`, resets `revision.txt` to 1 and re-applies every patch with
3-way merges. If a patch conflicts, it stops in `build/src`: resolve the conflict,
`git am --continue` until all patches are in, then run `scripts/export.sh`.

### Releasing

Push a change to `upstream.txt` or `revision.txt` on `main`. CI builds `linux-x64` and
`darwin-arm64` and publishes a GitHub release for the new version.

| Workflow | Runs | Does |
|---|---|---|
| `check` | every push and PR | all patches apply, and `patches/` matches what `export.sh` writes |
| `release` | version change on `main` | builds both targets, publishes the release |
| `bump` | Mondays, or manually | moves to the latest upstream release and opens a PR |

## Credits

Ocelot is built on [OpenCode](https://github.com/anomalyco/opencode) by the OpenCode team. The
patch-and-release pipeline is inspired by [Helium](https://github.com/imputnet/helium).
