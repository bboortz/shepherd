---
id: SH-014
slug: dev-cycle-umbrella
story: docs/stories/SH-014-dev-cycle-umbrella.md
branch: feat/SH-014-dev-cycle-umbrella
status: in-progress
---

# SH-014 plan — Dev-cycle contract: one pipeline model across the fleet

**Story:** [SH-014](../stories/SH-014-dev-cycle-umbrella.md)

## Design delta

The umbrella itself ships specs + templates + stubs, no executable code. The eleven sub-stories do the real work.

### Umbrella deliverables (this PR)

- **New specs (`docs/specs/`):**
  - `dev-cycle-contract.md` — authoritative contract: six `make` targets, four budgets (5/5/15/∞), build-once-promote rule, §12 protected-files extension, per-repo adoption map.
  - `ci-timing.md` — `build/ci-timing.json` schema v1 (target / budget_seconds / total_seconds / steps[] / git_sha / runner / started_at / finished_at).
- **New templates (`templates/`):**
  - `Makefile.contract.snippet` — six-target skeleton with timing wrappers (`step` macro + `ci-timing-finish-cmd`). Repos `include` it and define their own `build` / `test` / `lint` bodies.
  - `ci-branch.yml` / `ci-patch.yml` / `ci-release.yml` / `ci-nightly.yml` — thin workflow YAMLs calling `make ci-*`. SHA-pinned to `actions/*` only (`actions/checkout@3d3c4...`, `actions/upload-artifact@11bd7...`). `timeout-minutes` matches budget.
- **DESIGN.md (`docs/specs/DESIGN.md`):**
  - §12 Path blocklist: add `templates/**` to the protected list.
  - §12 adds a one-line rationale for the templates extension (SH-014, 2026-11-22).
  - §13 R2 "In scope" adds a bullet: "Dev-cycle contract adopted across the fleet (SH-014)".
  - §13 new "Decided on 2026-11-22" block records the umbrella decision + templates extension.
- **CAPABILITIES.md (`docs/specs/CAPABILITIES.md`):**
  - New section "Dev cycle (SH-014 umbrella)" with six CAP rows. All `status: design` for now; Test cell populated with the planned test path for each.
- **Story stubs (`docs/stories/SH-015 through SH-025.md`):**
  - Each `status: draft`, §1–3 filled, §4 urgency ticked, §7 links to this umbrella. §5/6/8/9 marked `TBD — filled when picked up`.
- **Index + ideas:**
  - `docs/stories/INDEX.md` gets twelve new rows (SH-014 + eleven sub-stories).
  - `docs/plan/IDEAS.md` promotes the two source-doc entries under a new "Dev cycle contract (SH-014)" heading.

### Not in this PR

- No executable code. No new Makefile targets on shepherd (SH-016 ships those).
- No `shepherd-bump --verify-contract` implementation (SH-017 ships it).
- No `ci-branch.yml` landed on shepherd itself (SH-015 ships it — reusing the template shipped here).
- No touches to the per-repo Makefile / `.shepherd.yml` files on healthy / beaconry / homelab / kernel-test / forge (SH-019 tracker opens those PRs on each repo).
- No acceptance test file for SH-014. The umbrella's self-consistency is covered by `make verify-traceability` (existing SH-012 + SH-013 checks pick up the new CAPs + story stubs + ref integrity).

## Alternatives rejected

