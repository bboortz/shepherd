---
created: 2026-11-23
status: recommendation (not enforcement)
---

# Step taxonomy — 12 recommended categories

Shared vocabulary for test / check targets across the fleet. Recommendation-only; audit flags deviations as `⚠️` but never hard-fails.

Rationale: an agent reading a Makefile in a repo it hasn't seen should be able to predict what `make <name>` does. A repo named a target `unit` should run unit tests; a target `scan` should run a security scanner. Deviations cost readability.

## The 12 categories

| Category | Means | Stage | Needs | Fleet examples |
|---|---|---|---|---|
| **`fmt`** | formatting check (not auto-fix) — `zig fmt --check`, `ruff format --check`, `prettier --check` | commit | nothing | healthy `zig-fmt`; beaconry's `lint` wraps ruff-format; HRC `prettier-check` (SH-042) |
| **`lint`** | static analysis — shellcheck, yamllint, ruff check, ansible-lint, hadolint, actionlint, eslint | commit, push, branch | nothing | shepherd `lint` (`yaml-lint + md-lint + verify-memory-size + verify-traceability`); forge `lint` (`scripts/ci-lint.sh`); homelab `lint` (7 linters) |
| **`typecheck`** | static type checking — pyright, tsc | push, branch | nothing | beaconry `type` (pyright); HRC `check` folds tsc |
| **`unit`** | logic tests, no I/O, no containers, no hardware | push, branch | nothing | beaconry `test` (pytest with markers); kernel-test `ci-test` (fixture-based framework tests) |
| **`build`** | produces the artifact (binary, image, kernel programs) | branch | toolchain | shepherd `build` (zig → `bin/shepherd-bump`); forge `build` (docker images); kernel-test `programs` (toybox binaries) |
| **`verify`** | repo-level invariants — changelog present, version bumped, docs drift, traceability, memory size | push, branch, release | git history | fleet-wide: beaconry has 19 `verify-*`; forge 11; others 2–6. Core: `verify-traceability`, `verify-version-bumped`, `verify-changelog`, `verify-memory-size` |
| **`integration`** | multi-component tests with local containers or spawned services | patch | containers | beaconry `test-integration` (docker-compose with real services); homelab `test` (pytest + role integration) |
| **`smoke`** | start the artifact, check it responds to a trivial request | patch, release | artifact | shepherd `smoke` (aliases to test-acceptance); beaconry `smoke` (`poc/demo.sh --smoke`); kernel-test `smoke` (tinyconfig + kunitconfig) |
| **`scan`** | security scanner — grype / trivy / syft — regression vs. baseline | patch | scanner | forge `scan` (syft + grype), `scan-regression` (FG-019); beaconry `dogfood-scan`; homelab `lint-trivy` |
| **`acceptance`** | full story-level test suite, often `test_SH_NNN_*.sh` or `test_HC_NNN_*.sh` — gherkin-shaped | nightly (affected subset in patch) | — | shepherd `test-acceptance`; forge `test-acceptance`; healthy `test-acceptance` |
| **`e2e`** | whole-stack cold start in docker-compose or equivalent, scenario-driven | nightly | docker, minutes | beaconry `test-e2e`, `test-cold-start`, `test-scenarios`; forge `check-strict` |
| **`hardware`** | real devices, lab-dependent — radio rig, UI browser against prod-adjacent, email delivery | nightly | lab | homelab `test-ui`, `test-ui-mobile`, `test-email`; kernel-test `tests/hardware/*.sh` |

## Per-repo mapping

How the fleet's actual targets map onto the taxonomy today. Blanks are gaps.

| Category | shepherd | healthy | beaconry | HRC | homelab | kernel-test | forge |
|---|---|---|---|---|---|---|---|
| `fmt` | — | `zig-fmt` | `lint` wraps ruff-format | `prettier-check` (new) | — | — | — |
| `lint` | `lint` (4 linters) | `lint` (2) | `lint` (ruff) | folded in `check` | `lint` (7) | `lint` (`ci-lint.sh`) | `lint` |
| `typecheck` | folded in `build` | folded in `build` | `type` (pyright) | folded in `check` | — | — | — |
| `unit` | — | — | `test` | — | `test` (+ `test-updates`) | `ci-test` | — |
| `build` | `build` | `build` + `cross` | `build` (no-op) | `build` = check | `build` = `lint` | `programs`, `build` | `build` |
| `verify` | 6 `verify-*` | 3 `verify-*` | **19 `verify-*`** | — | 4 `verify-*` + `check-docs` | 2 `verify-*` | **11 `verify-*`** |
| `integration` | — | `test` (functional TLS/HTTP) | `test-integration` | — | `test` (bots + roles) | `ci-test` | `test-images` |
| `smoke` | `smoke` → `test-acceptance` | `smoke` → `test` | `smoke` | `smoke` → `test` | `smoke` → `check` (operator-only) | `smoke` (tiny+kunit) | `smoke` → `test-fast` (deviation) |
| `scan` | — | — | `dogfood-scan`, `dogfood-sbom` | — | `lint-trivy` | — | `scan`, `scan-regression` |
| `acceptance` | `test-acceptance` | `test-acceptance` | folded in `test` | — | folded in `test` | `test` (VM boots) | `test-acceptance` |
| `e2e` | — | — | `test-e2e`, `test-cold-start`, `test-scenarios` | — | — | `all` | `check-strict` |
| `hardware` | — | — | — | — | `test-ui`, `test-email` | `tests/hardware/*.sh` | — |
| **Special (fleet-unique)** | `injection-drill` | `size`, `cross` | `perf` (BC-132), `audit`, `findings` | `smoke` → tsc | `ci-dry-run`, `ci-hetzner-deploy` | `smoke` (tinyconfig), `dev-test` | `check-smart`, `sign-local`, `dep-graph` |

## Deviations worth calling out

- **forge `smoke`** is `test-fast`, not a service startup — ergonomic alias, works for a build fleet with no runtime service.
- **homelab `smoke`** is `check` which is operator-only (needs vault + SSH). Doesn't fit the CI-friendly definition of smoke. Next alignment pass likely moves homelab's post-merge smoke to `ansible-check` or `lint + check-docs` (see SH-054).
- **homelab `build`** = `lint`. IaC has no runtime artifact; the "build" is the configuration being valid. SH-053 may adjust to `build: ; @true`.
- **HRC `build` = `test` = `smoke`** = `npm run check`. React Native app with no unit harness and no separate build step at the repo level (EAS handles device builds out-of-band).

## How this interacts with the audit

Next re-run of `docs/specs/fleet-consistency-audit-<date>.md` gains a 12th soft column: "taxonomy alignment" — counts how many of the 12 categories the repo has at least one target in. Deviations flagged as `⚠️`, never `❌`.

## How this interacts with the tier contract

The six tiers (`hook-commit`, `hook-push`, `ci-branch`, `ci-patch`, `ci-release`, `ci-nightly`) are the **contract**. The 12 categories are **vocabulary**. A repo's `*_STEPS` variable (SH-044) can name any targets — recommended names from this taxonomy get prettier audit ✅, but native names are accepted.

## Non-goals

- Enforce canonical step names fleet-wide. Explicitly rejected in [dev-workflow contract v3](../plan/IDEAS-dev-workflow-contract-v3.md) — survey showed canonicalizing would be malpractice.
- Rename any existing target in a managed repo. Each repo controls its vocabulary.
- Require every repo to have a target in every category. Gaps are honest; don't paper over them.
