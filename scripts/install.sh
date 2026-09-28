#!/usr/bin/env bash
# Install the locally built binary for this machine where the release installer puts it,
# ~/.ocelot/bin/ocelot (override with OCELOT_BIN_DIR), then restart the ocelot service if
# it is running. Put ~/.ocelot/bin on your PATH (the release installer does that).
#
#   scripts/install.sh              # restart as `ocelot service get restart` says (immediate or idle)
#   scripts/install.sh --now        # restart now
#   scripts/install.sh --when-idle  # restart once no session has run for 30 s
source "$(dirname "$0")/lib.sh"

restart=
case "${1:-}" in
  --now) restart=immediate ;;
  --when-idle) restart=idle ;;
  "") ;;
  *) die "usage: scripts/install.sh [--now | --when-idle]" ;;
esac

case "$(uname -s)-$(uname -m)" in
  Linux-x86_64) target=linux-x64 ;;
  Darwin-arm64) target=darwin-arm64 ;;
  *) die "no ocelot build for $(uname -s)-$(uname -m)" ;;
esac
bin=$ROOT/dist/ocelot-$target/ocelot
[ -x "$bin" ] || die "no $bin; run scripts/build.sh first"

dir=${OCELOT_BIN_DIR:-$HOME/.ocelot/bin}
mkdir -p "$dir"
# Write beside and rename, so a running ocelot keeps its old inode.
cp "$bin" "$dir/.ocelot.new" && mv -f "$dir/.ocelot.new" "$dir/ocelot"
log "installed $("$dir/ocelot" --version 2>/dev/null | head -1) to $dir/ocelot"
[ -n "$restart" ] || restart=$("$dir/ocelot" service get restart 2>/dev/null || echo immediate)

status=$("$dir/ocelot" service status 2>/dev/null | head -1 || true)
[ -n "$status" ] && [ "$status" != stopped ] || exit 0
if [ "$restart" = idle ]; then
  log "the ocelot service restarts once idle (ocelot service status)"
  "$dir/ocelot" service restart --when-idle >/dev/null
else
  log "restarting the ocelot service"
  if systemctl --user cat ocelot.service >/dev/null 2>&1; then
    # Let the systemd unit start it (see README), so the server gets a login shell's environment, not ours.
    "$dir/ocelot" service stop >/dev/null
    systemctl --user restart ocelot.service
  else
    "$dir/ocelot" service restart >/dev/null
  fi
fi
