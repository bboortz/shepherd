# ===========================================================================
# mk/ci.mk — Shepherd fleet-contract tier include (SH-044).
#
# This is the canonical master include for the six fleet-tier targets:
#
#     hook-commit  — commit-stage gate      (~15 s)
#     hook-push    — push-stage gate        (~2 min)
#     ci-branch    — PR gate                (5 min budget)
#     ci-patch     — post-merge smoke       (5 min budget)
#     ci-release   — promote + release      (15 min budget)
#     ci-nightly   — slow lane              (120 min soft cap)
#
# Each tier executes the steps listed in a repo-declared variable:
#
#     COMMIT_STEPS   — thin + fast (fmt, lint-staged)
#     PUSH_STEPS     — fast tests + repo rules (version, changelog)
#     BRANCH_STEPS   — PR-tier work (lint, build, test, scan)
#     PATCH_STEPS    — post-merge spot-check against the merged commit
#     RELEASE_STEPS  — promotion (dev → main FF + tag)
#     NIGHTLY_STEPS  — slower lane (cold builds, cross, e2e)
#
# What's canonical here (included verbatim by every fleet repo):
#   - the six tier targets themselves
#   - the `run_tier` recipe body (loops over *_STEPS, emits timing)
#   - the `ci-timing-finish-cmd` finish macro
#   - the `ci-timing-init` scaffolding target
#   - the `ci-release-promote` FF-only promote recipe (fleet convention)
#
# What stays per-repo (in the repo's own Makefile):
#   - each repo's step-level targets (yaml-lint, ruff, zig-fmt, …)
#   - each repo's *_STEPS variable assignment
#   - `.shepherd.yml → build:` + `.shepherd.yml → test:` pointers
#
# §12 protection: `mk/**` is on the agent blocklist. Edits here require a
# human-reviewed change (see CAPABILITIES → blocklist.protected-files).
#
# Spec: docs/stories/SH-044-mk-ci-include.md
# ===========================================================================

# ---------------------------------------------------------------------------
# Budgets + timing file paths. Each repo can override before including.
# ---------------------------------------------------------------------------
CI_BRANCH_BUDGET  ?= 300
CI_PATCH_BUDGET   ?= 300
CI_RELEASE_BUDGET ?= 900
CI_NIGHTLY_BUDGET ?= 0
CI_TIMING_FILE    ?= build/ci-timing.json
CI_STEPS_FILE     ?= build/ci-steps.jsonl

# ---------------------------------------------------------------------------
# Step defaults — repos declare their own; these are fallbacks that point
# at the fleet contract names for self-describing error messages.
# ---------------------------------------------------------------------------
COMMIT_STEPS  ?=
PUSH_STEPS    ?=
BRANCH_STEPS  ?=
PATCH_STEPS   ?=
RELEASE_STEPS ?= ci-release-promote
NIGHTLY_STEPS ?=

.PHONY: hook-commit hook-push \
        ci-branch ci-patch ci-release ci-release-promote \
        ci-timing-init
# Note: ci-nightly is NOT defined here. Each repo wraps its own nightly
# loop because the surrounding needs-human / notification policy differs
# per repo (shepherd opens an issue; healthy pages ntfy; others log).
# Each repo's ci-nightly MAY still use the `run_tier` macro below.

# ---------------------------------------------------------------------------
# SH-042 — local-gate tier wrappers. No timing instrumentation (budgets are
# measured by `time make hook-commit`, not emitted as JSON — they run on
# developer machines, not CI runners).
# ---------------------------------------------------------------------------
hook-commit: $(COMMIT_STEPS)
hook-push:   $(PUSH_STEPS)

# ---------------------------------------------------------------------------
# ci-timing scaffolding (SH-014 / SH-020).
# ---------------------------------------------------------------------------
ci-timing-init:
	@mkdir -p $(dir $(CI_STEPS_FILE)) build/release
	@: > $(CI_STEPS_FILE)
	@echo "$$(date -u +%FT%TZ)" > build/ci-started-at

