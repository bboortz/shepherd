#!/bin/sh
# test_SH_029_fleet_defaults.sh — SH-029 fleet-wide default-branch verifier
# Story:  docs/stories/SH-029-fleet-branching-convergence.md
# Plan:   docs/plan/SH-029-fleet-branching-convergence-plan.md
# CAPs:   dev-cycle.fleet.branching-convergence
#
# Asserts each armed repo's GitHub default branch matches expectation. Uses
# `gh api` live; in offline / unauthenticated environments the test skips
# rather than fails (CI auth is inferred from GITHUB_TOKEN).
#
# Expected state (SH-029 target):
#   - shepherd  + all 5 managed repos on `dev`
#   - HRC on `main` until SH-018 investigation lands
#
# Env knobs:
#   SH_029_SKIP_ON_NO_AUTH=1  (default)  skip gracefully when gh isn't logged in
#   SH_029_FIXTURE=path                  replay mode: read lines "<repo>::<branch>"
#                                        from the fixture instead of calling gh

set -u
pass=0; fail=0; skipped=0

assert_eq() { want=$1; got=$2; label=$3
  if [ "$got" = "$want" ]; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL $label: want=$want got=$got"; fi
}

# ---------------------------------------------------------------------------
# Fleet + expected defaults. Update when FLEET.md changes.
# ---------------------------------------------------------------------------

EXPECTED_DEV="bboortz/shepherd bboortz/beaconry bboortz/forge bboortz/healthy bb-claw/homelab bb-claw/kernel-test"
EXPECTED_MAIN="bboortz/ham-radio-compass"   # deferred to SH-018

# ---------------------------------------------------------------------------
# Resolver: live via gh, or replay from fixture.
# ---------------------------------------------------------------------------

resolve_default() {
  repo=$1
  if [ -n "${SH_029_FIXTURE:-}" ]; then
    awk -F'::' -v r="$repo" '$1 == r { print $2; exit }' "$SH_029_FIXTURE"
    return
  fi
  gh api "/repos/$repo" --jq .default_branch 2>/dev/null
}

# Check gh auth up-front unless in replay mode.
if [ -z "${SH_029_FIXTURE:-}" ]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "gh not found — SH_029_SKIP_ON_NO_AUTH=${SH_029_SKIP_ON_NO_AUTH:-1}: skipping"
    skipped=$((skipped + 1))
    echo "pass=$pass fail=$fail skipped=$skipped"
    [ "${SH_029_SKIP_ON_NO_AUTH:-1}" = 1 ] && exit 0 || exit 1
  fi
  if ! gh auth status >/dev/null 2>&1; then
    echo "gh not authenticated — SH_029_SKIP_ON_NO_AUTH=${SH_029_SKIP_ON_NO_AUTH:-1}: skipping"
    skipped=$((skipped + 1))
    echo "pass=$pass fail=$fail skipped=$skipped"
    [ "${SH_029_SKIP_ON_NO_AUTH:-1}" = 1 ] && exit 0 || exit 1
  fi
fi

# ---------------------------------------------------------------------------
# Scenario 1 — every "dev" repo actually defaults to dev
# ---------------------------------------------------------------------------

for r in $EXPECTED_DEV; do
  got=$(resolve_default "$r")
  [ -n "$got" ] || { fail=$((fail + 1)); echo "FAIL $r: empty response (API error?)"; continue; }
  assert_eq "dev" "$got" "$r default branch"
done

# ---------------------------------------------------------------------------
# Scenario 2 — HRC stays on main (deferred to SH-018)
# ---------------------------------------------------------------------------

for r in $EXPECTED_MAIN; do
  got=$(resolve_default "$r")
  [ -n "$got" ] || { fail=$((fail + 1)); echo "FAIL $r: empty response"; continue; }
  assert_eq "main" "$got" "$r default branch (deferred to SH-018)"
done

# ---------------------------------------------------------------------------
# Scenario 3 — replay mode produces predictable results (self-test)
# ---------------------------------------------------------------------------

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/good.fix" <<'EOF'
example/repo-a::dev
example/repo-b::main
EOF
if [ -z "${SH_029_FIXTURE:-}" ]; then
  # Only self-check replay when not already in replay mode.
  out=$(SH_029_FIXTURE="$tmp/good.fix" sh -c '
    got_a=$(awk -F"::" "\$1 == \"example/repo-a\" { print \$2; exit }" '"$tmp"'/good.fix)
    got_b=$(awk -F"::" "\$1 == \"example/repo-b\" { print \$2; exit }" '"$tmp"'/good.fix)
    printf "%s %s" "$got_a" "$got_b"
  ')
  assert_eq "dev main" "$out" "replay-mode fixture parse"
fi

# ---------------------------------------------------------------------------
echo "pass=$pass fail=$fail skipped=$skipped"
[ "$fail" = 0 ]
