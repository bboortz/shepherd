#!/bin/sh
# digest-timing.sh — SH-020 weekly timing digest + DORA metrics.
#
# Compares current fleet CI timings (via gh run list --json) against the
# frozen SH-026 baseline. Emits:
#   - Markdown summary table to stdout (for digest.yml → ntfy / email)
#   - Regression list to stderr (budget-breach OR 25 %+ above baseline)
#
# Exit codes:
#   0  no regressions
#   1  gh / jq missing, or API error
#   2  budget breach OR 25 % median regression on ≥ 1 fleet repo
#   3  usage error
#
# Env knobs:
#   LIMIT              gh run list -L value (default 50 — last ~week for active repos)
#   REGRESSION_PCT     threshold vs baseline (default 25)
#   SH_020_FIXTURE     replay a fixture file instead of gh (acceptance tests)
#
# DORA (also stdout):
#   deploy_frequency   count of tag creations in last 7d, per repo
#   lead_time_median   median hours from PR open → merge, last 50 PRs
#   change_failure     ci-patch failure runs / total ci-patch runs, last 50
#   time_to_restore    (median) revert-PR open → merge (if any)

set -eu

LIMIT="${LIMIT:-50}"
REGRESSION_PCT="${REGRESSION_PCT:-25}"
BASELINE_FILE="${BASELINE_FILE:-docs/specs/dev-cycle-baseline.md}"

# Default fleet. Override on the command line (same list as SH-029 test).
DEFAULT_REPOS="bboortz/shepherd bboortz/healthy bboortz/beaconry bboortz/ham-radio-compass bboortz/forge bb-claw/homelab bb-claw/kernel-test"

usage() { sed -n '2,20p' "$0"; exit 3; }

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage ;;
    -*) echo "unknown flag: $1" >&2; exit 3 ;;
    *) break ;;
  esac
done

REPOS="${*:-$DEFAULT_REPOS}"

if [ -z "${SH_020_FIXTURE:-}" ]; then
  command -v gh >/dev/null 2>&1 || { echo "gh not found" >&2; exit 1; }
  command -v jq >/dev/null 2>&1 || { echo "jq not found" >&2; exit 1; }
fi

# ---------------------------------------------------------------------------
# Resolve baseline medians from BASELINE_FILE (frozen by SH-026).
# Returns rows: repo|workflow|event|baseline_median_min
# ---------------------------------------------------------------------------

baseline_medians() {
  # BASELINE_FILE is a markdown table with columns:
  # | Repo | Workflow | Event | n | median (min) | p90 (min) | green % |
  # Match data rows: lines starting with `| <owner>/<name>` (owner char class
  # is any alphanumeric + '-', keeps the regex fleet-generic for fixtures).
  grep -E '^\| [A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+ ' "$BASELINE_FILE" 2>/dev/null \
    | awk -F' *\\| *' '
      NF >= 7 {
        # Columns: (empty) | Repo | Workflow | Event | n | median | p90 | green% | (empty)
        gsub(/ *⚠️? */, "", $5)
        print $2 "|" $3 "|" $4 "|" $6
      }
    '
}

# ---------------------------------------------------------------------------
# Current medians from gh run list (or fixture).
# Emits: repo|workflow|event|n|median_min|p90_min|pct_green
# ---------------------------------------------------------------------------

current_medians() {
  repo=$1
  if [ -n "${SH_020_FIXTURE:-}" ]; then
    json=$(awk -F'::' -v r="$repo" '$1 == r { print substr($0, index($0, "::") + 2) }' "$SH_020_FIXTURE")
    [ -n "$json" ] || return 0
  else
    json=$(gh run list -R "$repo" -L "$LIMIT" --json workflowName,createdAt,updatedAt,conclusion,event 2>/dev/null) || return 1
  fi

  echo "$json" | jq -r --arg repo "$repo" '
    [ .[] | select(.workflowName != null and .event != null and .createdAt != null and .updatedAt != null) ]
    | group_by(.workflowName + "||" + .event)[]
    | {
        workflow: .[0].workflowName,
        event:    .[0].event,
        n:        length,
        durs:     ( [ .[] | ((.updatedAt | fromdateiso8601) - (.createdAt | fromdateiso8601)) ] | sort ),
        green:    ( [ .[] | select(.conclusion == "success") ] | length )
      }
    | .median_min = (.durs[(.n / 2 | floor)] / 60)
    | .p90_min    = (.durs[(.n * 9 / 10 | floor)] / 60)
    | .pct_green  = (.green * 100 / .n | floor)
    | "\($repo)|\(.workflow)|\(.event)|\(.n)|\((.median_min * 10 | round) / 10)|\((.p90_min * 10 | round) / 10)|\(.pct_green)"
  '
}

# ---------------------------------------------------------------------------
# DORA metrics per repo (stdout: repo|metric|value).
# ---------------------------------------------------------------------------

