# opencode fork — TODO

Vendored OpenCode v2 with a patch set (Helium-style), built with
`packages/cli/script/build.ts --single` and published as our own binary.

Upstream releases almost daily (2.0.0 → 2.0.16 in 13 days, often 40–60 commits,
hundreds of files each). Pin a version, rebase every week or two. Keep patches
small and out of fast-moving core; upstream what we can so it leaves the set.

## 0. Infra first

- [ ] Vendor repo: upstream tag as base, `patches/NNNN-*.patch` applied in order.
- [ ] Rebase script: bump base tag, re-apply, report conflicts.
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
