---
created: 2026-11-23
supersedes: docs/plan/IDEAS-dev-workflow-contract-v2.md
source: /home/benni/Downloads/DEV-WORKFLOW.md + /tmp/fleet-makefile-survey.md (1196-line fleet Makefile deep-dive)
scope: fleet-wide (shepherd + 6 armed repos)
status: proposals, three design decisions resolved 2026-11-23
decisions:
  hook_commit_budget_seconds: 15
  make_test_alias_to_ci_branch: no (keeps repo-native)
  ci_patch_design: option_B_spirit_fitting (re-runs the merge-relevant check; homelab=ansible-check, kernel-test=ci-test, HRC=check, others=smoke)
---

# Dev-workflow contract v3 — fleet-shaped proposal

v2 was written against the brief alone. v3 is written after reading every armed repo's Makefile end-to-end. **The brief's direction holds**, but the mechanism needs to flex around three concrete realities the survey surfaced:

1. **`check` means four incompatible things.** shepherd runs full gate + injection-drill; healthy runs cross-compile sweep; beaconry runs lint+type+pytest+19 `verify-*`; homelab's `check` is operator-only (needs vault + SSH, not CI-runnable). HRC and kernel-test have no `check:` at all. Any proposal that tries to canonicalize `check` loses — leave it alone.
2. **Pre-push is split three ways.** pre-commit framework (healthy/beaconry/forge/shepherd), husky (HRC), `.githooks/` + `core.hooksPath` (homelab/kernel-test). Two of those (homelab, kernel-test) also carry a *shadow* `.pre-commit-config.yaml` — the real policy lives in `.githooks/`. `shepherd-bump --verify-prepush` as it stands today will **lie** about those two repos.
3. **`test-affected` means three different things.** Shell tests (4 repos), full `npm run check` (HRC), role-aware with stamp cache (homelab), docker-image-affects (forge). An agent running `make test-affected` does genuinely different work in each repo. Canonicalizing the semantics would be a major rewrite.

The **good news**: the four newer contract targets (`ci-branch`/`ci-patch`/`ci-release`/`ci-nightly`) are already more uniform than anything else in the fleet. The alignment gap is almost entirely in the local-gate layer (hook-commit, hook-push). Fix that and the contract is complete.

## Core design shift from v2 → v3

**v2** proposed a single master `mk/ci.mk` with byte-identical `*_STEPS` variables. That still holds, but v3 reframes it:

- **Tier wrappers are the contract.** The tier name (`hook-commit`, `hook-push`, `ci-branch`, `ci-patch`, `ci-release`, `ci-nightly`) means the same thing in every repo — same budget, same question answered, same artifact expectations.
- **Step names are NOT the contract.** Each repo declares its own `*_STEPS` list. `lint` on homelab (ansible-lint + yamllint + shellcheck + hadolint + ruff + terraform fmt + trivy) is different from `lint` on shepherd (yaml-lint + md-lint + verify-memory-size + verify-traceability). That's fine. What's aligned is the contract: both run when the repo's `hook-commit` tier fires.
- **A step-level taxonomy (fmt / lint / unit / build / verify / …) is a recommendation, not an enforcement.** Enforcing identical step names across kernel-test (bash framework) and beaconry (Python+docker-compose+pytest-xdist) would be malpractice.

This is the thing v2 got wrong by proposing to align `test-affected` across the fleet. v3 explicitly says: **don't**.

---

## Layer 1 — Tier contract (THIS is what the fleet converges on)

Every armed repo exposes these six tier targets, in a byte-identical `mk/ci.mk`. Each is a thin wrapper that iterates a repo-declared `*_STEPS` list.

| Tier | Budget | Question | Scope | Trigger | Protected? |
|---|---|---|---|---|---|
| `hook-commit` | **15 s** | Is this change tidy? | staged files only — fmt, lint-staged, commit-msg, no-secrets | git commit (local) | — |
| `hook-push`   | **2 min** | Is this safe to share? | fast tests + static checks + repo-rules (version/changelog) | git push (local) | — |
| `ci-branch`   | **5 min** | Does this change work on its own? | lint, types, unit, build, affected-only tests | pull_request | ruleset-required |
| `ci-patch`    | **5 min** | Does the merge still work? | smoke, integration, security scan on the merged commit | push: [dev, main] | ruleset-required on main |
| `ci-release`  | **15 min** | Is this exact artifact ready to ship? | FF-promote + tag + publish/sign | workflow_dispatch | admin-only |
| `ci-nightly`  | **∞** (soft 120 min) | What did the fast stages miss? | full matrices, cold builds, e2e, hardware | schedule + workflow_dispatch | never blocks |

