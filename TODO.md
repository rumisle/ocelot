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
- [x] `scripts/install.sh`: ~/.ocelot/bin/ocelot, restarts the service if running.
- [x] Own channel `ocelot`: own service file, port (46624) and database
      (`opencode-ocelot.db`); config, plugins and auth shared with stock.
- [x] Patches `ocelot/updates` + `ocelot/installer`: upstream's updater and installer,
      pointed at our GitHub releases (`~/.ocelot/bin`, `ocelot upgrade`, `autoupdate`).
- [x] Smoke test: service starts, all four plugins load, a prompt round-trips.
- [x] CI: `check` (patches apply + export is a no-op), `release` (build + GitHub
      release when the version is new), `bump` (weekly/manual, opens a PR).

Open:
- [x] CI green; v2.0.16-1 released (3.5 min).
- [x] Actions may open PRs (repo setting, for `bump`).
      Note: PRs opened with GITHUB_TOKEN don't trigger `check`; the bump job applies patches itself.
- [x] Switched over: copied `opencode.db` to `opencode-ocelot.db`; stock service stopped.
- [x] ocelot service on Tailscale: 100.78.68.89:46624.
- [x] opencode-octopi finds `service-*.json` by pid.
- [ ] Try the installer on the Mac (curl download, so no quarantine).

## Testing

- Never test against real models. Use a fake provider (like opencode-octopi's
  `test/fake-anthropic.ts`) and a throwaway server with its own XDG dirs.
- `scripts/dev-server.sh start` runs one: the built binary + `test/fake-anthropic.ts` (streams with
  realistic timings and cache usage; `LINES n`, `SHELL cmd`), web UI at http://127.0.0.1:4852 (opencode / test).

## 1. Plugin API (server)

The server already does these for its HTTP routes; the plugin API doesn't expose them.
Each removes an opencode-octopi ⚠️ workaround. Best candidates to upstream
(watch maintainer draft #51095 first).

- [x] Child sessions: patch `core/child-sessions`. `parentID` on create (plugin API and HTTP; a child
      lives at its parent's location unless one is given) and `child: true` on fork (same field as
      #51095's `Forked.child`). opencode-octopi uses both and falls back on stock.
      Note: after a restart the server resumes children only through a subagent job, so octopi
      resumes its own stopped children.

- [ ] Fork.
- [ ] Compact.
- [ ] Full message reads / list (drop the SQLite read).

## 2. Web UI

### Rendering
- [x] Math: `$…$`, `$$…$$` (also inline), `\[…\]` — patch `web/math-delimiters`.
- [ ] Syntax highlighting like pi-review.

### Timeline
- [ ] Follow scrolling. Upstream has it (virtualizer "pinned" state; wheel-up unpins, reaching the
      end or sending re-pins). Could not reproduce a failure headless (desktop + touch, plain text,
      tool calls, send while scrolled up). Need the exact case: device, what was on screen.
- [ ] Tool status: running state + duration per call. Needs a UI design first.
- [x] Working timer in the composer next to stop, whole run like pi (queued follow-ups included,
      resets when idle). Removed the flickering "Working" row. Patch `web/working-timer`.
- [x] Message meta: user messages lose "Build · model · time"; assistant keeps only the duration.
      Patch `web/message-meta`. (User revert/copy buttons stay in their row.)
- [x] Turn stats: `1m 14s · 95% cache · $0.23` under the reply (summed over the turn's steps).
      Patch `web/turn-stats`.
- [x] TTFT and tokens/s: patch `core/first-output-time` records `time.output`; turn stats show
      `2s · ttft 560ms · 43 t/s · 96% cache · $0.02` (last model call; fits a phone line).

### Composer
- [x] One-row composer `[+] [editor] [send]`, grows as you type; Model / Effort / Agent in the + menu.
      Patch `web/composer-one-line`. Upstream e2e `model-selection-flow.spec.ts` still expects the old button.

### Mobile
- [ ] (later) Top bar → two floating buttons; it wastes a lot of vertical space.

### Plugin UI in the web app
- [ ] General way for plugins to add UI to the web app (upstream only has TUI plugin slots).
      First users: cache-warmer status/tips like pi's (cache expiry countdown, warm now),
      octopi's fleet.
- [ ] Custom renderers for tool calls, so e.g. `tools.octopi.*` calls in Code Mode render as
      worker cards (name, model, status, result) instead of raw code + JSON.

### General
- [ ] The web UI has many small bugs; collect them here as we hit them.

## 3. Cost tracking

- [x] ChatGPT-plan OpenAI models keep API prices (upstream zeroed them). Patch `core/subscription-cost`.

## 4. Branching (big patch, last)

- [ ] Pi-style branching within a session: keep the old branch on
      undo-and-resend instead of deleting messages, with a tree to navigate.
      Touches session storage, the message projector and revert — the code that
      changes fastest upstream, so expect conflicts on every rebase.
