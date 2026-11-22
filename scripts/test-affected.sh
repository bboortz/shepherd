#!/bin/sh
# scripts/test-affected.sh — SH-036 diff-aware wrapper for `make test-affected`.
#
# Lists acceptance tests affected by the current working-tree diff against
# origin/dev (or git merge-base if a feature branch). Falls back to running
# the full suite when:
#   - the diff touches Makefile, bump.zig, build.zig, or .github/workflows/**
#   - docs/specs/CAPABILITIES.md changes (CAP may affect multiple tests)
#   - no diff is detectable
#
# Usage:
#   scripts/test-affected.sh           # emit selection + run selected tests
#   scripts/test-affected.sh --list    # emit only (don't run)
#
# Exit codes: 0 all affected tests passed; non-zero on first test failure.

set -eu

mode=${1:-run}

# ---- determine diff base --------------------------------------------------
base="${TEST_AFFECTED_BASE:-}"
if [ -z "$base" ]; then
  if git rev-parse --verify origin/dev >/dev/null 2>&1; then
    base=$(git merge-base HEAD origin/dev 2>/dev/null || git rev-parse origin/dev)
  elif git rev-parse --verify origin/main >/dev/null 2>&1; then
    base=$(git merge-base HEAD origin/main 2>/dev/null || git rev-parse origin/main)
  else
    base=HEAD
  fi
fi

{
  git diff --name-only "$base"...HEAD 2>/dev/null
  git diff --name-only
  git diff --cached --name-only
} | sort -u | grep -v '^$' > /tmp/sh-036-changed.txt || true

# ---- full-run bailouts ----------------------------------------------------
FULL_RE='^(Makefile|bump\.zig|build\.zig|\.github/workflows/|docs/specs/CAPABILITIES\.md|scripts/test-affected\.sh)$|^\.github/workflows/'

if grep -Eq "$FULL_RE" /tmp/sh-036-changed.txt; then
  echo "test-affected: full-run (diff touches build/workflow/CAPABILITIES surface)"
  tests=$(ls test/acceptance/test_SH_*.sh 2>/dev/null)
elif ! [ -s /tmp/sh-036-changed.txt ]; then
  echo "test-affected: no changes vs $base — running full suite"
  tests=$(ls test/acceptance/test_SH_*.sh 2>/dev/null)
else
  # ---- diff-aware selection -----------------------------------------------
  # 1) Changed test file → run it directly.
  # 2) docs/stories/SH-<N>-, docs/plan/SH-<N>-, docs/plan/<N>- → run test_SH_<N>_*.sh.
  # 3) scripts/shepherd-poc/<name>.sh → run tests that reference <name>.
  rm -f /tmp/sh-036-select.txt
  touch /tmp/sh-036-select.txt

  while IFS= read -r f; do
    case "$f" in
      test/acceptance/test_SH_*.sh)
        echo "$f" >> /tmp/sh-036-select.txt
        ;;
      docs/stories/SH-*.md|docs/plan/SH-*.md)
        # extract SH-NNN
        n=$(echo "$f" | sed -n 's|.*/SH-\([0-9][0-9]*\)-.*|\1|p')
        [ -n "$n" ] && ls test/acceptance/test_SH_"${n}"_*.sh 2>/dev/null >> /tmp/sh-036-select.txt || true
        ;;
      scripts/shepherd-poc/*.sh)
        name=$(basename "$f" .sh)
        for t in test/acceptance/test_SH_*.sh; do
          grep -Fq "$name" "$t" 2>/dev/null && echo "$t" >> /tmp/sh-036-select.txt
        done
        ;;
      *)
        # Untracked path → run the always-on traceability + docs-layout tests
        # as a safety net (they catch docs-structure drift).
        ls test/acceptance/test_SH_013_*.sh 2>/dev/null >> /tmp/sh-036-select.txt || true
        ls test/acceptance/test_SH_012_*.sh 2>/dev/null >> /tmp/sh-036-select.txt || true
        ;;
    esac
  done < /tmp/sh-036-changed.txt

  tests=$(sort -u /tmp/sh-036-select.txt | grep -v '^$' || true)

  if [ -z "$tests" ]; then
    echo "test-affected: no mappable tests from diff — running full suite"
    tests=$(ls test/acceptance/test_SH_*.sh 2>/dev/null)
  else
    n=$(printf '%s\n' "$tests" | wc -l | tr -d ' ')
    echo "test-affected: diff-aware ($n test(s) selected from diff)"
  fi
fi

# ---- show + run -----------------------------------------------------------
printf '%s\n' "$tests" | sed 's/^/  /'

[ "$mode" = "--list" ] && exit 0

fail=0
for t in $tests; do
  echo "→ $t"
  if ! sh "$t"; then
    fail=$((fail + 1))
    echo "FAIL $t"
  fi
done

if [ "$fail" != 0 ]; then
  echo "test-affected: $fail test(s) failed"
  exit 1
fi
echo "test-affected: all passed"
