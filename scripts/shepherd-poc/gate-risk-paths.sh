#!/bin/sh
# gate-risk-paths.sh — SH-027 standalone matcher (used by reusable-shepherd-gates.yml
# in the workflow; shipped as a script so test_SH_027_risk_paths.sh can
# exercise the parse + match logic offline).
#
# Usage:
#   gate-risk-paths.sh <shepherd.yml> <files-list.txt>
#
# shepherd.yml:  path to a .shepherd.yml fixture. Reads `risk_paths:` block-list
#                globs (indented `- glob` entries) or returns empty if absent.
# files-list:    path to a text file with one changed-file path per line.
#
# Behaviour:
#   - For each glob × file, emit matches on stdout as `<file>:<glob>` (one per line).
#   - Exit 0 if no matches; exit 2 if ≥1 match.
#   - Exit 3 on usage error.
#
# This script is called by reusable-shepherd-gates.yml inline (via the
# awk + case loop in that workflow); the standalone form exists for
# testability.

set -eu

cfg="${1:-}"
files="${2:-}"
[ -n "$cfg" ] && [ -n "$files" ] || {
  echo "usage: $0 <shepherd.yml> <files-list.txt>" >&2
  exit 3
}

# Extract risk_paths block-list entries.
risk_paths_raw=$(awk '
  /^risk_paths:/ { in_block = 1; next }
  in_block && /^[a-zA-Z]/ { exit }
  in_block && /^[[:space:]]+-[[:space:]]+/ {
    sub(/^[[:space:]]+-[[:space:]]+/, "");
    gsub(/[[:space:]]*#.*$/, "");
    gsub(/^"|"$/, "");
    gsub(/^'"'"'|'"'"'$/, "");
    print
  }
' "$cfg" 2>/dev/null || true)

if [ -z "$risk_paths_raw" ]; then
  exit 0   # no risk_paths configured → no match
fi

matches=""
# Iterate: glob × file → case-glob match. Portable sh pattern matching.
while IFS= read -r glob; do
  [ -z "$glob" ] && continue
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    # shellcheck disable=SC2254
    case "$f" in $glob) matches="${matches}${f}:${glob}
" ;; esac
  done < "$files"
done <<EOF
$risk_paths_raw
EOF

if [ -n "$matches" ]; then
  printf '%s' "$matches" | grep . | sort -u
  exit 2
fi
exit 0
