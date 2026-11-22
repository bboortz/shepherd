#!/bin/sh
# test_SH_017_verify_contract.sh — shepherd-bump --verify-contract
# Story:  docs/stories/SH-017-verify-contract.md
# Plan:   docs/plan/SH-017-verify-contract-plan.md
# CAPs:   dev-cycle.fleet.verify-contract

set -u
pass=0; fail=0

assert_rc() { want=$1; shift; "$@" >/dev/null 2>&1; rc=$?
  if [ "$rc" = "$want" ]; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL want=$want got=$rc: $*"; fi; }

assert_stdout_contains() { needle=$1; shift
  out=$("$@" 2>&1 || true)
  if printf '%s' "$out" | grep -Fq -- "$needle"; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL output missing '$needle' from: $*"
    printf '%s\n' "$out" | tail -3
  fi; }

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
cd "$repo" || exit 1

BUMP="$repo/bin/shepherd-bump"

# ----- Scenario 1 — binary exists + help lists --verify-contract -----------

[ -x "$BUMP" ] && pass=$((pass + 1)) || { fail=$((fail + 1)); echo "FAIL: $BUMP not built"; }
assert_stdout_contains "--verify-contract" "$BUMP" --help

# ----- Scenario 2 — shepherd itself passes verify-contract -----------------

assert_rc 0 "$BUMP" --verify-contract --root "$repo"
assert_stdout_contains "verify-contract: ok" "$BUMP" --verify-contract --root "$repo"

# ----- Fixture harness ------------------------------------------------------

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# ----- Scenario 3 — missing Makefile → exit 3 ------------------------------

mkdir -p "$tmp/no-makefile"
assert_rc 3 "$BUMP" --verify-contract --root "$tmp/no-makefile"
assert_stdout_contains "Makefile is missing" "$BUMP" --verify-contract --root "$tmp/no-makefile"

# ----- Scenario 4 — Makefile missing some targets → exit 4 ----------------

mkdir -p "$tmp/partial"
cat > "$tmp/partial/Makefile" <<'EOF'
build:
	@echo build

test:
	@echo test

# Missing: test-affected, smoke, release-artifacts, ci-branch, ci-patch, ci-release, ci-nightly
EOF
assert_rc 4 "$BUMP" --verify-contract --root "$tmp/partial"
assert_stdout_contains "missing target \`ci-branch\`" "$BUMP" --verify-contract --root "$tmp/partial"
assert_stdout_contains "missing target \`smoke\`" "$BUMP" --verify-contract --root "$tmp/partial"

# ----- Scenario 5 — Makefile with all targets → exit 0 --------------------

mkdir -p "$tmp/complete"
cat > "$tmp/complete/Makefile" <<'EOF'
.PHONY: build test test-affected smoke release-artifacts ci-branch ci-patch ci-release ci-nightly

build:      ; @echo build
test:       ; @echo test
test-affected: test
smoke:      test
release-artifacts: build
ci-branch:  ; @echo ci-branch
ci-patch:   ; @echo ci-patch
ci-release: ; @echo ci-release
ci-nightly: ; @echo ci-nightly
EOF
assert_rc 0 "$BUMP" --verify-contract --root "$tmp/complete"
assert_stdout_contains "9/9 contract targets present" "$BUMP" --verify-contract --root "$tmp/complete"

# ----- Scenario 6 — opt-out via .shepherd.yml → exit 0 --------------------

mkdir -p "$tmp/opt-out"
cat > "$tmp/opt-out/.shepherd.yml" <<'EOF'
version: 1
contract:
  enforce_enabled: false
EOF
# Deliberately NO Makefile — opt-out short-circuits before the file check.
assert_rc 0 "$BUMP" --verify-contract --root "$tmp/opt-out"
assert_stdout_contains "opted out via .shepherd.yml" "$BUMP" --verify-contract --root "$tmp/opt-out"

# ----- Scenario 7 — section-aware opt-out: dependabot false ≠ contract --

mkdir -p "$tmp/dependabot-only-off"
cat > "$tmp/dependabot-only-off/.shepherd.yml" <<'EOF'
version: 1
dependabot:
  enforce_enabled: false
contract:
  enforce_enabled: true
EOF
# Contract is still enforced; missing Makefile → exit 3.
assert_rc 3 "$BUMP" --verify-contract --root "$tmp/dependabot-only-off"

# ----- Scenario 8 — .PHONY-only declaration also counts -----------------

mkdir -p "$tmp/phony-only"
cat > "$tmp/phony-only/Makefile" <<'EOF'
.PHONY: build test test-affected smoke release-artifacts ci-branch ci-patch ci-release ci-nightly
# No recipe bodies — just the PHONY declaration counts for presence.
EOF
assert_rc 0 "$BUMP" --verify-contract --root "$tmp/phony-only"

# ---------------------------------------------------------------------------
echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
