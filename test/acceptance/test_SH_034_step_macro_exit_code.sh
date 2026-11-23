#!/bin/sh
# test_SH_034_step_macro_exit_code.sh — regression guard for the ci-release
# step-macro exit-code bug caught 2026-11-22.
#
# Story:  docs/stories/SH-034-step-macro-exit-code.md
# Plan:   docs/plan/SH-034-step-macro-exit-code-plan.md
# CAPs:   dev-cycle.step.exit-code-propagation
#
# Before the fix, the `step` macro in Makefile + templates/Makefile.contract.snippet
# chained its inner recipe with `;`, letting the timing-write that followed
# overwrite the recipe's non-zero exit code. `make ci-release` therefore
# reported SUCCESS even when the inner `ci-release-promote` push was rejected.
#
# After the fix: `$(2); _rc=$$?; … ; exit $$_rc`.
#
# This test verifies the source form (not runtime), so it stays fast and
# doesn't require an actual ci-release dispatch.

set -u
pass=0; fail=0

assert_matches() { pattern=$1; file=$2; label=$3
  if grep -Fq -- "$pattern" "$file"; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL $label: pattern '$pattern' not found in $file"; fi
}

assert_not_matches() { pattern=$1; file=$2; label=$3
  if ! grep -Fq -- "$pattern" "$file"; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL $label: forbidden pattern '$pattern' present in $file"; fi
}

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
cd "$repo" || exit 1

# Scan every Make file that hosts a tier recipe. Shepherd migrated the `step`
# macro to `run_tier` in mk/ci.mk (SH-044); exit-code shape is preserved but
# syntax changed (if/then/else with explicit `exit $$_rc`). The templates
# snippet still carries the legacy `step` macro for repos not yet on mk/ci.mk.
for mk in mk/ci.mk templates/Makefile.contract.snippet; do
  [ -f "$mk" ] || { fail=$((fail + 1)); echo "FAIL: $mk missing"; continue; }

  # Scenario 1/2 — captured _rc gets replayed as the compound's exit code.
  assert_matches '_rc=$$?' "$mk" "$mk: _rc capture"
  assert_matches 'exit $$_rc' "$mk" "$mk: exit \$\$_rc replay"

  # Scenario 3 — the old swallowed-exit form is forbidden inside any
  # `define step` block in this file.
  if grep -Fq "define step" "$mk"; then
    swallow_count=$(awk '
      /^define step/ { in_block = 1; next }
      /^endef/       { in_block = 0 }
      in_block && /\$\(2\); \\/ && !/_rc/ { n++ }
      END { print (n+0) }
    ' "$mk")
    if [ "$swallow_count" = 0 ]; then pass=$((pass + 1))
    else fail=$((fail + 1)); echo "FAIL $mk: bare backslash-chained inner recipe still present"; fi
  else
    pass=$((pass + 1))  # Not a `step`-macro host; scenario 3 N/A.
  fi
done

# Scenario 4 — end-to-end sanity: a failing recipe through the step macro
# must bubble up to make. Build a throwaway Makefile that imports the macro
# shape and asserts `make foo` exits non-zero.
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/Makefile" <<'EOF'
CI_STEPS_FILE := /tmp/sh-034-steps.jsonl

define step
	@mkdir -p $(dir $(CI_STEPS_FILE))
	@_t0=$$(date +%s.%N); \
	 $(2); _rc=$$?; \
	 _t1=$$(date +%s.%N); \
	 _secs=$$(awk -v a="$$_t1" -v b="$$_t0" 'BEGIN{printf "%.3f", a-b}'); \
	 printf '{"name":"%s","seconds":%s}\n' "$(1)" "$$_secs" >> $(CI_STEPS_FILE); \
	 exit $$_rc
endef

ok:
	$(call step,ok-step,true)

fail:
	$(call step,fail-step,false)
EOF

if (cd "$tmp" && make -s ok >/dev/null 2>&1); then pass=$((pass + 1))
else fail=$((fail + 1)); echo "FAIL end-to-end: successful inner recipe should exit 0 through the macro"; fi

if ! (cd "$tmp" && make -s fail >/dev/null 2>&1); then pass=$((pass + 1))
else fail=$((fail + 1)); echo "FAIL end-to-end: failing inner recipe (false) should propagate exit 1 through the macro"; fi

# ---------------------------------------------------------------------------
echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
