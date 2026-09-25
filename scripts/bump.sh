#!/usr/bin/env bash
# Move to a new upstream tag: pin it, reset the revision to 1, re-apply every patch
# with 3-way merges, and re-export the refreshed patches.
#
#   scripts/bump.sh           # latest upstream v2 release tag
#   scripts/bump.sh v2.0.17
#
# On a conflict it stops mid `git am` in build/src: resolve, `git am --continue`
# (repeat until every patch is in), then scripts/export.sh.
source "$(dirname "$0")/lib.sh"

tag=${1:-}
if [ -z "$tag" ]; then
  tag=$(git ls-remote --tags --refs "$UPSTREAM_URL" 'v2.*' | sed 's#.*refs/tags/##' |
    grep -E '^v2\.[0-9]+\.[0-9]+$' | sort -V | tail -1)
  [ -n "$tag" ] || die "could not find the latest upstream tag"
fi
if [ "$tag" = "$UPSTREAM" ]; then
  log "already on $tag"
  exit 0
fi
fetch_tag "$tag"

echo "$tag" > "$ROOT/upstream.txt"
echo 1 > "$ROOT/revision.txt"
log "bumped $UPSTREAM -> $tag, revision reset to 1"

"$ROOT/scripts/apply.sh"
"$ROOT/scripts/export.sh"
