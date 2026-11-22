#!/bin/sh
# open-needs-human.sh — open (or comment on) a needs-human issue on the caller
# repo when a gate fails or shepherd needs operator attention.
#
# Dedupe: existing open issues with a title matching `[shepherd] gate <GATE>
# on PR #<N>` get a new comment instead of a duplicate issue.
#
# Usage:
#   open-needs-human.sh <gate> <pr_number> <reason> [extra_lines_file]
#
# Env (set by caller):
#   GH_TOKEN   — needed by gh CLI
#   REPO       — owner/repo
#
# Exit codes:
#   0  issue opened or comment posted
#   3  usage / IO error
#   4  gh CLI missing or env unset

set -eu

if [ $# -lt 3 ] || [ $# -gt 4 ]; then
  echo "usage: $0 <gate> <pr_number> <reason> [extra_lines_file]" >&2
  exit 3
fi
GATE=$1
PR_NUMBER=$2
REASON=$3
EXTRA=${4:-}

: "${REPO:?REPO must be set (owner/repo)}"
command -v gh >/dev/null || { echo "gh CLI missing" >&2; exit 4; }

# Pre-PR escalations (e.g. agent diff malformed before open-pr.sh ran) set
# PR_NUMBER=0; the title + dedupe key swap to a PR-less form for that case.
if [ "$PR_NUMBER" = "0" ]; then
  title="[shepherd] $GATE (pre-PR)"
  pr_line="**PR:** _(none — failure happened before open-pr.sh)_"
  dedupe_key="$GATE@pre-pr"
else
  title="[shepherd] gate $GATE on PR #$PR_NUMBER"
  pr_line="**PR:** #$PR_NUMBER"
  dedupe_key="$GATE@$PR_NUMBER"
fi
body="**Gate:** \`$GATE\`
$pr_line
**Reason:** $REASON

See the [shepherd workflow runs](https://github.com/$REPO/actions) for the full log.

Dedupe key: \`$dedupe_key\`."

if [ -n "$EXTRA" ] && [ -s "$EXTRA" ]; then
  body="$body

<details>
<summary>Context</summary>

\`\`\`
$(cat "$EXTRA")
\`\`\`
</details>"
fi

# Look for an existing open issue with the same title (= dedupe key).
existing=$(gh issue list -R "$REPO" --state open --search "\"$title\" in:title" --json number --jq '.[0].number' 2>/dev/null || true)

if [ -n "$existing" ] && [ "$existing" != "null" ]; then
  gh issue comment "$existing" -R "$REPO" --body "$body" >/dev/null
  echo "needs-human: commented on existing issue #$existing"
else
  gh issue create -R "$REPO" \
    --title "$title" \
    --body "$body" \
    --label "needs-human" >/dev/null 2>&1 || {
      # Label may not exist; retry without it.
      gh issue create -R "$REPO" \
        --title "$title" \
        --body "$body"
    }
  echo "needs-human: opened new issue '$title'"
fi
