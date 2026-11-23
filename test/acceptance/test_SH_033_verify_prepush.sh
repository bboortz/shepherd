#!/bin/sh
# test_SH_033_verify_prepush.sh — shepherd-bump --verify-prepush (SH-033)
# Story:  docs/stories/SH-033-fleet-prepush-convergence.md
# Plan:   docs/plan/SH-033-fleet-prepush-convergence-plan.md
# CAPs:   dev-cycle.prepush.verify
#
# Verifier ensures a pre-push gate wired to `make check` exists in the repo.
# Accepts two shapes:
#   - .pre-commit-config.yaml with a hook: entry (contains) `make check` +
#     stages: [pre-push]
#   - .husky/pre-push script containing `make check`
# Opt-out: `.shepherd.yml → dev_cycle.prepush_enforce: false`.

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
assert_rc 0 "$BUMP" --verify-prepush
assert_stdout_contains "ok" "$BUMP" --verify-prepush

# ----- Scenario 2 — clean pre-commit config passes ------------------------
mkdir -p "$tmp/good"
cat > "$tmp/good/.pre-commit-config.yaml" <<'EOF'
repos:
  - repo: local
    hooks:
      - id: make-check
        name: make check pre-push
        language: system
        entry: make check
        pass_filenames: false
        stages: [pre-push]
EOF
assert_rc 0 "$BUMP" --verify-prepush --root "$tmp/good"

# ----- Scenario 3 — pre-commit with wrapped entry (bash -c) passes --------
mkdir -p "$tmp/wrap"
cat > "$tmp/wrap/.pre-commit-config.yaml" <<'EOF'
repos:
  - repo: local
    hooks:
      - id: make-check
        name: make check pre-push
        language: system
        entry: bash -c 'source .venv/bin/activate && make check'
        pass_filenames: false
        stages: [pre-push]
EOF
assert_rc 0 "$BUMP" --verify-prepush --root "$tmp/wrap"

# ----- Scenario 4 — pre-commit present but no pre-push hook fails ---------
mkdir -p "$tmp/no-pp"
cat > "$tmp/no-pp/.pre-commit-config.yaml" <<'EOF'
repos:
  - repo: local
    hooks:
      - id: lint
        name: lint only
        language: system
        entry: make lint
        pass_filenames: false
EOF
assert_rc 4 "$BUMP" --verify-prepush --root "$tmp/no-pp"
assert_stdout_contains "no hook with" "$BUMP" --verify-prepush --root "$tmp/no-pp"

# ----- Scenario 5 — pre-commit with pre-push but wrong entry fails --------
mkdir -p "$tmp/wrong"
cat > "$tmp/wrong/.pre-commit-config.yaml" <<'EOF'
repos:
  - repo: local
    hooks:
      - id: version-bump
        name: version bump
        language: system
        entry: bash scripts/verify-version.sh
        pass_filenames: false
        stages: [pre-push]
EOF
assert_rc 4 "$BUMP" --verify-prepush --root "$tmp/wrong"

# ----- Scenario 6 — husky pre-push with make check passes -----------------
mkdir -p "$tmp/husky/.husky"
cat > "$tmp/husky/.husky/pre-push" <<'EOF'
#!/bin/sh
. "$(dirname "$0")/_/husky.sh"
make check
EOF
chmod +x "$tmp/husky/.husky/pre-push"
assert_rc 0 "$BUMP" --verify-prepush --root "$tmp/husky"
assert_stdout_contains ".husky/pre-push" "$BUMP" --verify-prepush --root "$tmp/husky"

# ----- Scenario 7 — husky pre-push without make check fails ---------------
mkdir -p "$tmp/husky-bad/.husky"
cat > "$tmp/husky-bad/.husky/pre-push" <<'EOF'
#!/bin/sh
npm test
EOF
assert_rc 4 "$BUMP" --verify-prepush --root "$tmp/husky-bad"

# ----- Scenario 7b — .githooks/pre-push with make check passes (SH-043) --
mkdir -p "$tmp/githooks/.githooks"
cat > "$tmp/githooks/.githooks/pre-push" <<'EOF'
#!/bin/bash
set -euo pipefail
make check
EOF
chmod +x "$tmp/githooks/.githooks/pre-push"
assert_rc 0 "$BUMP" --verify-prepush --root "$tmp/githooks"
assert_stdout_contains ".githooks/pre-push" "$BUMP" --verify-prepush --root "$tmp/githooks"

# ----- Scenario 7c — .githooks/pre-push without make check fails ---------
mkdir -p "$tmp/githooks-bad/.githooks"
cat > "$tmp/githooks-bad/.githooks/pre-push" <<'EOF'
#!/bin/bash
echo only-prints
EOF
chmod +x "$tmp/githooks-bad/.githooks/pre-push"
assert_rc 4 "$BUMP" --verify-prepush --root "$tmp/githooks-bad"

# ----- Scenario 8 — no config at all → exit 3 -----------------------------
mkdir -p "$tmp/nothing"
assert_rc 3 "$BUMP" --verify-prepush --root "$tmp/nothing"
assert_stdout_contains "no pre-push config found" "$BUMP" --verify-prepush --root "$tmp/nothing"
assert_stdout_contains ".githooks/pre-push" "$BUMP" --verify-prepush --root "$tmp/nothing"

# ----- Scenario 9 — opt-out via .shepherd.yml → exit 0 --------------------
mkdir -p "$tmp/optout"
cat > "$tmp/optout/.shepherd.yml" <<'EOF'
version: 1
dev_cycle:
  prepush_enforce: false
EOF
assert_rc 0 "$BUMP" --verify-prepush --root "$tmp/optout"
assert_stdout_contains "opted out" "$BUMP" --verify-prepush --root "$tmp/optout"

# ----- Scenario 10 — opt-out only honoured inside dev_cycle: block --------
# A bare `prepush_enforce: false` outside dev_cycle: must NOT opt out.
mkdir -p "$tmp/fakeopt"
cat > "$tmp/fakeopt/.shepherd.yml" <<'EOF'
version: 1
dependabot:
  prepush_enforce: false
EOF
assert_rc 3 "$BUMP" --verify-prepush --root "$tmp/fakeopt"

# ----- Scenario 11 — bad root exits 1 ------------------------------------
assert_rc 1 "$BUMP" --verify-prepush --root "$tmp/no-such-dir"

# ---------------------------------------------------------------------------
echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
