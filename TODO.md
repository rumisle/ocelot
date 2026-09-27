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

- [x] Password prompt in the app: patch `web/password-prompt`. The server sends the Basic challenge
      only to page loads and non-browser clients; the app asks for a server's password on 401 and
      saves it (the browser's dialog answer was never saved: iOS home screen apps asked every launch).

### Plugin UI in the web app
- [ ] General way for plugins to add UI to the web app (upstream only has TUI plugin slots).
      First users: cache-warmer status/tips like pi's (cache expiry countdown, warm now),
      octopi's fleet.
- [x] Worker cards for octopi: patches `core/codemode-child-sessions` (Code Mode rows record the
      child sessions nested calls name in metadata `sessionID`/`sessionIDs`) and
      `web/child-session-cards` (the subagent card under the execute row; tap opens the live
      transcript). No octopi-specific code in ocelot.
- [ ] Custom renderers for tool calls in general (plugin-provided), e.g. showing a worker's model
      and result on its card.

- [x] Plugin notices in the transcript: patches `core/session-notices` (never sent to the model; optional usage
      counts toward the session), `web/session-notices`, `tui/session-notices`. opencode-cache-warmer posts
      refresh runs and significant misses.
- [ ] Live plugin status in the web app (e.g. the cache warmer's "refresh in 3m 12s" countdown).

### General
- [ ] The web UI has many small bugs; collect them here as we hit them.

## 3. Cost tracking

- [x] ChatGPT-plan OpenAI models keep API prices (upstream zeroed them). Patch `core/subscription-cost`.

## 4. Branching

- [x] ChatGPT-style branches in one session: sending after an edit/undo parks the old messages
      as a branch instead of deleting them; "‹ 2/3 ›" on the edited message switches in place.
      Reverts never touch files. Parked branches live in `_ocelot_branch` (no migration).
      Patches `core/message-branches`, `web/message-branches`, `tui/message-branches`.
- [ ] TUI: switch branches from the message actions (list the alternatives, pick one).
      Today the TUI follows switches made in the web app but can't make them.
- [ ] Forking stays upstream's `/fork` (web and TUI); no button.

## 5. Backlog from 2026-09-27 (researched, not started)

1. **Scrollback.**
   - [ ] Returning to the app (iOS app switch, any reconnect) loses your place. Likely cause:
         on reconnect `session-resolution.ts` re-runs `message.sync`, which replaces the
         transcript with only the latest 20 messages (`reconcile`), dropping every older page
         you had loaded. Fix: on resync, merge the fetched page into what is loaded (or refetch
         down to the oldest loaded message) instead of replacing it; keep the scroll anchor.
   - [ ] Loading older pages jumps back and forth (flicker). Needs a recording/repro; check the
         virtualizer's scroll anchoring when rows are prepended (`timeline/virtualizer.tsx`).
   - [ ] Orientation while scrolling back: e.g. a sticky "which turn am I in" header or
         scrubber with turn positions.
2. **Edit/branches polish.**
   - [ ] The ‹ n/m › switcher should fade with the other hover buttons, not stay visible.
   - [ ] "Message not found" after a model switch + edit. Not in the server log (client-side?).
         Suspect: a model switch while an edit is staged adds a marker message after the
         boundary. Needs a repro.
   - [ ] Edit feels slow: the web path interrupts, stages, then lists and cancels the inbox
         serially. Measure; make the UI optimistic.
3. **Compaction** that works automatically end to end. opencode-vcc is not enough. Decide
   what "works" means first (when it triggers, what survives, whether the cache is reused).
4. **Background shell considered harmful.** How it works today (`tool/plugin/shell.ts`,
   `job.ts`): `shell {background: true}` returns at once; on completion the output is posted
   as a *synthetic* inbox item with delivery `steer`, which reaches the model as a **user-role
   message** (`to-llm-message.ts`) at the next turn boundary, and wakes an idle session.
   Foreground commands block for up to 2 min (default timeout); background ones have no
   timeout. The agent has no tool to list, inspect, wait for or kill jobs: it only gets the
   output file path and "you will be notified, DO NOT poll".
   The complaints, all confirmed by the code:
   - [ ] Arrives at arbitrary points: a steer lands at whatever turn boundary comes next,
         mid-way through unrelated work.
   - [ ] Same weight as the user: it is a user-role message, so the model feels it must answer
         it right away, in the middle of what it was doing.
   - [ ] Forgotten / invisible: no job list/status tool, no reminder; a job that hangs never
         reports (no timeout) and the agent can't tell.
   - [ ] Doesn't solve blocking: a foreground command still blocks the agent (up to the
         timeout) unless a human clicks "run in background".
   - [ ] Cache: the agent ends its turn to wait, the completion wakes it minutes later on a cold
         cache (full re-bill) unless warming covers it.
   Decision (2026-09-27): the agent manages long work itself with the tmux recipe in
   AGENTS.md (log + `tmux wait-for`, short wait then guarded long wait). It already avoids all
   five problems; the user is making the recipe less verbose for weaker models. OpenCode
   doesn't need to know about the jobs.
   - [ ] Step 1: remove the `background` option and its "you will be notified, DO NOT poll"
         instructions from the shell tool, so no synthetic user-role notifications exist.
   - [ ] Step 2 (the one gap tmux leaves): a yield window. A command the agent didn't expect
         to be slow shouldn't block it: past ~10-30 s the shell tool hands the still-running
         command over to a tmux session and returns "still running in tmux session X, log L,
         wait with ..." plus the output so far, i.e. the same state the recipe would have
         produced. Needs the process to be started inside tmux from the beginning (or a
         wrapper), since a running child can't be moved into tmux afterwards.
5. **Cache warming for Claude on other providers.** The warmer hooks only providers with
   known lifetimes (default `anthropic`) and only warms `/v1/messages` URLs. Detect by
   request format (Anthropic Messages body; Vertex `:streamRawPredict`, gateways/proxies)
   rather than provider ID. Which provider(s)? (opencode-cache-warmer repo)
6. **GPT adapter of the internal LLM proxy.** Which proxy, and what is broken?
7. **Tool time elapsed.** Tool parts already record `time.created/ran/completed`: show the
   duration (live while running) in the tool row. Shell rows have created/completed too.
8. **Mobile header.** Always visible: model, effort, context % (bar) and cost; Changes /
   Files / Terminal move into the menu. Needs a design pass (sketch first).
9. **Pi-style rewind to any step.** Each model step is its own assistant message, and
   `_ocelot_branch` can park from any message, so "rewind here" on a step (e.g. before a tool
   result that trips a classifier) + a steering message is a UI + small core change: allow the
   revert boundary and the branch switcher on assistant steps, not only user messages.
   Not possible inside one step (parallel tool calls in one response).
10. **Shortcuts and settings.**
   - [ ] Defaults collide with the browser: mod+w, mod+t/mod+n, mod+shift+t (browser-reserved,
         never reach the page), mod+p, mod+f, mod+o, mod+u, mod+[ / mod+], mod+shift+r, f5,
         ctrl+l. Give the web app its own defaults (e.g. alt- or a leader key), keep the
         desktop ones for the desktop app.
   - [ ] Settings (shortcuts, auto-accept, ...) live in browser localStorage per device.
         Sync them through the server (core has a KV table; add an endpoint + a persistence
         adapter for the chosen namespaces).
11. [ ] Config watching fails: `~/.config/opencode` is a symlink (to agent-config) and the
      watcher errors "inotify_add_watch ... Not a directory", so config edits may not reload.
