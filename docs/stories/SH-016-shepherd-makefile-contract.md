---
id: SH-016
slug: shepherd-makefile-contract
status: shipped
created: 2026-11-22
owner: @benni
---

# SH-016 — Shepherd Makefile contract: expose ci-branch / ci-patch / ci-release / ci-nightly

> **Sub-story of [SH-014](SH-014-dev-cycle-umbrella.md) umbrella.** Give shepherd's own Makefile the four tiered targets + `build/ci-timing.json` emission. Dogfood ground truth for the contract.

## 1. Who is the consumer?

Shepherd itself. Every CI run should emit `build/ci-timing.json`; every tier should respect its budget. Once shepherd exposes the shape, it is the reference the SH-017 verifier scans for and the SH-025 healthy migration copies.

## 2. When does the story fire?

- Every `pull_request` (via SH-015's `ci-branch.yml`).
- Every `push` to `main` (via `ci-patch.yml`).
- Every manual `workflow_dispatch` on `release.yml` (via `ci-release.yml`).
- Nightly cron (via `ci-nightly.yml`).

## 3. What does success look like?

Mechanically checkable:

- Shepherd's root `Makefile` gets the four `.PHONY: ci-branch ci-patch ci-release ci-nightly` targets.
- Each target runs the right steps + emits `build/ci-timing.json` matching `docs/specs/ci-timing.md`.
- Each tier has its `timeout-minutes` cap in the matching workflow (5 / 5 / 15 / 120).
- `templates/ci-*.yml` are copied into `.github/workflows/ci-*.yml` on shepherd (same content, SHA-pinned).
- `shepherd-bump --verify-contract` (SH-017) sees shepherd as a passing managed repo.

## 4. How urgent?

- [ ] Security-critical
- [x] Correctness
- [x] Quality-of-life
- [x] Onboarding (reference impl for the quickstart)

## 5. Happy path

```
$ make ci-branch
→ lint (yaml-lint + md-lint + verify-memory-size + verify-traceability)
→ release-artifacts (zig build → bin/shepherd-bump)
→ test-affected (7 acceptance test files, all pass)
→ injection-drill (10 pass / 0 fail / 2 live-skip / 1 known-gap)
$ cat build/ci-timing.json
{"schema_version":1,"target":"ci-branch","budget_seconds":300,"total_seconds":2.726,
 "steps":[{"name":"lint","seconds":0.780}, {"name":"release-artifacts","seconds":0.038},
          {"name":"test-affected","seconds":1.465}, {"name":"injection-drill","seconds":0.443}],
 "git_sha":"7663646","runner":"Linux-x86_64",...}
```

Measured 2026-11-22: local wall-clock 2.7 s (ReleaseSafe build cached; test-acceptance across 7 files). Within budget by a factor of 100.

## 6. Edge cases / failure modes that matter

- `jq` absent on the minimal runner — not used; the Makefile assembles JSON via `awk` + `printf`. No jq dependency.
- `build/ci-steps.jsonl` empty when `make ci-branch` fails mid-step — the step macro appends synchronously; a dying step leaves a partial file. `ci-timing-finish-cmd` still assembles a valid partial JSON (whatever steps completed).
- `GITHUB_REPOSITORY` unset locally — `ci-nightly`'s failure branch guards with `[ -n "$GITHUB_REPOSITORY" ]`; the `gh issue create` is skipped on local runs.

## 7. Out of scope

- Per-repo adoption on healthy / beaconry / etc. (SH-021..SH-025 and the SH-019 tracker).
- `shepherd-bump --verify-contract` implementation (SH-017).
- Timing digest consumption (SH-020).

## 8. Acceptance (Gherkin → test assertions)

_TBD — filled when picked up._

## 9. Capabilities delivered or extended

- `dev-cycle.contract.tiered-make-targets` — `design → active` for the shepherd repo.
- `dev-cycle.budget.timeout-caps` — `design → active` for the shepherd workflows.

---

## Plan doc

Lands when this story moves from `draft → ready → in-progress`.
