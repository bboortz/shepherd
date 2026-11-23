---
id: SH-014
slug: dev-cycle-umbrella
status: shipped
created: 2026-11-22
owner: @benni
---

# SH-014 — Dev-cycle contract: one pipeline model across the fleet

> **Umbrella story.** The one-pipeline model (`docs/specs/dev-cycle-contract.md`) bundles fourteen distinct deliverables. This story owns the direction + exit criteria + CAP list; the plan doc splits it into fourteen sub-stories (SH-015..SH-028) that ship independently. Follows the SH-006 pattern.
>
> **Scope revised 2026-11-22** after post-draft review against both source docs: the contract grew from 6 to 8 targets (added `test-affected`, `smoke`, `release-artifacts` — the agent entry points that carry build-once-promote between tiers); templates now wire `actions/upload-artifact` + `actions/download-artifact` keyed by commit SHA; rollout re-ordered so SH-019 (fleet contract fixes) ships FIRST per dev-cycle doc §"Rollout order" step 1; three new sub-stories cut (SH-026 baseline capture, SH-027 risk-paths, SH-028 auto-revert).

## 1. Who is the consumer?

- **Contributor extending Shepherd** (human + Claude). Needs one Makefile shape they can learn once and apply to any managed repo. Today each repo has its own idiom; cross-repo work loses minutes to idiom-shopping.
- **Shepherd's own verifier.** Reads `.shepherd.yml` → `build` + `test` today. Tomorrow a future scope-level-3 agent reads `ci-*` targets + `build/ci-timing.json` to propose Makefile improvements without touching workflow YAML (which stays on the §12 protected list).
- **Repo owner onboarding a new repo.** Instead of inventing a pipeline shape, copy `templates/Makefile.contract.snippet` + the four `templates/ci-*.yml` workflows and fill in the repo-specific `build` / `test` bodies.

## 2. When does the story fire?

- Every `make check` on shepherd itself (once SH-015 lands) — PR gate.
- Every managed-repo verification run (once SH-017 lands) — `shepherd-bump --verify-contract` fails fast if the Makefile is missing a contract target.
- Every onboarding of a new repo — the quickstart's copy-paste set now includes `templates/Makefile.contract.snippet` + `templates/ci-*.yml`.
- Every nightly digest run (once SH-020 lands) — consumes `build/ci-timing.json` artifacts and flags tier budget breaches.

## 3. What does success look like?

Mechanically checkable, decomposed by sub-story:

### SH-014 umbrella (this story)

- `docs/specs/dev-cycle-contract.md` exists and names the six targets, four budgets, build-once-promote rule, and §12 protected-files extension.
- `docs/specs/ci-timing.md` exists and defines `build/ci-timing.json` schema v1.
- `templates/Makefile.contract.snippet` + `templates/ci-branch.yml` + `templates/ci-patch.yml` + `templates/ci-release.yml` + `templates/ci-nightly.yml` exist, SHA-pinned to `actions/*`, timeout-minutes matched to budgets.
- `docs/specs/DESIGN.md §12` adds `templates/**` to the protected-files list; §13 "Decided on 2026-11-22" records the umbrella decision.
- `docs/specs/CAPABILITIES.md` lists the six new CAPs under "Dev cycle (SH-014 umbrella)".
- `docs/stories/SH-015..SH-025` exist as `status: draft` stubs with §1–3 filled and the slug reserved.
- `docs/stories/INDEX.md` lists all twelve rows (SH-014 + eleven sub-stories).
- `docs/plan/IDEAS.md` moves the two source-doc entries into "Promoted".

### SH-015 — shepherd self-CI gate

- `.github/workflows/ci-branch.yml` on shepherd runs `make check` on every PR. Timeout 5 minutes. SHA-pinned actions only.
- Dogfoods the contract: shepherd is the first repo whose Makefile exposes `ci-branch` properly.

### SH-016 — shepherd Makefile contract

- Shepherd's own `Makefile` exposes `ci-branch` + `ci-patch` + `ci-release` + `ci-nightly`, each emitting `build/ci-timing.json` matching the schema.
- The four workflow templates become live workflows on shepherd (via SH-015/SH-016 together).

### SH-017 — `shepherd-bump --verify-contract`

- New verb on `shepherd-bump`: scans the managed repo's Makefile; exits 3 if any contract target is missing; opens a needs-human issue naming the gap. Symmetric with `--verify-dependabot`.
- `.shepherd.yml` → `contract.enforce_enabled` toggles the verifier (default `true`).

