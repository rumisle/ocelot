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
- [x] Restart when idle: patch `cli/restart-when-idle`. `ocelot service set restart idle|immediate`
      (default `immediate` = upstream). With `idle`, a new binary at the server's path and a newer
      TUI meeting a busy server restart it once no session has run for 30 s; `service restart
      --when-idle` asks for it regardless; `service status` shows it. `scripts/install.sh` follows
      the setting (`--now` / `--when-idle`).
  - [x] Web app: upstream's titlebar "Update" pill (patch web/service-update + routes in
        cli/restart-when-idle: GET/POST /api/ocelot/restart). Shows while a restart is pending (version
        of the new binary on hover); click restarts now and reloads; a stale page after a restart offers
        a reload the same way. Small icon instead of a banner, so nothing to dismiss. Desktop + phone checked.
  - [x] A session waiting on a permission/question counts as running, so it holds the restart back
        until answered. Decided (2026-10-02): keep it that way.
      Accepted: the restarted server inherits the waiter's environment (the old server's, or the
      shell that ran install.sh), not a fresh login shell as the systemd unit gives.

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

- [x] Password prompt in the app. Dropped `web/password-prompt` in 2.0.19: upstream now sends the
      Basic challenge only to page loads (#50970) and shows a sign-in screen with address, password,
      one-time link (`ocelot pair`) and QR scan when the server rejects the app (#50972).
- [x] Links the app opens on its server (a file under /api/fs/read) no longer ask for the password:
      patch `server/session-cookie` gives the app's authenticated same-origin requests upstream's
      session cookie (HttpOnly, SameSite=Lax, 30 days).
- [x] Download files from the file view: patch `web/file-download` ("Download" in the artifact
      toolbar, an icon on plain text files). Not checked on the phone layout yet.

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
   - [x] The ‹ n/m › switcher fades with the other hover buttons (always shown on touch screens).
   - [x] "Message not found" after a model switch + edit. Cause: sending an edit with another model
         selected switches the model (a marker message after the staged boundary), then commits the
         edit, which parked the marker too; the client's read-back of the marker got a 404 (upstream
         deletes it the same way). Fixed in core/message-branches: the selections at the end of the
         parked range stay in the continuing history. Repro 3/3 before, 0/3 after (browser, dev server).
   - [ ] Edit feels slow: the web path interrupts, stages, then lists and cancels the inbox
         serially. Measured 2026-10-01: stage is 2-17 ms on the server (long session copy); in the
         browser the composer fills in 1-16 ms and the messages hide in 34-46 ms, idle or running.
         Not reproduced; need the case (phone? a running tool? a very long session?).
3. **Compaction** that works automatically end to end. opencode-vcc is not enough.
   - [x] Step 1: patch `core/checkpoint-compaction`, opt-in with `"compaction": { "strategy": "checkpoint" }`.
         Compacts at min(90% of the window, 540k) (`threshold.ratio` / `threshold.tokens`). The checkpoint is a
         follow-up to the live context (whole prefix is a cache read; tools and tool_choice unchanged), with pi's
         sections plus OpenCode's rules and a "Running" section, rewritten fresh each time. One reminder for a
         reply that calls a tool or skips the template, then the summary strategy as fallback; 5 min idle timeout
         (`timeout`, ms) retried under the session retry policy; overflow recovery takes the summary path.
         Config goes through `core/src/config/normalize.ts`, which copies known fields: new ones must be added there.
   - [x] Step 2 (same patch): the newest messages stay as messages (pi's cut: back to `keep` tokens, from the
         user message that opened that exchange, or from a step when that exchange is over 2 × keep). The
         compaction records `keep: { id, seq }` (forks rewrite ids, imports renumber seqs); history reads from it
         with the compaction moved in front, dropping earlier compactions and instruction updates in the kept part;
         usage measured before the compaction is ignored. E2E (fake provider): compaction, no second compaction,
         editing a kept message undoes it, switching back restores it, forks before/after both correct.
   - [x] opencode-vcc removed from the config (its compaction hook result would win).
   - Note: on this machine 6 "config plugin reloads" tests and preload's "isolates global home and XDG roots"
     fail on plain v2.0.19 too. Since 2026-10-01 also 7 in test/plugin/{supervisor-reload,module}.test.ts
     (plugin never activates: "RPC is unavailable: greeter"), again on plain v2.0.19 too, with an empty HOME
     too. Environment; not investigated yet. packages/cli test/updater-install.test.ts (22) fails by design:
     patch ocelot/updates installs from GitHub releases, not npm.
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
5. [x] **Cache warming for Claude on other providers.** Done in opencode-cache-warmer e727c81 / 87aff71. The warmer hooks only providers with
   known lifetimes (default `anthropic`) and only warms `/v1/messages` URLs. Detect by
   request format (Anthropic Messages body; Vertex `:streamRawPredict`, gateways/proxies)
   rather than provider ID. Which provider(s)? (opencode-cache-warmer repo)
6. **GPT adapter of the internal LLM proxy.** Which proxy, and what is broken?
7. [x] **Tool time elapsed.** Patch web/tool-elapsed: "Shell 12s" after the tool name (execution time
   ran→completed, live while running, hidden under 1 s); collapsed groups show first start → last end. Tool parts already record `time.created/ran/completed`: show the
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
12. [x] **Errors that say nothing.** Patch server/api-errors (JSON body + ERROR log; client error names status + path). A defect (e.g. SQLITE_CORRUPT) or an unknown route returns a 500/404
      with an empty body and no content-type; the web client then shows only
      "ClientError: UnsupportedContentType", and the defect is logged at INFO. Return a JSON error body
      for defects and unknown routes, log defects at ERROR, and have the client include status + path.
      (Hit 2026-10-01 on an NFS home that filled up and corrupted the database.)
13. [ ] **`job` helper instead of the tmux recipe** (agent-config): `job start NAME -- cmd`, `job wait ID`
      (≤ 90 s, re-callable; done = an `exit` file written by rename; process gone without it = died),
      `job log`, `job kill` (process group). Then shrink the AGENTS.md section, then item 4 step 1.
11. [x] (patch core/watch-symlinked-dir: watch the real directory, report paths under the link) Config watching fails: `~/.config/opencode` is a symlink (to agent-config) and the
      watcher errors "inotify_add_watch ... Not a directory", so config edits may not reload.
