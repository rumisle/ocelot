#!/usr/bin/env bash
# Run unit tests in build/src the way each package expects, with the pinned bun
# (packageManager in package.json). A plain `bun test` with another bun or without
# a package's preload fails dozens of tests that are fine.
#
#   scripts/test.sh                 # core server client cli app
#   scripts/test.sh core app        # some packages
#   scripts/test.sh core test/plugin/module.test.ts   # files within one package
#
# Known failures (upstream or by design): client 4 (stale upstream tests: file.write,
# interrupt ?continue, DateTime.Utc decode, import boundaries); cli 22 in
# test/updater-install.test.ts (ocelot installs from GitHub releases, not npm).
source "$(dirname "$0")/lib.sh"

[ -e "$SRC/.git" ] || die "no build/src; run scripts/apply.sh first"
BUN=$(bun_bin)
export PATH="$(dirname "$BUN"):$PATH"

script() {
  case "$1" in
    core | cli) echo "test" ;;
    app) echo "test:unit" ;;
    *) echo "" ;;
  esac
}

if [ $# -ge 2 ] && [ -d "$SRC/packages/$1" ] && [ ! -d "$SRC/packages/$2" ]; then
  pkg=$1; shift
  cd "$SRC/packages/$pkg"
  case "$pkg" in
    app) exec bun test --conditions=solid --preload ./happydom.ts "$@" ;;
    core) exec bun run script/test.ts "$@" ;;
    *) exec bun test "$@" ;;
  esac
fi

packages=("$@")
[ ${#packages[@]} -gt 0 ] || packages=(core server client cli app)
status=0
for pkg in "${packages[@]}"; do
  log "$pkg"
  s=$(script "$pkg")
  if [ -n "$s" ]; then (cd "$SRC/packages/$pkg" && bun run "$s") || status=1
  else (cd "$SRC/packages/$pkg" && bun test) || status=1
  fi
done
exit $status
