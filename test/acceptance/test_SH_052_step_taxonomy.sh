#!/bin/sh
# test_SH_052_step_taxonomy.sh — step taxonomy doc existence + shape (SH-052)
# Story:  docs/stories/SH-052-step-taxonomy.md
# Plan:   docs/plan/SH-052-step-taxonomy-plan.md
# CAPs:   dev-cycle.taxonomy.recommendation

set -u
pass=0; fail=0

assert_file() { f=$1
  if [ -f "$f" ]; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL missing: $f"; fi; }

assert_grep() { pattern=$1; file=$2
  if grep -Fq -- "$pattern" "$file"; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL grep '$pattern' in $file"; fi; }

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
cd "$repo" || exit 1

DOC=docs/specs/test-taxonomy.md
CAPS=docs/specs/CAPABILITIES.md

# ----- Scenario 1 — doc exists --------------------------------------------
assert_file "$DOC"

# ----- Scenario 2 — all 12 category rows present -------------------------
for cat in fmt lint typecheck unit build verify integration smoke scan acceptance e2e hardware; do
  if grep -Eq "^\| \*\*\`$cat\`\*\*" "$DOC"; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL category '$cat' row missing"; fi
done

# ----- Scenario 3 — per-repo mapping has every repo -----------------------
for repo_name in shepherd healthy beaconry HRC homelab kernel-test forge; do
  assert_grep "$repo_name" "$DOC"
done

# ----- Scenario 4 — CAPABILITIES has the taxonomy row ---------------------
assert_grep "dev-cycle.taxonomy.recommendation" "$CAPS"

# ----- Scenario 5 — taxonomy doc is referenced from CAPABILITIES ---------
assert_grep "test-taxonomy.md" "$CAPS"

# ---------------------------------------------------------------------------
echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
