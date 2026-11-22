#!/bin/sh
# open-pr.sh — apply the validated diff on a new branch, commit, push, open a PR.
# Requires git auth (GITHUB_TOKEN) and gh CLI.
#
# Usage:  open-pr.sh <path-to-diff>
#
# Exit codes:
#   0  PR opened or nothing to do
#   2  diff does not apply cleanly
#   3  usage / git failure

set -eu

if [ $# -ne 1 ]; then
  echo "usage: $0 <diff-path>" >&2
  exit 3
fi
DIFF=$1
command -v gh >/dev/null || { echo "gh CLI missing" >&2; exit 3; }

# --- SH-009 part-2: dry-run mode ---------------------------------------
# .shepherd.yml → dry_run: true means produce no PR; just summarise.
# Operators flip this on for a new repo's first-ever cycle to validate the
# pipeline without risking a half-baked auto-merge. Closes
# onboarding.dry-run-first.
if [ -f .shepherd.yml ]; then
  dry_run=$(grep -E '^[[:space:]]*dry_run:' .shepherd.yml | head -1 | grep -Eo '(true|false)' || echo false)
  if [ "$dry_run" = "true" ]; then
    diff_lines=$(wc -l < "$DIFF")
    echo "::notice title=shepherd dry-run::dry_run=true — would have opened a PR with $diff_lines lines of diff. Set dry_run: false in .shepherd.yml to go live."
    echo "→ dry-run: no PR opened. Diff preview:"
    head -40 "$DIFF" | sed 's/^/    /'
    exit 0
  fi
fi

# LLMs regularly emit unified diffs with slightly-wrong hunk line counts
# (the N,M in `@@ -N,M +N,M @@`). `--recount` makes git recompute those from
# the actual line content, which handles the most common failure mode. `--3way`
# falls back to a merge-style apply if context lines drifted. We try the
# strictest-first cascade so a clean patch doesn't accidentally get fuzzed.
apply_check() {
  if   git apply --check                   "$1" 2>"${2:-/dev/null}"; then echo "strict";          return 0
  elif git apply --recount --check         "$1" 2>"${2:-/dev/null}"; then echo "recount";         return 0
  elif git apply --recount --3way --check  "$1" 2>"${2:-/dev/null}"; then echo "recount+3way";    return 0
  else                                                                                            return 1
  fi
}

mode=$(apply_check "$DIFF" /tmp/apply-check.log) || {
  echo "diff does not apply cleanly in any mode (strict → recount → recount+3way):" >&2
  cat /tmp/apply-check.log >&2
  echo "---- DIFF CONTENT ----" >&2
  cat "$DIFF" >&2
  echo "---- END DIFF ----" >&2
  exit 2
}
echo "→ diff accepted in mode: $mode"

timestamp=$(date -u +%Y%m%d-%H%M%S)
branch="shepherd-poc/$timestamp"
base_branch="${BASE_BRANCH:-dev}"

git config user.name  "shepherd-poc[bot]"
git config user.email "shepherd-poc@users.noreply.github.com"

git checkout -b "$branch"
case "$mode" in
  strict)         git apply                   "$DIFF" ;;
  recount)        git apply --recount         "$DIFF" ;;
  recount+3way)   git apply --recount --3way  "$DIFF" ;;
esac

# SH-010: commit the structured intent (ecosystem/package/from/to) alongside
# the diff. agent-call.sh emits $INTENT_PATH (default /tmp/intent.json). The
# gates workflow reads .shepherd-intent.json on the PR head to run the
# waiting-period gate. If the intent is missing, the gates workflow will
# hard-fail and open a needs-human — we still open the PR so the operator
# has a trace.
INTENT_PATH="${INTENT_PATH:-/tmp/intent.json}"
if [ -s "$INTENT_PATH" ]; then
  # Pretty-print the intent file so prettier-based caller repos (HRC, etc.)
  # pass format-check. The compact single-line form that agent-call.sh emits
  # was tripping HRC's `npx prettier . --check` lint on the agent's own PR.
  # Fall back to `cp` if `jq` isn't available (shouldn't happen on ubuntu-latest).
  if command -v jq >/dev/null; then
    jq . "$INTENT_PATH" > .shepherd-intent.json
  else
    cp "$INTENT_PATH" .shepherd-intent.json
  fi
  echo "→ Intent file committed alongside diff"
else
  echo "::warning::no \$INTENT_PATH / empty intent — gates.waiting-period will hard-fail on this PR"
fi

