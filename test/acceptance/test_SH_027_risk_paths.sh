#!/bin/sh
# test_SH_027_risk_paths.sh — risk-paths gate matcher (SH-027)
# Story:  docs/stories/SH-027-risk-paths.md
# Plan:   docs/plan/SH-027-risk-paths-plan.md
# CAPs:   risk-paths.human-approval-required

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

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
cd "$repo" || exit 1

SCRIPT="$repo/scripts/shepherd-poc/gate-risk-paths.sh"

[ -x "$SCRIPT" ] && pass=$((pass + 1)) || { fail=$((fail + 1)); echo "FAIL: $SCRIPT not executable"; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# ----- Scenario 1 — no risk_paths configured → exit 0 ----------------------
cat > "$tmp/no-risk.yml" <<'EOF'
version: 1
risk: low
EOF
cat > "$tmp/files-any.txt" <<'EOF'
README.md
roles/network/main.yml
EOF
assert_rc 0 "$SCRIPT" "$tmp/no-risk.yml" "$tmp/files-any.txt"

# ----- Scenario 2 — risk_paths present but no match → exit 0 ---------------
cat > "$tmp/with-risk.yml" <<'EOF'
version: 1
risk_paths:
  - "roles/network/**"
  - "Dockerfile*"
EOF
cat > "$tmp/benign.txt" <<'EOF'
README.md
poc/hub/hub.py
EOF
assert_rc 0 "$SCRIPT" "$tmp/with-risk.yml" "$tmp/benign.txt"

# ----- Scenario 3 — one risk-path glob matches → exit 2 --------------------
cat > "$tmp/one-match.txt" <<'EOF'
README.md
roles/network/main.yml
poc/hub/hub.py
EOF
assert_rc 2 "$SCRIPT" "$tmp/with-risk.yml" "$tmp/one-match.txt"
assert_stdout_contains "roles/network/main.yml:roles/network/**" "$SCRIPT" "$tmp/with-risk.yml" "$tmp/one-match.txt"

# ----- Scenario 4 — multiple risk-path globs match → exit 2 ----------------
cat > "$tmp/multi-match.txt" <<'EOF'
roles/network/main.yml
Dockerfile.hub
poc/hub/hub.py
EOF
assert_rc 2 "$SCRIPT" "$tmp/with-risk.yml" "$tmp/multi-match.txt"
assert_stdout_contains "Dockerfile.hub:Dockerfile*" "$SCRIPT" "$tmp/with-risk.yml" "$tmp/multi-match.txt"

# ----- Scenario 5 — comments in config don't confuse parser ----------------
cat > "$tmp/with-comment.yml" <<'EOF'
version: 1
risk_paths:
  - "roles/network/**"   # critical; always human review
  - "Dockerfile*"        # image builds
EOF
assert_rc 2 "$SCRIPT" "$tmp/with-comment.yml" "$tmp/one-match.txt"

# ----- Scenario 6 — malformed config missing risk_paths → exit 0 ----------
cat > "$tmp/malformed.yml" <<'EOF'
version: 1
# no risk_paths at all
EOF
assert_rc 0 "$SCRIPT" "$tmp/malformed.yml" "$tmp/one-match.txt"

# ----- Scenario 7 — empty risk_paths block → exit 0 ------------------------
cat > "$tmp/empty-block.yml" <<'EOF'
version: 1
risk_paths: []
EOF
assert_rc 0 "$SCRIPT" "$tmp/empty-block.yml" "$tmp/one-match.txt"

# ----- Scenario 8 — usage error on missing args → exit 3 -------------------
assert_rc 3 "$SCRIPT"
assert_rc 3 "$SCRIPT" /only/one/arg

# ---------------------------------------------------------------------------
echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
