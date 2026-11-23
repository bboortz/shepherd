#!/bin/sh
# test_SH_044_mk_ci_include.sh — mk/ci.mk as canonical fleet master include (SH-044)
# Story:  docs/stories/SH-044-mk-ci-include.md
# Plan:   docs/plan/SH-044-mk-ci-include-plan.md
# CAPs:   dev-cycle.master-include, blocklist.protected-files,
#         dev-cycle.step.exit-code-propagation

set -u
pass=0; fail=0

assert_rc() { want=$1; shift; "$@" >/dev/null 2>&1; rc=$?
  if [ "$rc" = "$want" ]; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL want=$want got=$rc: $*"; fi; }

assert_grep() { needle=$1; shift
  if "$@" 2>&1 | grep -Fq -- "$needle"; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL output missing '$needle' from $*"; fi; }

assert_file_has() { pattern=$1; file=$2; label=$3
  if grep -Fq -- "$pattern" "$file"; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL $label: '$pattern' not found in $file"; fi; }

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
cd "$repo" || exit 1

# ----- Scenario 1 — mk/ci.mk exists and declares the fleet tiers ----------
assert_rc 0 test -f mk/ci.mk
assert_file_has "hook-commit" mk/ci.mk "mk/ci.mk declares hook-commit"
assert_file_has "hook-push"   mk/ci.mk "mk/ci.mk declares hook-push"
assert_file_has "ci-branch:"  mk/ci.mk "mk/ci.mk ships ci-branch target"
assert_file_has "ci-patch:"   mk/ci.mk "mk/ci.mk ships ci-patch target"
assert_file_has "ci-release:" mk/ci.mk "mk/ci.mk ships ci-release target"
assert_file_has "define run_tier"           mk/ci.mk "mk/ci.mk defines run_tier macro"
assert_file_has "define ci-timing-finish-cmd" mk/ci.mk "mk/ci.mk defines ci-timing-finish-cmd macro"
assert_file_has "ci-release-promote:"       mk/ci.mk "mk/ci.mk ships ci-release-promote"

# ----- Scenario 2 — shepherd dogfoods via include -------------------------
assert_file_has "include mk/ci.mk" Makefile "shepherd Makefile includes mk/ci.mk"
assert_file_has "COMMIT_STEPS"  Makefile "shepherd declares COMMIT_STEPS"
assert_file_has "PUSH_STEPS"    Makefile "shepherd declares PUSH_STEPS"
assert_file_has "BRANCH_STEPS"  Makefile "shepherd declares BRANCH_STEPS"
assert_file_has "PATCH_STEPS"   Makefile "shepherd declares PATCH_STEPS"
assert_file_has "RELEASE_STEPS" Makefile "shepherd declares RELEASE_STEPS"
assert_file_has "NIGHTLY_STEPS" Makefile "shepherd declares NIGHTLY_STEPS"

# ----- Scenario 3 — verify-contract scans the include ---------------------
BUMP="$repo/bin/shepherd-bump"
if [ -x "$BUMP" ]; then
  assert_rc 0 "$BUMP" --verify-contract
  assert_grep "9/9 contract targets present" "$BUMP" --verify-contract
else
  fail=$((fail + 1)); echo "FAIL: $BUMP not executable"
fi

# ----- Scenario 4 — step exit-code propagation preserved in mk/ci.mk ------
# SH-034 regression guard: run_tier captures and replays the failing step's rc.
assert_file_has "_rc=\$\$?"  mk/ci.mk "mk/ci.mk captures step exit code"
assert_file_has "exit \$\$_rc" mk/ci.mk "mk/ci.mk replays captured rc"

# ----- Scenario 5 — dry-run on dogfood resolves all five tier wrappers ----
assert_rc 0 make -n hook-commit
assert_rc 0 make -n hook-push
assert_rc 0 make -n ci-branch
assert_rc 0 make -n ci-patch
# Note: ci-release invokes ci-release-promote which inspects git state —
# dry-run still succeeds because make just prints the recipe.
assert_rc 0 make -n ci-release

# ---------------------------------------------------------------------------
echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
