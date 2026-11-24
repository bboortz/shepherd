#!/bin/sh
# test_SH_056_verify_index_status.sh — SH-056 INDEX ↔ frontmatter status drift
# Story:  docs/stories/SH-056-verify-index-status.md
# Plan:   docs/plan/SH-056-verify-index-status-plan.md
# CAPs:   dev-cycle.verify-index-status

set -u
pass=0; fail=0

assert_rc() { want=$1; shift; "$@" >/dev/null 2>&1; rc=$?
  if [ "$rc" = "$want" ]; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL want=$want got=$rc: $*"; fi; }

assert_grep() { pattern=$1; shift
  if "$@" 2>&1 | grep -Fq -- "$pattern"; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL output missing '$pattern' from $*"; fi; }

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
cd "$repo" || exit 1

SCRIPT="$repo/scripts/verify-index-status.sh"
INDEX="$repo/docs/stories/INDEX.md"

# ----- Scenario 1 — script exists + executable ---------------------------
assert_rc 0 test -f "$SCRIPT"
assert_rc 0 test -x "$SCRIPT"

# ----- Scenario 2 — shepherd itself passes (dogfood) ---------------------
assert_rc 0 "$SCRIPT"
assert_grep "ok (INDEX.md matches frontmatter for all stories)" "$SCRIPT"

# ----- Scenario 3 — drift catch: flip SH-042 row to draft ----------------
cp "$INDEX" /tmp/sh-056-index.bak
trap 'cp /tmp/sh-056-index.bak "$INDEX"; rm -f /tmp/sh-056-index.bak' EXIT

sed -i 's/| SH-042 | shipped |/| SH-042 | draft |/' "$INDEX"
assert_rc 1 "$SCRIPT"
assert_grep "SH-042" "$SCRIPT"
assert_grep "INDEX row status='draft' but frontmatter says 'shipped'" "$SCRIPT"
cp /tmp/sh-056-index.bak "$INDEX"

# ----- Scenario 4 — drift catch: delete SH-042 row -----------------------
grep -v "^| SH-042 " "$INDEX" > /tmp/sh-056-index.notrow
cp /tmp/sh-056-index.notrow "$INDEX"
assert_rc 1 "$SCRIPT"
assert_grep "SH-042: missing INDEX.md row" "$SCRIPT"
cp /tmp/sh-056-index.bak "$INDEX"
rm -f /tmp/sh-056-index.notrow

# ----- Scenario 5 — Makefile exposes verify-index-status -----------------
# .PHONY may span multi-line with backslash continuations; fold then grep.
phony=$(awk '/^\.PHONY:/{flag=1} flag{printf "%s ", $0; if ($0 !~ /\\$/) {print ""; flag=0}}' Makefile)
if printf '%s' "$phony" | grep -Fq "verify-index-status"; then pass=$((pass + 1))
else fail=$((fail + 1)); echo "FAIL .PHONY missing verify-index-status"; fi
if grep -qE '^verify-index-status:' Makefile; then pass=$((pass + 1))
else fail=$((fail + 1)); echo "FAIL Makefile missing 'verify-index-status:' target"; fi

# ----- Scenario 6 — check-docs includes verify-index-status --------------
if grep -qE '^check-docs:.* verify-index-status' Makefile; then pass=$((pass + 1))
else fail=$((fail + 1)); echo "FAIL check-docs doesn't depend on verify-index-status"; fi

# ----- Scenario 7 — make -n verify-index-status resolves cleanly --------
assert_rc 0 make -n verify-index-status
assert_grep "scripts/verify-index-status.sh" make -n verify-index-status

# ----- Scenario 8 — no-op guard when INDEX absent ------------------------
# Use a temp fixture outside the repo so script's --root-style guard fires.
tmp=$(mktemp -d)
mkdir -p "$tmp/scripts" "$tmp/docs/stories"
cp "$SCRIPT" "$tmp/scripts/"
# Script resolves root relative to its own dir — run from the fixture.
( cd "$tmp" && ./scripts/verify-index-status.sh ) >/dev/null 2>&1
rc=$?
if [ "$rc" = 0 ]; then pass=$((pass + 1))
else fail=$((fail + 1)); echo "FAIL no-INDEX guard: expected exit 0, got $rc"; fi
rm -rf "$tmp"

# ---------------------------------------------------------------------------
echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