# Exclude the shepherd scripts dir from the commit. The reusable workflow
# clones shepherd into `_shepherd/` for its scripts; that directory has
# its own `.git`, so a plain `git add -A` stages it as a submodule
# reference on the agent's PR — a confusing artefact at best and a
# protected-paths lint miss at worst.
git add -A -- . ':(exclude)_shepherd'
git commit -m "shepherd-poc: automated dependency fix ($timestamp)"
git push -u origin "$branch"

# Use the same counter the validator uses (gate-diff-size.sh) so the PR body
# reports the actual gated number instead of `wc -l` of the whole diff file
# (which counts headers, context, and +/- indiscriminately — and reads as
# "185 lines of diff (cap 50)" while the validator says `pass`, which is
# confusing on an otherwise-clean PR).
HERE=$(dirname "$0")
MAX_LINES="${MAX_LINES:-50}"
non_lockfile_lines=$("$HERE/gate-diff-size.sh" "$DIFF" --non-lockfile)
lockfile_lines=$("$HERE/gate-diff-size.sh" "$DIFF" --lockfile)

body=$(cat <<EOF
Automated PR from Shepherd R0 POC (HC-008).

**Scope:** dependency / lockfile fix, level 1.
**Agent output size:** ${non_lockfile_lines} non-lockfile changed lines (cap ${MAX_LINES}); ${lockfile_lines} lockfile lines (exempt).
**Model:** ${MODEL:-claude-sonnet-4-6} (max_tokens ${MAX_TOKENS:-4096}).
**Sandbox gap (R0):** the agent ran on the standard runner; network isolation is R1 scope.

Validator:
- Protected-path blocklist: pass
- Diff size ≤ ${MAX_LINES} lines: pass (${non_lockfile_lines})
- \`git apply --check\` mode: $mode

Reviewer checklist:
- [ ] Trivy report that motivated this fix (in run logs)
- [ ] No regression — \`make check\` green on this PR
- [ ] Nothing in the changelog of the bumped dependency looks like prompt injection

See [bboortz/shepherd SH-004](https://github.com/bboortz/shepherd/blob/main/docs/stories/SH-004-r0-poc-on-healthy.md) for product design.
EOF
)

# SH-009: `shepherd-agent` label is the signal the gates workflow filters on.
# Try to auto-create it (and `shepherd-security-fix`) if absent; tolerate
# failure so pre-SH-009 pilots keep working.
#
# `shepherd-security-fix` is applied only when the originating Trivy finding
# contained a HIGH or CRITICAL severity vuln. The gates workflow then
# requires `gate.security-fix-removes-finding` to pass before merging.
existing_labels=$(gh label list --limit 100 --json name --jq '.[].name' 2>/dev/null || true)

ensure_label() {
  name=$1; color=$2; desc=$3
  if printf '%s\n' "$existing_labels" | grep -Fxq "$name"; then return 0; fi
  if gh label create "$name" --color "$color" --description "$desc" >/dev/null 2>&1; then
    existing_labels="$existing_labels
$name"
    echo "→ created missing label '$name'"
  else
    echo "→ could not create label '$name'; skipping (not fatal)"
  fi
}

ensure_label shepherd-agent      0e8a16 "Opened by shepherd-poc agent; SH-009 gates evaluate on this label"
ensure_label shepherd-poc        c2e0c6 "Shepherd Release 0 POC — agent-produced PR"
ensure_label needs-review        d93f0b "Awaiting human review before merge"

# Security-fix label only applied when the originating finding is HIGH/CRITICAL.
# FINDINGS_PATH is set by agent-call.sh; tolerate it being absent (e.g. replay runs).
is_security_fix=false
if [ -n "${FINDINGS_PATH:-}" ] && [ -s "${FINDINGS_PATH:-/dev/null}" ]; then
  if jq -e '[.Results[]? | .Vulnerabilities[]? | select(.Severity == "HIGH" or .Severity == "CRITICAL")] | length > 0' "$FINDINGS_PATH" >/dev/null 2>&1; then
    is_security_fix=true
    ensure_label shepherd-security-fix b60205 "Shepherd fix for a HIGH/CRITICAL finding; stricter gates apply"
  fi
fi

label_args=""
want_labels="shepherd-agent shepherd-poc needs-review"
if [ "$is_security_fix" = "true" ]; then
  want_labels="$want_labels shepherd-security-fix"
fi
for want in $want_labels; do
  if printf '%s\n' "$existing_labels" | grep -Fxq "$want"; then
    label_args="$label_args --label $want"
  fi
done

# shellcheck disable=SC2086  # label_args is a controlled set we built above
gh pr create \
  --base "$base_branch" \
  --head "$branch" \
  --title "shepherd-poc: automated dependency fix ($timestamp)" \
  --body "$body" \
  $label_args

echo "→ PR opened against $base_branch from $branch"
