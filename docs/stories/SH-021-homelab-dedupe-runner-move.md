---
id: SH-021
slug: homelab-dedupe-runner-move
status: shipped
created: 2026-11-22
owner: @benni
---

# SH-021 — Homelab: stop the double run + move Lint off `server2`

> **Sub-story of [SH-014](SH-014-dev-cycle-umbrella.md) umbrella.** The `bb-claw/homelab` repo runs the same CI twice per commit (push + PR) and the Lint job runs on `server2` — the production host — creating a single-point queue. Measured 2026-11-22: median 4.1 min on dev, 7.1 min on PRs, 20–29 min queue spikes when server2 is busy.

## 1. Who is the consumer?

- Homelab maintainer (@bb-claw / user) opening a PR. Today each commit burns runner time twice.
- `server2` itself. Today a long CI queue competes with production workloads.

## 2. When does the story fire?

- Once: edit `bb-claw/homelab/.github/workflows/*` to (a) trigger only on `pull_request` for `feat/**` + `fix/**` + `chore/**` branches (keep `push` for `dev` + `main`), and (b) move the Lint job to a GitHub-hosted runner or a second non-`server2` self-hosted runner.

## 3. What does success look like?

Mechanically checkable:

- `bb-claw/homelab/.github/workflows/*.yml` triggers show: `pull_request:` yes, `push:` only on `dev` + `main` + `ci/**`.
- Lint job `runs-on:` no longer references `server2` exclusively.
- Post-change: PR median drops from 7.1 min → ≤ 4 min; no 20–29 min queue spikes in a 2-week window.

## 4. How urgent?

- [ ] Security-critical (though single-runner-on-prod-host IS a lateral-movement vector)
- [x] Correctness
- [x] Quality-of-life
- [ ] Onboarding

**Opportunistic R1 cherry-pick** per umbrella §7 — if queue spikes recur during the R1 soak, this can land before R2.

## 5. Happy path

_TBD — filled when picked up._

## 6. Edge cases / failure modes that matter

_TBD — filled when picked up. Likely: `push` trigger removal breaks some integration (check what currently depends on it)._

## 7. Out of scope

- Introducing new self-hosted runners.
- Migrating Homelab's existing pipeline to the `ci-*` contract shape (that's part of SH-019's five-row rollout; this story is pure dedupe + runner move).

## 8. Acceptance (Gherkin → test assertions)

_TBD — filled when picked up._

## 9. Capabilities delivered or extended

- `dev-cycle.fleet.uniformity` — Homelab shape straightens; combined with SH-019 contributes to the CAP.

---

## Plan doc

Lands when this story moves from `draft → ready → in-progress`.
