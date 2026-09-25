#!/usr/bin/env bash
# Install the locally built binary for this machine to ~/.local/bin/ocelot
# (override with OCELOT_BIN_DIR), then restart the ocelot service if it is running.
source "$(dirname "$0")/lib.sh"

case "$(uname -s)-$(uname -m)" in
  Linux-x86_64) target=linux-x64 ;;
  Darwin-arm64) target=darwin-arm64 ;;
  *) die "no ocelot build for $(uname -s)-$(uname -m)" ;;
esac
bin=$ROOT/dist/ocelot-$target/ocelot
[ -x "$bin" ] || die "no $bin; run scripts/build.sh first"

dir=${OCELOT_BIN_DIR:-$HOME/.local/bin}
mkdir -p "$dir"
# Write beside and rename, so a running ocelot keeps its old inode.
cp "$bin" "$dir/.ocelot.new" && mv -f "$dir/.ocelot.new" "$dir/ocelot"
log "installed $("$dir/ocelot" --version 2>/dev/null | head -1) to $dir/ocelot"

if [ -n "$("$dir/ocelot" service status 2>/dev/null)" ]; then # prints the URL only when running
  log "restarting the ocelot service"
  "$dir/ocelot" service restart >/dev/null
fi
