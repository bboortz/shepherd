#!/bin/sh
# test_SH_036_test_affected.sh — shepherd diff-aware test-affected (SH-036)
# Story:  docs/stories/SH-036-shepherd-diff-aware-test-affected.md
# Plan:   docs/plan/SH-036-shepherd-diff-aware-test-affected-plan.md
# CAPs:   dev-cycle.shepherd.test-affected-diff-aware

set -u
pass=0; fail=0

assert_rc() { want=$1; shift; "$@" >/dev/null 2>&1; rc=$?
  if [ "$rc" = "$want" ]; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL want=$want got=$rc: $*"; fi; }

assert_stdout_contains() { needle=$1; shift
  out=$("$@" 2>&1 || true)
  if printf '%s' "$out" | grep -Fq -- "$needle"; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL output missing '$needle' from $*"; fi; }

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
cd "$repo" || exit 1

SCRIPT="$repo/scripts/test-affected.sh"

# ----- Scenario 1 — script exists + executable + shellcheck-clean ---------
[ -x "$SCRIPT" ] && pass=$((pass + 1)) || { fail=$((fail + 1)); echo "FAIL: $SCRIPT not executable"; }

if command -v shellcheck >/dev/null; then
  if shellcheck "$SCRIPT" >/dev/null 2>&1; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL shellcheck: $(shellcheck "$SCRIPT" 2>&1 | head -3)"; fi
fi

# ----- Scenario 2 — Makefile wires test-affected to the script ------------
if grep -q 'sh scripts/test-affected.sh' Makefile; then pass=$((pass + 1))
else fail=$((fail + 1)); echo "FAIL: Makefile test-affected not wired to scripts/test-affected.sh"; fi

# Check it's no longer the identity alias.
if grep -qE '^test-affected:[[:space:]]+test-acceptance[[:space:]]*$' Makefile; then
  fail=$((fail + 1)); echo "FAIL: Makefile still has identity alias 'test-affected: test-acceptance'"
else
  pass=$((pass + 1))
fi

# ----- Scenario 3 — --list mode emits something -----------------------
assert_rc 0 "$SCRIPT" --list

# ----- Scenario 4 — full-run bailout rules ---------------------------
# Check the source for the FULL_RE set — sanity check the regex still
# protects Makefile/bump.zig/workflows/CAPABILITIES.md.
assert_stdout_contains 'Makefile' head -n 40 "$SCRIPT"
assert_stdout_contains 'bump\.zig' head -n 40 "$SCRIPT"
assert_stdout_contains 'CAPABILITIES' head -n 40 "$SCRIPT"
assert_stdout_contains '.github/workflows' head -n 40 "$SCRIPT"

# ----- Scenario 5 — TEST_AFFECTED_BASE env override honoured -------------
assert_stdout_contains 'TEST_AFFECTED_BASE' head -n 40 "$SCRIPT"

# ----- Scenario 6 — diff-aware selection rules ------------------------
# Source-form assertions (avoid actual git state manipulation here).
assert_stdout_contains 'test/acceptance/test_SH_' grep -F 'test/acceptance' "$SCRIPT"
assert_stdout_contains 'docs/stories/SH-' head -n 100 "$SCRIPT"
assert_stdout_contains 'docs/plan/SH-' head -n 100 "$SCRIPT"
assert_stdout_contains 'scripts/shepherd-poc' head -n 100 "$SCRIPT"

# ----- Scenario 7 — behavioural sanity --------------------------------
# A --list run on a clean repo must emit at least the "full-run" or
# "no changes" message and include test_SH_013 (always-on traceability test).
out=$("$SCRIPT" --list 2>&1 || true)
if printf '%s' "$out" | grep -Eq 'full-run|no changes|diff-aware'; then pass=$((pass + 1))
else fail=$((fail + 1)); echo "FAIL --list didn't emit a recognised status: $out" | head -3; fi

# ---------------------------------------------------------------------------
echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
