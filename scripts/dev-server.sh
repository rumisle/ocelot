#!/usr/bin/env bash
# A throwaway ocelot server against test/fake-anthropic.ts, for checking UI changes without
# real models or your real sessions. Everything lives in $E (default /tmp/ocelot-dev).
#
#   scripts/dev-server.sh start [binary]   # default: dist/ocelot-<host>/ocelot (scripts/build.sh)
#   scripts/dev-server.sh stop
#   . /tmp/ocelot-dev/env.sh               # then: A get /api/session, prompt <session> "LINES 40"
#
# The web UI is served at $URL (sign in with username opencode, password test).
source "$(dirname "$0")/lib.sh"

E=${E:-/tmp/ocelot-dev}
PORT=${PORT:-4852}
FAKE=${FAKE:-4851}

stop() { [ -f "$E/tmux" ] && tmux kill-session -t "$(cat "$E/tmux")" 2>/dev/null || true; }
case "${1:-start}" in
  stop) stop; exit 0 ;;
  start) ;;
  *) die "usage: scripts/dev-server.sh start [binary] | stop" ;;
esac

case "$(uname -s)-$(uname -m)" in
  Linux-x86_64) host=linux-x64 ;;
  Darwin-arm64) host=darwin-arm64 ;;
  *) die "unsupported platform" ;;
esac
OC=${2:-$ROOT/dist/ocelot-$host/ocelot}
[ -x "$OC" ] || die "no $OC; run scripts/build.sh first"
BUN=$(command -v bun || true)
[ -n "$BUN" ] || BUN=$(bun_bin)

stop
rm -rf "$E" && mkdir -p "$E"/{config/opencode,data,state,cache,work}
cat > "$E/config/opencode/opencode.jsonc" <<EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "providers": { "anthropic": { "settings": { "baseURL": "http://127.0.0.1:$FAKE/v1" } } },
  "model": "anthropic/claude-opus-5-5"
}
EOF
cat > "$E/env.sh" <<EOF
export XDG_CONFIG_HOME=$E/config XDG_DATA_HOME=$E/data XDG_STATE_HOME=$E/state XDG_CACHE_HOME=$E/cache
export OPENCODE_SERVER_PASSWORD=test ANTHROPIC_API_KEY=sk-ant-fake FAKE_PORT=$FAKE
export OC=$OC URL=http://127.0.0.1:$PORT E=$E
A() { "\$OC" api --server "\$URL" "\$@"; }
# session [title] -> new session id
session() { A post /api/session -d "{\"title\":\"\${1:-dev}\",\"model\":{\"id\":\"claude-opus-5-5\",\"providerID\":\"anthropic\"},\"location\":{\"directory\":\"$E/work\"}}" | jq -r '.data.id // .id'; }
# prompt <session> <text>: send, don't wait
prompt() { A post "/api/session/\$1/prompt" -d "\$(jq -nc --arg t "\$2" '{text:\$t}')" >/dev/null; }
EOF
S=pi-ocelot-dev-$(openssl rand -hex 3)
echo "$S" > "$E/tmux"
tmux new-session -d -s "$S" -n fake ". $E/env.sh && '$BUN' '$ROOT/test/fake-anthropic.ts' > $E/fake.log 2>&1"
tmux new-window -t "$S" -n oc ". $E/env.sh && cd $E/work && '$OC' serve --port $PORT > $E/oc.log 2>&1"
. "$E/env.sh"
timeout 60 sh -c "until '$OC' api --server '$URL' get /api/session >/dev/null 2>&1; do sleep 0.5; done" ||
  die "server did not start; see $E/oc.log"
log "ready at $URL (opencode / test). . $E/env.sh for A, session, prompt"