### SH-018 — HRC migration investigation

- Audit ham-radio-compass against the contract; produce a migration plan as a plan-doc appendix. Land the PRs on HRC until the verifier is green.

### SH-019 — fleet contract-rollout tracker

- Tracks per-repo Makefile + `.shepherd.yml` fixes for healthy / beaconry / homelab / kernel-test / forge. Each row in FLEET.md gets a `contract-adopted: <PR link>` cell.
- Fixes themselves land as human-driven PRs in each repo (not automated by the agent — §12 protected on each side).

### SH-020 — `build/ci-timing.json` digest

- Extends the stubbed `digest.yml` to download `ci-timing-*` artifacts across the fleet, compute per-repo per-tier rolling medians, and open a needs-human issue when any tier exceeds its `budget_seconds` or grows 25 % over its 14-day median.

### SH-021..SH-024 — per-repo deep speed-ups

- SH-021 Homelab: dedupe push+PR triggers; move Lint off `server2`.
- SH-022 Forge: affected-only test matrix in `ci-branch` (reuse `scripts/affected_images.py`).
- SH-023 Beaconry: add `pytest-xdist`; split `make check` into `check-fast` + nightly.
- SH-024 Kernel-Test: `ci-nightly` with tinyconfig x86_64 smoke + QEMU boot.

### SH-025 — healthy `ci-*` rename

- Healthy adopts the shared target names; becomes the reference implementation named from the dev-cycle doc.

## 4. How urgent?

- [ ] Security-critical
- [ ] Correctness
- [x] Quality-of-life (uniform shape across six repos saves minutes per cross-repo task and unlocks a future scope-level-3 agent)
- [x] Onboarding (every new repo onboards with one copy-paste set instead of inventing a pipeline shape)

R2 (2026-12-11) target per the "release" question answered 2026-11-22. R1 opportunistic cherry-picks (SH-015, SH-016, SH-021 if Homelab queue spikes recur) explicitly allowed — see §7.

## 5. Happy path

```
# A new repo onboards (R2 world):

$ gh repo clone myorg/new-service
$ cp templates/shepherd.yml                   new-service/.shepherd.yml
$ cp templates/caller-shepherd.yml            new-service/.github/workflows/shepherd.yml
$ cp templates/Makefile.contract.snippet      new-service/.make/shepherd-contract.mk
$ cp templates/ci-branch.yml                  new-service/.github/workflows/ci-branch.yml
$ cp templates/ci-patch.yml                   new-service/.github/workflows/ci-patch.yml
$ cp templates/ci-release.yml                 new-service/.github/workflows/ci-release.yml
$ cp templates/ci-nightly.yml                 new-service/.github/workflows/ci-nightly.yml

# Edit Makefile to include the snippet and define repo-specific build/test:
$ printf 'include .make/shepherd-contract.mk\nbuild: ; zig build --prefix .\ntest: ; test/run.sh\nlint: ; yamllint .\n' >> new-service/Makefile

$ git add . && git commit -m "feat: onboard to shepherd + adopt dev-cycle contract" && git push
# PR opens. ci-branch runs in <5 min. shepherd-bump --verify-contract passes.
# Weekly digest reports: "new-service ci-branch median 3.4 min (budget 5 min) ✓".
```

## 6. Edge cases / failure modes that matter

- A repo overrides `ci-branch` body with a 20-minute cold build. `timeout-minutes: 5` in `templates/ci-branch.yml` kills it at 5. Needs-human fires naming the budget breach.
- A repo's `make -n ci-branch` exits non-zero (target missing). `shepherd-bump --verify-contract` exits 3; needs-human issue opens with the missing target(s) and a copy-paste snippet.
- `build/ci-timing.json` fails to write (jq missing, shell quirk). Workflow continues; artifact upload is `if-no-files-found: ignore`; digest warns.
- Two sub-stories race on the same `.github/workflows/ci-*.yml` file in shepherd. Umbrella sequences them: SH-015 (ci-branch only) lands first; SH-016 adds the other three.
- HRC's audit (SH-018) surfaces that HRC cannot meet one of the budgets on current hardware. SH-018's migration plan documents a documented-gap entry in FLEET.md until it can.

## 7. Out of scope

