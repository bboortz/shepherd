---
id: SH-024
slug: kernel-test-nightly
story: docs/stories/SH-024-kernel-test-nightly.md
branch: (kernel-test-side feat/SH-024-nightly-smoke)
status: shipped
---

# SH-024 plan — Kernel-Test ci-nightly (tinyconfig + kunitconfig smoke)

**Story:** [SH-024](../stories/SH-024-kernel-test-nightly.md)

## Design delta

Kernel-Test's existing `ci.yml` runs harness lint + 3-arch programs + self-tests but never builds a kernel. Add a nightly tier that does: tinyconfig x86_64 build with ccache + kunitconfig smoke. Budget: unbounded (target under 2 h); ccache hot-cache drops defconfig rebuilds from ~647s to ~99s (Desaulniers 2018, 4-core).

### Changed files (kernel-test side)

- `.github/workflows/ci-nightly.yml` (new) — `schedule: '30 2 * * *'` + `workflow_dispatch`. `timeout-minutes: 120`. SHA-pinned actions. ccache persistence via `actions/cache` keyed on `Makefile`+`tests/` hash. Calls `make ci-nightly`.
- `Makefile` — `ci-nightly: ci-nightly-body` + `ci-nightly-body: smoke` (wrapped by SH-019 with the needs-human failure trap).

### Changed files (this PR — shepherd side, closing the loop)

- `docs/stories/SH-024-kernel-test-nightly.md` → shipped.
- `docs/plan/SH-024-kernel-test-nightly-plan.md` (this file).

## Alternatives rejected

| Alternative | Why not |
|---|---|
| Put the kernel build in `ci-branch` on PRs | Breaks the 5-min PR budget per `docs/specs/dev-cycle-contract.md`; cold-cache kernel builds take 10+ min. Nightly is the right home. |
| virtme-ng or TuxMake | Story §7 explicitly carves these out — the dev-cycle doc flags them as NOT worth doing today. |
| Full defconfig + allmodconfig matrix | Future expansion once a stronger runner is available; out of scope. |

## Breaking changes

- No. kernel-test's existing CI stays untouched; nightly is strictly additive.

## Rollout

- [x] kernel-test `.github/workflows/ci-nightly.yml` + Makefile landed on `dev` via **PR [#112](https://github.com/bb-claw/kernel-test/pull/112)** (2026-11-22). Earlier shepherd-side close-loop PR incorrectly stated the commit `08f3c90` was already on `main` — it was on the feature branch only at the time. Promoted to `main` via PR [#114](https://github.com/bb-claw/kernel-test/pull/114) + VERSION bump 0.1.0 → 0.1.1 via PR [#113](https://github.com/bb-claw/kernel-test/pull/113).
- [x] shepherd story + plan close the loop here.
- [ ] First nightly run will fire at 02:30 UTC — post-merge note added when it reports green/red.

## Shipping evidence

### Lens 1 — Gherkin coverage

| Scenario | Evidence | Status |
|---|---|---|
| `make ci-nightly` on kernel-test does tinyconfig x86_64 + QEMU boot | kernel-test `Makefile` → `ci-nightly: ci-nightly-body: smoke`; smoke recipe owns the build + boot step | ✅ |
| Nightly workflow exists | kernel-test `.github/workflows/ci-nightly.yml` | ✅ |
| Timings emitted to `build/ci-timing.json` | wrapped by SH-019's needs-human failure trap + timing emitter | ✅ |
| Nightly failure opens needs-human issue | SH-019 wrap on `ci-nightly-body` | ✅ |
| `ci-branch` stays 15-min framework-only PR gate | kernel-test `ci.yml` preserved as-is | ✅ |

### Lens 2 — Behaviour symmetry

| CAP | Evidence | Status |
|---|---|---|
| `dev-cycle.fleet.uniformity` | Already active after SH-019 + SH-018; SH-024 contributes kernel-test's nightly tier | active (no row change required) |

### Lens 3 — Self-consistency

| Check | Status |
|---|---|
| Story §7 obeyed (no virtme-ng; no allmodconfig; no PR-tier kernel build) | ✅ |
| SHA-pinned actions only (SH-001) | ✅ `actions/checkout@3d3c42e5…` + `actions/cache@0057852b…` |
| Budget cap unchanged (nightly is unbounded; `timeout-minutes: 120` soft target) | ✅ |
| `make check` green on shepherd after the close-loop PR | ✅ |

## Post-merge notes

- **First nightly run**: kernel-test ci-nightly is scheduled for 02:30 UTC. Will link the first run URL here on next session.
