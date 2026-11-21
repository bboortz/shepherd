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

title="[shepherd] gate $GATE on PR #$PR_NUMBER"
body="**Gate:** \`$GATE\`
**PR:** #$PR_NUMBER
**Reason:** $REASON

See the [shepherd gates workflow run](https://github.com/$REPO/actions) for the full log.

Dedupe key: \`$GATE@$PR_NUMBER\`."

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
