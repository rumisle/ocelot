# ocelot — TODO

OpenCode v2 with our fixes as a patch set (Helium-style). See README.md for the workflow.

Upstream releases almost daily (2.0.0 → 2.0.16 in 13 days, often 40–60 commits,
hundreds of files each). Pin a version, rebase every week or two. Keep patches
small and out of fast-moving core; upstream what we can so it leaves the set.

## 0. Infra

Modelled on Helium (imputnet/helium + helium-linux), adapted to a git upstream:
patches are `git format-patch` files applied with `git am --3way`, so a bump gets
real merge conflicts instead of Helium's quilt no-fuzz failures.

Done:
- [x] Layout: `upstream.txt`, `revision.txt`, `patches/series` + `patches/<area>/<name>.patch`.
- [x] `scripts/apply.sh` / `export.sh`: build/src = tag + one commit per patch
      (`Ocelot-Patch:` trailer names the file); edit with git, export back.
- [x] `scripts/bump.sh [tag]`: pin, reset revision, re-apply, re-export.
- [x] `scripts/build.sh [targets]`: bun 1.4.2 (upstream's pin, auto-downloaded),
      linux-x64 + darwin-arm64 cross-compiled on Linux in ~45 s total, 194 / 172 MB.
      The Mac binary carries bun's ad-hoc code signature.
- [x] `scripts/install.sh`: ~/.local/bin/ocelot, restarts the service if running.
- [x] Own channel `ocelot`: own service file, port (46624) and database
      (`opencode-ocelot.db`); config, plugins and auth shared with stock.
- [x] Patch `ocelot/no-upstream-updates`: the updater would otherwise replace us
      with stock OpenCode.
- [x] Smoke test: service starts, all four plugins load, a prompt round-trips.
- [x] CI: `check` (patches apply + export is a no-op), `release` (build + GitHub
      release when the version is new), `bump` (weekly/manual, opens a PR).

Open:
- [ ] Check CI actually runs green (first push).
- [ ] `bump` PRs need "Allow GitHub Actions to create pull requests" in repo settings.
      PRs opened with GITHUB_TOKEN don't trigger `check`; the bump job applies patches itself.
- [ ] Switch over from stock: move sessions? `opencode-ocelot.db` starts empty. Options:
      copy `opencode.db` once while both services are stopped, or build with
      `OPENCODE_DISABLE_CHANNEL_DB` semantics (shared DB; risky once patches touch the schema).
- [ ] Service hostname for ocelot (`ocelot service set hostname 100.78.68.89`), web UI pairing.
- [ ] opencode-octopi reads `service.json` only; make it find `service-*.json` by pid.
      (Goes away with the plugin-API patches.)
- [ ] Branding: `--version` says "opencode v2.0.16-1"; web UI title, TUI name.
- [ ] Install from a release on the Mac (curl + tar; no quarantine that way).

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