**Non-negotiables:**
- Workflow YAML calls `make ci-*` only — no logic in YAML.
- Hook YAML (`.pre-commit-config.yaml` / `.husky/pre-push` / `.githooks/pre-push`) calls `make hook-*` only.
- `timeout-minutes` on the workflow job equals the tier budget (already enforced by `shepherd-bump --verify-timeouts`).
- Each run emits `build/ci-timing.json` (keep the current schema — SH-020 digest + DORA consume it).

**What stays repo-native (do not canonicalize):**
- `make check` — human-dispatched super-set. Leave it alone. Every repo keeps its own meaning.
- `make test` — repo-native fast test for local dev loops. **Do NOT alias to `ci-branch`**. The brief suggests aliasing; after reading the survey, aliasing would mean `make test` on beaconry adds 19 verify-* passes to what's currently a pytest run. Breaks fast iteration. Keep `.shepherd.yml → test:` pointing at the repo-native target.
- Step names inside `*_STEPS` lists — see Layer 2.

---

## Layer 2 — Step taxonomy (RECOMMENDATION, not enforcement)

The 12 categories from the brief (fmt / lint / typecheck / unit / build / verify / integration / smoke / scan / acceptance / e2e / hardware) become a **taxonomy doc** at `docs/specs/test-taxonomy` (future). Repos are **encouraged** to name a target `unit` if it runs unit tests, `scan` if it runs a security scanner, etc. — but no verifier fails on a deviation.

Audit (`fleet-consistency-audit-<date>.md`) gets a new column: "step taxonomy alignment" showing which repos use canonical names vs. aliases. Gentle pressure; not a gate.

**Why not enforce**: the survey shows beaconry's step shape (19 `verify-*`) is genuinely different from kernel-test's (2 `verify-*`). Forcing the same names loses information.

---

## Layer 3 — Fleet-specific `*_STEPS` blocks (concrete migration target)

Each block is what the repo sets BEFORE `include mk/ci.mk`. Derived from the survey, not invented — these are the targets each repo ALREADY has. Only the grouping is new.

```make
# shepherd — Zig CLI, DD-TGD fleet brain
COMMIT_STEPS  = yaml-lint md-lint verify-memory-size
PUSH_STEPS    = verify-traceability build test-acceptance
BRANCH_STEPS  = lint build test-acceptance injection-drill
PATCH_STEPS   = smoke
RELEASE_STEPS = ci-release-promote
NIGHTLY_STEPS = injection-drill
```

```make
# healthy — Zig single-binary HTTP client
COMMIT_STEPS  = zig-fmt shell-lint verify-traceability
PUSH_STEPS    = build test verify-version-bumped verify-changelog
BRANCH_STEPS  = lint build test test-acceptance
PATCH_STEPS   = test-acceptance cross
RELEASE_STEPS = verify-changelog cross
NIGHTLY_STEPS = cross test test-acceptance
```

```make
# beaconry — Python CVE scanner + compose stack (19 verify-*)
COMMIT_STEPS  = lint type
PUSH_STEPS    = check-fast verify-version-bumped verify-changelog verify-feature-complete
BRANCH_STEPS  = lint type test verify-docs-drift verify-variables
PATCH_STEPS   = smoke test-integration
RELEASE_STEPS = verify-changelog verify-version-sync smoke
NIGHTLY_STEPS = test-e2e test-cold-start test-scenarios
```

```make
# ham-radio-compass — React Native / Expo (no unit harness today)
COMMIT_STEPS  = prettier-check                        # (*) target to add; npx prettier . --check
PUSH_STEPS    = check                                 # (*) alias for npm run check (tsc + eslint)
BRANCH_STEPS  = check
PATCH_STEPS   = check                                 # Option B: re-run tsc + eslint on merged commit
RELEASE_STEPS = ci-release-promote
NIGHTLY_STEPS = check prettier-check                  # same work, cold runner
```

