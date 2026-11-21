#!/bin/bash
# scan-not-worse.sh — diff two Trivy findings JSONs; fail if the PR adds new
# vulnerabilities at the monitored severity vs. the base.
#
# Used by SH-009 part-2 gate.scan-not-worse (the §12 gate).
#
# Dedupe key per advisory: (PkgName, VulnerabilityID) — stable enough that an
# advisory's CVSS metadata drift (same CVE, new CVSS vector) doesn't register
# as "added" or "removed".
#
# Usage:
#   scan-not-worse.sh <base-findings.json> <head-findings.json> [severity]
#
#   severity = HIGH,CRITICAL (default) or ALL
#
# Writes to stdout a single-line JSON summary:
#   {"added": N, "removed": M, "unchanged": K,
#    "added_ids": [...], "removed_ids": [...]}
#
# Exit codes:
#   0  added == 0 (PR does not make the scan worse)
#   2  added >  0 (PR introduces at least one new finding)
#   3  usage / IO error

set -eu

if [ $# -lt 2 ] || [ $# -gt 3 ]; then
  echo "usage: $0 <base-findings.json> <head-findings.json> [HIGH,CRITICAL|ALL]" >&2
  exit 3
fi
BASE=$1
HEAD=$2
SEV=${3:-HIGH,CRITICAL}

command -v jq >/dev/null || { echo "jq missing" >&2; exit 3; }
[ -f "$BASE" ] || { echo "no such file: $BASE" >&2; exit 3; }
[ -f "$HEAD" ] || { echo "no such file: $HEAD" >&2; exit 3; }

# Build severity filter for jq. ALL = accept everything.
case "$SEV" in
  ALL|all)
    sev_filter='true'
    ;;
  *)
    # Transform "HIGH,CRITICAL" → [\"HIGH\",\"CRITICAL\"]
    sev_list=$(printf '%s' "$SEV" | awk -F, '{for (i=1;i<=NF;i++) printf "\"%s\"%s", $i, (i<NF?",":""); }')
    sev_filter="(.Severity | ascii_upcase) as \$s | [${sev_list}] | index(\$s) != null"
    ;;
esac

ids_of() {
  jq -r --argjson _ 0 "[.Results[]? | .Vulnerabilities[]? | select(${sev_filter}) | \"\(.PkgName)::\(.VulnerabilityID)\"] | unique | .[]" "$1"
}

base_ids=$(ids_of "$BASE" | sort)
head_ids=$(ids_of "$HEAD" | sort)

# Set difference via comm (lines-only, sorted input).
added=$(comm -13 <(printf '%s\n' "$base_ids") <(printf '%s\n' "$head_ids") | sed '/^$/d')
removed=$(comm -23 <(printf '%s\n' "$base_ids") <(printf '%s\n' "$head_ids") | sed '/^$/d')
unchanged=$(comm -12 <(printf '%s\n' "$base_ids") <(printf '%s\n' "$head_ids") | sed '/^$/d')

count() { if [ -z "$1" ]; then echo 0; else printf '%s\n' "$1" | wc -l | tr -d ' '; fi; }
json_arr() {
  if [ -z "$1" ]; then echo '[]'; return; fi
  printf '%s\n' "$1" | jq -R . | jq -sc .
}

A=$(count "$added")
R=$(count "$removed")
U=$(count "$unchanged")

printf '{"added":%d,"removed":%d,"unchanged":%d,"added_ids":%s,"removed_ids":%s,"severity":"%s"}\n' \
  "$A" "$R" "$U" "$(json_arr "$added")" "$(json_arr "$removed")" "$SEV"

if [ "$A" -gt 0 ]; then exit 2; fi
exit 0
