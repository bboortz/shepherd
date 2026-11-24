---
id: SH-056
slug: verify-index-status
status: in-progress
created: 2026-11-24
owner: @benni
---

# SH-056 — `verify-index-status`: catch INDEX ↔ frontmatter status drift

> **Closes a gap SH-055 named but didn't actually wire up.** The SH-055 story's §5 Happy-path example cites a failure message like `check-docs: INDEX.md row for SH-017 is draft but frontmatter says shipped`. But SH-055 as shipped only wraps existing `verify-*` targets — none of them actually diff the INDEX status column against each story's frontmatter. SH-056 ships that missing check as `scripts/verify-index-status.sh`.

## 1. Who is the consumer?

- Agent or human about to push a story status change (e.g. `draft → shipped`). Without this check, the frontmatter can flip while INDEX stays stale — the exact drift class we hit in the SH-012..SH-029 batch (PR #55) when 6 shipped stories still showed `draft`/`in-progress` in the INDEX.
- Future SH-NNN rollouts that don't want to repeat PR #55's catch-up work.

## 2. When does the story fire?

- Every invocation of `make check-docs` or `make verify-index-status` directly. Transitively: every `make hook-push` and `make ci-branch` on repos where `check-docs` is in `PUSH_STEPS` + `BRANCH_STEPS` (SH-055 fleet rollout).

## 3. What does success look like?

Mechanically checkable:

- `scripts/verify-index-status.sh` exists in each INDEX-bearing repo, executable.
- Walks `docs/stories/<ID>-*.md`; extracts frontmatter `status:` + INDEX row status column; fails if any disagree, or if a story has no INDEX row.
- Exit 0 clean; exit 1 on any mismatch with a specific `<ID>: INDEX row status='X' but frontmatter says 'Y'` line.
- Wired into shepherd's `check-docs` target as a new prerequisite.
- Live-proof case: flipping an INDEX row from `shipped → draft` for an existing story reproduces the fail.

## 4. How urgent?

- [ ] Security-critical
- [x] Correctness (we had the exact bug this week — PR #55 caught 6 rows of drift manually)
- [x] Quality-of-life (one less thing to remember after flipping frontmatter)
- [ ] Onboarding

## 5. Happy path

```
$ make check-docs
  verify-index-status: ok (INDEX.md matches frontmatter for all stories)
  verify-traceability: ok (85 CAPs, 23 tests, 43 CAP refs, 38 ready+ stories)
  verify-memory-size: ok
```

Failure case (reproduced live during this story's test cycle):
```
$ make check-docs
  verify-index-status: SH-055: missing INDEX.md row (frontmatter status=in-progress)
  verify-index-status: mismatches found; sync docs/stories/INDEX.md with story frontmatter.
  make: *** [Makefile:...: verify-index-status] Error 1
```

## 6. Edge cases / failure modes that matter

- **A repo has no `docs/stories/INDEX.md`.** Script no-ops with exit 0 — nothing to check (per `[ -f "$index" ]` guard). HRC + any other repo without the stories layout fall through cleanly.
- **A story file has no frontmatter `status:` field.** Reported as a per-story failure (`<ID>: no status: in frontmatter`), not a silent skip.
- **INDEX row exists but status column is whitespace-weird** (e.g. padded with 4 spaces). The script trims whitespace on both sides of the column before compare — tolerant of README prettifiers.
- **Multiple `status:` lines in a story's body** (not frontmatter). The script reads only the first `status:` occurrence, which matches YAML frontmatter convention.
- **A repo uses a different ID shape** (e.g. `FG-091` on forge, `BC-150` on beaconry). The script's ID extractor (`$1-$2` split on `-`) works for every repo's convention we've seen.
- **The per-repo INDEX has extra columns** (shepherd has 4: ID, Status, Slug, Title; forge has 3). The check only reads column 3 (status) — extra columns are ignored.

## 7. Out of scope

- Auto-fixing drift (just reports). The fix is one-line `sed` by the operator — intentional, so flipping the INDEX stays a reviewable diff.
- Validating that the status transitions are legal (e.g. `draft → shipped` without passing through `ready` / `in-progress`). Per-repo policy varies; not every repo uses the full 4-stage lifecycle.
- Checking against the rest of the row content (slug link, title). Just the status column — the drift class that bit us was always the status.
- HRC (no `docs/stories/`) and other repos that don't maintain an INDEX. The guard no-ops cleanly.

## 8. Acceptance (Gherkin → test assertions)

```gherkin
Scenario: clean fleet passes
  Given all docs/stories/*.md have status matching INDEX.md
  When  make verify-index-status runs
  Then  exit 0
  And   stdout says "ok (INDEX.md matches frontmatter for all stories)"

Scenario: INDEX row says draft but frontmatter says shipped
  Given a story with frontmatter status: shipped
  And   its INDEX row carries "draft"
  When  make verify-index-status runs
  Then  exit 1
  And   stderr names the disagreeing story ID

Scenario: story has no INDEX row
  Given a story file exists but no INDEX row references it
  When  make verify-index-status runs
  Then  exit 1
  And   stderr names "missing INDEX.md row"

Scenario: repo has no INDEX.md at all
  Given $repo/docs/stories/INDEX.md does not exist
  When  make verify-index-status runs
  Then  exit 0 cleanly (no-op guard)
```

Test: `test/acceptance/test_SH_056_verify_index_status.sh`.

## 9. Capabilities delivered or extended

- `dev-cycle.verify-index-status` — new CAP: INDEX row status ≠ frontmatter status is now a blocking check in every INDEX-bearing repo.
- `dev-cycle.tier.check-docs` — extended: shepherd's `check-docs` body now includes `verify-index-status`.

---

## Plan doc

See `docs/plan/SH-056-verify-index-status-plan.md`.
