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
- [x] ocelot service reachable over Tailscale.
- [x] opencode-octopi finds `service-*.json` by pid.
- [ ] Try the installer on macOS (curl download, so no quarantine).
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

## Bugs seen in use

- [ ] Read tool, images: a newly written image often reads as "File not found" for several seconds although `ls`
      shows it, and a path written again keeps returning the old image. Looks like a stale stat/content cache
      keyed by path. Workaround: a new filename per image, and wait ~8 s. Seen 2026-10-13 (paw captcha work).

- [ ] Web app polls `/api/skill` and `/api/provider` for many worktree locations at ~2-3 requests/s, nonstop.
      Measured on the real server's event stream (2026-10-14, 15 s): 143 `skill.updated`, one for each of ~48 live
      locations every ~4 s, all at once; the client refetches `/api/skill` for each (`client/src/solid/data.ts`,
      `skill.updated`). Global trigger: skills come from `~/.agents/skills` (`config/plugin/compatibility.ts`), whose
      recursive watcher reloads every location's skills on any change below it (100 ms debounce, no path filter,
      notifies even when nothing changed). Something there changes every few seconds; not yet found. Also cold
      locations booting (`provider.updated` + `model.updated`) for worktrees that showed up empty at first. Fix ideas:
      only react to `*.md` changes, skip notify when the skill set is unchanged, refetch only shown locations.

## Testing

- Never test against real models. Use a fake provider (like opencode-octopi's
  `test/fake-anthropic.ts`) and a throwaway server with its own XDG dirs.
- `scripts/dev-server.sh start` runs one: the built binary + `test/fake-anthropic.ts` (streams with
  realistic timings and cache usage; `LINES n`, `SHELL cmd`, `ECHO text`, `QUESTION text`), web UI at http://127.0.0.1:4852 (opencode / test).
- Web Push, server side: `uv run --with http_ece,cryptography,requests python test/web-push-check.py`
  against the dev server (fake push service; decrypts and verifies VAPID independently).
- Unit tests: `scripts/test.sh [pkg ...]` or `scripts/test.sh pkg file ...`. It uses the pinned bun
  (1.4.2, not the system 1.3.11) and each package's own runner (core's script/test.ts sets the test
  HOME, app needs the happydom preload). Plain `bun test` gave ~40 false failures (plugin reload,
  watcher, preload, app SSR). Baseline 2026-10-03 (v2.0.22): core 5620/0, server 67/0, app 728/0,
  gui-extensions 102/0, session-ui 199/0; client 4 and cli 22 known (see the script header).

## 1. Plugin API (server)

