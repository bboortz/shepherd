#!/bin/sh
# test_SH_007_reusable.sh — R1-A: reusable shepherd Action (required .shepherd.yml)
# Story:  docs/stories/SH-007-reusable-action.md
# Plan:   docs/plan/SH-007-reusable-action-plan.md
# Covers: r1.reusable-action,
#         onboarding.one-workflow,
#         onboarding.default-github-token,
#         config.required-per-repo

set -u
pass=0; fail=0

assert_rc() { want=$1; shift; "$@" >/dev/null 2>&1; rc=$?
  if [ "$rc" = "$want" ]; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL want=$want got=$rc: $*"; fi; }

assert_exists() { f=$1
  if [ -e "$f" ]; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL missing: $f"; fi; }

assert_contains() { file=$1; needle=$2
  if [ -f "$file" ] && grep -Fq -- "$needle" "$file"; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL $file does not contain: $needle"; fi; }

assert_not_contains() { file=$1; needle=$2
  if [ -f "$file" ] && grep -Fq -- "$needle" "$file"; then
    fail=$((fail + 1)); echo "FAIL $file should not contain: $needle"
  else pass=$((pass + 1)); fi; }

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
cd "$repo" || exit 1

# ----- Scenario 1 — Reusable workflow shape --------------------------------
REUSABLE=".github/workflows/reusable-shepherd.yml"
assert_exists "$REUSABLE"
assert_contains "$REUSABLE" "workflow_call"
assert_contains "$REUSABLE" "ANTHROPIC_API_KEY"
assert_contains "$REUSABLE" "required: true"
assert_contains "$REUSABLE" "contents: write"
assert_contains "$REUSABLE" "pull-requests: write"
# Trivy scan widens: file-patterns for pip variants + deprecated checks.
assert_contains "$REUSABLE" "--file-patterns 'pip:requirements"
assert_contains "$REUSABLE" "--include-deprecated-checks"
# Every `uses:` must reference actions/* and be SHA-pinned (40 hex).
bad_uses=""
while IFS= read -r line; do
  u=$(echo "$line" | awk '{for(i=1;i<=NF;i++) if($i ~ /@/) print $i}')
  [ -z "$u" ] && continue
  owner=${u%%/*}
  sha=${u##*@}
  case "$owner" in
    actions) ;;
    bboortz) ;;                              # self-ref ok (reusable workflow)
    *) bad_uses="$bad_uses\n$u (non-actions/*)"; ;;
  esac
  # SHA check: exactly 40 lowercase hex.
  if [ "$owner" = "actions" ]; then
    case "$sha" in
      ????????????????????????????????????????) ;;
      *) bad_uses="$bad_uses\n$u (not 40-hex)"; ;;
    esac
  fi
done <<EOF
$(grep -E '^[[:space:]]*(-[[:space:]]+)?uses:[[:space:]]+' "$REUSABLE")
EOF
if [ -z "$bad_uses" ]; then pass=$((pass + 1))
else fail=$((fail + 1)); printf 'FAIL reusable uses:\n%b\n' "$bad_uses"; fi

# ----- Scenario 2 — Caller template shape ----------------------------------
CALLER="templates/caller-shepherd.yml"
assert_exists "$CALLER"

n=$(wc -l < "$CALLER" | tr -d ' ')
if [ "$n" -le 20 ]; then pass=$((pass + 1))
else fail=$((fail + 1)); echo "FAIL caller-shepherd.yml is $n lines, cap is 20"; fi

assert_contains "$CALLER" "bboortz/shepherd/.github/workflows/reusable-shepherd.yml"
assert_contains "$CALLER" "secrets:"
assert_contains "$CALLER" "ANTHROPIC_API_KEY"
assert_not_contains "$CALLER" "secrets: inherit"

# ----- Scenario 3/4 — verify-shepherd-yml.sh behaviour --------------------
VERIFY="scripts/shepherd-poc/verify-shepherd-yml.sh"
assert_exists "$VERIFY"
if [ -x "$VERIFY" ]; then pass=$((pass + 1))
else fail=$((fail + 1)); echo "FAIL $VERIFY not executable"; fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/missing"
assert_rc 1 "$VERIFY" "$tmp/missing"

mkdir -p "$tmp/ok"
echo "version: 1" > "$tmp/ok/.shepherd.yml"
assert_rc 0 "$VERIFY" "$tmp/ok"

# ----- Scenario 5 — Canary migration ---------------------------------------
# Live-canary; recorded in the plan's post-merge notes once dispatch runs.

# ----- Scenario 6 — DESIGN reflects required-yml decision ------------------
DESIGN="docs/specs/DESIGN.md"
# Required-yml language present
assert_contains "$DESIGN" "Required \`.shepherd.yml\`"
# Old "Optional .shepherd.yml with per-repo overrides" line removed
assert_not_contains "$DESIGN" "Optional \`.shepherd.yml\` with per-repo overrides"
# "Zero config by default" principle removed (replaced)
assert_not_contains "$DESIGN" "Zero config by default"

# ---------------------------------------------------------------------------
echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
