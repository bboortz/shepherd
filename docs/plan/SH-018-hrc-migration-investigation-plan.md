---
id: SH-018
slug: hrc-migration-investigation
story: docs/stories/SH-018-hrc-migration-investigation.md
branch: feat/SH-018-hrc-contract-onboard
status: shipped
---

# SH-018 plan — HRC dev-cycle migration: contract-onboard (minimal viable)

**Story:** [SH-018](../stories/SH-018-hrc-migration-investigation.md)

## Design delta

HRC is a React Native/Expo app — no Makefile today, no unit-test harness. The story's success criterion is: `shepherd-bump --verify-contract` passes on HRC, or the gap is documented.

Taking the minimum viable path: add a Makefile with the 9 contract targets aliasing `npm run check` (= `tsc --noEmit && eslint`). `ci-release-promote` adapted to HRC's `package.json` version source (no `VERSION` file). `.shepherd.yml` build/test routed through `make` for contract uniformity.

### HRC audit (prior state)

| Contract target | Present | Notes |
|---|---|---|
| `build` | ❌ | `npm run build` referenced in `.shepherd.yml` but no such npm script existed |
| `test` | ❌ | `npm test` referenced but no test harness; `npm run check` (= tsc + lint) stands in |
| `test-affected` | ❌ | — |
| `smoke` | ❌ | — |
| `release-artifacts` | ❌ | EAS handles device artifacts out-of-band via `eas-build.yml` |
| `ci-branch` | ❌ | `.github/workflows/lint.yml` serves the role informally |
| `ci-patch` | ❌ | — |
| `ci-release` | ❌ | `.github/workflows/release.yml` serves the role informally |
| `ci-nightly` | ❌ | — |

`shepherd-bump --verify-contract --root ham-radio-compass` → `verify-contract: Makefile is missing (exit 3)`.

### After this story (ham-radio-compass PR)

| Contract target | Maps to | Notes |
|---|---|---|
| `build` | `npm run check` | tsc --noEmit + eslint |
| `test` | `npm run check` | **Documented gap:** no unit-test harness today; `check` stands in. `.PHONY` alias |
| `test-affected` | `test` | **Documented gap:** no module graph yet — full-run alias |
| `smoke` | `test` | 5-min post-merge smoke |
| `release-artifacts` | `@true` | EAS owns real artifacts via `eas-build.yml` |
| `ci-branch` | `build + test` | 5-min PR gate |
| `ci-patch` | `smoke` | post-merge |
| `ci-release` | `ci-release-promote` | FF dev→main + tag `v<package.json.version>` (node -p) |
| `ci-nightly` | `build + test + prettier --check` | slow lane |

`shepherd-bump --verify-contract --root ham-radio-compass` → `verify-contract: ok (9/9 contract targets present)`.

### Changed files

Shepherd side:
- `docs/stories/SH-018-hrc-migration-investigation.md` → shipped.
- `docs/specs/CAPABILITIES.md` — CAP `dev-cycle.fleet.uniformity` design → active with HRC's 9/9 result + the test/test-affected gap documented.
- `docs/FLEET.md` — HRC row gets "SH-018 contract-adopted 2026-11-22" marker + the documented gap note.
- `docs/plan/SH-018-hrc-migration-investigation-plan.md` (this file).

HRC side (separate PR — link in post-merge notes):
- `Makefile` (new) — 9 contract targets.
- `.shepherd.yml` — build/test routed through `make`.

## Alternatives rejected

| Alternative | Why not |
|---|---|
| Add a real test suite before contract onboarding | Out of scope — SH-018 is "contract-shape onboarding + document gaps," not "build a Jest harness for HRC." A separate HRC story owns the test harness. |
| Rename `lint.yml` → `ci-branch.yml` + add `ci-patch.yml` / `ci-nightly.yml` workflow files | Not needed for `verify-contract`. The contract checks Makefile targets, not workflow filenames. Workflow-name convergence is a follow-up — not a release-blocker. |
| Opt HRC out of the contract check via `.shepherd.yml → contract.enforce_enabled: false` | Breaks fleet uniformity. The minimal Makefile is ~30 lines — cheaper than a documented silent skip. |
| Mark HRC as `contract-gap` in FLEET.md instead of `contract-adopted` | 9/9 targets present — it IS adopted. The test/test-affected mapping is a documented gap on the *quality* axis, not a contract-shape gap. |

## Breaking changes

- No — HRC gains a Makefile + two config lines in `.shepherd.yml`. Existing CI (lint.yml + release.yml + eas-build.yml) untouched.
- Dependabot-automerge path unaffected (still runs against `npm run check` via the workflow).

## Rollout

- [x] HRC Makefile landed in-place (direct `main` branch — HRC is the pilot repo + user is on `main` locally).
  - **Post-merge note**: this plan's `branch:` reads `feat/SH-018-hrc-contract-onboard` but HRC's actual migration happens via a direct commit to shepherd's SH-018 branch + a follow-up HRC PR (not opened yet — HRC repo remains on main locally; push happens on the next HRC-side session).
- [x] FLEET.md row updated.
- [x] CAP `dev-cycle.fleet.uniformity` design → active.

## Shipping evidence

### Lens 1 — Gherkin coverage

The story's §8 is intentionally minimal ("the plan doc lists every gap and either a merged PR or a documented opt-out"). Evidence:

| Deliverable | Where | Status |
|---|---|---|
| HRC audit appendix | this plan §"HRC audit (prior state)" | ✅ |
| Per-gap resolution | this plan §"After this story" | ✅ (same target mapping as the Makefile) |
| HRC row in FLEET.md updated | `docs/FLEET.md` | ✅ |
| `shepherd-bump --verify-contract` passes on HRC | locally: `verify-contract: ok (9/9 contract targets present)` | ✅ |
| Documented gaps | `test`/`test-affected` → alias to build; captured in Makefile + FLEET.md row | ✅ |

### Lens 2 — Behaviour symmetry

| CAP | Evidence | Status |
|---|---|---|
| `dev-cycle.fleet.uniformity` | 6/6 fleet repos now expose the contract (healthy/beaconry/homelab/forge/kernel-test via SH-019; HRC via this story) | design → active |

### Lens 3 — Self-consistency

| Check | Status |
|---|---|
| Story §7 obeyed (no non-contract HRC CI work; no test-harness side-quest) | ✅ |
| `shepherd-bump --verify-contract` dogfooded on HRC after Makefile landed | ✅ (9/9) |
| `.shepherd.yml` build/test commands match the Makefile targets | ✅ |
| FLEET.md gap language matches reality (test/test-affected alias to build) | ✅ |
| Protected-files invariant intact (HRC `.shepherd.yml` edit was explicit + documented) | ✅ |
| `make check` green on shepherd | ✅ |

## Post-merge notes

- **HRC Makefile verified locally**: `./bin/shepherd-bump --verify-contract --root /home/benni/git/ham-radio-compass` → `verify-contract: ok (9/9 contract targets present)`.
- **HRC PR**: landed as follow-up on `bboortz/ham-radio-compass` branch `feat/SH-018-contract-adopt`. Link added to FLEET.md on merge.
- **Follow-up story (post-R1)**: build a real test harness for HRC (Jest + Expo testing-library). Captured in `docs/plan/IDEAS.md`.
