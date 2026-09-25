# Shared paths and helpers. Sourced by the other scripts.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
UPSTREAM_URL=${UPSTREAM_URL:-https://github.com/anomalyco/opencode.git}
CACHE=${OCELOT_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/ocelot}
MIRROR=$CACHE/upstream.git
SRC=$ROOT/build/src
BRANCH=ocelot
CHANNEL=ocelot

UPSTREAM=$(tr -d '[:space:]' < "$ROOT/upstream.txt")
REVISION=$(tr -d '[:space:]' < "$ROOT/revision.txt")
# v2.0.16 + revision 1 -> 2.0.16-1
VERSION=${UPSTREAM#v}-$REVISION

log() { printf '\033[1;34m==>\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# Blobless bare mirror of upstream; fetches the given tag if it is missing.
fetch_tag() {
  local tag=$1
  if [ ! -d "$MIRROR" ]; then
    log "cloning upstream mirror into $MIRROR"
    mkdir -p "$CACHE"
    git clone --bare --filter=blob:none "$UPSTREAM_URL" "$MIRROR"
  fi
  if ! git -C "$MIRROR" rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
    log "fetching $tag"
    git -C "$MIRROR" fetch --filter=blob:none origin "refs/tags/$tag:refs/tags/$tag"
  fi
}

# Patches listed in patches/series, in order (blank lines and # comments skipped).
series() {
  sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$ROOT/patches/series" | awk 'NF'
}

# The bun the upstream repo pins (package.json packageManager), downloaded on demand.
bun_bin() {
  local want
  want=$(sed -n 's/.*"packageManager": *"bun@\([^"]*\)".*/\1/p' "$SRC/package.json")
  [ -n "$want" ] || die "no packageManager bun version in $SRC/package.json"
  if command -v bun >/dev/null && [ "$(bun --version)" = "$want" ]; then command -v bun; return; fi
  local os arch dir
  case "$(uname -s)" in Linux) os=linux ;; Darwin) os=darwin ;; *) die "unsupported OS" ;; esac
  case "$(uname -m)" in x86_64 | amd64) arch=x64 ;; arm64 | aarch64) arch=aarch64 ;; *) die "unsupported arch" ;; esac
  dir=$CACHE/bun-$want
  if [ ! -x "$dir/bun" ]; then
    log "downloading bun $want"
    mkdir -p "$dir"
    curl -fsSL -o "$dir/bun.zip" "https://github.com/oven-sh/bun/releases/download/bun-v$want/bun-$os-$arch.zip"
    unzip -qoj "$dir/bun.zip" -d "$dir" && rm "$dir/bun.zip"
  fi
  echo "$dir/bun"
}
