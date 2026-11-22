#!/bin/sh
# verify-traceability.sh — enforce CAPs ↔ test ↔ story bidirectional links.
#
# Three rules, mirroring healthy/scripts/verify-traceability.sh and
# forge/scripts/verify-traceability.sh (SH-013):
#
#   1. Every CAP row in docs/specs/CAPABILITIES.md with status containing
#      `active` has a non-empty Test column (not bare `—`).
#   2. Every test/acceptance/test_SH_*.sh has a `# CAPs:` (or `# CAPs
#      (part N):`) header, and every CAP id it names exists in CAPABILITIES.
#   3. Every story with status ready|in-progress|shipped has at least one
#      `- `cap.id.name`` bullet in its §9 Capabilities section.
#
# Usage:
#   scripts/verify-traceability.sh              # run on the current repo
#   scripts/verify-traceability.sh --root DIR   # run on an alternate tree
#                                               # (used by fixtures in
#                                               # test_SH_013_traceability.sh)
#
# Exit codes:
#   0  all three rules pass
#   1  one or more rules fail; details on stderr
#   3  usage / IO error

set -eu

root=.
if [ $# -gt 0 ]; then
  case "$1" in
    --root) shift; root=$1 ;;
    -h|--help)
      sed -n '2,20p' "$0"
      exit 0
      ;;
    *) echo "usage: $0 [--root DIR]" >&2; exit 3 ;;
  esac
fi

caps_file="$root/docs/specs/CAPABILITIES.md"
tests_glob="$root/test/acceptance/test_SH_*.sh"
stories_glob="$root/docs/stories/SH-*.md"

[ -f "$caps_file" ] || { echo "FAIL: $caps_file missing" >&2; exit 1; }

fail=0

# --- rule 1: every active CAP has a non-empty Test pointer -----------------
# Row shape: `| \`<cap.id>\` | desc | source | status | test |`
# awk -F'|' columns: 1 empty, 2 CAP, 3 desc, 4 source, 5 status, 6 test, 7 empty.
# Known CAP ids are the set of CAP cells across ALL rows (any status).

known_caps=$(awk -F'|' '
  /^\| `[a-z][a-z0-9.-]*`/ {
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
    gsub(/`/, "", $2)
    sub(/ \(.*\)$/, "", $2)       # strip " (parenthetical)" suffixes
    print $2
  }
' "$caps_file" | sort -u)

if [ -z "$known_caps" ]; then
  echo "FAIL: no CAP rows found in $caps_file" >&2
  exit 1
fi

# Active CAPs whose Test cell is empty or bare `—`.
missing_test=$(awk -F'|' '
  /^\| `[a-z][a-z0-9.-]*`/ {
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); gsub(/`/, "", $2)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", $5)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", $6)
    # Match any status that contains the word "active" (incl. "active (approximated)").
    if ($5 ~ /active/) {
      if ($6 == "" || $6 == "—" || $6 == "-") print $2
    }
  }
' "$caps_file")

if [ -n "$missing_test" ]; then
  echo "FAIL: active CAPs with no Test pointer in $caps_file:" >&2
  printf '  %s\n' $missing_test >&2
  fail=1
fi

# --- rule 2: every test has # CAPs: and names only known CAPs --------------
# Header shapes we accept (all equivalent):
#   # CAPs: cap.a, cap.b
#   # CAPs (part 1): cap.a,
#   #                cap.b
# The CAP block continues on subsequent `#` lines until we hit a blank or a
# non-indented `#` line.

test_count=0
caps_named=0
for t in $tests_glob; do
  [ -f "$t" ] || continue
  test_count=$((test_count + 1))
  if ! grep -Eq '^# CAPs(\s*\(.+\))?:' "$t"; then
    echo "FAIL: $t is missing a '# CAPs:' header" >&2
    echo "       Add near the top: '# CAPs: cap.id.name, ...'" >&2
    fail=1
    continue
  fi
  # Extract the CAPs block and pull CAP ids from it.
  block=$(awk '
    /^# CAPs(\s*\(.+\))?:/ { in_block = 1; sub(/^# CAPs(\s*\(.+\))?:[[:space:]]*/, ""); print; next }
    in_block && /^#[[:space:]]+[[:space:]]/ { sub(/^#[[:space:]]+/, ""); print; next }
    in_block { exit }
  ' "$t")
  for cap in $(echo "$block" | tr ',' '\n' | awk '{gsub(/^[[:space:]]+|[[:space:]]+$/, ""); print}' | grep -E '^[a-z][a-z0-9.-]*$' || true); do
    caps_named=$((caps_named + 1))
    # Strip " (parenthetical)" suffixes to match how we normalised known_caps.
    base=$(echo "$cap" | sed 's/ (.*)//')
    if ! printf '%s\n' "$known_caps" | grep -Fxq "$base"; then
      echo "FAIL: $t names unknown CAP: $base" >&2
      fail=1
    fi
  done
done

# --- rule 3: every ready+ story has ≥1 CAP id bullet in §9 ----------------
story_count=0
for s in $stories_glob; do
  [ -f "$s" ] || continue
  # Skip templates + the 9-questions reference.
  case "$(basename "$s")" in _*) continue ;; INDEX.md) continue ;; esac
  status=$(awk -F'[: ]+' '/^status:/ { print $2; exit }' "$s")
  case "$status" in
    ready|in-progress|shipped) ;;
    *) continue ;;
  esac
  story_count=$((story_count + 1))
  if ! grep -Eq '^-[[:space:]]+`[a-z][a-z0-9.-]*`' "$s"; then
    echo "FAIL: $s (status $status) lacks CAP bullets in §9 (expected '- \`cap.id\`')" >&2
    fail=1
  fi
done

# --- summary ---------------------------------------------------------------
if [ "$fail" = 0 ]; then
  cap_count=$(printf '%s\n' "$known_caps" | wc -l | tr -d ' ')
  echo "verify-traceability: ok ($cap_count CAPs, $test_count tests, $caps_named CAP refs, $story_count ready+ stories)"
fi
exit "$fail"
