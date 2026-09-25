# ocelot

OpenCode v2 with our fixes, kept as a small patch set on top of a pinned upstream
release (the way Helium sits on Chromium).

- `upstream.txt`: the upstream tag we build on (e.g. `v2.0.16`).
- `revision.txt`: our release counter on that tag. The version is `<tag>-<revision>`,
  e.g. `2.0.16-1`. A new upstream tag resets it to 1; a patch-only release bumps it.
- `patches/series`: the patches, applied in order. Each patch is one feature, stored as
  `patches/<area>/<name>.patch` in `git format-patch` form.

## Working on patches

```bash
scripts/apply.sh    # build/src = upstream tag + patches, one commit per patch on branch "ocelot"
# edit in build/src with normal git: new commits, rebase -i, fixup, amend
scripts/export.sh   # write the commits back to patches/ and regenerate patches/series
```

Every commit needs an `Ocelot-Patch: <area>/<name>` trailer naming its patch file:

```bash
git commit -m "web/markdown: render \$…\$ math" --trailer "Ocelot-Patch: web/math-delimiters"
```

Commit titles lead with the area, not `feat:`/`fix:`. If a patch has an upstream PR,
link it in the message, so the patch can be dropped once that PR merges.

## Updating upstream

```bash
scripts/bump.sh v2.0.17   # pins the tag, resets the revision, re-applies with 3-way merges
```

On a conflict it stops mid `git am` in `build/src`: resolve, `git am --continue`
(repeat until all patches are in), then `scripts/export.sh`.

## Building and installing

```bash
scripts/build.sh                          # this machine
scripts/build.sh linux-x64 darwin-arm64   # both release targets (cross-compiled)
scripts/install.sh                        # ~/.local/bin/ocelot, restarts the service
```

Builds use the bun version upstream pins (downloaded to `~/.cache/ocelot`). The upstream
mirror is a blobless clone in `~/.cache/ocelot/upstream.git`.

## How it differs from OpenCode at runtime

Ocelot is built with its own release channel, `ocelot`, so it runs beside stock OpenCode
without sharing its background service: its own service registration
(`~/.local/state/opencode/service-ocelot.json`), port and database
(`~/.local/share/opencode/opencode-ocelot.db`). Config, plugins and auth are shared
(`~/.config/opencode`, `~/.local/share/opencode/auth.json`).

It never updates itself from upstream OpenCode.
