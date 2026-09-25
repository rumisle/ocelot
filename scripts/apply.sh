#!/usr/bin/env bash
# Check out the pinned upstream tag in build/src and apply patches/series on top,
# one commit per patch, on branch "ocelot". Uncommitted work in build/src is discarded.
#
# On a conflict it stops mid `git am`: resolve in build/src, `git am --continue`,
# then run scripts/export.sh to write the refreshed patches back.
source "$(dirname "$0")/lib.sh"

fetch_tag "$UPSTREAM"

if [ ! -e "$SRC/.git" ]; then
  log "creating worktree build/src at $UPSTREAM"
  mkdir -p "$(dirname "$SRC")"
  git -C "$MIRROR" worktree prune
  git -C "$MIRROR" worktree add -q --detach "$SRC" "$UPSTREAM"
fi

cd "$SRC"
git am --abort 2>/dev/null || true
git checkout -q -f -B "$BRANCH" "$UPSTREAM"
git clean -q -fd # keeps ignored files (node_modules) so rebuilds stay fast

count=0
while read -r patch; do
  [ -f "$ROOT/patches/$patch" ] || die "missing patch: patches/$patch"
  if ! git am -q -k --3way --keep-cr "$ROOT/patches/$patch"; then
    die "patches/$patch does not apply. Resolve in build/src, 'git am --continue', then scripts/export.sh"
  fi
  count=$((count + 1))
done < <(series)

log "applied $count patches on $UPSTREAM (branch $BRANCH in build/src)"
