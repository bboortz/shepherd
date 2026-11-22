---
id: SH-027
slug: risk-paths
status: draft
created: 2026-11-22
owner: @benni
---

# SH-027 — Risk-paths: human-approval gate (distinct from §12 blocklist)

> **Sub-story of [SH-014](SH-014-dev-cycle-umbrella.md) umbrella.** Research-doc core recommendation ("agent PRs touching `risk-paths` never auto-merge"). Distinct from §12 `blocklist.protected-files`: the blocklist bars the agent from WRITING a path at all; risk-paths let the agent write but force a human to approve before auto-merge.

## 1. Who is the consumer?

- Repo maintainer who wants fine-grained control over what the shepherd agent can auto-merge. Today's choice is binary: either §12 blocks the file entirely (no agent writes ever) or the file auto-merges through the gates. Risk-paths add a middle tier.
- Example (research doc): Shepherd's own remediation and patching actions. Sensitive but editable.
- Example: `roles/network/**`, `remediations/**`, `Dockerfile*`, `build.zig*`, `.github/**`.

## 2. When does the story fire?

Every shepherd-agent PR and every Dependabot PR: new step in `reusable-shepherd-gates.yml` checks the diff against `.shepherd.yml → risk_paths`.

## 3. What does success look like?

Mechanically checkable:

- `.shepherd.yml` schema grows `risk_paths: [glob, ...]` (default `[]`).
- `.shepherd.yml` optionally grows `risk_paths_reviewers: [github-handle, ...]` (default `[]` — shepherd just opens a needs-human issue, doesn't request reviewers).
- New gate `gate.risk-paths-requires-approval` in `reusable-shepherd-gates.yml`. If the PR's diff touches any glob in `risk_paths`:
  - Auto-merge is refused regardless of all other gates passing.
  - A needs-human issue opens with title `[shepherd] risk-path touched on PR #<N>` and body listing the touched paths + reviewer hints.
  - PR gets label `shepherd-risk-path`.
- `templates/shepherd.yml` ships with a commented example.
- Semantic distinction from blocklist documented in `docs/specs/DESIGN.md §12`.

## 4. How urgent?

- [ ] Security-critical
- [x] Correctness (fine-grained auto-merge control; narrows the "either block or merge" choice)
- [x] Quality-of-life
- [ ] Onboarding

## 5. Happy path

_TBD — filled when picked up._

## 6. Edge cases / failure modes that matter

_TBD — filled when picked up. Likely: globs that match too much (default risk-path list for new onboarders?); risk_paths overlapping with blocklist (blocklist wins)._

## 7. Out of scope

- Reviewers auto-assignment via GitHub CODEOWNERS (orthogonal mechanism).
- Risk-paths on non-agent PRs (a human PR touching risk-paths just gets the label + issue, but is not blocked from manual merge).

## 8. Acceptance (Gherkin → test assertions)

_TBD — filled when picked up._

## 9. Capabilities delivered or extended

- `risk-paths.human-approval-required` — `design → active`.

---

## Plan doc

Lands when this story moves from `draft → ready → in-progress`.
