---
id: SH-020
slug: ci-timing-digest
status: draft
created: 2026-11-22
owner: @benni
---

# SH-020 — `build/ci-timing.json` emission + digest consumption

> **Sub-story of [SH-014](SH-014-dev-cycle-umbrella.md) umbrella.** The schema was defined in SH-014. This story ships the emission (via the `templates/Makefile.contract.snippet`) and the digest side that reads the artifacts and opens needs-human issues on regression.

## 1. Who is the consumer?

- Repo maintainer who gets a weekly digest line: "forge ci-branch median 4.8 min (↑ 28 % vs 14-day median)".
- `shepherd-bump --verify-contract` (SH-017) — optional secondary read: warn if `total_seconds > budget_seconds` on a recent timing file.

## 2. When does the story fire?

- Every `ci-*` workflow run on every managed repo — emission.
- Weekly `digest.yml` cron run — consumption.

## 3. What does success look like?

Mechanically checkable:

- `templates/Makefile.contract.snippet` emits `build/ci-timing.json` matching `docs/specs/ci-timing.md` schema v1 for every `ci-*` target. (Shepherd's own copy ships in SH-016.)
- `.github/workflows/digest.yml` (currently a stub) grows a step that downloads `ci-timing-*` artifacts across the fleet, computes per-repo per-tier medians over 14 days, and:
  - Opens a needs-human issue on the repo if `total_seconds > budget_seconds`.
  - Opens a needs-human issue on the repo if current median is ≥ 25 % above the 14-day median (naming the slowest step).
- Needs-human issue title: `[shepherd] dev-cycle budget breach: <repo> <tier>`; dedupe on `(repo, tier)` via title match (reuses `open-needs-human.sh` from SH-009).

## 4. How urgent?

- [ ] Security-critical
- [x] Correctness
- [x] Quality-of-life
- [ ] Onboarding

## 5. Happy path

_TBD — filled when picked up._

## 6. Edge cases / failure modes that matter

_TBD — filled when picked up. Likely: artifact missing (repo hasn't adopted yet — skip, don't error); clock skew between steps; a step that emits `null` seconds._

## 7. Out of scope

- The six Makefile targets themselves (SH-016).
- Verifier (SH-017).
- A visual dashboard. `digest.yml` posts to ntfy (eventually); this is text + issues, not Grafana.

## 8. Acceptance (Gherkin → test assertions)

_TBD — filled when picked up._

## 9. Capabilities delivered or extended

- `dev-cycle.timing.json-emission` — `design → active`.

---

## Plan doc

Lands when this story moves from `draft → ready → in-progress`.
