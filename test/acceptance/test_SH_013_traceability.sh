#!/bin/sh
# test_SH_013_traceability.sh — CAPs↔test↔story bidirectional traceability.
# Story:  docs/stories/SH-013-caps-traceability.md
# Plan:   docs/plan/SH-013-caps-traceability-plan.md
# CAPs:   traceability.caps-have-test-pointer,
#         traceability.tests-name-known-caps,
#         traceability.stories-name-caps,
#         traceability.unified-make-target

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

assert_not_contains_any() { file=$1; needle=$2
  if [ -f "$file" ] && grep -Fq -- "$needle" "$file"; then
    fail=$((fail + 1)); echo "FAIL $file should not contain: $needle"
  else pass=$((pass + 1)); fi; }

# Resolve repo root relative to this script so the test is CWD-independent.
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
cd "$repo" || exit 1

SCRIPT=scripts/verify-traceability.sh

# ----- Scenario 1 — script exists and is executable ------------------------

assert_exists "$SCRIPT"
assert_executable "$SCRIPT"

# ----- Scenario 6 — # CAPs header convention across all acceptance tests ---
# (Checked early so the happy-path run below passes.)

for t in test/acceptance/test_SH_*.sh; do
  [ -f "$t" ] || continue
  # Skip self — this file carries the fixture strings in its assertions.
  case "$t" in */test_SH_013_traceability.sh) continue ;; esac
  # Accept `# CAPs:` or `# CAPs (part N):` — SH-009 uses the latter.
  if grep -Eq '^# CAPs(\s*\(.+\))?:' "$t"; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL $t has no '# CAPs:' header"; fi
  assert_not_contains_any "$t" "# Covers:"
done

# ----- Scenario 2 — happy path: real repo passes ---------------------------

if [ -x "$SCRIPT" ]; then
  assert_rc 0 "$SCRIPT"
fi

# ----- Fixture harness -----------------------------------------------------
# The negative scenarios build a scratch copy of the three inputs (CAPS file,
# a test file, a story file) in a tmpdir and point the script at it via
# REPO_ROOT. The script must honour REPO_ROOT so we never pollute the real
# tree.

run_on_fixture() {
  # Usage: run_on_fixture <tmpdir> → echoes exit code
  "$SCRIPT" --root "$1" >/dev/null 2>&1
  echo $?
}

# Build a minimal passing fixture tree, then each negative scenario mutates
# one file and asserts the script fails.

build_fixture_pass() {
  d=$1
  mkdir -p "$d/docs/specs" "$d/docs/stories" "$d/test/acceptance"
  cat > "$d/docs/specs/CAPABILITIES.md" <<'EOF'
# Capabilities

## Section

| CAP | Description | Source | Status | Test |
|---|---|---|---|---|
| `cap.one.pass` | First cap | SH-X | active | `test/acceptance/test_SH_X_one.sh` |
| `cap.two.pass` | Second cap | SH-X | active | `test/acceptance/test_SH_X_one.sh` |
EOF
  cat > "$d/test/acceptance/test_SH_X_one.sh" <<'EOF'
#!/bin/sh
# Story:  docs/stories/SH-X-one.md
# Plan:   docs/plan/SH-X-one-plan.md
# CAPs:   cap.one.pass, cap.two.pass
echo ok
EOF
  chmod +x "$d/test/acceptance/test_SH_X_one.sh"
  cat > "$d/docs/stories/SH-X-one.md" <<'EOF'
---
id: SH-X
slug: one
status: ready
created: 2026-11-22
---

# SH-X — One

## 9. Capabilities delivered or extended

- `cap.one.pass` — described
- `cap.two.pass` — described
EOF
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

if [ -x "$SCRIPT" ]; then
  # Baseline: fixture passes.
  build_fixture_pass "$tmp/pass"
  rc=$(run_on_fixture "$tmp/pass")
  if [ "$rc" = 0 ]; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL baseline fixture rc=$rc, want 0"; fi

  # ----- Scenario 3 — CAP without test pointer fails -----------------------
  build_fixture_pass "$tmp/cap-no-test"
  # Rewrite CAPABILITIES.md so cap.one.pass has an empty Test cell.
  cat > "$tmp/cap-no-test/docs/specs/CAPABILITIES.md" <<'EOF'
# Capabilities

| CAP | Description | Source | Status | Test |
|---|---|---|---|---|
| `cap.one.pass` | First cap | SH-X | active |  |
| `cap.two.pass` | Second cap | SH-X | active | `test/acceptance/test_SH_X_one.sh` |
EOF
  rc=$(run_on_fixture "$tmp/cap-no-test")
  if [ "$rc" != 0 ]; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL cap-no-test fixture rc=$rc, want non-zero"; fi

  # ----- Scenario 4 — test referencing an unknown CAP fails ----------------
  build_fixture_pass "$tmp/unknown-cap"
  sed -i 's|cap.one.pass, cap.two.pass|cap.one.pass, cap.does.not.exist|' \
    "$tmp/unknown-cap/test/acceptance/test_SH_X_one.sh"
  rc=$(run_on_fixture "$tmp/unknown-cap")
  if [ "$rc" != 0 ]; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL unknown-cap fixture rc=$rc, want non-zero"; fi

  # ----- Scenario 5 — ready+ story without §9 CAP bullets fails ------------
  build_fixture_pass "$tmp/orphan-story"
  # Strip the CAP bullets from §9.
  sed -i '/^- `cap\./d' "$tmp/orphan-story/docs/stories/SH-X-one.md"
  rc=$(run_on_fixture "$tmp/orphan-story")
  if [ "$rc" != 0 ]; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL orphan-story fixture rc=$rc, want non-zero"; fi
fi

# ---------------------------------------------------------------------------
echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
