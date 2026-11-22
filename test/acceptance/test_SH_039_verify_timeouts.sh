#!/bin/sh
# test_SH_039_verify_timeouts.sh — shepherd-bump --verify-timeouts (SH-039)
# Story:  docs/stories/SH-039-verify-timeouts.md
# Plan:   docs/plan/SH-039-verify-timeouts-plan.md
# CAPs:   dev-cycle.budget.verify-timeouts

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

BUMP="$repo/bin/shepherd-bump"
[ -x "$BUMP" ] && pass=$((pass + 1)) || { fail=$((fail + 1)); echo "FAIL: $BUMP not executable"; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# ----- Scenario 1 — shepherd itself passes (dogfood) ----------------------
assert_rc 0 "$BUMP" --verify-timeouts
assert_stdout_contains "ok" "$BUMP" --verify-timeouts

# ----- Scenario 2 — clean fixture passes ----------------------------------
mk_workflows() {
  local dir=$1 b=$2 p=$3 r=$4 n=$5
  mkdir -p "$dir/.github/workflows"
  for pair in "ci-branch.yml:$b" "ci-patch.yml:$p" "ci-release.yml:$r" "ci-nightly.yml:$n"; do
    f=${pair%%:*}; t=${pair#*:}
    cat > "$dir/.github/workflows/$f" <<EOF
name: ${f%.yml}
"on": {}
jobs:
  gate:
    runs-on: ubuntu-latest
    timeout-minutes: $t
    steps:
      - run: echo
EOF
  done
}

mk_workflows "$tmp/ok" 5 5 15 120
assert_rc 0 "$BUMP" --verify-timeouts --root "$tmp/ok"
assert_stdout_contains "ci-branch.yml timeout-minutes=5" "$BUMP" --verify-timeouts --root "$tmp/ok"
assert_stdout_contains "ci-nightly.yml timeout-minutes=120" "$BUMP" --verify-timeouts --root "$tmp/ok"

# ----- Scenario 3 — over-budget fails with exit 4 -------------------------
mk_workflows "$tmp/over" 10 5 15 120
assert_rc 4 "$BUMP" --verify-timeouts --root "$tmp/over"
assert_stdout_contains "timeout-minutes=10 > budget 5" "$BUMP" --verify-timeouts --root "$tmp/over"

# ----- Scenario 4 — missing timeout-minutes fails with exit 4 -------------
mkdir -p "$tmp/notimeout/.github/workflows"
cat > "$tmp/notimeout/.github/workflows/ci-branch.yml" <<'EOF'
name: ci-branch
"on": {}
jobs:
  gate:
    runs-on: ubuntu-latest
    steps:
      - run: echo
EOF
# Add the other three correctly to isolate the missing-key path.
cat > "$tmp/notimeout/.github/workflows/ci-patch.yml" <<'EOF'
jobs:
  p:
    timeout-minutes: 5
    steps:
      - run: echo
EOF
cat > "$tmp/notimeout/.github/workflows/ci-release.yml" <<'EOF'
jobs:
  r:
    timeout-minutes: 15
    steps:
      - run: echo
EOF
cat > "$tmp/notimeout/.github/workflows/ci-nightly.yml" <<'EOF'
jobs:
  n:
    timeout-minutes: 120
    steps:
      - run: echo
EOF
assert_rc 4 "$BUMP" --verify-timeouts --root "$tmp/notimeout"
assert_stdout_contains "no \`timeout-minutes:\` key" "$BUMP" --verify-timeouts --root "$tmp/notimeout"

# ----- Scenario 5 — missing tier workflow fails with exit 3 ---------------
mkdir -p "$tmp/missing/.github/workflows"
cat > "$tmp/missing/.github/workflows/ci-release.yml" <<'EOF'
jobs:
  r:
    timeout-minutes: 15
    steps:
      - run: echo
EOF
assert_rc 3 "$BUMP" --verify-timeouts --root "$tmp/missing"
assert_stdout_contains "ci-branch.yml missing" "$BUMP" --verify-timeouts --root "$tmp/missing"
assert_stdout_contains "ci-patch.yml missing" "$BUMP" --verify-timeouts --root "$tmp/missing"
assert_stdout_contains "ci-nightly.yml missing" "$BUMP" --verify-timeouts --root "$tmp/missing"

# ----- Scenario 6 — inline comment on timeout-minutes line is tolerated ---
mkdir -p "$tmp/comment/.github/workflows"
cat > "$tmp/comment/.github/workflows/ci-branch.yml" <<'EOF'
jobs:
  gate:
    timeout-minutes: 5    # hard cap per SH-014
    steps: [{run: "echo"}]
EOF
cat > "$tmp/comment/.github/workflows/ci-patch.yml" <<'EOF'
jobs:
  p:
    timeout-minutes: 5
    steps: [{run: "echo"}]
EOF
cat > "$tmp/comment/.github/workflows/ci-release.yml" <<'EOF'
jobs:
  r:
    timeout-minutes: 15
    steps: [{run: "echo"}]
EOF
cat > "$tmp/comment/.github/workflows/ci-nightly.yml" <<'EOF'
jobs:
  n:
    timeout-minutes: 120
    steps: [{run: "echo"}]
EOF
assert_rc 0 "$BUMP" --verify-timeouts --root "$tmp/comment"

# ----- Scenario 7 — multiple jobs: verifier picks the largest ----------
mkdir -p "$tmp/multi/.github/workflows"
cat > "$tmp/multi/.github/workflows/ci-branch.yml" <<'EOF'
jobs:
  fast:
    timeout-minutes: 3
    steps: [{run: "echo"}]
  slow:
    timeout-minutes: 7
    steps: [{run: "echo"}]
EOF
cat > "$tmp/multi/.github/workflows/ci-patch.yml" <<'EOF'
jobs:
  p:
    timeout-minutes: 5
    steps: [{run: "echo"}]
EOF
cat > "$tmp/multi/.github/workflows/ci-release.yml" <<'EOF'
jobs:
  r:
    timeout-minutes: 15
    steps: [{run: "echo"}]
EOF
cat > "$tmp/multi/.github/workflows/ci-nightly.yml" <<'EOF'
jobs:
  n:
    timeout-minutes: 120
    steps: [{run: "echo"}]
EOF
# Max is 7 > 5 budget, so fail.
assert_rc 4 "$BUMP" --verify-timeouts --root "$tmp/multi"
assert_stdout_contains "timeout-minutes=7 > budget 5" "$BUMP" --verify-timeouts --root "$tmp/multi"

# ----- Scenario 8 — bad root exits 1 --------------------------------------
assert_rc 1 "$BUMP" --verify-timeouts --root "$tmp/no-such-dir"

# ---------------------------------------------------------------------------
echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
