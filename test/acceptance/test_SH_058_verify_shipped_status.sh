#!/bin/sh
# test_SH_058_verify_shipped_status.sh — SH-058 released-story-must-be-shipped
# Story:  docs/stories/SH-058-verify-shipped-status.md
# Plan:   docs/plan/SH-058-verify-shipped-status-plan.md
# CAPs:   dev-cycle.verify-shipped-status

set -u
pass=0; fail=0

assert_rc() { want=$1; shift; "$@" >/dev/null 2>&1; rc=$?
  if [ "$rc" = "$want" ]; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL want=$want got=$rc: $*"; fi; }

assert_grep() { pattern=$1; shift
  if "$@" 2>&1 | grep -Fq -- "$pattern"; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL output missing '$pattern' from $*"; fi; }

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
cd "$repo" || exit 1

SCRIPT="$repo/scripts/verify-shipped-status.sh"
STORY="$repo/docs/stories/SH-057-fleet-audit.md"

# ----- Scenario 1 — script exists + executable --------------------------
assert_rc 0 test -f "$SCRIPT"
assert_rc 0 test -x "$SCRIPT"

# ----- Scenario 2 — shepherd itself passes (dogfood) --------------------
assert_rc 0 "$SCRIPT"
assert_grep "ok (every CHANGELOG-released story is shipped)" "$SCRIPT"

# ----- Scenario 3 — released-but-unshipped story fails ------------------
# SH-057 is named in the v0.11.0-rc1 heading. Flip it to in-progress.
cp "$STORY" /tmp/sh-058-story.bak
trap 'cp /tmp/sh-058-story.bak "$STORY"; rm -f /tmp/sh-058-story.bak' EXIT
sed -i 's/^status: shipped/status: in-progress/' "$STORY"
assert_rc 1 "$SCRIPT"
assert_grep "SH-057" "$SCRIPT"
assert_grep "v0.11.0-rc1" "$SCRIPT"
cp /tmp/sh-058-story.bak "$STORY"

# ----- Scenario 4 — [Unreleased] section is exempt ----------------------
tmp=$(mktemp -d)
mkdir -p "$tmp/scripts" "$tmp/docs/stories"
cp "$SCRIPT" "$tmp/scripts/"
cat > "$tmp/CHANGELOG.md" <<'EOF'
# Changelog

## [Unreleased]

SH-999 in flight.

## [v1.0.0] — 2026-11-28 — SH-001 something
EOF
printf -- '---\nid: SH-999\nstatus: in-progress\n---\n# SH-999\n' > "$tmp/docs/stories/SH-999-wip.md"
printf -- '---\nid: SH-001\nstatus: shipped\n---\n# SH-001\n' > "$tmp/docs/stories/SH-001-done.md"
( cd "$tmp" && ./scripts/verify-shipped-status.sh ) >/dev/null 2>&1
if [ "$?" = 0 ]; then pass=$((pass + 1))
else fail=$((fail + 1)); echo "FAIL [Unreleased] SH-999 should be exempt"; fi

# ----- Scenario 5 — heading-named story with no file is skipped ---------
cat > "$tmp/CHANGELOG.md" <<'EOF'
# Changelog

## [v1.0.0] — 2026-11-28 — SH-998 ghost story (no file)
EOF
( cd "$tmp" && ./scripts/verify-shipped-status.sh ) >/dev/null 2>&1
if [ "$?" = 0 ]; then pass=$((pass + 1))
else fail=$((fail + 1)); echo "FAIL missing-file SH-998 should be skipped"; fi

# ----- Scenario 5b — released + unshipped + file present → fail ---------
cat > "$tmp/CHANGELOG.md" <<'EOF'
# Changelog

## [v1.0.0] — 2026-11-28 — SH-999 shipped it
EOF
( cd "$tmp" && ./scripts/verify-shipped-status.sh ) >/dev/null 2>&1
if [ "$?" = 1 ]; then pass=$((pass + 1))
else fail=$((fail + 1)); echo "FAIL released SH-999 in-progress should fail"; fi

# ----- Scenario 6 — no-op when CHANGELOG absent -------------------------
rm -f "$tmp/CHANGELOG.md"
( cd "$tmp" && ./scripts/verify-shipped-status.sh ) >/dev/null 2>&1
if [ "$?" = 0 ]; then pass=$((pass + 1))
else fail=$((fail + 1)); echo "FAIL no-CHANGELOG guard should exit 0"; fi
rm -rf "$tmp"

# ----- Scenario 7 — Makefile wiring -------------------------------------
phony=$(awk '/^\.PHONY:/{flag=1} flag{printf "%s ", $0; if ($0 !~ /\\$/) {print ""; flag=0}}' Makefile)
if printf '%s' "$phony" | grep -Fq "verify-shipped-status"; then pass=$((pass + 1))
else fail=$((fail + 1)); echo "FAIL .PHONY missing verify-shipped-status"; fi
if grep -qE '^verify-shipped-status:' Makefile; then pass=$((pass + 1))
else fail=$((fail + 1)); echo "FAIL Makefile missing 'verify-shipped-status:' target"; fi
if grep -qE '^check-docs:.* verify-shipped-status' Makefile; then pass=$((pass + 1))
else fail=$((fail + 1)); echo "FAIL check-docs doesn't depend on verify-shipped-status"; fi
assert_rc 0 make -n verify-shipped-status
assert_grep "scripts/verify-shipped-status.sh" make -n verify-shipped-status

# ------------------------------------------------------------------------
echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
