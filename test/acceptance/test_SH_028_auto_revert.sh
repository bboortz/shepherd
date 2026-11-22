#!/bin/sh
# test_SH_028_auto_revert.sh — auto-revert decision logic (SH-028)
# Story:  docs/stories/SH-028-auto-revert-patch.md
# Plan:   docs/plan/SH-028-auto-revert-patch-plan.md
# CAPs:   auto-revert.patch-tier

set -u
pass=0; fail=0

assert_rc() { want=$1; shift; "$@" >/dev/null 2>&1; rc=$?
  if [ "$rc" = "$want" ]; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL want=$want got=$rc: $*"; fi; }

assert_stdout_eq() { want=$1; shift
  got=$("$@" 2>&1 | head -1 || true)
  if [ "$got" = "$want" ]; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL want='$want' got='$got': $*"; fi; }

assert_stdout_contains() { needle=$1; shift
  out=$("$@" 2>&1 || true)
  if printf '%s' "$out" | grep -Fq -- "$needle"; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL output missing '$needle' from $*"
    printf '%s\n' "$out" | tail -3
  fi; }

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
cd "$repo" || exit 1

SCRIPT="$repo/scripts/shepherd-poc/auto-revert.sh"

[ -x "$SCRIPT" ] && pass=$((pass + 1)) || { fail=$((fail + 1)); echo "FAIL: $SCRIPT not executable"; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Benign file list — used across scenarios.
cat > "$tmp/benign.txt" <<'EOF'
README.md
poc/hub/hub.py
src/feature/compass.ts
EOF

# Blocklist-touching file list.
cat > "$tmp/blocklist.txt" <<'EOF'
README.md
.github/workflows/ci.yml
poc/hub/hub.py
EOF

# ----- Scenario 1 — auto_revert absent → SKIP:disabled --------------------
cat > "$tmp/no-revert.yml" <<'EOF'
version: 1
risk: low
EOF
assert_stdout_eq "SKIP:disabled" "$SCRIPT" decide "$tmp/no-revert.yml" "$tmp/benign.txt"

# ----- Scenario 2 — auto_revert.enabled: false → SKIP:disabled ------------
cat > "$tmp/revert-off.yml" <<'EOF'
version: 1
auto_revert:
  enabled: false
  comment_only: true
EOF
assert_stdout_eq "SKIP:disabled" "$SCRIPT" decide "$tmp/revert-off.yml" "$tmp/benign.txt"

# ----- Scenario 3 — enabled + default comment_only → REVERT:comment-only --
cat > "$tmp/revert-default.yml" <<'EOF'
version: 1
auto_revert:
  enabled: true
EOF
assert_stdout_eq "REVERT:comment-only" "$SCRIPT" decide "$tmp/revert-default.yml" "$tmp/benign.txt"

# ----- Scenario 4 — enabled + comment_only: true → REVERT:comment-only ----
cat > "$tmp/revert-co.yml" <<'EOF'
version: 1
auto_revert:
  enabled: true
  comment_only: true
EOF
assert_stdout_eq "REVERT:comment-only" "$SCRIPT" decide "$tmp/revert-co.yml" "$tmp/benign.txt"

# ----- Scenario 5 — enabled + comment_only: false → REVERT:auto-merge -----
cat > "$tmp/revert-am.yml" <<'EOF'
version: 1
auto_revert:
  enabled: true
  comment_only: false
EOF
assert_stdout_eq "REVERT:auto-merge" "$SCRIPT" decide "$tmp/revert-am.yml" "$tmp/benign.txt"

# ----- Scenario 6 — enabled but revert would touch blocklist → SKIP -------
# Default blocklist applies (no explicit `blocklist:` block in .shepherd.yml).
assert_stdout_eq "SKIP:touches-blocklist" "$SCRIPT" decide "$tmp/revert-am.yml" "$tmp/blocklist.txt"
assert_stdout_contains ".github/workflows/ci.yml" "$SCRIPT" decide "$tmp/revert-am.yml" "$tmp/blocklist.txt"

# ----- Scenario 7 — explicit blocklist overrides default + matches --------
cat > "$tmp/revert-custom-block.yml" <<'EOF'
version: 1
auto_revert:
  enabled: true
  comment_only: false
blocklist:
  - "poc/hub/**"
EOF
assert_stdout_eq "SKIP:touches-blocklist" "$SCRIPT" decide "$tmp/revert-custom-block.yml" "$tmp/benign.txt"

# ----- Scenario 8 — comments in config don't confuse parser ---------------
cat > "$tmp/revert-comments.yml" <<'EOF'
version: 1
auto_revert:
  enabled: true        # opt-in
  comment_only: false  # phase-2
EOF
assert_stdout_eq "REVERT:auto-merge" "$SCRIPT" decide "$tmp/revert-comments.yml" "$tmp/benign.txt"

# ----- Scenario 9 — execute usage errors → exit 3 -------------------------
assert_rc 3 "$SCRIPT" execute
assert_rc 3 "$SCRIPT" execute abc1234
assert_rc 3 "$SCRIPT" execute abc1234 bogus-mode

# ----- Scenario 10 — decide usage errors → exit 3 -------------------------
assert_rc 3 "$SCRIPT" decide
assert_rc 3 "$SCRIPT" decide "$tmp/revert-am.yml"

# ----- Scenario 11 — unknown subcommand → exit 3 --------------------------
assert_rc 3 "$SCRIPT" wat

# ---------------------------------------------------------------------------
echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
