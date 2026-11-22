#!/bin/sh
# test_SH_020_timing_digest.sh — SH-020 fleet timing digest
# Story:  docs/stories/SH-020-ci-timing-digest.md
# Plan:   docs/plan/SH-020-ci-timing-digest-plan.md
# CAPs:   dev-cycle.timing.json-emission

set -u
pass=0; fail=0

assert_rc() { want=$1; shift; "$@" >/dev/null 2>&1; rc=$?
  if [ "$rc" = "$want" ]; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL want=$want got=$rc: $*"; fi; }

assert_stdout_contains() { needle=$1; shift
  out=$("$@" 2>&1 || true)
  if printf '%s' "$out" | grep -Fq -- "$needle"; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL output missing '$needle' from: $*"
    printf '%s\n' "$out" | tail -5
  fi; }

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
cd "$repo" || exit 1

SCRIPT="$repo/scripts/digest-timing.sh"

# ----- Scenario 1 — script exists + executable ------------------------------

[ -x "$SCRIPT" ] && pass=$((pass + 1)) || { fail=$((fail + 1)); echo "FAIL: $SCRIPT not executable"; }
assert_rc 3 "$SCRIPT" --help

# ----- Fixture harness ------------------------------------------------------

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Build a minimal baseline file (3 rows).
cat > "$tmp/baseline.md" <<'EOF'
# Dev-cycle baseline

| Repo | Workflow | Event | n | median (min) | p90 (min) | green % |
|---|---|---|---:|---:|---:|---:|
| example/alpha | CI | pull_request | 50 | 4.0 | 5.2 | 90 |
| example/alpha | CI | push | 30 | 1.0 | 2.0 | 95 |
| example/beta  | CI | pull_request | 40 | 2.0 | 3.0 | 95 |
EOF

# Fixture 1 — one repo at baseline, no regression
cat > "$tmp/no-regression.jsonl" <<'EOF'
example/alpha::[{"workflowName":"CI","event":"pull_request","createdAt":"2026-11-22T10:00:00Z","updatedAt":"2026-11-22T10:04:00Z","conclusion":"success"},{"workflowName":"CI","event":"pull_request","createdAt":"2026-11-22T11:00:00Z","updatedAt":"2026-11-22T11:04:00Z","conclusion":"success"},{"workflowName":"CI","event":"pull_request","createdAt":"2026-11-22T12:00:00Z","updatedAt":"2026-11-22T12:04:00Z","conclusion":"success"}]
EOF

# Fixture 2 — one repo at 50 % above baseline (regression!)
cat > "$tmp/regression.jsonl" <<'EOF'
example/alpha::[{"workflowName":"CI","event":"pull_request","createdAt":"2026-11-22T10:00:00Z","updatedAt":"2026-11-22T10:06:00Z","conclusion":"success"},{"workflowName":"CI","event":"pull_request","createdAt":"2026-11-22T11:00:00Z","updatedAt":"2026-11-22T11:06:00Z","conclusion":"success"},{"workflowName":"CI","event":"pull_request","createdAt":"2026-11-22T12:00:00Z","updatedAt":"2026-11-22T12:06:00Z","conclusion":"success"}]
EOF

# ----- Scenario 2 — no-regression fixture → exit 0 -------------------------

BASELINE_FILE="$tmp/baseline.md" SH_020_FIXTURE="$tmp/no-regression.jsonl" "$SCRIPT" example/alpha >/dev/null 2>&1
rc=$?
if [ "$rc" = 0 ]; then pass=$((pass + 1))
else fail=$((fail + 1)); echo "FAIL no-regression expected exit 0 got $rc"; fi

# ----- Scenario 3 — regression fixture → exit 2 ---------------------------

BASELINE_FILE="$tmp/baseline.md" SH_020_FIXTURE="$tmp/regression.jsonl" "$SCRIPT" example/alpha >/dev/null 2>&1
rc=$?
if [ "$rc" = 2 ]; then pass=$((pass + 1))
else fail=$((fail + 1)); echo "FAIL regression expected exit 2 got $rc"; fi

# ----- Scenario 4 — regression fixture emits ⚠️ marker + delta ------------

out=$(BASELINE_FILE="$tmp/baseline.md" SH_020_FIXTURE="$tmp/regression.jsonl" "$SCRIPT" example/alpha 2>/dev/null || true)
if printf '%s' "$out" | grep -Fq "⚠️"; then pass=$((pass + 1))
else fail=$((fail + 1)); echo "FAIL regression row missing ⚠️ marker"; printf '%s\n' "$out" | tail -5; fi

if printf '%s' "$out" | grep -Fq "+50%"; then pass=$((pass + 1))
else fail=$((fail + 1)); echo "FAIL delta '+50%' missing"; printf '%s\n' "$out" | tail -5; fi

# ----- Scenario 5 — regression stderr names the (repo, workflow, event) ---

err=$(BASELINE_FILE="$tmp/baseline.md" SH_020_FIXTURE="$tmp/regression.jsonl" "$SCRIPT" example/alpha 2>&1 >/dev/null || true)
if printf '%s' "$err" | grep -Fq "regression: example/alpha CI pull_request"; then pass=$((pass + 1))
else fail=$((fail + 1)); echo "FAIL stderr missing regression line"; printf '%s\n' "$err" | tail -5; fi

# ----- Scenario 6 — header + baseline reference in output -----------------

assert_stdout_contains "Dev-cycle timing digest" env BASELINE_FILE="$tmp/baseline.md" SH_020_FIXTURE="$tmp/no-regression.jsonl" "$SCRIPT" example/alpha
assert_stdout_contains "baseline (min)" env BASELINE_FILE="$tmp/baseline.md" SH_020_FIXTURE="$tmp/no-regression.jsonl" "$SCRIPT" example/alpha

# ---------------------------------------------------------------------------
echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