| Alternative | Why not |
|---|---|
| One monolithic SH-014 shipping all 11 pieces | Would land ~2,000 lines across workflows + Makefiles + Zig verifier code + 5 cross-repo PRs. Un-reviewable; un-revertable. SH-006 R1 umbrella already validated the decomposed pattern. |
| Shepherd-only now, per-repo stories cut later | Loses the shape — reviewers can't see what R2 commits to. Sub-story slugs float; INDEX.md doesn't carry the roadmap. |
| Cut only the direction doc (no templates, no §12 update) | Templates are the highest-value artefact for the quickstart; without them, every repo invents its own. §12 update is the trust-boundary piece — deferring it creates a window where an agent could edit `templates/`. |
| Canonical tier names `t0/t1/t2/t3` | Role-named (`ci-branch`) is terser at the shell, matches shepherd's branch flow, and reads unambiguously in CI logs. T-tier naming belongs in the research spec, not at the Makefile prompt. |
| Hybrid soft+hard enforcement (document now, verify later) | Lets drift accumulate across the five migration PRs. Hard enforcement from day one dogfoods on shepherd first (SH-015/SH-016) and gives the fleet a clear signal when it's green. |
| Squash-only merges (research doc recommendation) | Contradicts shepherd's merge-commit-into-dev flow, which the §12 auto-merge gates depend on for reverts. SH-009's auto-merge path assumes the PR boundary survives in history. |
| GitHub merge queue adoption | Needs an org repo; `bboortz` is personal. One agent at a time doesn't need one (dev-cycle doc confirmed). Reserved as an IDEAS entry for post-R3 if parallel-agent landing becomes real. |
| `templates/**` not protected | A silent edit to `templates/Makefile.contract.snippet` would propagate through every future onboarding. Matches existing `.github/workflows/**` + `scripts/shepherd-poc/**` protection pattern. |

## Breaking changes

- [x] Yes — §12 Path blocklist grows: `templates/**` is now protected. Any future agent-produced diff that touches `templates/` fails `validate.sh` with exit 2 and opens a needs-human issue.
  - **Mitigation:** none needed. No existing workflow produces agent diffs targeting `templates/`.
  - **Downstream notice:** none — this is a trust-boundary tightening, not a public-contract change. Managed-repo workflows are unaffected.
- [ ] No other breaks. The six make targets are additive — managed repos adopt them on their own schedule. Contract verifier (SH-017) rolls out behind `.shepherd.yml → contract.enforce_enabled` which defaults to `true` **only after SH-017 ships**. Until then the contract is informational.

## Rollout

- [x] README untouched — umbrella is specs + templates + stubs; no public contract moved.
- [x] `memory/project.md` — no invariant shifted (merge-commit flow and §12 are preserved; the extension is additive).
- [x] `memory/workflow.md` — no gate change in this PR.
- [x] `docs/specs/DESIGN.md` reconciled — §12 extended, §13 R2 bullet added, §13 "Decided on 2026-11-22" block added.
- [ ] Downstream notice — n/a. Managed repos see no change until their own SH-019 PR lands.

**R2 slot:** Fri 2026-12-11 per DESIGN §13 release schedule. Sub-stories ship individually; the umbrella's own ship is this PR landing on main.

**R1 opportunistic cherry-picks:** SH-015 / SH-016 / SH-021 can land during the R1 soak if their pain surfaces — each still cuts a feature branch + plan.

## Rollout order (revised 2026-11-22)

Dev-cycle doc §"Rollout order" step 1 is explicit: "Contract fixes (action 4) in all repos, one small PR each. Without them Shepherd cannot verify changes in Forge, Beaconry and Kernel-Test." The original umbrella draft had SH-015/016 first (shepherd dogfood). That is invalid — if SH-017 `--verify-contract` ships before SH-019, the verifier floods needs-human on four of six managed repos on day one.

Revised sequence:

