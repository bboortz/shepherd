#!/bin/sh
# test_SH_030_verify_sha_pin.sh — shepherd-bump --verify-sha-pin (SH-030)
# Story:  docs/stories/SH-030-fleet-sha-pin-sweep.md
# Plan:   docs/plan/SH-030-fleet-sha-pin-sweep-plan.md
# CAPs:   supply-chain.verify-sha-pin
#
# Verifier scans .github/workflows/*.yml and .github/actions/**/action.yml for
# `uses:` refs. Any ref that is NOT a 40-hex SHA fails the check (exit 4).
# Dogfoods on shepherd itself (expected 0 violations).

set -u
pass=0; fail=0

assert_rc() { want=$1; shift; "$@" >/dev/null 2>&1; rc=$?
  if [ "$rc" = "$want" ]; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL want=$want got=$rc: $*"; fi; }

assert_stdout_contains() { needle=$1; shift
  out=$("$@" 2>&1 || true)
  if printf '%s' "$out" | grep -Fq -- "$needle"; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL output missing '$needle' from $*"
    printf '%s\n' "$out" | tail -3
  fi; }

assert_stdout_not_contains() { needle=$1; shift
  out=$("$@" 2>&1 || true)
  if ! printf '%s' "$out" | grep -Fq -- "$needle"; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL forbidden output '$needle' found from $*"; fi; }

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
cd "$repo" || exit 1

BUMP="$repo/bin/shepherd-bump"

[ -x "$BUMP" ] && pass=$((pass + 1)) || { fail=$((fail + 1)); echo "FAIL: $BUMP not executable — run 'make build' first"; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# ----- Scenario 1 — shepherd itself passes (dogfood) ----------------------
assert_rc 0 "$BUMP" --verify-sha-pin
assert_stdout_contains "ok (all uses: refs are SHA-pinned)" "$BUMP" --verify-sha-pin

# ----- Scenario 2 — clean fixture passes --------------------------------
mkdir -p "$tmp/clean/.github/workflows"
cat > "$tmp/clean/.github/workflows/ci.yml" <<'EOF'
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1
      - uses: actions/setup-node@abc1234567890abcdef1234567890abcdef12345  # v4.5.6
EOF
assert_rc 0 "$BUMP" --verify-sha-pin --root "$tmp/clean"

# ----- Scenario 3 — single mutable ref fails loud -----------------------
mkdir -p "$tmp/bad1/.github/workflows"
cat > "$tmp/bad1/.github/workflows/ci.yml" <<'EOF'
jobs:
  test:
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1
EOF
assert_rc 4 "$BUMP" --verify-sha-pin --root "$tmp/bad1"
assert_stdout_contains "actions/checkout@v4" "$BUMP" --verify-sha-pin --root "$tmp/bad1"
assert_stdout_contains ".github/workflows/ci.yml:4" "$BUMP" --verify-sha-pin --root "$tmp/bad1"
# The pinned ref must NOT be reported.
assert_stdout_not_contains "actions/setup-node@3d3c42e5" "$BUMP" --verify-sha-pin --root "$tmp/bad1"

# ----- Scenario 4 — multiple mutable refs count up ---------------------
mkdir -p "$tmp/bad2/.github/workflows"
cat > "$tmp/bad2/.github/workflows/ci.yml" <<'EOF'
jobs:
  test:
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - uses: actions/upload-artifact@main
EOF
assert_rc 4 "$BUMP" --verify-sha-pin --root "$tmp/bad2"
assert_stdout_contains "3 unpinned" "$BUMP" --verify-sha-pin --root "$tmp/bad2"

# ----- Scenario 5 — composite actions under .github/actions scanned ----
mkdir -p "$tmp/comp/.github/actions/my-action"
cat > "$tmp/comp/.github/actions/my-action/action.yml" <<'EOF'
runs:
  using: composite
  steps:
    - uses: actions/setup-python@v5
EOF
assert_rc 4 "$BUMP" --verify-sha-pin --root "$tmp/comp"
assert_stdout_contains ".github/actions/my-action/action.yml" "$BUMP" --verify-sha-pin --root "$tmp/comp"

# ----- Scenario 6 — internal reusable-workflow ref must still SHA-pin ---
# `uses: owner/repo/.github/workflows/foo.yml@<ref>` — the parser must treat
# the sub-path segments correctly and report @v1 as unpinned.
mkdir -p "$tmp/sub/.github/workflows"
cat > "$tmp/sub/.github/workflows/ci.yml" <<'EOF'
jobs:
  verify:
    uses: bboortz/shepherd/.github/workflows/reusable-shepherd-gates.yml@v1
EOF
assert_rc 4 "$BUMP" --verify-sha-pin --root "$tmp/sub"
assert_stdout_contains "@v1" "$BUMP" --verify-sha-pin --root "$tmp/sub"
assert_stdout_contains "reusable-shepherd-gates.yml" "$BUMP" --verify-sha-pin --root "$tmp/sub"

# ----- Scenario 7 — local path refs (./) exempt ----------------------
mkdir -p "$tmp/local/.github/workflows"
cat > "$tmp/local/.github/workflows/ci.yml" <<'EOF'
jobs:
  test:
    steps:
      - uses: ./.github/actions/my-action
      - uses: ./setup
EOF
assert_rc 0 "$BUMP" --verify-sha-pin --root "$tmp/local"

# ----- Scenario 8 — docker:// refs exempt --------------------------
mkdir -p "$tmp/docker/.github/workflows"
cat > "$tmp/docker/.github/workflows/ci.yml" <<'EOF'
jobs:
  test:
    steps:
      - uses: docker://alpine:3.19
EOF
assert_rc 0 "$BUMP" --verify-sha-pin --root "$tmp/docker"

# ----- Scenario 9 — no .github directory → clean -----------------
mkdir -p "$tmp/nogithub"
assert_rc 0 "$BUMP" --verify-sha-pin --root "$tmp/nogithub"

# ----- Scenario 10 — --root pointing at a non-existent dir fails loud ---
assert_rc 1 "$BUMP" --verify-sha-pin --root "$tmp/no-such-dir"

# ---------------------------------------------------------------------------
echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
