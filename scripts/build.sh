#!/usr/bin/env bash
# Build ocelot binaries from build/src (run scripts/apply.sh first).
#
#   scripts/build.sh                          # this machine's platform
#   scripts/build.sh linux-x64 darwin-arm64   # cross-compile (bun supports it)
#
# Output: dist/ocelot-<target>/ocelot and dist/ocelot-<version>-<target>.tar.gz
source "$(dirname "$0")/lib.sh"

[ -e "$SRC/.git" ] || die "no build/src; run scripts/apply.sh first"

host() {
  local os arch
  case "$(uname -s)" in Linux) os=linux ;; Darwin) os=darwin ;; *) die "unsupported OS" ;; esac
  case "$(uname -m)" in x86_64 | amd64) arch=x64 ;; arm64 | aarch64) arch=arm64 ;; *) die "unsupported arch" ;; esac
  echo "$os-$arch"
}
targets=("$@")
[ ${#targets[@]} -gt 0 ] || targets=("$(host)")

BUN=$(bun_bin)
export PATH="$(dirname "$BUN"):$PATH" # build.ts shells out to `bun`
BUN_VERSION=$(bun --version)

# bun installs occasionally hang on a stalled download; retry with a timeout.
retry() {
  local n
  for n in 1 2 3; do
    timeout 300 "$@" && return 0
    log "attempt $n failed: $*"
  done
  die "giving up: $*"
}

cd "$SRC"
log "bun $BUN_VERSION: installing dependencies"
retry bun install --frozen-lockfile
# What build.ts would install itself: native packages for every platform, for cross-compiling.
deps() { sed -n "s/.*\"$1\": *\"\([^\"]*\)\".*/\1/p" packages/cli/package.json | head -1; }
(cd packages/cli && retry bun install --os='*' --cpu='*' "@opentui/core@$(deps @opentui/core)" "@opencode-ai/pty@$(deps @opencode-ai/pty)")
git checkout -q -- packages/cli/package.json bun.lock # that install reorders package.json

mkdir -p "$ROOT/dist"
for target in "${targets[@]}"; do
  log "building ocelot $VERSION for $target"
  out=$ROOT/dist/.build-$target
  (
    cd packages/cli
    OPENCODE_CHANNEL=$CHANNEL OPENCODE_VERSION=$VERSION BUN_COMPILE_RELEASE=bun-v$BUN_VERSION \
      bun run script/build.ts --target="opencode-$target" --outdir="$out" --skip-install
  )
  dest=$ROOT/dist/ocelot-$target
  rm -rf "$dest" && mkdir -p "$dest"
  cp "$out/cli-$target/bin/opencode" "$dest/ocelot"
  rm -rf "$out"
  tar -C "$ROOT/dist" -czf "$ROOT/dist/ocelot-$VERSION-$target.tar.gz" "ocelot-$target"
  log "dist/ocelot-$target/ocelot ($(du -h "$dest/ocelot" | cut -f1))"
done
