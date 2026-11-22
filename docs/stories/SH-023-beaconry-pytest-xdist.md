---
id: SH-023
slug: beaconry-pytest-xdist
status: draft
created: 2026-11-22
owner: @benni
---

# SH-023 — Beaconry: pytest-xdist + split check-fast

> **Sub-story of [SH-014](SH-014-dev-cycle-umbrella.md) umbrella.** Beaconry (`bboortz/beaconry`) runs 1714 tests with coverage in one serial process. Parallelism is the unused lever. Expect 2–3× on the test step; measurement lands after `build/ci-timing.json` emission.

## 1. Who is the consumer?

Beaconry contributor running `make check` locally or watching a PR run in CI. Today `check` is a single serial process; after this story, unit + fast-integration run in parallel.

## 2. When does the story fire?

- Once: add `pytest-xdist` dep + `pytest -n auto --cov` + split `make check` into `make check-fast` (lint + types + unit + verify scripts) and keep integration markers in `ci-nightly`.

## 3. What does success look like?

Mechanically checkable:

- `pytest-xdist` added to beaconry's dev dependencies; pytest config enables `-n auto` with combined coverage.
- `make check` on beaconry stays — but its body splits into a `check-fast` dependency + integration markers running via nightly.
- `ci-branch` on beaconry calls `check-fast` (not the full `check`); `ci-nightly` calls the slow suite.
- PR-tier wall-clock decreases measurably (baseline via SH-020 emission).

## 4. How urgent?

- [ ] Security-critical
- [x] Correctness
- [x] Quality-of-life
- [ ] Onboarding

## 5. Happy path

_TBD — filled when picked up._

## 6. Edge cases / failure modes that matter

_TBD — filled when picked up. Likely: a test suite that assumes single-process state (DB fixtures, filesystem tempdir); xdist's distributed-coverage merge._

## 7. Out of scope

- Mutation testing (research doc recommendation — nice-to-have, separate SH).
- Beaconry's own contract adoption shape (SH-019 covers the minimum, including the `make build` alias).

## 8. Acceptance (Gherkin → test assertions)

_TBD — filled when picked up._

## 9. Capabilities delivered or extended

- `dev-cycle.fleet.uniformity` — Beaconry speedup; combined with SH-019 contributes to the CAP.

---

## Plan doc

Lands when this story moves from `draft → ready → in-progress`.
