# opencode fork — TODO

Vendored OpenCode v2 with a patch set (Helium-style), built with
`packages/cli/script/build.ts --single` and published as our own binary.

Upstream releases almost daily (2.0.0 → 2.0.16 in 13 days, often 40–60 commits,
hundreds of files each). Pin a version, rebase every week or two. Keep patches
small and out of fast-moving core; upstream what we can so it leaves the set.

## 0. Infra first

Modelled on Helium (imputnet/helium + helium-linux), adapted to a git upstream.

- [ ] Layout: `upstream.txt` (pinned opencode tag), `revision.txt`,
      `patches/series` (order) + `patches/<area>/<name>.patch`
      (areas e.g. `plugin-api/`, `web/`, `tui/`, `upstream-fixes/`).
      One feature per patch; patch header says what and why.
- [ ] Apply: clone upstream at the tag, apply `series` in order with
      `git apply --3way` (Helium uses quilt with no fuzz because Chromium ships as a
      tarball; we have git, so we get 3-way merges on conflicts).
- [ ] Edit loop: apply series as one commit per patch on a work branch, edit with
      normal git (rebase -i, fixup), re-export to `patches/` with a script.
- [ ] Bump script (Helium's `bump-platform`): move to a new tag, re-apply, refresh
      every patch, reset revision to 1, open a PR. Stop and report on conflicts.
- [ ] Versioning: `<upstream>-<revision>`, e.g. `2.0.16-1`. Revision resets to 1 on
      a base bump and increments for patch-only releases. Release automatically
      when the version changes on main, with `git log` since the last tag as changelog.
- [ ] Own channel: build with our own OPENCODE_CHANNEL so the service registration
      (`service-<channel>.json`) and default port don't collide with stock opencode.
      Check what else keys off the channel (updates, TUI channel, plugin cache).
- [ ] CI: validate that all patches apply cleanly to the pinned tag on every push.
- [ ] Commit style: scope first, e.g. `web/timeline: show tool duration`.
- [ ] Credit where a patch came from (upstream PR number) so it can be dropped once merged.
- [ ] Build: bun 1.4.2 (repo's pin; we have 1.3.11), `--single` for linux-x64.
      Measure build time and binary size (stock is 194 MB).
- [ ] Install/swap: replace `@opencode/cli` binary or ship our own package;
      restart service. Config and plugins unchanged.
- [ ] Publish: GitHub release with binary (and CI to build on base bump).
- [ ] Smoke test: service starts, plugins load, web UI serves, octopi e2e passes.

## 1. Plugin API (server)

The server already does these for its HTTP routes; the plugin API doesn't expose them.
Each removes an opencode-octopi ⚠️ workaround. Best candidates to upstream
(watch maintainer draft #51095 first).

- [ ] `parentID` on session create (workers become children of the leader).
- [ ] Fork.
- [ ] Compact.
- [ ] Full message reads / list (drop the SQLite read).

## 2. Web UI

### Rendering
- [ ] Math: accept `$…$` inline and single-line `$$…$$` (renderer only takes
      `\(…\)` and `$$` on their own lines; `packages/ui/src/context/marked-parser.tsx`).
- [ ] Syntax highlighting like pi-review.

### Timeline
- [ ] Follow scrolling (auto-scroll with new output; stop when the user scrolls up).
- [ ] Show clearly whether a tool call is running.
- [ ] Show how long each tool call ran.
- [ ] Working timer (port of our pi working-timer extension).
- [ ] Drop the per-message meta (model name, "Build") on user and assistant
      messages. Wastes vertical space; nobody switches model that often.
- [ ] Per-turn stats: show something useful instead, e.g. cache hit rate.

### Composer
- [ ] Move model and effort selection into the "+" menu.
- [ ] One-line chat box by default; grow as you type.

### Mobile
- [ ] Top bar → two floating buttons; it wastes a lot of vertical space.

### General
- [ ] The web UI has many small bugs; collect them here as we hit them.

## 3. Cost tracking

- [ ] Track cost of GPT models on a subscription (upstream doesn't).

## 4. Branching (big patch, last)

- [ ] Pi-style branching within a session: keep the old branch on
      undo-and-resend instead of deleting messages, with a tree to navigate.
      Touches session storage, the message projector and revert — the code that
      changes fastest upstream, so expect conflicts on every rebase.
