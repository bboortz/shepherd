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
        verify-traceability verify-docs-layout verify-caps-traceability \
        verify-version-bumped verify-changelog install-hooks clean \
        lint test-affected smoke release-artifacts \
        ci-branch ci-patch ci-release ci-release-promote ci-nightly ci-nightly-body ci-timing-init

help:
	@echo "shepherd targets:"
	@echo "  build               compile bump.zig → $(BUMP)"
	@echo "  test                alias for test-acceptance"
	@echo "  test-acceptance     run every test/acceptance/test_SH_*.sh"
	@echo "  injection-drill     SH-005 prompt-injection drill (tests/injection/run.sh)"
	@echo "  check               yaml-lint + md-lint + verify-memory-size + build + test + injection-drill"
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
# Shepherd dev-cycle contract (SH-014 / SH-016) — dogfood.
# Spec: docs/specs/dev-cycle-contract.md + docs/specs/ci-timing.md.
#
# Shepherd exposes all eight canonical contract targets so it looks identical
# to the shepherd verifier (SH-017) and to a human arriving cold from any
# other fleet repo. Each tier emits build/ci-timing.json per docs/specs/ci-
# timing.md schema v1, consumed by the digest in SH-020.
# =============================================================================

CI_BRANCH_BUDGET  ?= 300
CI_PATCH_BUDGET   ?= 300
CI_RELEASE_BUDGET ?= 900
CI_NIGHTLY_BUDGET ?= 0
CI_TIMING_FILE    ?= build/ci-timing.json
CI_STEPS_FILE     ?= build/ci-steps.jsonl

# "lint" = the fast-gate bundle; aggregates yaml + md + memory + traceability.
lint: yaml-lint md-lint verify-memory-size verify-traceability

# Contract agent-entry points — identity aliases to shepherd's fast natives.
test-affected: test-acceptance
smoke: test-acceptance
release-artifacts: build

# Timing helpers: $(call step,NAME,RECIPE) appends {name,seconds} to the
# steps file; ci-timing-finish-cmd assembles the final build/ci-timing.json.
define step
	@mkdir -p $(dir $(CI_STEPS_FILE))
	@_t0=$$(date +%s.%N); \
	 $(2); _rc=$$?; \
	 _t1=$$(date +%s.%N); \
	 _secs=$$(awk -v a="$$_t1" -v b="$$_t0" 'BEGIN{printf "%.3f", a-b}'); \
	 printf '{"name":"%s","seconds":%s}\n' "$(1)" "$$_secs" >> $(CI_STEPS_FILE); \
	 exit $$_rc
endef

ci-timing-init:
	@mkdir -p $(dir $(CI_STEPS_FILE)) build/release
	@: > $(CI_STEPS_FILE)
	@echo "$$(date -u +%FT%TZ)" > build/ci-started-at

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

# ci-branch: full 5-min PR gate. Matches `make check` content with timing.
ci-branch: ci-timing-init
	$(call step,lint,$(MAKE) lint)
	$(call step,release-artifacts,$(MAKE) release-artifacts)
	$(call step,test-affected,$(MAKE) test-affected)
	$(call step,injection-drill,$(MAKE) injection-drill)
	@$(call ci-timing-finish-cmd,ci-branch,$(CI_BRANCH_BUDGET))

# ci-patch: 5-min post-merge smoke. No rebuild.
ci-patch: ci-timing-init
	$(call step,smoke,$(MAKE) smoke)
	@$(call ci-timing-finish-cmd,ci-patch,$(CI_PATCH_BUDGET))

# ci-release-promote: fast-forward main to dev + tag from VERSION (SH-029).
# Must run on `dev` branch. Mutates the working tree; intended for CI only.
# Shared contract shape; see templates/Makefile.contract.snippet.
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

# ci-release: promote + emit timing. Shepherd has no SBOM/signing yet; that
# arrives in a follow-up SH if needed.
ci-release: ci-timing-init
	$(call step,release-promote,$(MAKE) ci-release-promote)
	@$(call ci-timing-finish-cmd,ci-release,$(CI_RELEASE_BUDGET))

# ci-nightly: nightly slow lane. Failures open a needs-human issue.
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

# ci-nightly-body: same content as ci-branch today. Future stories will
# extend with slower checks (cross-build, cold builds, etc.).
ci-nightly-body: check
