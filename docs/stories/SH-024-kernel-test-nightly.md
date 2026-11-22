---
id: SH-024
slug: kernel-test-nightly
status: shipped
created: 2026-11-22
owner: @benni
---

# SH-024 — Kernel-Test: ci-nightly with tinyconfig x86_64 smoke + QEMU boot

> **Sub-story of [SH-014](SH-014-dev-cycle-umbrella.md) umbrella.** Kernel-Test (`bb-claw/kernel-test`) CI today runs lint + programs for 3 architectures + a harness self-test suite — but never builds a kernel. The gap is a kernel smoke build, not a pipeline. Full kernel builds cannot fit the 5-min `ci-branch` budget; nightly is the right home.

## 1. Who is the consumer?

- Kernel-Test maintainer (user) catching kernel-build regressions nightly rather than discovering them during an actual kernel test campaign.

## 2. When does the story fire?

- Every nightly cron (`ci-nightly.yml`) on kernel-test.

## 3. What does success look like?

Mechanically checkable:

- `make ci-nightly` on kernel-test does: tinyconfig x86_64 build with ccache restored from cache → QEMU boot test. Both steps emitted to `build/ci-timing.json` per `docs/specs/ci-timing.md`.
- Nightly workflow exists at `.github/workflows/ci-nightly.yml` (copy of `templates/ci-nightly.yml` + repo-specific body).
- A build regression (intentionally introduced test fixture, verified once) opens a needs-human issue on kernel-test.
- `ci-branch` stays as the 15-min PR gate running framework-only checks (no kernel build on PRs — the repo's existing `ci.yml` is preserved as-is in SH-019).

## 4. How urgent?

- [ ] Security-critical
- [x] Correctness (today kernel-test never knows if the kernel its framework targets still builds)
- [x] Quality-of-life
- [ ] Onboarding

## 5. Happy path

_TBD — filled when picked up._

## 6. Edge cases / failure modes that matter

_TBD — filled when picked up. Likely: ccache miss on first run (slow cold build); QEMU boot timeout on a slow runner; upstream kernel ref moves._

## 7. Out of scope

- Full defconfig / allmodconfig matrices (future nightly expansion; needs stronger runner).
- Replacing kernel-test's existing VM/QEMU harness with virtme-ng or TuxMake (the dev-cycle doc explicitly flags this as NOT worth doing).
- Kernel-test's own contract adoption shape (SH-019 covers the minimum, including the `make build` + `make test` targets that work on a clean runner — kernel tree isn't required for the contract targets to pass).

## 8. Acceptance (Gherkin → test assertions)

_TBD — filled when picked up._

## 9. Capabilities delivered or extended

- `dev-cycle.fleet.uniformity` — Kernel-Test gets a ci-nightly; combined with SH-019 contributes to the CAP.

---

## Plan doc

Lands when this story moves from `draft → ready → in-progress`.
