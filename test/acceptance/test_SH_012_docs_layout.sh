#!/bin/sh
# test_SH_012_docs_layout.sh — docs/ layout + reference integrity
# Story:  docs/stories/SH-012-docs-layout-reshape.md
# Plan:   docs/plan/SH-012-docs-layout-reshape-plan.md
# Covers: docs.layout.three-dirs,
#         docs.specs.authoritative-contracts,
#         docs.references.stable

set -u
pass=0; fail=0

# --- assertion helpers ------------------------------------------------------

assert_exists() { f=$1
  if [ -e "$f" ]; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL missing: $f"; fi; }

assert_dir() { d=$1
  if [ -d "$d" ]; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL not a directory: $d"; fi; }

assert_absent() { f=$1
  if [ -e "$f" ]; then fail=$((fail + 1)); echo "FAIL should not exist: $f"
  else pass=$((pass + 1)); fi; }

assert_contains() { file=$1; needle=$2
  if [ -f "$file" ] && grep -Fq -- "$needle" "$file"; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL $file does not contain: $needle"; fi; }

# Resolve repo root relative to this script so the test is CWD-independent.
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
cd "$repo" || exit 1

# ----- Scenario 1 — the three directories exist ----------------------------

assert_dir docs/specs
assert_dir docs/plan
assert_dir docs/stories

# ----- Scenario 2 — authoritative contracts live under docs/specs/ ---------

assert_exists docs/specs/DESIGN.md
assert_exists docs/specs/CAPABILITIES.md
assert_absent docs/DESIGN.md
assert_absent docs/CAPABILITIES.md

# ----- Scenario 3 — ops references stay at docs/ root ----------------------

assert_exists docs/FLEET.md
assert_exists docs/needs-human.md

# ----- Scenario 6 — the layout spec exists ---------------------------------
# (Checked before §4/§5 so failures are in a readable order.)

assert_exists docs/specs/docs-layout.md
assert_contains docs/specs/docs-layout.md "docs/specs/"
assert_contains docs/specs/docs-layout.md "docs/plan/"
assert_contains docs/specs/docs-layout.md "docs/stories/"

# ----- Scenario 4 — every live reference to docs/ resolves -----------------
#
# Scan every tracked file *except* CHANGELOG.md (historical by design) and
# the SH-012 story/plan themselves (which contain pedagogical examples of
# old-path references — e.g. "the test must exclude CHANGELOG.md" and
# "`docs/DESIGN.md §12`"). The test itself is also excluded — it names old
# paths as fixtures.
#
# Extract substrings that look like `docs/<path>.md` or `docs/<dir>/` and
# assert each resolves to a real path. Globs/placeholders (`<slug>`, `NNN`,
# `*`) are skipped.
#
# Why awk and not grep -o: we need to tolerate markdown quoting syntax like
# [`docs/foo.md`](docs/foo.md) and avoid matching inside fenced code blocks
# when the path is obviously a shape-example (e.g. `docs/stories/SH-NNN-...`).

# Portable file enumeration: prefer `git ls-files` when available (respects
# .gitignore + submodule boundaries); fall back to find.
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  files=$(git ls-files)
else
  files=$(find . -type f -not -path './.git/*' -not -path './_shepherd/*' \
    -not -path './.zig-cache/*' -not -path './bin/*' -not -path './node_modules/*' \
    | sed 's|^\./||')
fi

ref_fail=0
ref_checked=0
for f in $files; do
  case "$f" in
    CHANGELOG.md) continue ;;
    .gitignore) continue ;;   # glob patterns, not references
    docs/stories/SH-012-docs-layout-reshape.md) continue ;;
    docs/plan/SH-012-docs-layout-reshape-plan.md) continue ;;
    test/acceptance/test_SH_012_docs_layout.sh) continue ;;
  esac
  # Extract candidate paths. Two forms:
  #   1. docs/<file>.md               → check exists
  #   2. docs/<dir>/                  → check is dir
  # Skip paths embedded in URLs (preceding char is `/`) so external
  # references like `https://.../docs/stories/HC-008-...md` don't register
  # as local dangling links. Guard against placeholders (`<slug>`, `NNN`,
  # `*`, `$`).
  cands=$(awk -v file="$f" '
    {
      line = $0
      pos = 1
      while (match(line, /docs\/[A-Za-z0-9_./-]+(\.md|\/)/)) {
        prev = (RSTART > 1) ? substr(line, RSTART - 1, 1) : ""
        p = substr(line, RSTART, RLENGTH)
        if (prev != "/") print p
        line = substr(line, RSTART + RLENGTH)
      }
    }
  ' "$f" | sort -u)

  for p in $cands; do
    # Skip templates + placeholders.
    case "$p" in
      *'<'*|*'>'*|*'NNN'*|*'*'*|*'$'*) continue ;;
      docs/|docs/specs/|docs/plan/|docs/stories/) continue ;; # bare dir refs — handled above
    esac
    ref_checked=$((ref_checked + 1))
    if [ -e "$p" ]; then
      :
    elif [ -d "${p%/}" ]; then
      :
    else
      ref_fail=$((ref_fail + 1))
      echo "FAIL dangling ref in $f: $p"
    fi
  done
done

if [ "$ref_fail" = 0 ]; then
  pass=$((pass + 1))
  echo "  references: $ref_checked live docs/ links, all resolve"
else
  fail=$((fail + ref_fail))
fi

# ----- Scenario 5 — every acceptance test's Story/Plan headers resolve -----

hdr_fail=0
hdr_checked=0
for t in test/acceptance/test_SH_*.sh; do
  [ -f "$t" ] || continue
  # Header shape: `# Story:  docs/stories/...`  or  `# Plan:   docs/plan/...`
  story=$(awk '/^# Story:/ { sub(/^# Story:[[:space:]]+/, ""); print; exit }' "$t")
  plan=$(awk  '/^# Plan:/  { sub(/^# Plan:[[:space:]]+/,  ""); print; exit }' "$t")
  for ref in "$story" "$plan"; do
    [ -z "$ref" ] && continue
    hdr_checked=$((hdr_checked + 1))
    if [ ! -f "$ref" ]; then
      hdr_fail=$((hdr_fail + 1))
      echo "FAIL $t header points to missing file: $ref"
    fi
  done
done

if [ "$hdr_fail" = 0 ]; then
  pass=$((pass + 1))
  echo "  test headers: $hdr_checked Story/Plan pointers, all resolve"
else
  fail=$((fail + hdr_fail))
fi

# ---------------------------------------------------------------------------
echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