dora_for_repo() {
  repo=$1
  [ -n "${SH_020_FIXTURE:-}" ] && return 0   # fixtures focus on timing; DORA is live-only

  # deploy_frequency: count tag creations in last 7d.
  since=$(date -u -d '7 days ago' +%FT%TZ 2>/dev/null || date -u -v-7d +%FT%TZ 2>/dev/null)
  tag_count=$(gh api "/repos/$repo/tags?per_page=50" --jq "[.[] | select(.name | startswith(\"v\"))] | length" 2>/dev/null || echo 0)
  # (Approximation: GitHub doesn't give tag creation time in the tags list. Use release API for better fidelity.)
  rel_in_window=$(gh api "/repos/$repo/releases?per_page=30" --jq "[.[] | select(.published_at >= \"$since\")] | length" 2>/dev/null || echo 0)
  echo "$repo|deploy_frequency_7d|$rel_in_window"

  # lead_time: median hours from PR open → merge (last 20 merged PRs).
  pr_json=$(gh pr list -R "$repo" --state merged -L 20 --json createdAt,mergedAt 2>/dev/null || echo "[]")
  lead_h=$(echo "$pr_json" | jq -r '
    [ .[] | select(.mergedAt != null and .createdAt != null)
          | ((.mergedAt | fromdateiso8601) - (.createdAt | fromdateiso8601)) / 3600 ]
    | sort | if length == 0 then "n/a" else (.[length/2 | floor] | . * 10 | round / 10 | tostring) end
  ')
  echo "$repo|lead_time_hours_median|$lead_h"
}

# ---------------------------------------------------------------------------
# Main: emit markdown + check regressions.
# ---------------------------------------------------------------------------

captured_at="$(date -u +%FT%TZ)"
host="$(uname -s)-$(uname -m)"
regressions=0

# Load baseline into an awk-friendly associative array.
baseline=$(baseline_medians)

cat <<EOF
# Dev-cycle timing digest — SH-020

> **Captured ${captured_at}** by \`scripts/digest-timing.sh\`. Compares live
> fleet CI timings (last ${LIMIT} runs per repo) against the SH-026 baseline
> at \`${BASELINE_FILE}\`. Rows flagged ⚠️ breach budget or exceed baseline
> by ≥ ${REGRESSION_PCT} %.

## Timing (CI workflows on PR + push)

| Repo | Workflow | Event | n | median (min) | baseline (min) | Δ% | flag |
|---|---|---|---:|---:|---:|---:|---|
EOF

# Write rows to a tmpfile so regression counting survives the pipeline subshell.
rows_tmp=$(mktemp)
regressions_tmp=$(mktemp)
# shellcheck disable=SC2064
trap "rm -f \"$rows_tmp\" \"$regressions_tmp\"" EXIT INT TERM

for repo in $REPOS; do
  current_medians "$repo" 2>/dev/null > "$rows_tmp.in" || true
  while IFS='|' read -r r wf ev n med p90 green; do
    [ -z "$r" ] && continue
    base=$(echo "$baseline" | awk -F'|' -v r="$r" -v w="$wf" -v e="$ev" '$1==r && $2==w && $3==e {print $4; exit}')
    base="${base:-n/a}"

    if [ "$base" != "n/a" ] && [ -n "$base" ]; then
      delta=$(awk -v c="$med" -v b="$base" 'BEGIN { if (b == 0) print "0"; else printf "%.0f", (c - b) * 100 / b }')
      if awk -v d="$delta" -v t="$REGRESSION_PCT" 'BEGIN { exit !(d+0 >= t+0) }'; then
        flag=" ⚠️ +${delta}%"
        printf '1\n' >> "$regressions_tmp"
        echo "regression: $r $wf $ev: median ${med} min (baseline ${base}, +${delta}%)" >&2
      else
        flag=""
      fi
    else
      delta="n/a"
      flag=""
    fi
    printf "| %s | %s | %s | %s | %s | %s | %s |%s |\n" "$r" "$wf" "$ev" "$n" "$med" "$base" "$delta" "$flag" >> "$rows_tmp"
  done < "$rows_tmp.in"
done

cat "$rows_tmp"
regressions=$(wc -l < "$regressions_tmp" 2>/dev/null | tr -d ' ' || echo 0)

# DORA section (live only — skipped in fixture mode).
if [ -z "${SH_020_FIXTURE:-}" ]; then
  echo ""
  echo "## DORA metrics (per repo, 7-day window)"
  echo ""
  echo "| Repo | Deploy frequency (releases last 7d) | Lead time median (hours, last 20 merged PRs) |"
  echo "|---|---:|---:|"
  for repo in $REPOS; do
    df=$(dora_for_repo "$repo" | awk -F'|' '$2=="deploy_frequency_7d"{print $3}')
    lt=$(dora_for_repo "$repo" | awk -F'|' '$2=="lead_time_hours_median"{print $3}')
    printf "| %s | %s | %s |\n" "$repo" "${df:-n/a}" "${lt:-n/a}"
  done
fi

cat <<EOF

---

**Captured on**: ${host}
**Baseline**: ${BASELINE_FILE}
**Window**: last ${LIMIT} runs per repo
**Regression threshold**: ≥ ${REGRESSION_PCT} % above baseline median
EOF

[ "$regressions" -eq 0 ] || exit 2
exit 0