- Squash-only merges (contradicts shepherd's `feat/* → dev → main` merge-commit flow; auto-merge depends on the commit boundary).
- GitHub merge queue (needs org repo; not applicable to `bboortz`).
- Expanding self-hosted runners beyond the existing `server2` Lint job on `bb-claw/homelab`.
- Dagger / Earthly as the pipeline runtime. Future candidate for Forge only; not blocking SH-014.
- Device-side pipelines (post-R3 scope per DESIGN §13).
- macOS / Windows runners (DESIGN §13 "Linux first").
- SH-008 €/API budget caps. SH-008 is a parallel track; the two overlap only in the word "budget" (seconds vs. euros).

**Opportunistic R1 cherry-picks explicitly allowed (not scope creep):** SH-015 (shepherd self-CI), SH-016 (shepherd Makefile contract), and SH-021 (Homelab dedupe) may land during R1 soak if pain surfaces. Each still goes through its own PR + plan — the umbrella is the direction, not the vehicle.

## 8. Acceptance (Gherkin → test assertions)

The umbrella itself ships specs + templates + stubs, no acceptance test. Each sub-story brings its own Gherkin + test. For completeness, the umbrella's self-consistency assertions (verified by `make verify-traceability` + a manual read of the plan's Shipping evidence table at step 6a):

```gherkin
Scenario: the six new CAPs exist in CAPABILITIES.md
  Given docs/specs/CAPABILITIES.md
  Then  the "Dev cycle (SH-014 umbrella)" section lists
        dev-cycle.contract.tiered-make-targets,
        dev-cycle.timing.json-emission,
        dev-cycle.budget.timeout-caps,
        dev-cycle.fleet.verify-contract,
        dev-cycle.fleet.uniformity,
        dev-cycle.shepherd.self-ci-gate

Scenario: the dev-cycle contract spec exists and is linked
  Given docs/specs/dev-cycle-contract.md
  Then  it names six make targets and four budgets
  And   docs/specs/DESIGN.md §13 "Decided on 2026-11-22" links to it

Scenario: templates/ is on the §12 protected-files list
  Given docs/specs/DESIGN.md §12 Path blocklist
  Then  it names templates/** as a protected path

Scenario: the eleven sub-stories exist as draft stubs
  Given docs/stories/
  Then  SH-015..SH-025 exist as files
  And   each has frontmatter status: draft
  And   each links back to SH-014-dev-cycle-umbrella.md

Scenario: make verify-traceability is green
  Given the umbrella branch
  When  make verify-traceability runs
  Then  exit code is 0
```

## 9. Capabilities delivered or extended

Nine new CAPs (revised from six after 2026-11-22 scope revision). The umbrella names them; each ships as its named sub-story flips `design → active`.

- `dev-cycle.contract.tiered-make-targets` — eight-target Makefile contract (build, test, test-affected, smoke, release-artifacts, ci-branch, ci-patch, ci-release, ci-nightly). Delivered by SH-016.
- `dev-cycle.timing.json-emission` — `build/ci-timing.json` schema + emission + DORA metrics in digest. Delivered by SH-020.
- `dev-cycle.budget.timeout-caps` — hard `timeout-minutes` per tier. Delivered by SH-016.
- `dev-cycle.artifact.build-once-promote` — `upload-artifact` in ci-branch + `download-artifact` in ci-patch wire the invariant mechanically. Delivered by SH-016.
- `dev-cycle.fleet.verify-contract` — `shepherd-bump --verify-contract`. Delivered by SH-017.
- `dev-cycle.fleet.uniformity` — contract adopted on all six fleet repos. Delivered by SH-018 + SH-019 + SH-021..SH-025 (rollout tracker).
- `dev-cycle.baseline.frozen-snapshot` — pre-adoption fleet timings frozen to `docs/specs/dev-cycle-baseline.md`. Delivered by SH-026.
- `dev-cycle.shepherd.self-ci-gate` — shepherd's own PR `make check` gate. Delivered by SH-015.
- `risk-paths.human-approval-required` — distinct from §12 blocklist; agent CAN write, human MUST approve. Delivered by SH-027.
- `auto-revert.patch-tier` — opt-in revert PR on `ci-patch` failure. Delivered by SH-028.

All listed under "Dev cycle (SH-014 umbrella)" in `docs/specs/CAPABILITIES.md`.

---

## Plan doc

[`docs/plan/SH-014-dev-cycle-umbrella-plan.md`](../plan/SH-014-dev-cycle-umbrella-plan.md).
