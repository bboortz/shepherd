#!/bin/sh
# test_SH_026_baseline.sh — SH-026 one-shot baseline capture
# Story:  docs/stories/SH-026-baseline-capture.md
# Plan:   docs/plan/SH-026-baseline-capture-plan.md
# CAPs:   dev-cycle.baseline.frozen-snapshot

set -u
pass=0; fail=0

assert_rc() { want=$1; shift; "$@" >/dev/null 2>&1; rc=$?
  if [ "$rc" = "$want" ]; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL want=$want got=$rc: $*"; fi; }

assert_exists() { f=$1
  if [ -e "$f" ]; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL missing: $f"; fi; }

assert_executable() { f=$1
  if [ -x "$f" ]; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL not executable: $f"; fi; }

assert_contains() { file=$1; needle=$2
  if [ -f "$file" ] && grep -Fq -- "$needle" "$file"; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL $file does not contain: $needle"; fi; }

assert_stdout_contains() { needle=$1; shift
  out=$("$@" 2>/dev/null) || true
  if printf '%s' "$out" | grep -Fq -- "$needle"; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL output does not contain: $needle"; fi; }

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
cd "$repo" || exit 1

SCRIPT=scripts/measure-baseline.sh

# ----- Scenario 1 — script exists and is executable ------------------------

assert_exists "$SCRIPT"
assert_executable "$SCRIPT"

# ----- Scenario 2 — baseline doc exists and has the expected table ---------

BASELINE=docs/specs/dev-cycle-baseline.md
assert_exists "$BASELINE"
assert_contains "$BASELINE" "Dev-cycle baseline"
assert_contains "$BASELINE" "| Repo | Workflow | Event |"
assert_contains "$BASELINE" "bboortz/healthy"
assert_contains "$BASELINE" "bboortz/forge"
assert_contains "$BASELINE" "bb-claw/homelab"
assert_contains "$BASELINE" "bb-claw/kernel-test"

# ----- Scenario 3 — replay mode produces a valid markdown table ------------
# Build a fixture file, drive the script through it, inspect stdout.

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/fixture.jsonl" <<'EOF'
example/repo::[{"workflowName":"ci","event":"pull_request","createdAt":"2026-11-22T10:00:00Z","updatedAt":"2026-11-22T10:03:00Z","conclusion":"success"},{"workflowName":"ci","event":"pull_request","createdAt":"2026-11-22T11:00:00Z","updatedAt":"2026-11-22T11:04:00Z","conclusion":"success"},{"workflowName":"ci","event":"pull_request","createdAt":"2026-11-22T12:00:00Z","updatedAt":"2026-11-22T12:05:00Z","conclusion":"failure"}]
EOF

out=$(SH_026_SAMPLE_FILE="$tmp/fixture.jsonl" MIN_SAMPLES=2 "$SCRIPT" example/repo 2>&1) || true

# Expect: header + one data row + footer.
if printf '%s' "$out" | grep -Fq "| example/repo | ci | pull_request | 3 |"; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  echo "FAIL replay mode did not emit expected row. Output was:"
  printf '%s\n' "$out" | tail -20
fi

# Median of 3,4,5 = 4; p90 ≈ 5; pct_green = 2/3 ≈ 66.
if printf '%s' "$out" | grep -Fq "| 4 | 5 | 66 |"; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  echo "FAIL replay mode produced wrong median/p90/green stats. Got:"
  printf '%s\n' "$out" | grep "example/repo" || true
fi

# ----- Scenario 4 — MIN_SAMPLES warning exits 2 ----------------------------

cat > "$tmp/small.jsonl" <<'EOF'
example/repo::[{"workflowName":"ci","event":"pull_request","createdAt":"2026-11-22T10:00:00Z","updatedAt":"2026-11-22T10:03:00Z","conclusion":"success"}]
EOF

SH_026_SAMPLE_FILE="$tmp/small.jsonl" MIN_SAMPLES=10 "$SCRIPT" example/repo >/dev/null 2>&1
rc=$?
if [ "$rc" = 2 ]; then pass=$((pass + 1))
else fail=$((fail + 1)); echo "FAIL expected exit 2 on MIN_SAMPLES breach, got $rc"; fi

# ----- Scenario 5 — --help prints usage + exits 3 --------------------------

assert_rc 3 "$SCRIPT" --help

# ----- Scenario 6 — unknown flag exits 3 -----------------------------------

assert_rc 3 "$SCRIPT" --bogus

# ----- Scenario 7 — baseline doc has at least one row for each fleet repo ---

for r in bboortz/shepherd bboortz/healthy bboortz/beaconry bboortz/ham-radio-compass bboortz/forge bb-claw/homelab bb-claw/kernel-test; do
  assert_contains "$BASELINE" "$r"
done

# ---------------------------------------------------------------------------
echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
