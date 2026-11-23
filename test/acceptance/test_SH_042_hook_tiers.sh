#!/bin/sh
# test_SH_042_hook_tiers.sh — hook-commit + hook-push fleet-tier wrappers (SH-042)
# Story:  docs/stories/SH-042-hook-tiers.md
# Plan:   docs/plan/SH-042-hook-tiers-plan.md
# CAPs:   dev-cycle.tier.hook-commit, dev-cycle.tier.hook-push

set -u
pass=0; fail=0

assert_rc() { want=$1; shift; "$@" >/dev/null 2>&1; rc=$?
  if [ "$rc" = "$want" ]; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL want=$want got=$rc: $*"; fi; }

assert_grep() { needle=$1; shift
  if "$@" 2>&1 | grep -Fq -- "$needle"; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL output missing '$needle' from $*"; fi; }

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
cd "$repo" || exit 1

# ----- Scenario 1 — hook-commit + hook-push declared .PHONY ---------------
# Line-continuation tolerant: fold logical .PHONY: line to one line then grep.
phony=$(awk '/^\.PHONY:/{flag=1} flag{printf "%s ", $0; if ($0 !~ /\\$/) {print ""; flag=0}}' Makefile)
if printf '%s' "$phony" | grep -Fq "hook-commit"; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL .PHONY missing hook-commit"; fi
if printf '%s' "$phony" | grep -Fq "hook-push";   then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL .PHONY missing hook-push"; fi

# ----- Scenario 2 — dry-run resolves without executing recipes ------------
assert_rc 0 make -n hook-commit
assert_rc 0 make -n hook-push

# ----- Scenario 3 — hook-commit dry-run invokes the commit steps ----------
# The recipe expands to the underlying commands, so match those markers.
assert_grep "yamllint"            make -n hook-commit
assert_grep "markdownlint"        make -n hook-commit
assert_grep "memory/MEMORY.md"    make -n hook-commit

# ----- Scenario 4 — hook-push dry-run invokes the push steps --------------
# Note: `build` is a file-target and may be skipped as up-to-date in CI (ci-
# branch builds the artifact before test-affected). We assert the two .PHONY
# bundles instead, which always emit their recipes.
assert_grep "verify-traceability.sh"      make -n hook-push
assert_grep "test/acceptance/test_SH_"    make -n hook-push

# ----- Scenario 5 — docs link resolves ------------------------------------
assert_rc 0 test -f docs/stories/SH-042-hook-tiers.md
assert_rc 0 test -f docs/plan/SH-042-hook-tiers-plan.md

# ---------------------------------------------------------------------------
echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
