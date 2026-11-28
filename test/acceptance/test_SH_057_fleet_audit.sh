#!/bin/sh
# test_SH_057_fleet_audit.sh — SH-057 repeatable fleet audit
# Story:  docs/stories/SH-057-fleet-audit.md
# Plan:   docs/plan/SH-057-fleet-audit-plan.md
# CAPs:   fleet.audit.repeatable
#
# Runs the audit --offline only. The live `gh` path is exercised by the
# operator at `make fleet-audit` time, never in CI (needs network + auth).

set -u
pass=0; fail=0

assert_rc() { want=$1; shift; "$@" >/dev/null 2>&1; rc=$?
  if [ "$rc" = "$want" ]; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL want=$want got=$rc: $*"; fi; }

assert_file_has() { f=$1; pat=$2
  if grep -Fq -- "$pat" "$f"; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL '$f' missing '$pat'"; fi; }

assert_file_lacks() { f=$1; pat=$2
  if grep -Fq -- "$pat" "$f"; then fail=$((fail + 1)); echo "FAIL '$f' unexpectedly has '$pat'"
  else pass=$((pass + 1)); fi; }

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
cd "$repo" || exit 1

SCRIPT="$repo/scripts/fleet-audit.sh"
FLEET="$repo/docs/FLEET.md"

# ----- Scenario 1 — script exists + executable --------------------------
assert_rc 0 test -f "$SCRIPT"
assert_rc 0 test -x "$SCRIPT"

# ----- Scenario 2 — offline run → full structure, exit 0 ----------------
OUT=$(mktemp)
trap 'rm -f "$OUT"' EXIT
assert_rc 0 "$SCRIPT" --offline --out "$OUT"
assert_file_has "$OUT" "## Verdict"
assert_file_has "$OUT" "## Arming matrix"
assert_file_has "$OUT" "## Best-practice conformance matrix"
assert_file_has "$OUT" "## Pipeline health"
assert_file_has "$OUT" "## Findings"
assert_file_has "$OUT" "## Appendix — method"

# ----- Scenario 3 — repo list parsed from FLEET.md, not hardcoded -------
# Every owner/repo in FLEET.md's Active table must appear as a matrix row.
"$SCRIPT" --offline --out "$OUT" >/dev/null 2>&1
repos=$(awk '
  /^## Active/        {inactive=1; next}
  /^## /              {inactive=0}
  inactive && /^\| *\[`/ {
    if (match($0, /`[^`]+`/)) { s=substr($0, RSTART+1, RLENGTH-2); print s }
  }' "$FLEET")
if [ -z "$repos" ]; then
  fail=$((fail + 1)); echo "FAIL could not parse any repo from FLEET.md Active table"
else
  for r in $repos; do assert_file_has "$OUT" "$r"; done
fi

# ----- Scenario 4 — live-only cells render skip (⏭), never fail (❌) -----
"$SCRIPT" --offline --out "$OUT" >/dev/null 2>&1
assert_file_has  "$OUT" "⏭"
assert_file_has  "$OUT" "INCONCLUSIVE"
# No matrix data row (a table line naming a fleet repo) may carry ❌ offline.
if grep -E '^\|.*(bboortz|bb-claw)/' "$OUT" | grep -q '❌'; then
  fail=$((fail + 1)); echo "FAIL offline data row carries ❌ (should be ⏭)"
else pass=$((pass + 1)); fi

# ----- Scenario 5 — Makefile exposes fleet-audit + resolves -------------
phony=$(awk '/^\.PHONY:/{flag=1} flag{printf "%s ", $0; if ($0 !~ /\\$/) {print ""; flag=0}}' Makefile)
if printf '%s' "$phony" | grep -Fq "fleet-audit"; then pass=$((pass + 1))
else fail=$((fail + 1)); echo "FAIL .PHONY missing fleet-audit"; fi
if grep -qE '^fleet-audit:' Makefile; then pass=$((pass + 1))
else fail=$((fail + 1)); echo "FAIL Makefile missing 'fleet-audit:' target"; fi
assert_rc 0 make -n fleet-audit
if make -n fleet-audit 2>&1 | grep -Fq "scripts/fleet-audit.sh"; then pass=$((pass + 1))
else fail=$((fail + 1)); echo "FAIL 'make -n fleet-audit' doesn't invoke the script"; fi

# ----- Scenario 6 — empty FLEET.md Active table does not crash ----------
tmp=$(mktemp -d)
mkdir -p "$tmp/docs"
printf '# Fleet\n\n## Active\n\n*None yet.*\n\n## Archived\n' > "$tmp/docs/FLEET.md"
OUT2="$tmp/out.md"
"$SCRIPT" --offline --fleet "$tmp/docs/FLEET.md" --out "$OUT2" >/dev/null 2>&1
rc=$?
if [ "$rc" = 0 ]; then pass=$((pass + 1))
else fail=$((fail + 1)); echo "FAIL empty-FLEET: expected exit 0, got $rc"; fi
assert_file_has "$OUT2" "No repositories parsed"
rm -rf "$tmp"

# ----- Scenario 7 — custom FLEET.md proves non-hardcoding ---------------
tmp2=$(mktemp -d)
mkdir -p "$tmp2/docs"
cat > "$tmp2/docs/FLEET.md" <<'EOF'
# Fleet

## Active

| Repo | Release line | Onboarded |
|---|---|---|
| [`acme/widget`](https://github.com/acme/widget) | R1 | 2026-11-28 |
| [`acme/gadget`](https://github.com/acme/gadget) | R1 | 2026-11-28 |

## Archived
EOF
OUT3="$tmp2/out.md"
"$SCRIPT" --offline --fleet "$tmp2/docs/FLEET.md" --out "$OUT3" >/dev/null 2>&1
assert_file_has "$OUT3" "acme/widget"
assert_file_has "$OUT3" "acme/gadget"
assert_file_lacks "$OUT3" "bboortz/healthy"
rm -rf "$tmp2"

# ------------------------------------------------------------------------
echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