```make
# homelab — Ansible IaC, role-aware
COMMIT_STEPS  = lint-context shellcheck-staged yamllint-staged
PUSH_STEPS    = lint-updates test-updates
BRANCH_STEPS  = lint-updates test-updates check-docs
PATCH_STEPS   = ansible-check                         # Option B: (*) new target; ansible --check dry-run against staging. Extracts the dry-run currently bundled inside ci-branch.yml's "Dry-run against server" job.
RELEASE_STEPS = ci-release-promote
NIGHTLY_STEPS = lint test test-ui lint-trivy
```

```make
# kernel-test — kernel CI harness
COMMIT_STEPS  = shellcheck-staged
PUSH_STEPS    = lint ci-test
BRANCH_STEPS  = lint programs ci-test
PATCH_STEPS   = ci-test                               # Option B: re-run framework self-tests against the merged commit (~30 s). No QEMU boot — that lives in ci-nightly.
RELEASE_STEPS = ci-release-promote
NIGHTLY_STEPS = lint ci-test                          # framework-only per yesterday's fix
```

```make
# forge — container-image build fleet (11 verify-*, scope-aware)
COMMIT_STEPS  = lint verify-sid-pins verify-traceability
PUSH_STEPS    = check-smart
BRANCH_STEPS  = lint check-smart test-acceptance
PATCH_STEPS   = smoke scan-regression
RELEASE_STEPS = verify-sid-pins verify-traceability
NIGHTLY_STEPS = check-strict
```

Targets marked `(*)` don't exist yet and need to be added. Fleet migration wave adds those first, then the `mk/ci.mk` import.

---

## Protected: pre-push mechanism accepts three forms

v2 had `--verify-prepush` reading `.pre-commit-config.yaml` + `.husky/pre-push` only. Survey showed two repos (homelab, kernel-test) use `.githooks/` + `core.hooksPath` and the `.pre-commit-config.yaml` is a shadow file that doesn't fire.

**Fix:** `--verify-prepush` accepts THREE forms:
1. `.pre-commit-config.yaml` with `entry: … make hook-push …` + `stages: [pre-push]`
2. `.husky/pre-push` script invoking `make hook-push`
3. `.githooks/pre-push` script invoking `make hook-push` **AND** `git config core.hooksPath` is set to `.githooks`

Report per-repo which form is in use. Prevents the "shadow .pre-commit-config exists but doesn't run" false-pass.

---

## Verifier contract upgrade

Extend `shepherd-bump --verify-contract` (SH-017) to validate both shape AND steps:

1. **Shape check (existing)**: Makefile declares `hook-commit`, `hook-push`, `ci-branch`, `ci-patch`, `ci-release`, `ci-nightly`, `build`, `test` as `.PHONY` targets.
2. **Include integrity check (new)**: `mk/ci.mk` sha256 matches master (`bboortz/shepherd/mk/ci.mk`).
3. **Step reachability check (new)**: every string in the repo's `*_STEPS` variables maps to a real `.PHONY` target — no dangling references.
4. **Opt-out knob**: `.shepherd.yml → contract.enforce_mk_include: false` lets a repo opt out of the sha256 check during migration.

Exit codes stay 0 / 3 (missing file) / 4 (malformed or dangling step).

---

## What this proposal does NOT change

- `make check` — unchanged per repo.
- `make test` — unchanged per repo. `.shepherd.yml → test:` keeps pointing at the repo-native target.
- Step names inside `*_STEPS` — repos keep their native names (`check-smart`, `test-updates`, `check-fast`, `test-acceptance`, etc.).
- Existing workflow files — only change is `timeout-minutes` (already aligned) and the Makefile target they call (`make ci-branch` etc. — already aligned).
- `.github/workflows/`, `.shepherd.yml`, `templates/` — stay human-owned per §12.
- Any repo's existing `verify-*` targets — survey shows beaconry has 19, forge has 11, the rest have 2–6. Each repo keeps its own set.

---

## Migration plan (ROI-ranked)

### SH-042 — `hook-commit` and `hook-push` named tiers (highest value)

Per-repo PR: add `hook-commit` and `hook-push` as thin wrappers over existing step aggregates. Each repo's wrapper is ≤5 lines. No step renames. No step moves. Just the tier entry-point.