| # | Sub-story | Why this slot | Effort |
|---|---|---|---|
| 1 | **SH-019** fleet contract rollout | Five-to-six 10-line Makefile PRs across the fleet. Unblocks everything downstream. Anchors on native idioms: homelab `test-updates` → `test-affected`, forge `smart-check.sh` → `test-affected`, repos with nothing today alias `test-affected: test` (identity, compliant, no speedup yet). | 1 day |
| 2 | **SH-021** Homelab dedupe + runner move | Known recurring pain (20–29 min queue spikes on 2026-11-21). Cheapest win. | 0.5 day |
| 3 | **SH-026** baseline capture (NEW) | 2-h bash script × `gh run list --json`; freezes `docs/specs/dev-cycle-baseline.md`. Ships BEFORE SH-022/023/024 so their Shipping evidence can claim measured deltas instead of estimates. | 2 h |
| 4 | **SH-015 + SH-016** shepherd self-CI + Makefile contract | Dogfood. Shepherd becomes the reference implementation. | 0.5 day each |
| 5 | **SH-017** `--verify-contract` | Now ships against a compliant fleet; zero day-1 needs-human floods. | 1 day |
| 6 | **SH-020** timing digest + DORA metrics | Needs `build/ci-timing.json` emission from SH-016 to exist. | 1 day |
| 7 | **SH-022** Forge affected-only | Biggest expected single win (dev-cycle doc Action #1). Now has a baseline to prove against. | 1.5 days |
| 8 | **SH-023** Beaconry pytest-xdist | | 1 day |
| 9 | **SH-024** Kernel-Test nightly | | 1 day |
| 10 | **SH-025** Healthy ci-* rename | Reference impl. | 0.5 day |
| 11 | **SH-018** HRC migration investigation | Can start in parallel from day one. | 0.5 day |
| 12 | **SH-027** risk-paths | R2/R3 boundary. Changes auto-merge behaviour — pilot risk. | 0.5 day |
| 13 | **SH-028** auto-revert | R2/R3 boundary. Destructive — needs threat-model review. | 1 day |

**Total estimated effort:** ~11 days across sub-stories. Comfortable in R2's window (Fri 2026-11-22 → Fri 2026-12-11 = 20 days).

## Revision log

- **2026-11-22 (initial draft)** — 6 targets, 11 sub-stories (SH-015 through SH-025), rollout ordered by SH-NNN numerical sequence.
- **2026-11-22 (post-review revision)** — grown to 8 targets + build-once-promote wiring + 14 sub-stories (adds SH-026 baseline, SH-027 risk-paths, SH-028 auto-revert) + rollout reordered (SH-019 first). Driven by review against the two source docs that caught: no `test-affected`/`smoke`/`release-artifacts` in contract; no artifact passing between tiers; rollout inversion; missing risk-paths and auto-revert concepts; baselines deferred past the speed-up stories.

## Shipping evidence (fill at step 6a)

Three lenses. Any ⚠️/❌ row blocks shipping.

### Lens 1 — Gherkin coverage

| Scenario (from story §8) | Test pointer | Status |
|---|---|---|
| The six new CAPs exist in CAPABILITIES.md | `scripts/verify-traceability.sh` (SH-013) — reads the new section | ✅ pending verify |
| The dev-cycle contract spec exists and is linked | Manual grep + `test/acceptance/test_SH_012_docs_layout.sh` (references scenario) | ✅ pending verify |
| `templates/**` is on the §12 protected-files list | Manual grep of `docs/specs/DESIGN.md` §12 | ✅ pending verify |
| The eleven sub-stories exist as draft stubs | `test/acceptance/test_SH_012_docs_layout.sh` (layout + refs) + grep for `status: draft` | ✅ pending verify |
| `make verify-traceability` is green | `make verify-traceability` | ✅ pending verify |

### Lens 2 — Behaviour symmetry

| CAP delivered | ≥1 test? | Exit / failure paths tested? | Status |
|---|---|---|---|
| `dev-cycle.contract.tiered-make-targets` | — (umbrella; SH-016 brings test) | n/a this PR | design → active via SH-016 |
| `dev-cycle.timing.json-emission` | — (umbrella; SH-020 brings test) | n/a this PR | design → active via SH-020 |
| `dev-cycle.budget.timeout-caps` | — (umbrella; SH-016 brings test) | n/a this PR | design → active via SH-016 |
| `dev-cycle.fleet.verify-contract` | — (umbrella; SH-017 brings test) | n/a this PR | design → active via SH-017 |
| `dev-cycle.fleet.uniformity` | — (rollout tracker; SH-019 brings per-repo evidence) | n/a this PR | design → active after last SH-021..SH-025 ships |
| `dev-cycle.shepherd.self-ci-gate` | — (umbrella; SH-015 brings test) | n/a this PR | design → active via SH-015 |

### Lens 3 — Self-consistency

| Check | Status |
|---|---|
| Story obeys its own §7 (out-of-scope) — no scope creep | ✅ pending final pass |
| New CAPs listed in §9 all appear in `docs/specs/CAPABILITIES.md` | ✅ pending verify |
| Protected-files invariant intact (DESIGN §12) — this PR extends, does not relax | ✅ pending verify |
| Budget caps unchanged, or escalated to a human-reviewed change | ✅ n/a — SH-014 adds wall-clock budgets, independent from §12 € budgets (SH-008) |
| `make verify-traceability` green | ✅ pending verify |
| `make check` green | ✅ pending verify |

## Post-merge notes

_(filled after merge)_