The server already does these for its HTTP routes; the plugin API doesn't expose them.
Each removes an opencode-octopi ⚠️ workaround. Best candidates to upstream
(watch maintainer draft #51095 first).

- [x] Child sessions: patch `core/child-sessions`. `parentID` on create (plugin API and HTTP; a child
      lives at its parent's location unless one is given) and `child: true` on fork (same field as
      #51095's `Forked.child`). opencode-octopi uses both and falls back on stock.
      Note: after a restart the server resumes children only through a subagent job, so octopi
      resumes its own stopped children.

      Upstream v2.0.22 added `parentID` on create (#52359); the patch now only keeps the explicit
      child location and fork `child: true`.

- [ ] Fork.
- [x] Compact: upstream v2.0.22 `session.compact` (#52385); also `session.remove` (#52387).
      opencode-octopi can drop its workaround.
- [ ] Full message reads / list (drop the SQLite read).

## 2. Web UI

### Rendering
- [x] Math: `$…$`, `$$…$$` (also inline), `\[…\]` — patch `web/math-delimiters`.
- [ ] Syntax highlighting like pi-review.

### Timeline
- [x] Follow scrolling: upstream has it (virtualizer "pinned" state; wheel-up unpins, reaching the
      end or sending re-pins). No failure reproduced; reopen with the exact case if it shows up.
- [x] Tool status: running state + duration per call, see backlog 7 (web/tool-elapsed).
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
- (moved to backlog 8, session header, high priority)

- [x] Password prompt in the app. Dropped `web/password-prompt` in 2.0.19: upstream now sends the
      Basic challenge only to page loads (#50970) and shows a sign-in screen with address, password,
      one-time link (`ocelot pair`) and QR scan when the server rejects the app (#50972).
- [x] Links the app opens on its server (a file under /api/fs/read) no longer ask for the password:
      patch `server/session-cookie` gives the app's authenticated same-origin requests upstream's
      session cookie (HttpOnly, SameSite=Lax, 30 days).
- [x] Download files from the file view: patch `web/file-download` ("Download" in the artifact
      toolbar, an icon on plain text files). Not checked on the phone layout yet.
- [x] Push notifications (2.0.22-2): patches `cli/web-push` (VAPID, subscriptions, presence, event →
      push) and `web/push-notifications` (service worker, Settings > Notifications > Push, presence
      reports, tap opens the session). Nothing is pushed while any web app is in use (visible,
      focused, input in the last 3 min). Title = session title; body = the reply / "Needs
      permission · …" / the question / "Failed · …". Also notifies in the browser for permissions
      and questions (upstream had the switch but no code). The TUI reports presence too
      (tui/push-presence: terminal focus + a key in the last 3 min, 2.0.22-3).
- [x] Push confirmed on iOS (home screen app, 2026-10-03): delivery through
      web.push.apple.com, lock-screen look, and a tap with the app closed opens the session.
- [x] Home screen app stuck on an old build (2.0.22-4, patch `web/app-update`): a new service
      worker waited for every page to close, which a suspended iOS app never does. Now it checks
      on return to the app (at most once a minute) and offers "A new version is ready · Reload".
      `ocelot-push-sw.js` is imported with its hash (the server caches it for a year).
- [x] A file tab whose file is gone (2.0.22-5, patch `web/missing-file`): reading from a missing
      directory answered 500, and any missing file toasted "Failed to load file" on every visit.
      Now 404 like a missing file, no toast; the tab stays struck through and loads again once the
      file is back.

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
   - [x] Returning to the app (iOS app switch, any reconnect) loses your place. Confirmed: any
         reconnect (foreground after the stream went quiet 20 s, `online`, pagehide/pageshow, a server
         restart) invalidates everything and `message.sync` kept only the newest page, so the view
         jumped (repro: scrolled back to turn 8 of 60, reconnect → turn 52). Also hit by a branch
         switch and by an interrupted run with a tool still running. Fixed in web/scrollback-resync:
         resync refetches down to the oldest loaded message (exact depth). Repro after: stays on turn 8,
         with or without new messages while away.
   - [x] Reopen where it was left after a reload (web/timeline-position, Telegram-like, option B): the
         top row's key + turn + offset per session in localStorage (saved 300 ms after scrolling and on
         hide); following the bottom saves nothing. Restore loads older pages down to the turn (≤ 100),
         then corrects against layout. No new-message hint (the existing jump-to-bottom button stays).
         Checked desktop + phone: turn 54 → 54, turn 10 → 10, bottom → bottom.
   - [x] Fixed (web/ios-history-prepend): cause is @tanstack/virtual-core deferring scroll corrections
         on iOS while scrolling (`_iosDeferredAdjustment`), so a prepended page showed older content, then
         snapped back at rest. On iOS the loaded page is now published once the timeline is at rest (no
         touch, 200 ms without scroll). WebKit repro after: no flash, steady 59 → 1. Left: with wheel + iPhone
         UA (not a real combination) deferred row-size corrections still flush at the top; the touch path
         translates those visually instead.
         Repro: test/flicker-webkit.py in podman mcr.microsoft.com/playwright/python:v1.63.0-noble
         (samples the top row every frame). Programmatic scrollBy without a wheel/touch never unpins,
         so tests must send the intent first. Confirm on the phone (2.0.19-8+).
   - [x] Slow history over a high-latency link (2.0.22-6). A read during a reply returned the block
         empty until it ended (text is stored on `*.ended`), so a reconnect mid-reply showed it garbled;
         restoring far back walked 20-message pages; a reconnect refetched everything loaded. Patches
         `core/message-sync` (streamed text in reads, deltas with their offset, a delta sync route) and
         `web/history-sync` (delta resync, an IndexedDB cache verified against server update times,
         one-request restore, the place kept by several rows' keys). At 165 ms / 1.2 MB/s: reload ~80
         messages back 6 s → 0.35 s, ~1400 back never → 0.5 s, reconnect mid-reply garbled → exact.
   - [x] Bottom felt sticky, and "Jump to latest" bounced after waking (patch `web/timeline-follow`):
         rows below shrinking clamped a just-scrolled-up view onto the end, which re-pinned it; also
         TanStack kept steering to a scrollToEnd target after the user scrolled. Repro: 6/6 stuck before,
         0/6 after.
   - [x] Switching tabs opened the session at the bottom (patch `web/tab-position`): upstream pins on
         every session change. The place is saved on leaving and restored before the first paint.
   - [x] A connection lost while a transcript loads showed the app's error screen until a reload
         (patch `web/transcript-retry`, upstream bug): 20/24 → 0/24, retried with backoff.
   - [ ] Confirm on the phone (WebKit/iOS momentum not covered by the Chromium tests).
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
   - Note: the "pre-existing" core failures (plugin reload, watcher, preload) were the wrong bun /
     runner; all pass with scripts/test.sh (see Testing).
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
   - [x] Step 1 (core/no-shell-background, opt-in `experimental.no_shell_background`): the model no
         longer sees the `background` option (schema + description rewritten per request); a background
         request runs in the foreground. The user's "move to background" stays: plain wording ("the user
         moved this command…, no need to wait or check"), completion still a steer.
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
8. [x] **Session header** (web/session-header-meta): desktop shows provider · model · effort · cost next to the
   context circle; hovering it shows context %, window used/max (pi's 8.1k / 1.0M) and the compaction threshold.
   Phone: the circle in the Session/Changes/Files/Terminal row, tap for all figures. Bigger layout changes
   (dropping the phone's tab row) rejected for now as too big a change.
9. **Pi-style rewind to any step.** Each model step is its own assistant message, and
   `_ocelot_branch` can park from any message, so "rewind here" on a step (e.g. before a tool
   result that trips a classifier) + a steering message is a UI + small core change: allow the
   revert boundary and the branch switcher on assistant steps, not only user messages.
   Not possible inside one step (parallel tool calls in one response).
10. **Shortcuts and settings.**
   - [x] Keyboard (web/keyboard, 2.0.22-3): web defaults alt+T/W/shift+T, alt+[ ] tabs, alt+I
         input (desktop keeps its own); alt+1..9 tabs; alt+↑/↓ steps through messages and reply
         starts; PageUp/Down scroll the transcript while typing; alt+G stops; double Esc in the
         composer; alt+E edit last; alt+C copy last reply; alt+Y/A/N permissions; alt+/ shortcuts.
         Combinations only (no single-key vim mode: too easy to mis-tap in a web page).
   - [ ] Keyboard, next: act on the message in focus (copy, edit, branch ‹ ›, fork), expand or
         collapse tool calls, the composer's + menu, a picker for sessions beyond the tabs.
   - [ ] Settings (shortcuts, auto-accept, ...) live in browser localStorage per device.
         Sync them through the server (core has a KV table; add an endpoint + a persistence
         adapter for the chosen namespaces).
12. [x] **Errors that say nothing.** Patch server/api-errors (JSON body + ERROR log; client error names status + path). A defect (e.g. SQLITE_CORRUPT) or an unknown route returns a 500/404
      with an empty body and no content-type; the web client then shows only
      "ClientError: UnsupportedContentType", and the defect is logged at INFO. Return a JSON error body
      for defects and unknown routes, log defects at ERROR, and have the client include status + path.
      (Hit 2026-10-01 on an NFS home that filled up and corrupted the database.)
13. [x] **`bgjob` instead of the tmux recipe** (agent-config 157bb3f): `bgjob start/wait/log/peek/send/ls/kill`
      on `tmux -L agent`, job ID = session name; `wait` prints one status line (running / exited N / killed /
      died), output via `log`. AGENTS.md section rewritten; test/bgjob-test.sh (34 checks, 16 parallel runs clean).
      Next: item 4 step 1.
11. [x] (patch core/watch-symlinked-dir: watch the real directory, report paths under the link) Config watching fails: `~/.config/opencode` is a symlink (to agent-config) and the
      watcher errors "inotify_add_watch ... Not a directory", so config edits may not reload.

## 6. Browser use / computer use (researched 2026-10-05, UX not decided)

- Upstream has a browser plugin (`opencode.browser`, packages/plugin-browser): 44 Code Mode tools
  on the server; the browser is a Chromium tab in the Electron app's Review panel, attached over a
  public RPC (version 4 attach). Tools are hidden unless a desktop attaches, so nothing works from
  the web app. Most of it is plain CDP; only tab management and screenshots need Electron.
- Upstream has no computer use (open requests #40782, #48377, #20490).
- Codex computer use (reverse engineered): the model writes JS against `cua` in an MCP REPL
  (`cua_repl`). A signed native helper (SkyComputerUseService) holds Accessibility + Screen Recording
  and serves JSON-RPC over a unix socket. `get_app_state(app)` returns one window's screenshot plus
  a numbered accessibility tree, and the model acts by element index or coordinates. It works in
  the background without taking focus: CGEventPostToPid, AX actions, and CGWindowListCreateImage
  for covered windows; Chromium apps need CDP for move and scroll. Codex's Chrome use is an
  extension plus a native messaging host.
- Open clones: iFurySt/open-codex-computer-use (`ocu`; MCP + CLI `ocu call` / `ocu js`;
  macOS/Linux/Windows; `install-opencode-mcp`), iFurySt/open-browser-use (Chrome extension + CLI),
  trycua/cua (cua-driver).
- Cheapest experiment: run `ocu` on the machine to control and call it from the server over a
  remote shell (or its MCP over stdio). No new code. Stepping in happens at that machine.

## 7. Backlog from 2026-10-13 (not started)

1. **Archive sessions.** Old conversations pile up in the session list. Want a way to archive
   them (hide from the list, keep them retrievable). Upstream's session schema already has
   `time.archived` (`time_archived` column, carried over from v1); check what v2 still does with it
   (API, web app, TUI) before adding anything.
2. **Worktree feature: what is it?** Find out what upstream's worktree support does and how it is
   used (plugin API `packages/plugin/src/worktree.ts`, workspace menu in `gui-extensions/src/summary`,
   `app/src/workspaces`), and whether it is worth using here.
3. **Subagent list.** Today a child session (e.g. an octopi worker) is reachable only from the card under
   the tool call that names it (web/child-session-cards); one spawned or used in a call that doesn't
   name it, or far back in the transcript, is hard to find. Upstream's web app only links child → parent
   (breadcrumb in `session-identity-header.tsx`), nothing parent → children. Want a list of a session's
   children (sessions with `parentID` = this one, recursively) with state (running / idle / closed),
   title, model, cost; tap opens it. UI not decided. Options: a popover from the session header
   (next to the context circle, like web/session-header-meta), a "Subagents" tab beside
   Session/Changes/Files/Terminal, or a side panel. Keep it generic (any child session, no octopi code).
4. **Full-text session search, like [fast-resume](https://github.com/angristan/fast-resume).** fast-resume
   (Rust, Tantivy) indexes local agent history (titles, directories, user and assistant messages) with
   typo-tolerant ranking, filters (`agent:`, `dir:`, `date:<2d`), a preview, and `fr --json` for agents.
   Upstream's session list search is title-only (`LIKE` on the title, `core/src/session/store.ts`).
   Want, over ocelot's own sessions:
   - Web UI: a search/jump palette (query → matching sessions with the hit in context → open at that
     message). Fits with the keyboard work (backlog 5.10, "a picker for sessions beyond the tabs").
   - A tool the model can call: search past sessions (query, directory, date, limit/offset) and read
     the matching excerpt or messages, e.g. "what did we decide about X last week".
   Open: index in the server's SQLite (FTS5, kept current on message writes) vs. a separate index;
   include archived sessions (item 1) and child sessions (item 3)? Possibly just use fast-resume
   itself for other agents' history.
5. **Transcript readability (expanded mode).** Harder to read than pi's TUI. Worst offender: every
   tool call and thought gets its own header row ("Shell ▾", "Thought 2s ▾") above the content,
   which says nothing in expanded mode (a command block is obviously a shell; thinking is already
   greyed). The headers make sense collapsed, not expanded. Constraints from the user: the copy
   button has the card's top-right corner; no per-card collapse in expanded mode (clicking a command
   must do nothing); phones have no margins (so no time gutter); nothing that needs hover. Layouts
   sketched 2026-10-13 (time in a margin, on the command line, terminal-style, border label, shaded
   blocks); none chosen, parked.
6. [~] **Give the model a sense of time.** Prototype: patch `core/time-stamps`, opt-in `experimental.time_stamps` (2026-10-14; not released, not tried with a real model yet). Append `[ended 14:32:05, took 12s]` on its own line to every tool
   result (failed and interrupted ones too; Code Mode `execute` once, not its nested calls), and prefix
   user messages with `[sent 14:32:05]`. End time, not start: it is the model's "now" when it reads the
   result, and start = end − took. Durations: `<1s`, plain seconds up to a few minutes (`74s`, cheaper
   than `1m 14s`), then `12m`. No date (the date instruction already covers it, including day changes);
   state the time zone once next to it.
   - Rendered in `to-llm-message.ts` from the stored part/message times, not stored, so old sessions get
     it too (one full re-read of each on first use). The time zone follows the system (the same one the
     date uses); changing it re-renders every past stamp, so one full re-read then.
   - Prototype findings: "took" counts from `ran`, which is before a permission prompt, so a call that
     waited for approval reports the wait too. Synthetic user-role messages (steers, queued
     follow-ups, background completions) are not stamped yet. A queued user message is stamped when
     it is delivered, not when it was typed (keeps stamps in order). Forks keep the original times.
     Crossing midnight mid-turn: stamps go 23:59 → 00:00 before the "date is now" update arrives.
   - Opt-in config switch; add it to `core/src/config/normalize.ts`.
   - Times: tool `time.ran` → `time.completed` (not `created`, which is when the call streamed in); user
     `time.created`. Completed results: append to the text, or a text part for content results. Error
     results carry `{ error, content }`; check each provider adapter actually sends `content` before
     relying on it.
   - Explain it once, as an instruction next to `core/date` (`instructions/builtins.ts`; keyed, so a
     change is posted as an update instead of rewriting the prompt): what the stamps are, the time zone,
     that the harness adds them (not the tool or the user), and not to write them itself.
   - Code Mode `execute`: one stamp on the whole result (plain text: the return value, then Warnings /
     Logs). Nested calls return values into the script, not to the model, so stamping them would change
     what the script sees (string compares, `JSON.parse`). Scripts that need per-call timing have
     `Date.now()` in the runtime.
   - Cost (ctok, Claude v4.8 and v3 tokenizers alike, measured 2026-10-13): 16 tokens per tool result
     (~3.2k per 200 calls, cached after the first send), 11 per user message. Cheaper forms if needed:
     `[14:32:05 +12s]` 12, `[14:32 +12s]` 10, `[12s]` 5. Two-digit numbers, colons, spaces and brackets
     are ~1 token each; a full date doubles the stamp.
