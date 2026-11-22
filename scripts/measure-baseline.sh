#!/bin/sh
# measure-baseline.sh — SH-026 one-shot freeze of pre-adoption fleet CI timings.
#
# Pulls `gh run list --json workflowName,createdAt,updatedAt,conclusion,event`
# for each fleet repo, computes median + p90 wall-clock + pct_green per
# (repo, workflow, event) tuple, and emits a markdown table to stdout.
#
# Usage:
#   scripts/measure-baseline.sh                  # fleet defaults, markdown to stdout
#   scripts/measure-baseline.sh bboortz/forge    # one repo only
#   LIMIT=200 scripts/measure-baseline.sh > out.md
#   MIN_SAMPLES=5 scripts/measure-baseline.sh    # lower warning threshold
#   SH_026_SAMPLE_FILE=... scripts/measure-baseline.sh  # replay fixture (no gh call)
#
# Env knobs:
#   LIMIT              gh run list -L value (default 100)
#   MIN_SAMPLES        warn (exit 2) if any (repo,wf,event) has fewer (default 10)
#   SH_026_SAMPLE_FILE replay a JSON file per repo (for tests); format:
#                      $repo::$json where the script reads one line per repo.
#
# Exit codes:
#   0  all repos returned samples; no (repo,wf,event) tuple below MIN_SAMPLES
#   1  tool missing (gh or jq) or API error on any repo
#   2  at least one (repo,wf,event) tuple has < MIN_SAMPLES samples
#   3  usage error (bad flag)

set -eu

usage() {
  sed -n '2,25p' "$0"
  exit 3
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage ;;
    -*) echo "unknown flag: $1" >&2; exit 3 ;;
    *) break ;;
  esac
done

LIMIT="${LIMIT:-100}"
MIN_SAMPLES="${MIN_SAMPLES:-10}"

# Fleet defaults — updated when docs/FLEET.md changes. Positional args override.
DEFAULT_REPOS="bboortz/shepherd bboortz/healthy bboortz/beaconry bboortz/ham-radio-compass bboortz/forge bb-claw/homelab bb-claw/kernel-test"

if [ $# -gt 0 ]; then
  REPOS="$*"
else
  REPOS="$DEFAULT_REPOS"
fi

# Verify tool chain unless we're running in replay mode.
if [ -z "${SH_026_SAMPLE_FILE:-}" ]; then
  command -v gh >/dev/null 2>&1 || { echo "gh not found" >&2; exit 1; }
  command -v jq >/dev/null 2>&1 || { echo "jq not found" >&2; exit 1; }
fi

captured_at="$(date -u +%FT%TZ)"
host="$(uname -s)-$(uname -m)"
warn=0
error=0

# Emit markdown header.
cat <<EOF
# Dev-cycle baseline — frozen snapshot of pre-adoption fleet timings

> **Captured $captured_at by \`scripts/measure-baseline.sh\`.** Re-run on the
> same day produces slightly different numbers (new runs since capture time);
> this snapshot is the reference for SH-022 / SH-023 / SH-024 Shipping evidence
> tables. See \`docs/stories/SH-026-baseline-capture.md\`.

**Scope**: $LIMIT most-recent runs per repo; wall-clock computed as
\`(updatedAt - createdAt)\` in minutes; median = sorted[n/2];
p90 = sorted[(int)(n × 0.9)]; pct_green = count(conclusion="success") × 100 / n.

**MIN_SAMPLES threshold**: $MIN_SAMPLES. Rows below the threshold are flagged ⚠️.

| Repo | Workflow | Event | n | median (min) | p90 (min) | green % |
|---|---|---|---:|---:|---:|---:|
EOF

for repo in $REPOS; do
  if [ -n "${SH_026_SAMPLE_FILE:-}" ]; then
    json=$(awk -F'::' -v r="$repo" '$1 == r { print substr($0, index($0, "::") + 2) }' "$SH_026_SAMPLE_FILE")
    [ -n "$json" ] || continue
  else
    json=$(gh run list -R "$repo" -L "$LIMIT" --json workflowName,createdAt,updatedAt,conclusion,event 2>/dev/null) || {
      printf '| %s | — | — | 0 | — | — | — |\n' "$repo"
      error=1
      continue
    }
  fi

  # jq script:
  # - group by (workflowName, event)
  # - compute durations_sec per entry
  # - emit one line per group with: repo | workflow | event | n | median_min | p90_min | pct_green
  echo "$json" | jq -r --arg repo "$repo" --argjson min "$MIN_SAMPLES" '
    [ .[] | select(.workflowName != null and .event != null and .createdAt != null and .updatedAt != null) ]
    | group_by(.workflowName + "||" + .event)[]
    | {
        workflow: .[0].workflowName,
        event:    .[0].event,
        n:        length,
        durs:     ( [ .[] | ( (.updatedAt | fromdateiso8601) - (.createdAt | fromdateiso8601) ) ] | sort ),
        green:    ( [ .[] | select(.conclusion == "success") ] | length )
      }
    | .median_min = (.durs[(.n / 2 | floor)] / 60)
    | .p90_min    = (.durs[(.n * 9 / 10 | floor)] / 60)
    | .pct_green  = (.green * 100 / .n | floor)
    | .flag       = (if .n < $min then " ⚠️" else "" end)
    | "| \($repo) | \(.workflow) | \(.event) | \(.n)\(.flag) | \((.median_min * 10 | round) / 10) | \((.p90_min * 10 | round) / 10) | \(.pct_green) |"
  '

  # Did any tuple fall below MIN_SAMPLES? (Second jq pass over the same data.)
  below=$(echo "$json" | jq --argjson min "$MIN_SAMPLES" '
    [ .[] | select(.workflowName != null and .event != null) ]
    | group_by(.workflowName + "||" + .event)
    | map(select(length < $min))
    | length
  ')
  if [ "${below:-0}" -gt 0 ]; then
    warn=$((warn + 1))
  fi
done

# Footer with host + run context so re-runs are diff-friendly.
cat <<EOF

---

**Captured on**: $host
**Tool chain**: gh $(gh --version 2>/dev/null | head -1), jq $(jq --version 2>/dev/null)
EOF

if [ "$error" -gt 0 ]; then
  echo "measure-baseline: at least one repo failed API lookup" >&2
  exit 1
fi
if [ "$warn" -gt 0 ]; then
  echo "measure-baseline: $warn repo(s) had tuples below MIN_SAMPLES=$MIN_SAMPLES" >&2
  exit 2
fi
exit 0
