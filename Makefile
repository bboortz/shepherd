# shepherd — top-level Makefile.
# See memory/workflow.md for the full gate matrix. Gates grow with releases.
#
#   make build                 # compile bump.zig → bin/shepherd-bump
#   make test                  # run the acceptance suite
#   make test-acceptance       # same, direct target
#   make check                 # yaml-lint + md-lint + verify-memory-size + build + test
#   make clean                 # remove build artefacts

ZIG           ?= zig
YAMLLINT      ?= yamllint
MARKDOWNLINT  ?= markdownlint-cli2
MEMORY_LINE_LIMIT ?= 150

MEMORY_FILES := $(wildcard memory/*.md) CLAUDE.md
ACCEPTANCE_TESTS := $(wildcard test/acceptance/test_SH_*.sh)
BUMP := bin/shepherd-bump

.PHONY: help build test test-acceptance injection-drill check yaml-lint md-lint verify-memory-size \
        verify-traceability verify-docs-layout verify-caps-traceability verify-index-status \
        verify-version-bumped verify-changelog install-hooks clean \
        lint test-affected smoke release-artifacts check-docs fleet-audit \
        hook-commit hook-push \
        ci-branch ci-patch ci-release ci-release-promote ci-nightly ci-nightly-body ci-timing-init

help:
	@echo "shepherd targets:"
	@echo "  build               compile bump.zig → $(BUMP)"
	@echo "  test                alias for test-acceptance"
	@echo "  test-acceptance     run every test/acceptance/test_SH_*.sh"
	@echo "  injection-drill     SH-005 prompt-injection drill (tests/injection/run.sh)"
	@echo "  check               yaml-lint + md-lint + verify-memory-size + build + test + injection-drill"
	@echo "  hook-commit         fleet tier — ~15 s commit-stage gate (SH-042)"
	@echo "  hook-push           fleet tier — ~2 min push-stage gate (SH-042)"
	@echo "  yaml-lint           $(YAMLLINT) ."
	@echo "  md-lint             $(MARKDOWNLINT) '**/*.md'"
	@echo "  verify-memory-size  memory/*.md and CLAUDE.md each ≤ $(MEMORY_LINE_LIMIT) lines"
	@echo "  clean               remove .zig-cache/ and bin/"
	@echo ""
	@echo "  verify-traceability docs/ layout (SH-012) + CAPs↔test↔story links (SH-013)"
	@echo ""
	@echo "Stubs (grow in follow-up stories):"
	@echo "  verify-version-bumped  VERSION differs from origin/main:VERSION"
	@echo "  verify-changelog       CHANGELOG.md has '## [v\$$(cat VERSION)]' entry"
	@echo "  install-hooks          activate commit-msg + pre-commit + pre-push"

build: $(BUMP)

$(BUMP): bump.zig build.zig
	$(ZIG) build --prefix .

test: test-acceptance

test-acceptance: build
	@fail=0; \
	for t in $(ACCEPTANCE_TESTS); do \
	  echo "→ $$t"; \
	  "$$t" || fail=1; \
	done; \
	exit $$fail

check: yaml-lint md-lint verify-memory-size verify-traceability build test-acceptance injection-drill

injection-drill:
	@tests/injection/run.sh
	@tests/injection/global_invariants.sh

yaml-lint:
	$(YAMLLINT) .

md-lint:
	@if command -v $(MARKDOWNLINT) >/dev/null 2>&1; then \
	  $(MARKDOWNLINT) '**/*.md'; \
	else \
	  echo "md-lint: $(MARKDOWNLINT) not installed — skipping"; \
	fi

verify-memory-size:
	@fail=0; \
	for f in $(MEMORY_FILES); do \
	  [ -f "$$f" ] || continue; \
	  n=$$(wc -l < "$$f"); \
	  if [ "$$n" -gt "$(MEMORY_LINE_LIMIT)" ]; then \
	    echo "::error file=$$f::$$n lines > $(MEMORY_LINE_LIMIT) line limit"; \
	    fail=1; \
	  fi; \
	done; \
	exit $$fail

verify-traceability: verify-docs-layout verify-caps-traceability

# SH-056 — catches INDEX row status ≠ frontmatter status (gap SH-055 named
# but didn't actually wire up).
verify-index-status:
	@scripts/verify-index-status.sh

# ---------------------------------------------------------------------------
# SH-055 — fleet-wide check-docs wrapper. Each fleet repo's check-docs
# target has the SAME NAME but repo-specific body. Shepherd's wraps the
# existing verify-* drift targets + SH-056's index-status check; see
# docs/plan/SH-055-check-docs-plan.md for the per-repo mapping.
# ---------------------------------------------------------------------------
check-docs: verify-traceability verify-index-status verify-memory-size

# SH-057 — repeatable fleet arming + health audit. Operator tool, NOT a gate:
# needs network + gh auth, so it is deliberately out of `check` / `ci-*`.
# Writes docs/specs/fleet-audit-<date>.md. Args pass through, e.g.
#   make fleet-audit ARGS="--offline --out /tmp/a.md"
fleet-audit:
	@scripts/fleet-audit.sh $(ARGS)

verify-docs-layout:
	@test/acceptance/test_SH_012_docs_layout.sh

verify-caps-traceability:
	@scripts/verify-traceability.sh

verify-version-bumped:
	@echo "verify-version-bumped: stub — lands in a follow-up SH story"

verify-changelog:
	@echo "verify-changelog: stub — lands in a follow-up SH story"

install-hooks:
	@echo "install-hooks: stub — lands in a follow-up SH story (pre-commit framework)"

clean:
	rm -rf .zig-cache bin

# =============================================================================
# Shepherd dev-cycle contract (SH-014 / SH-016 / SH-044) — dogfood.
# Spec: docs/specs/dev-cycle-contract.md + docs/specs/ci-timing.md.
#
# Shepherd exposes all eight canonical contract targets so it looks identical
# to the shepherd verifier (SH-017) and to a human arriving cold from any
# other fleet repo. The six tier targets + ci-timing scaffolding are shipped
# from mk/ci.mk (SH-044 master include); shepherd declares only its
# *_STEPS variables and its own repo-specific step bodies here.
# =============================================================================

# ---------------------------------------------------------------------------
# Per-repo step declarations — read by mk/ci.mk's tier wrappers.
# Fleet contract: COMMIT_STEPS / PUSH_STEPS / BRANCH_STEPS / PATCH_STEPS /
# RELEASE_STEPS / NIGHTLY_STEPS are the only knobs. See
# docs/plan/IDEAS-dev-workflow-contract-v3.md Layer 3.
# ---------------------------------------------------------------------------
COMMIT_STEPS  = yaml-lint md-lint verify-memory-size
PUSH_STEPS    = verify-traceability check-docs build test-acceptance
BRANCH_STEPS  = lint check-docs release-artifacts test-affected injection-drill
PATCH_STEPS   = smoke
RELEASE_STEPS = ci-release-promote
NIGHTLY_STEPS = check

# "lint" = the fast-gate bundle; aggregates yaml + md + memory + traceability.
lint: yaml-lint md-lint verify-memory-size verify-traceability

# Contract agent-entry points. test-affected is diff-aware via SH-036;
# smoke + release-artifacts stay as identity aliases (shepherd has no
# separate smoke tier; build is the artifact).
test-affected: build
	@sh scripts/test-affected.sh
smoke: test-acceptance
release-artifacts: build

# ---------------------------------------------------------------------------
# mk/ci.mk — fleet-contract tier wrappers + timing scaffolding.
# ---------------------------------------------------------------------------
include mk/ci.mk

# ---------------------------------------------------------------------------
# ci-nightly — shepherd's custom wrapper. Opens a needs-human issue on
# failure. Uses mk/ci.mk's run_tier macro + ci-timing-{init,finish} bodies.
# Not shipped from mk/ci.mk because each repo has a different post-failure
# escalation policy.
# ---------------------------------------------------------------------------
.PHONY: ci-nightly ci-nightly-body
ci-nightly: ci-timing-init
	@if ! $(MAKE) ci-nightly-body; then \
	  rc=$$?; \
	  if command -v gh >/dev/null 2>&1 && [ -n "$$GITHUB_REPOSITORY" ]; then \
	    gh issue create \
	      --title "[shepherd] ci-nightly failed on $$(git rev-parse --short HEAD 2>/dev/null || echo HEAD)" \
	      --body "ci-nightly failed with exit code $$rc. Workflow run: $${GITHUB_SERVER_URL:-https://github.com}/$${GITHUB_REPOSITORY}/actions/runs/$${GITHUB_RUN_ID}." \
	      --label needs-human || true; \
	  fi; \
	  exit $$rc; \
	fi
	@$(call ci-timing-finish-cmd,ci-nightly,$(CI_NIGHTLY_BUDGET))

# ci-nightly-body: delegate to the NIGHTLY_STEPS chain. Keeps the check
# content canonical (`make check` = full gate).
ci-nightly-body: $(NIGHTLY_STEPS)