After this lands, agents and humans both call `make hook-push` before pushing instead of memorizing the per-repo incantation.

7 PRs. Each minimal.

### SH-043 — `shepherd-bump --verify-prepush` accepts `.githooks/` form

Extends the verifier to recognize the third mechanism. Dogfood: homelab + kernel-test currently fail under the old verifier logic silently (survey finding). This fix exposes + confirms them.

Shepherd-only. 1 PR.

### SH-044 (umbrella) — ship `mk/ci.mk` as the master include

- Shepherd PR: add `mk/ci.mk` as new file with the tier wrappers + `run-steps` macro + sha256 manifest. Protect under §12 (`mk/**`).
- `shepherd-bump --verify-contract` upgrade: sha256 check + step reachability check.
- Dogfood: migrate shepherd's own Makefile to the new pattern.

Decomposes to SH-045 … SH-051 (one per managed repo migration).

### SH-052 — step taxonomy doc

`docs/specs/test-taxonomy` (future). 12 categories, examples, "recommended name" column. Zero code change. Audit matrix gains a new "taxonomy alignment" column (soft).

Shepherd-only. 1 PR.

### SH-053 — `.shepherd.yml` contract tune-up

Per §9 of the brief:
- forge: ensure `test: make test` (currently `make test-fast` per brief; survey shows `test: test-fast` which IS `test`'s delegate — borderline aligned).
- beaconry: `build: make build` — already set per BC-148.
- homelab: `build: make build` — currently `make lint`. Change to a new `build: ; @true` target or keep as-is with explicit note.
- kernel-test: `build: make build` / `test: make test` — currently `make programs` / `make ci-test`.

One-line edits per repo. 4 tiny PRs.

### SH-054 — homelab `push: [dev, main]` trigger removal

Final brief-§9 partial. Remove the double-fire. 1 PR.

---

## Resolved decisions (2026-11-23)

1. **`hook-commit` budget: 15 s** (relaxed from brief's 10 s). kernel-test's `shellcheck-staged` alone can take 5–8 s on a cold runner; 15 s gives real headroom while still staying "faster than people notice."

2. **`make test` is the repo-native full test run, not an alias to `ci-branch`.** Same semantics as today: each repo keeps its existing `test:` body (shepherd `test-acceptance`, healthy `test/run.sh`, beaconry pytest, etc.). `.shepherd.yml → test:` continues pointing at the repo-native target. The brief's "test = ci-branch" aliasing suggestion is **rejected** — it would slow dev feedback loops in 3+ repos without catching anything new.

3. **`ci-patch` design: Option B — spirit-fitting.** Each repo's `PATCH_STEPS` runs the thing that most closely answers "does the merge still work?":
   - shepherd / healthy / beaconry / forge: `smoke` + optional integration/scan (as drafted above)
   - **HRC**: `check` — re-runs tsc + eslint on the merged commit
   - **homelab**: `ansible-check` — new `(*)` target to add; extracts the Ansible dry-run currently bundled inside ci-branch.yml's "Dry-run against server" job
   - **kernel-test**: `ci-test` — re-runs framework self-tests against the merged commit (~30 s). No QEMU boot; that stays in ci-nightly.

   Contract shape stays uniform across the fleet; content is tier-appropriate per repo.

---

## What v3 fixes from v2

- v2 said "rename step names fleet-wide to canonical taxonomy." v3 explicitly rejects that after seeing the survey.
- v2 said `--verify-prepush` is complete. v3 extends it to `.githooks/` form (homelab + kernel-test gap).
- v2 proposed `make test` alias to `ci-branch`. v3 recommends against it.
- v2 proposed per-repo `*_STEPS` blocks sight-unseen. v3's blocks map 1:1 to targets that already exist (verified via survey).
- v2's P5 (explicit `.shepherd.yml → blocklist`) is deferred. The hard-coded blocklist in `validate.sh` is working; adding the per-repo YAML field adds surface for drift. Revisit after the agent flow uses it in anger.

---

## One-sentence summary

**Canonical tier wrappers (hook-commit, hook-push, ci-branch, ci-patch, ci-release, ci-nightly), repo-declared step lists, one byte-identical `mk/ci.mk`, zero step-name coercion.** Six SH-NNN stories, ordered by ROI.
