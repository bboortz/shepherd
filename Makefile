# shepherd — top-level Makefile.
# See memory/workflow.md for the full gate matrix. Gates grow with releases.
#
#   make check                 # all locally runnable gates
#   make yaml-lint             # yamllint .
#   make md-lint               # markdownlint on *.md
#   make verify-memory-size    # memory/*.md and CLAUDE.md ≤ 150 lines
#   make verify-traceability   # (stub until the Action lands in R1)

YAMLLINT      ?= yamllint
MARKDOWNLINT  ?= markdownlint-cli2
MEMORY_LINE_LIMIT ?= 150

MEMORY_FILES := $(wildcard memory/*.md) CLAUDE.md

.PHONY: help check yaml-lint md-lint verify-memory-size \
        verify-traceability verify-version-bumped verify-changelog \
        install-hooks clean

help:
	@echo "shepherd targets:"
	@echo "  check               yaml-lint + md-lint + verify-memory-size (+ future gates)"
	@echo "  yaml-lint           $(YAMLLINT) ."
	@echo "  md-lint             $(MARKDOWNLINT) '**/*.md'"
	@echo "  verify-memory-size  memory/*.md and CLAUDE.md each ≤ $(MEMORY_LINE_LIMIT) lines"
	@echo ""
	@echo "Stubs (become real with Release 1):"
	@echo "  verify-traceability    story ↔ plan ↔ test ↔ CAP enforcement"
	@echo "  verify-version-bumped  VERSION differs from origin/main:VERSION"
	@echo "  verify-changelog       CHANGELOG.md has '## [v\$$(cat VERSION)]' entry"
	@echo "  install-hooks          activate commit-msg + pre-commit + pre-push"
	@echo ""
	@echo "Variables: YAMLLINT=$(YAMLLINT) MARKDOWNLINT=$(MARKDOWNLINT) MEMORY_LINE_LIMIT=$(MEMORY_LINE_LIMIT)"

check: yaml-lint md-lint verify-memory-size

yaml-lint:
	$(YAMLLINT) .

md-lint:
	$(MARKDOWNLINT) '**/*.md'

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

verify-traceability:
	@echo "verify-traceability: stub — lands with Release 1 (the Action + first SH-NNN stories)"

verify-version-bumped:
	@echo "verify-version-bumped: stub — lands with Release 1"

verify-changelog:
	@echo "verify-changelog: stub — lands with Release 1"

install-hooks:
	@echo "install-hooks: stub — lands with Release 1 (pre-commit framework: commit-msg + pre-commit + pre-push)"

clean:
	@echo "Nothing to clean yet (no build outputs)."
