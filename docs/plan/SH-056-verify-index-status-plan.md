---
id: SH-056
slug: verify-index-status
story: docs/stories/SH-056-verify-index-status.md
branch: feat/SH-056-verify-index-status
status: in-progress
---

# SH-056 plan — close the INDEX ↔ frontmatter status-drift gap SH-055 named

**Story:** [SH-056](../stories/SH-056-verify-index-status.md)

## Design delta

1. `scripts/verify-index-status.sh` — new, ~45 lines. Walks `docs/stories/*-*.md`; extracts frontmatter `status:` + INDEX row column-3 status; fails on any mismatch.
2. `Makefile`:
   - Add `verify-index-status` as `.PHONY` + target invoking the script.
   - Add `verify-index-status` to `check-docs`'s prereq list.
3. `test/acceptance/test_SH_056_verify_index_status.sh` — new; asserts script shape + live pass/fail/no-index scenarios.
4. CAP `dev-cycle.verify-index-status` added to `docs/specs/CAPABILITIES.md`; CAP `dev-cycle.tier.check-docs` body refreshed.

Per-repo rollout: identical script (byte-identical where possible), wired into each repo's `check-docs` target. Repos covered:

| Repo | Has INDEX.md | SH-056 scope |
|---|---|---|
| shepherd | ✓ | this PR (reference) |
| healthy | ✓ | copy script + add `verify-index-status` to `check-docs` prereq |
| beaconry | ✓ | same (also add to `check-docs` per BC-151) |
| HRC | — | skip (no `docs/stories/`) |
| homelab | ✓ | same (add as a wrapper step in `scripts/check-docs.sh` or as a new Make target) |
| kernel-test | ✓ | same |
| forge | ✓ | same (FG-NNN convention; script already handles via `$1-$2` split) |

## Alternatives rejected

| Alternative | Why not |
|---|---|
| Add the check to each repo's existing `verify-traceability.sh` | Different code in each repo; six separate edits. Keeping SH-056 as a standalone 45-line script makes it fleet-identical. |
| Make the check auto-fix by rewriting INDEX rows | Hides the drift. A reviewable diff is better — SH-055 PR #55 is the model. |
| Validate the full row (status + slug link + title) | Not the drift class that bit us. Scope creep. |
| Ship as a Zig extension of `shepherd-bump` | Overkill for 45 lines of portable shell; pays off only if we add many future invariants. |

## Breaking changes

- [ ] Yes
- [x] No — strictly additive on each repo. Existing drift goes from undetected to detected; nothing already-shipped fails (shepherd's self-run of the new script passed on first run after I synced SH-055's INDEX row).

## Rollout

- [x] Shepherd reference (this PR)
- [ ] Per-repo PRs via parallel agents: healthy, beaconry, homelab, kernel-test, forge

HRC skipped — no `docs/stories/` infrastructure.

## Shipping evidence

| Lens | Evidence | ✅ / ⚠️ / ❌ |
|---|---|---|
| Gherkin coverage | 4 scenarios in story §8; test asserts script shape + live pass/fail/no-index cases | ✅ |
| Behaviour symmetry | Script is pure-read; no auto-fix path. Failure messages are specific (name the story ID + both statuses). | ✅ |
| Self-consistency | Script caught its own SH-055 drift as the first thing it ran; INDEX synced before merge. | ✅ |
