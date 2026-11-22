---
id: SH-032
slug: hrc-default-branch-flip
status: shipped
created: 2026-11-22
owner: @benni
---

# SH-032 — Flip ham-radio-compass default branch to `dev`

> **Follow-up from the [2026-11-22 fleet consistency audit](../specs/fleet-consistency-audit-2026-11-22.md) — high severity, chore-sized.** HRC was the only fleet repo still on `main` as default after SH-029 landed. SH-018 onboarded HRC the same day and the branch flip was punted. Done as a straight `gh repo edit` — no code change required.

## 1. Who is the consumer?

- HRC maintainer (the user). Every new PR should default to `dev` as base, matching the rest of the fleet (SH-029 invariant).

## 2. When does the story fire?

- Once. `gh repo edit bboortz/ham-radio-compass --default-branch dev`.

## 3. What does success look like?

Mechanically checkable:

- `gh repo view bboortz/ham-radio-compass --json defaultBranchRef --jq .defaultBranchRef.name` returns `dev`.
- Open PRs that targeted `main` either auto-reparent or get reopened against `dev` (GitHub leaves existing PRs at their original base; only new PRs default to the new branch).
- Fleet-defaults acceptance test (`test/acceptance/test_SH_029_fleet_defaults.sh`) still 7/7 green — HRC was deferred there; this story adds the row.
- Audit matrix column 1 flips 6✅/1❌ → 7✅.

## 4. How urgent?

- [ ] Security-critical
- [x] Correctness (fleet uniformity; SH-029 invariant)
- [x] Quality-of-life (removes the "wait, is HRC the exception?" tax)
- [ ] Onboarding

## 5. Happy path

```
$ gh repo edit bboortz/ham-radio-compass --default-branch dev
$ gh repo view bboortz/ham-radio-compass --json defaultBranchRef --jq .defaultBranchRef.name
dev
```

## 6. Edge cases / failure modes that matter

- **Pending PRs targeting `main`.** GitHub preserves the base of open PRs; any PR intended for the next release should be rebased onto `dev`. Verified by gating on `gh pr list --repo bboortz/ham-radio-compass --base main --state open --json number` → empty, or reparent + comment.
- **CI referencing `main` explicitly.** `.github/workflows/release.yml` uses `inputs.ref: dev` as default — good. `lint.yml` triggers on `push`/`pull_request` without a branch filter — unaffected.
- **Dependabot targets.** `.github/dependabot.yml` uses the repository's default-branch as the PR base — flips automatically.

## 7. Out of scope

- Any code change on HRC (this is a GitHub-settings flip).
- Expanding `test_SH_029_fleet_defaults.sh` to include HRC — becomes a tiny follow-up docs PR on shepherd side, bundled here.

## 8. Acceptance (Gherkin → test assertions)

```gherkin
Scenario: HRC default branch is dev
  Given the HRC repo on GitHub
  When  I query the default branch
  Then  it is "dev"
```

Test: `test/acceptance/test_SH_029_fleet_defaults.sh` — add HRC to the fleet loop.

## 9. Capabilities delivered or extended

- `dev-cycle.fleet.branching-convergence` — already `active`; this story completes HRC's row.

---

## Plan doc

See `docs/plan/SH-032-hrc-default-branch-flip-plan.md`.
