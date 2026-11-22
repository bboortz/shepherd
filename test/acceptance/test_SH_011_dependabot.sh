#!/bin/sh
# test_SH_011_dependabot.sh — Dependabot baseline: enforce + opt-in gated auto-merge
# Story:  docs/stories/SH-011-dependabot-enforce-automerge.md
# Plan:   docs/plan/SH-011-dependabot-enforce-automerge-plan.md
# CAPs: dependabot.presence-verified,
#         dependabot.config-enforce-opt-in,
#         dependabot.auto-merge-opt-in-per-repo,
#         dependabot.auto-merge-level-patch-minor,
#         gate.diff-size (extension),
#         gate.waiting-period (partial: npm + gh-actions),
#         supply-chain.no-third-party-actions-critical-path (extended)

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

assert_regex_count() { file=$1; regex=$2; want=$3
  n=$(grep -Ec -- "$regex" "$file" 2>/dev/null || echo 0)
  if [ "$n" -ge "$want" ]; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL $file regex /$regex/ matched $n, want >= $want"; fi; }

# Resolve repo root relative to this script so the test is CWD-independent.
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
cd "$repo" || exit 1

BUMP="$repo/bin/shepherd-bump"

# ----- Scenario 1 — templates ship the shepherd side of the baseline -------

# templates/shepherd.yml carries the dependabot block.
assert_exists templates/shepherd.yml
assert_contains templates/shepherd.yml "dependabot:"
assert_contains templates/shepherd.yml "enforce_enabled:"
assert_contains templates/shepherd.yml "auto_merge:"

# templates/dependabot.yml — reference baseline.
assert_exists templates/dependabot.yml
assert_contains templates/dependabot.yml "version: 2"
assert_contains templates/dependabot.yml "- package-ecosystem:"

# templates/dependabot-automerge.yml — workflow template.
assert_exists templates/dependabot-automerge.yml
assert_contains templates/dependabot-automerge.yml "dependabot[bot]"
assert_contains templates/dependabot-automerge.yml "gh pr merge"

# SH-001 invariant: no dependabot/fetch-metadata anywhere in the template.
assert_not_contains templates/dependabot-automerge.yml "dependabot/fetch-metadata"

# SH-001 invariant: every `uses:` must be under actions/* and SHA-pinned (40 hex).
# Extract every non-commented `uses:` line and verify shape.
bad_uses=$(grep -E '^[[:space:]]*(-[[:space:]]+)?uses:[[:space:]]+' templates/dependabot-automerge.yml \
  | awk '{for(i=1;i<=NF;i++) if($i ~ /@/) print $i}')
if [ -z "$bad_uses" ]; then
  pass=$((pass + 1))  # no uses: lines at all is acceptable; workflow may be pure `run:`.
else
  all_ok=1
  for u in $bad_uses; do
    owner=${u%%/*}
    sha=${u##*@}
    # owner must be "actions" (GitHub-native namespace).
    case "$owner" in
      actions) ;;
      *) all_ok=0; echo "FAIL non-actions uses: $u"; break ;;
    esac
    # SHA must be 40 lowercase hex.
    case "$sha" in
      *[!0-9a-f]* | "" ) all_ok=0; echo "FAIL non-40-hex sha in $u"; break ;;
      ?????????????????????????????????????????) all_ok=0; echo "FAIL sha too long in $u"; break ;;
      ????????????????????????????????????????) ;;
      *) all_ok=0; echo "FAIL sha wrong length in $u"; break ;;
    esac
  done
  if [ "$all_ok" = 1 ]; then pass=$((pass + 1))
  else fail=$((fail + 1)); fi
fi

# Patch/minor gate: the classification logic must consider both.
assert_contains templates/dependabot-automerge.yml "patch"
assert_contains templates/dependabot-automerge.yml "minor"

# Every `gh pr view` / `gh pr merge` must pass -R; the workflow has no
# git checkout, so gh needs the repo explicit. Skip comment lines.
bad_gh=$(grep -nE 'gh pr (view|merge)' templates/dependabot-automerge.yml \
  | grep -vE '^[0-9]+:[[:space:]]*#' \
  | grep -v -- '-R ' || true)
if [ -z "$bad_gh" ]; then pass=$((pass + 1))
else fail=$((fail + 1)); echo "FAIL gh pr view/merge without -R:"; echo "$bad_gh"; fi

# The jq regex embedded in the workflow must be a valid jq regex. We can't
# execute the full workflow here, but we can lift the LOCK_RE line and test
# it against a fixture to catch jq escape-parsing bugs at build time.
if command -v jq >/dev/null 2>&1; then
  lock_re=$(grep -E "^[[:space:]]*LOCK_RE=" templates/dependabot-automerge.yml \
    | head -1 | sed -E "s/^[[:space:]]*LOCK_RE=//; s/^'//; s/'$//")
  if [ -n "$lock_re" ] && \
     printf '{"files":[{"path":"package-lock.json","additions":1,"deletions":1},{"path":"pyproject.toml","additions":1,"deletions":1}]}' \
     | jq --argjson _ 0 "[.files[] | select(.path | test(\"$lock_re\") | not) | (.additions + .deletions)] | add // 0" \
     >/dev/null 2>&1; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1)); echo "FAIL LOCK_RE is not a valid jq regex: $lock_re"
  fi
fi

# Release-date lookup: npm + pip + github_actions covered.
assert_contains templates/dependabot-automerge.yml "registry.npmjs.org"
assert_contains templates/dependabot-automerge.yml "pypi.org"
assert_contains templates/dependabot-automerge.yml "releases/tags"

# ----- Scenario 2/3/4/5 — verify-dependabot exit codes ---------------------

assert_exists "$BUMP"
# bin may not exist on first red run — only assert further if the binary is there.
if [ -x "$BUMP" ]; then
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT

  # Scenario 2: missing .github/dependabot.yml → exit 3
  mkdir -p "$tmp/missing"
  assert_rc 3 "$BUMP" --verify-dependabot --root "$tmp/missing"

  # Scenario 3: well-formed config → exit 0
  mkdir -p "$tmp/ok/.github"
  cat > "$tmp/ok/.github/dependabot.yml" <<'EOF'
version: 2
updates:
  - package-ecosystem: github-actions
    directory: "/"
    schedule:
      interval: weekly
EOF
  assert_rc 0 "$BUMP" --verify-dependabot --root "$tmp/ok"

  # Scenario 4a: empty file → exit 4
  mkdir -p "$tmp/empty/.github"
  : > "$tmp/empty/.github/dependabot.yml"
  assert_rc 4 "$BUMP" --verify-dependabot --root "$tmp/empty"

  # Scenario 4b: version: 1 (deprecated) → exit 4
  mkdir -p "$tmp/v1/.github"
  cat > "$tmp/v1/.github/dependabot.yml" <<'EOF'
version: 1
update_configs:
  - package_manager: "javascript"
    directory: "/"
    update_schedule: "weekly"
EOF
  assert_rc 4 "$BUMP" --verify-dependabot --root "$tmp/v1"

  # Scenario 4c: no updates entry → exit 4
  mkdir -p "$tmp/noupdates/.github"
  cat > "$tmp/noupdates/.github/dependabot.yml" <<'EOF'
version: 2
EOF
  assert_rc 4 "$BUMP" --verify-dependabot --root "$tmp/noupdates"

  # Scenario 5: enforce_enabled: false opts out even with no dependabot.yml → exit 0
  mkdir -p "$tmp/optout"
  cat > "$tmp/optout/.shepherd.yml" <<'EOF'
version: 1
risk: low
dependabot:
  enforce_enabled: false
  auto_merge: false
EOF
  assert_rc 0 "$BUMP" --verify-dependabot --root "$tmp/optout"
else
  # Binary not built — expected on the first red run.
  fail=$((fail + 1)); echo "FAIL $BUMP missing / not executable (expected red before implementation)"
fi

# ---------------------------------------------------------------------------
echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
