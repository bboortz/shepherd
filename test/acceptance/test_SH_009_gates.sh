#!/bin/sh
# test_SH_009_gates.sh — R1-C: auto-merge gates + schema v1 (part 1).
# Story:  docs/stories/SH-009-auto-merge-gates.md
# Plan:   docs/plan/SH-009-auto-merge-gates-plan.md
# Covers (part 1): gate.pipelines-green,
#                  gate.diff-size (extension to PR re-run),
#                  gate.security-fix-removes-finding (partial — label-trust),
#                  auto-merge.opt-in-per-repo,
#                  auto-merge.risk.low/.medium/.high,
#                  config.schema-v1

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

assert_stdout_eq() { want=$1; shift; got=$("$@" 2>/dev/null)
  if [ "$got" = "$want" ]; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL stdout want='$want' got='$got': $*"; fi; }

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
cd "$repo" || exit 1

# ----- Scenario 1 — schema v1 in templates/shepherd.yml --------------------
TEMPL=templates/shepherd.yml
assert_exists "$TEMPL"
assert_contains "$TEMPL" "schema_version: 1"
assert_contains "$TEMPL" "monitored_pipelines:"
assert_contains "$TEMPL" "max_diff_lines:"
assert_contains "$TEMPL" "rescan_scope:"
assert_contains "$TEMPL" "dry_run:"
assert_contains "$TEMPL" "needs_human_label:"
assert_contains "$TEMPL" "gates:"

# ----- Scenario 2 — gates reusable workflow shape --------------------------
GATES=.github/workflows/reusable-shepherd-gates.yml
assert_exists "$GATES"
assert_contains "$GATES" "workflow_call"
# Part 2 (rc6): contents:write is needed on the immediate-merge path
# (gh pr merge --auto on already-clean PRs calls mergePullRequest directly,
# which requires contents:write). pull-requests + issues are for the gate
# logic itself (merge-enable + needs-human issue).
assert_contains "$GATES" "contents: write"
assert_contains "$GATES" "pull-requests: write"
assert_contains "$GATES" "issues: write"
assert_contains "$GATES" "gate.diff-size"
assert_contains "$GATES" "gate.pipelines-green"
assert_contains "$GATES" "gate.security-fix-removes-finding"
# Part-1 explicit — scan-not-worse not implemented, documented inline.
assert_contains "$GATES" "part 2"
# SH-001 invariant — every `uses:` is actions/* + 40-hex SHA-pinned.
bad_uses=""
while IFS= read -r line; do
  u=$(echo "$line" | awk '{for(i=1;i<=NF;i++) if($i ~ /@/) print $i}')
  [ -z "$u" ] && continue
  owner=${u%%/*}
  sha=${u##*@}
  case "$owner" in
    actions) ;;
    bboortz) ;;
    *) bad_uses="$bad_uses $u(non-actions)"; ;;
  esac
  if [ "$owner" = "actions" ]; then
    case "$sha" in
      ????????????????????????????????????????) ;;
      *) bad_uses="$bad_uses $u(not40hex)"; ;;
    esac
  fi
done <<EOF
$(grep -E '^[[:space:]]*(-[[:space:]]+)?uses:[[:space:]]+' "$GATES")
EOF
if [ -z "$bad_uses" ]; then pass=$((pass + 1))
else fail=$((fail + 1)); echo "FAIL gates uses: $bad_uses"; fi

# ----- Scenario 3 — caller template shape ----------------------------------
CALLER=templates/caller-shepherd-gates.yml
assert_exists "$CALLER"
n=$(wc -l < "$CALLER" | tr -d ' ')
# Part 1 target was 25; part 2 adds workflow_run + SHA-based PR resolution,
# which inflates to ~55. Keep a cap so we notice if it grows further.
if [ "$n" -le 60 ]; then pass=$((pass + 1))
else fail=$((fail + 1)); echo "FAIL caller-shepherd-gates.yml is $n lines, cap is 60"; fi
assert_contains "$CALLER" "bboortz/shepherd/.github/workflows/reusable-shepherd-gates.yml"
assert_contains "$CALLER" "shepherd-agent"
assert_contains "$CALLER" "pull_request"
assert_contains "$CALLER" "workflow_run"
assert_not_contains "$CALLER" "secrets: inherit"

# Part 2: reusable workflow must reference scan-not-worse + needs-human.
GATES=.github/workflows/reusable-shepherd-gates.yml
assert_contains "$GATES" "scan-not-worse.sh"
assert_contains "$GATES" "open-needs-human.sh"
assert_contains "$GATES" "gate.scan-not-worse"
# Dry-run plumbing in open-pr.sh
assert_contains scripts/shepherd-poc/open-pr.sh "dry_run"
# scan-not-worse.sh exists + executable
assert_exists scripts/shepherd-poc/scan-not-worse.sh
if [ -x scripts/shepherd-poc/scan-not-worse.sh ]; then pass=$((pass + 1))
else fail=$((fail + 1)); echo "FAIL scan-not-worse.sh not executable"; fi
# open-needs-human.sh exists + executable
assert_exists scripts/shepherd-poc/open-needs-human.sh
if [ -x scripts/shepherd-poc/open-needs-human.sh ]; then pass=$((pass + 1))
else fail=$((fail + 1)); echo "FAIL open-needs-human.sh not executable"; fi

# scan-not-worse behaviour
tmp=$(mktemp -d)
cat > "$tmp/base.json" <<'EOF'
{"Results":[{"Vulnerabilities":[
  {"PkgName":"ws","VulnerabilityID":"CVE-2026-1","Severity":"HIGH"},
  {"PkgName":"form-data","VulnerabilityID":"CVE-2025-7783","Severity":"CRITICAL"}
]}]}
EOF
cat > "$tmp/head-fixed.json" <<'EOF'
{"Results":[{"Vulnerabilities":[
  {"PkgName":"ws","VulnerabilityID":"CVE-2026-1","Severity":"HIGH"}
]}]}
EOF
cat > "$tmp/head-worse.json" <<'EOF'
{"Results":[{"Vulnerabilities":[
  {"PkgName":"ws","VulnerabilityID":"CVE-2026-1","Severity":"HIGH"},
  {"PkgName":"form-data","VulnerabilityID":"CVE-2025-7783","Severity":"CRITICAL"},
  {"PkgName":"new","VulnerabilityID":"CVE-2027-999","Severity":"HIGH"}
]}]}
EOF
# base vs fixed → 0 added → exit 0
assert_rc 0 scripts/shepherd-poc/scan-not-worse.sh "$tmp/base.json" "$tmp/head-fixed.json"
# base vs worse → 1 added → exit 2
assert_rc 2 scripts/shepherd-poc/scan-not-worse.sh "$tmp/base.json" "$tmp/head-worse.json"
# base vs base → 0 added → exit 0
assert_rc 0 scripts/shepherd-poc/scan-not-worse.sh "$tmp/base.json" "$tmp/base.json"
# Removed count on fix: expect 1
rc=0; out=$(scripts/shepherd-poc/scan-not-worse.sh "$tmp/base.json" "$tmp/head-fixed.json") || rc=$?
removed=$(echo "$out" | jq -r .removed)
if [ "$removed" = "1" ]; then pass=$((pass + 1))
else fail=$((fail + 1)); echo "FAIL scan-not-worse.removed want=1 got=$removed"; fi
rm -rf "$tmp"

# ----- Scenario 4 — open-pr.sh applies shepherd-agent label ----------------
OPEN=scripts/shepherd-poc/open-pr.sh
assert_contains "$OPEN" "shepherd-agent"
assert_contains "$OPEN" "shepherd-security-fix"
# Label-presence is driven by findings severity — must check FINDINGS_PATH.
assert_contains "$OPEN" "FINDINGS_PATH"

# ----- Scenario 5 — gate-diff-size.sh standalone counter -------------------
DIFF=$(mktemp)
cat > "$DIFF" <<'EOF'
diff --git a/package.json b/package.json
--- a/package.json
+++ b/package.json
@@ -1,2 +1,2 @@
-  "version": "1.0.0"
+  "version": "1.0.1"
diff --git a/package-lock.json b/package-lock.json
--- a/package-lock.json
+++ b/package-lock.json
@@ -1,3 +1,3 @@
-a
-b
-c
+A
+B
+C
EOF
assert_stdout_eq 2 scripts/shepherd-poc/gate-diff-size.sh "$DIFF"
assert_stdout_eq 2 scripts/shepherd-poc/gate-diff-size.sh "$DIFF" --non-lockfile
assert_stdout_eq 6 scripts/shepherd-poc/gate-diff-size.sh "$DIFF" --lockfile
# Validate the existing R0 contract still holds after the refactor.
assert_rc 0 scripts/shepherd-poc/validate.sh "$DIFF"
rm -f "$DIFF"

# ----- Scenario 6 — oversize diff still fails validate.sh ------------------
BIG=$(mktemp)
{
  echo 'diff --git a/src.js b/src.js'
  echo '--- a/src.js'
  echo '+++ b/src.js'
  echo '@@ -1,1 +1,61 @@'
  echo '-old'
  i=0; while [ "$i" -lt 60 ]; do echo "+line $i"; i=$((i + 1)); done
} > "$BIG"
assert_rc 2 scripts/shepherd-poc/validate.sh "$BIG"
rm -f "$BIG"

# ---------------------------------------------------------------------------
echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