# ci-timing-finish-cmd assembles the final build/ci-timing.json per
# docs/specs/ci-timing.md schema v1.
define ci-timing-finish-cmd
	finished_at=$$(date -u +%FT%TZ); \
	started_at=$$(cat build/ci-started-at 2>/dev/null || echo "$$finished_at"); \
	total=$$(awk -F'"seconds":' '/"seconds":/ { s=$$2; gsub(/[^0-9.]/, "", s); sum+=s } END{ printf "%.3f", sum }' $(CI_STEPS_FILE) 2>/dev/null || echo 0); \
	git_sha=$$(git rev-parse --short HEAD 2>/dev/null || echo unknown); \
	runner=$${RUNNER_OS:+$${RUNNER_OS}-$${RUNNER_ARCH}}; \
	runner=$${runner:-$$(uname -s)-$$(uname -m)}; \
	steps_json=$$(awk 'BEGIN{printf "["} NR>1{printf ","} {printf "%s", $$0} END{printf "]"}' $(CI_STEPS_FILE) 2>/dev/null || echo '[]'); \
	printf '{"schema_version":1,"target":"%s","budget_seconds":%s,"total_seconds":%s,"steps":%s,"git_sha":"%s","runner":"%s","started_at":"%s","finished_at":"%s"}\n' \
	  "$(1)" "$(2)" "$$total" "$$steps_json" "$$git_sha" "$$runner" "$$started_at" "$$finished_at" \
	  > $(CI_TIMING_FILE)
endef

# run_tier $(1)=steps-list $(2)=tier-name — shell-loop invokes each step via
# $(MAKE), records per-step timing, propagates failure exit code. The loop
# stops on the first failing step and marks it `"failed": true` in the
# per-step timing record.
define run_tier
	@for s in $(1); do \
	  _t0=$$(date +%s.%N); \
	  if $(MAKE) $$s; then \
	    _t1=$$(date +%s.%N); _secs=$$(awk -v a="$$_t1" -v b="$$_t0" 'BEGIN{printf "%.3f", a-b}'); \
	    printf '{"name":"%s","seconds":%s}\n' "$$s" "$$_secs" >> $(CI_STEPS_FILE); \
	  else \
	    _rc=$$?; _t1=$$(date +%s.%N); _secs=$$(awk -v a="$$_t1" -v b="$$_t0" 'BEGIN{printf "%.3f", a-b}'); \
	    printf '{"name":"%s","seconds":%s,"failed":true}\n' "$$s" "$$_secs" >> $(CI_STEPS_FILE); \
	    exit $$_rc; \
	  fi; \
	done
	@$(call ci-timing-finish-cmd,$(2),$(3))
endef

# ---------------------------------------------------------------------------
# Tier targets — each delegates to run_tier with its budget.
# ---------------------------------------------------------------------------
ci-branch: ci-timing-init
	$(call run_tier,$(BRANCH_STEPS),ci-branch,$(CI_BRANCH_BUDGET))

ci-patch: ci-timing-init
	$(call run_tier,$(PATCH_STEPS),ci-patch,$(CI_PATCH_BUDGET))

ci-release: ci-timing-init
	$(call run_tier,$(RELEASE_STEPS),ci-release,$(CI_RELEASE_BUDGET))

# ci-nightly is intentionally NOT defined here. Each repo wraps its own
# nightly loop because the surrounding needs-human / notification policy
# differs per repo. A canonical body is: `ci-nightly: ci-timing-init;
# $(call run_tier,$(NIGHTLY_STEPS),ci-nightly,$(CI_NIGHTLY_BUDGET))`.

# ---------------------------------------------------------------------------
# ci-release-promote — SH-029 fleet FF-only promotion. Must run on `dev`.
# ---------------------------------------------------------------------------
ci-release-promote:
	@current=$$(git branch --show-current); \
	 [ "$$current" = "dev" ] || { echo "ci-release-promote must run on 'dev', got '$$current'"; exit 1; }
	@[ -f VERSION ] || { echo "VERSION file missing — cannot determine tag"; exit 1; }
	@version=$$(cat VERSION | tr -d '[:space:]'); \
	 echo "SH-029 promote: dev → main as v$$version"; \
	 git fetch origin main && \
	 git checkout main && \
	 git merge --ff-only origin/dev && \
	 git tag "v$$version" HEAD && \
	 git push origin main && \
	 git push origin "v$$version" && \
	 git checkout dev
