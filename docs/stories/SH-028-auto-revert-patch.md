---
id: SH-028
slug: auto-revert-patch
status: draft
created: 2026-11-22
owner: @benni
---

# SH-028 — Auto-revert on ci-patch failure (opt-in)

> **Sub-story of [SH-014](SH-014-dev-cycle-umbrella.md) umbrella.** Research-doc checklist T2 line: "deploy canary, smoke, **auto-revert on failure**." Backs the "narrow pre-merge gate + broad post-merge backstop" pattern shared by Google TAP and modern trunk-based development. Destructive, so opt-in only.

## 1. Who is the consumer?

- Repo maintainer who wants automatic rollback when `ci-patch` catches a regression post-merge. Today a bad merge stays on `dev`/`main` until a human notices.
- Research doc specifically: "Post-merge validation with auto-revert is reasonable for low-risk paths (docs, dashboards, bot prompts) and for Shepherd's own config. It is not reasonable for anything that rolls out to devices."

## 2. When does the story fire?

Every `ci-patch` workflow run on `dev` or `main`. Only acts if the run fails AND `.shepherd.yml → auto_revert.enabled` is `true`.

## 3. What does success look like?

Mechanically checkable:

- `.shepherd.yml` schema grows:

  ```yaml
  auto_revert:
    enabled: false           # default
    labels: [shepherd-auto-revert]
    comment_only: true       # phase 1: open revert PR but don't auto-merge
  ```

- On `ci-patch` failure, when `auto_revert.enabled: true`:
  - Workflow creates branch `shepherd-revert/<failed-sha>`.
  - Runs `git revert <failed-sha>` (handles merge-commit case).
  - Pushes branch; opens PR titled `[shepherd] auto-revert <short-sha>` labelled `shepherd-auto-revert`.
  - Opens a needs-human issue in parallel linking the failed run + the revert PR.
  - If `auto_revert.comment_only: false`, calls `gh pr merge --auto` on the revert PR.
- `templates/shepherd.yml` ships with a commented example + explicit opt-in notice.
- Blocklist invariant respected: if the revert would touch a `blocklist.protected-files` path, the workflow opens the needs-human issue but does NOT create the revert PR.

## 4. How urgent?

- [ ] Security-critical
- [x] Correctness (automated post-merge safety net)
- [x] Quality-of-life
- [ ] Onboarding

Target: R2/R3 boundary. Needs threat-model review before shipping — auto-revert on a flaky `ci-patch` can lose work.

## 5. Happy path

_TBD — filled when picked up._

## 6. Edge cases / failure modes that matter

_TBD — filled when picked up. Likely: merge-commit revert needs `-m 1`; revert itself conflicts; flaky ci-patch causing repeated reverts; revert touches blocklisted files._

## 7. Out of scope

- Auto-revert on `ci-branch` failure (PR itself is blocked by the gate; no merge happened).
- Device-side rollback (post-R3 scope per DESIGN §13).
- Bisect-driven culprit detection (nightly's job, SH-020 scope).

## 8. Acceptance (Gherkin → test assertions)

_TBD — filled when picked up._

## 9. Capabilities delivered or extended

- `auto-revert.patch-tier` — `design → active`.

---

## Plan doc

Lands when this story moves from `draft → ready → in-progress`.
