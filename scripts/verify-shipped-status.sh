#!/bin/sh
# verify-shipped-status.sh — SH-058 released-story-must-be-shipped check.
#
# Closes the verify-index-status (SH-056) blind spot: that check keeps INDEX.md
# and story frontmatter in AGREEMENT but can't tell when they agree on a stale
# value. SH-056 itself proved it — shipped in v0.10.1-rc1 yet both sat at
# `in-progress` for days, mutually consistent, so the checker stayed silent.
#
# For every released CHANGELOG heading (`## [vX.Y.Z] …`; the `[Unreleased]`
# section is exempt), each `SH-NNN` token with a matching
# docs/stories/SH-NNN-*.md must carry frontmatter `status: shipped`.
#
# Heading-only (not the section body — bodies name follow-ups that may be
# legitimately unshipped). SH-NNN with no story file is skipped (may live in
# another repo / predate the stories dir). No-op when CHANGELOG.md is absent.
#
# Exit 0 clean; exit 1 on any violation.
#
# CAPs: dev-cycle.verify-shipped-status
# Story: docs/stories/SH-058-verify-shipped-status.md

set -eu

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/.." && pwd)
changelog="$root/CHANGELOG.md"
stories="$root/docs/stories"

[ -f "$changelog" ] || { echo "verify-shipped-status: $changelog missing — nothing to check"; exit 0; }

# Story IDs named in released version headings (skip [Unreleased]).
ids=$(grep -E '^## \[v' "$changelog" | grep -oE 'SH-[0-9]+' | sort -u)

fail=0
for id in $ids; do
    f=""
    for cand in "$stories/$id"-*.md; do
        [ -f "$cand" ] && { f=$cand; break; }
    done
    [ -n "$f" ] || continue   # no story file — not ours to judge

    status=$(awk '/^status:/{print $2; exit}' "$f")
    [ -n "$status" ] || { echo "verify-shipped-status: $id: no status: in frontmatter"; fail=1; continue; }

    if [ "$status" != "shipped" ]; then
        ver=$(grep -E "^## \[v.*$id" "$changelog" | head -1 | sed -E 's/^## \[(v[^]]+)\].*/\1/')
        echo "verify-shipped-status: $id released in ${ver:-a CHANGELOG version} but frontmatter status='$status'"
        fail=1
    fi
done

if [ "$fail" = 0 ]; then
    echo "verify-shipped-status: ok (every CHANGELOG-released story is shipped)"
    exit 0
fi
echo "verify-shipped-status: released stories must be status: shipped; flip the frontmatter + INDEX."
exit 1
