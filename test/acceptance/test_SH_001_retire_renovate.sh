#!/bin/sh
# test_SH_001_retire_renovate.sh — retire Renovate; add shepherd-bump for GH Actions
# Story:  docs/stories/SH-001-retire-renovate.md
# Plan:   docs/plan/SH-001-retire-renovate-plan.md
# Covers: supply-chain.no-third-party-actions-critical-path,
#         supply-chain.first-party-bump-engine,
#         supply-chain.sha-pin-all-actions,
#         bump.gh-actions

set -u
pass=0; fail=0

assert_rc() { want=$1; shift; "$@" >/dev/null 2>&1; rc=$?
  if [ "$rc" = "$want" ]; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL want=$want got=$rc: $*"; fi; }

assert_exists() { f=$1
  if [ -e "$f" ]; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL missing: $f"; fi; }

assert_absent() { f=$1
  if [ ! -e "$f" ]; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL should not exist: $f"; fi; }

assert_exec() { f=$1
  if [ -x "$f" ]; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL not executable: $f"; fi; }

assert_contains() { file=$1; needle=$2
  if [ -f "$file" ] && grep -Fq -- "$needle" "$file"; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL $file does not contain: $needle"; fi; }

assert_not_contains() { file=$1; needle=$2
  if [ -f "$file" ] && grep -Fq -- "$needle" "$file"; then
    fail=$((fail + 1)); echo "FAIL $file should not contain: $needle"
  else pass=$((pass + 1)); fi; }

# Resolve repo root relative to this script so the test is CWD-independent.
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
cd "$repo" || exit 1

# ----- Scenario 1 — Renovate removed from the scaffold ---------------------
assert_absent .github/workflows/renovate.yml
assert_absent renovate/default.json
assert_absent renovate/
assert_exists .github/workflows/bump.yml
assert_contains .github/workflows/bump.yml "shepherd-bump"
assert_contains .github/workflows/bump.yml "cron:"
# No workflow may reference renovatebot upstream after SH-001.
for wf in .github/workflows/*.yml; do
  assert_not_contains "$wf" "renovatebot/"
done

# ----- Scenario 2 — build artefact + entry points --------------------------
assert_exists build.zig
assert_exists bump.zig
assert_exists bin/shepherd-bump
assert_exec   bin/shepherd-bump

# ----- Scenario 3 — shepherd-bump discovers pinned actions -----------------
# --list emits tab-separated lines: <file>\t<owner>/<repo>\t<sha>\t<version>
# Sorted; deterministic.
out=$(./bin/shepherd-bump --list --root . 2>/dev/null)
rc=$?
if [ "$rc" = 0 ]; then pass=$((pass + 1))
else fail=$((fail + 1)); echo "FAIL --list exit=$rc"; fi

for dep in actions/checkout actions/create-github-app-token aquasecurity/trivy-action; do
  if printf '%s\n' "$out" | grep -Fq "	$dep	"; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL --list missing $dep"; fi
done
# renovatebot/github-action must NOT appear after SH-001.
if printf '%s\n' "$out" | grep -Fq "	renovatebot/github-action	"; then
  fail=$((fail + 1)); echo "FAIL --list still reports renovatebot/github-action"
else pass=$((pass + 1)); fi

# ----- Scenario 4 — SHA format is 40 hex -----------------------------------
# Every emitted SHA must be a 40-character lowercase hex string.
bad_shas=$(printf '%s\n' "$out" | awk -F'\t' 'NF>=3 && $3 !~ /^[0-9a-f]{40}$/ { print $0 }')
if [ -z "$bad_shas" ]; then pass=$((pass + 1))
else fail=$((fail + 1)); echo "FAIL --list emitted non-40-hex SHAs:"; echo "$bad_shas"; fi

# ----- Scenario 5 — exit non-zero when root is not a repo ------------------
assert_rc 1 ./bin/shepherd-bump --list --root /nonexistent-path

# ---------------------------------------------------------------------------
echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
