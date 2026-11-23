---
created: 2026-11-23
source: /home/benni/Downloads/DEV-WORKFLOW.md
scope: fleet-wide (shepherd + 6 armed repos)
status: proposals (not yet promoted to SH-NNN stories)
---

# Dev-workflow contract v2 — proposals

Analysis of the DEV-WORKFLOW.md brief vs. the current state of the fleet after SH-014 / SH-030–033 / SH-035–041 landed. The brief's direction is tight — most of it is already shipped. This doc captures the delta: what's ALREADY matching the brief, what's DIVERGING, and concrete SH-NNN candidates to close each gap.

## Snapshot of alignment

| Brief section | Fleet state today | Gap |
|---|---|---|
| **§1 Principles** (6 principles) | 5/6 ✅ shipped (contract, build-once, hard timeouts, logic-in-Makefiles, nightly-never-blocks). | 1 gap: "pre-push subset of branch" — our pre-push runs full `make check`, not a subset (see Proposal **P1**). |
| **§2 Six stages** | 4/6 ✅ shipped (`ci-branch`, `ci-patch`, `ci-release`, `ci-nightly` with 5/5/15/∞ budgets). | 2 gaps: no distinct `pre-commit` / `pre-push` tiered Makefile targets (Proposal **P1**). |
| **§3 Test categories** | Informally present per-repo. Not formalized. | Document the 12 categories as a shared taxonomy (Proposal **P2**). |
| **§4 Shared `mk/ci.mk`** | Not shipped. We have `templates/Makefile.contract.snippet` which each repo copies (drifts). | Promote to `mk/ci.mk` with `*_STEPS` variables + byte-identical include (Proposal **P3** — highest value). |
| **§5 Per-repo steps** | Each repo has its own tier bodies. Not reduced to `*_STEPS` lists yet. | After P3, each repo trims to a declarative `*_STEPS` block (Proposal **P4**). |
| **§6 Branches + merging** | ✅ shipped via SH-029 + SH-032. 7/7 on `dev`, FF-only to `main`, auto-merge per repo. | None. |
| **§7 Hooks** | ✅ pre-push via SH-033 (7/7 wired to `make check`). No `make hook-push` target. | Rename-alias `make check` ↔ `make hook-push` after P3 (part of P4). |
| **§8 Rules for agents** | Mostly codified in `DESIGN.md §12` (protected-files) + `memory/project.md` (trust-boundary). | Codify Scope-Level 4 (workflows + `.shepherd.yml` + new `mk/`) explicitly in `.shepherd.yml → blocklist` (Proposal **P5**). |
| **§9 Rollout checklist (10 items)** | 7/10 done; 3 partial (see "Open from §9" below). | Close the 3 remaining (Proposal **P6**). |

**Verifiers already shipped** that match the brief's spirit:
- `shepherd-bump --verify-contract` — the 9-target Makefile shape (SH-017).
- `shepherd-bump --verify-sha-pin` — §12 supply-chain invariant (SH-030).
- `shepherd-bump --verify-prepush` — §7 hooks presence (SH-033).
- `shepherd-bump --verify-timeouts` — §2 tier budgets (SH-039).

What's missing: a verifier that enforces §4's declarative `*_STEPS` contract. That's **Proposal P3** below.

---

## Proposals (ordered by ROI)

### P1 — Split pre-commit and pre-push into distinct tiered targets

**Why:** Brief §1 principle 2: "pre-push is a subset of branch." Today our pre-push runs the **full** `make check` (yaml-lint + md-lint + verify-memory-size + verify-traceability + build + test-acceptance + injection-drill) — 30–60 s on shepherd, longer elsewhere. That's not a subset of branch — it's branch. Makes people reach for `--no-verify`.

**What:**
- Ship `make hook-commit` (≤10 s) and `make hook-push` (≤2 min) as named tiers in `mk/ci.mk`.
- `hook-commit` = `fmt + lint-staged + commit-msg` only.
- `hook-push` = `lint + typecheck + unit-fast + verify-fast` — a real subset.
- Keep `make check` as a human-dispatched super-set alias (for when the user explicitly wants branch-tier locally).

**Scope**: verifier update (`shepherd-bump --verify-prepush` now checks for `make hook-push` instead of `make check`); `templates/pre-commit-config.yaml.snippet` rewired; 7/7 fleet `.pre-commit-config.yaml` files patched.

**Candidate story**: SH-042.

---

### P2 — Formalize the 12 test categories as a shared taxonomy

**Why:** Brief §3 defines 12 categories (fmt / lint / typecheck / unit / build / verify / integration / smoke / scan / acceptance / e2e / hardware). Today each repo invents its own names (`test-updates`, `test-acceptance-affected`, `check-strict`, `smoke-tiny`, …). Agents and operators can't predict what a `make <target>` does without reading the Makefile.

**What:**
- Ship `docs/specs/test-taxonomy` (future) on shepherd with the 12-category contract.
- For each managed repo, map current targets → canonical category (table in `docs/FLEET.md`).
- Over time, rename per-repo targets to canonical names where cheap (`test-updates` → `unit-affected`, etc.) — but keep aliases to avoid breaking CI.

**Scope**: pure docs + aliases. Zero workflow risk. High readability payoff.

**Candidate story**: SH-043.

---

### P3 — Ship `mk/ci.mk` as the single master include (replaces `templates/Makefile.contract.snippet`)

**Why:** The highest-value gap. The brief proposes:
- One file in every repo, byte-identical.
- Repo-specific `*_STEPS` variables.
- `make verify-contract` validates both the include is up to date AND every step name is a real `.PHONY` target.

**Today:** each repo has its own copy of the `step` macro + its own tier bodies (`ci-branch:` with `$(call step,lint,…)` etc.). Drift is documented (SH-034's step-macro-exit-code fix needed to propagate across 5 repos).

**Proposed layout:**

```
bboortz/shepherd/
  mk/ci.mk                  # master (replaces templates/Makefile.contract.snippet)
  mk/ci.mk.sha256           # manifest for verify-contract
```

Each managed repo:
```
mk/ci.mk                     # byte-identical copy
Makefile:                    # imports it
    COMMIT_STEPS  = fmt lint-staged
    PUSH_STEPS    = lint typecheck unit verify-fast
    BRANCH_STEPS  = lint typecheck unit build verify
    PATCH_STEPS   = integration smoke scan
    RELEASE_STEPS = verify-release package smoke-artifact
    NIGHTLY_STEPS = acceptance e2e
    include mk/ci.mk
```

**Verifier extension:** `shepherd-bump --verify-contract` upgraded to:
1. Check `mk/ci.mk` is present and its sha256 matches the master on shepherd (prevents silent drift).
2. Check every string in `*_STEPS` is a defined `.PHONY` target in the repo's Makefile.

**Upgrade path:** one PR per fleet repo. Each PR is additive (copies `mk/ci.mk` in, declares `*_STEPS`, removes the inline `$(call step,…)` bodies which now live in `mk/ci.mk`).

**Protection:** add `mk/**` to §12 blocklist (same tier as `.github/workflows/**`, `templates/**`).

**Candidate umbrella story**: SH-044. Decomposes to SH-045 (verifier upgrade) + SH-046..SH-052 (one per repo migration).

---

### P4 — Convert per-repo tier bodies to declarative `*_STEPS` lists

**Why:** Direct follow-up of P3. Brief §5 shows exactly what each repo's `*_STEPS` should look like. Clean declarative syntax; composable; agent-friendly.

**What (per repo, concrete):** Brief §5 blocks are the migration target. Reproduced here for traceability:

- **shepherd**: add `COMMIT_STEPS = yaml-lint md-lint`; `PUSH_STEPS = build test-acceptance injection-drill`; etc.
- **healthy**: `COMMIT_STEPS = shell-lint zig-fmt verify-traceability check-memory-size`; `PUSH_STEPS = test verify-version-bumped verify-changelog`; etc.
- **homelab**: `COMMIT_STEPS = ruff-fmt shellcheck yamllint ansible-lint-staged`; etc.
- **forge**: `PUSH_STEPS = test-fast check-smart`; etc.
- **beaconry**: `PUSH_STEPS = check-fast verify-version-bumped verify-changelog verify-feature-complete`; etc.
- **kernel-test**: `BRANCH_STEPS = lint programs ci-test`; etc.

The `*` suffix in the brief marks targets that don't yet exist. Per-repo backlog:
- healthy: `package-image`, `smoke-image`, `repro-check`
- homelab: `ansible-lint-staged`, `syntax-check`, `dry-run`, `deploy-staging`, `smoke-staging`, `deploy-prod`, `smoke-prod`
- forge: `check-fast` (fast tier stand-alone), `build-affected`, `test-acceptance-affected`, `promote`
- beaconry: `check-fast`, `test-integration`
- kernel-test: `programs-one-arch`, `smoke-tiny`, `smoke-configs`
- shepherd: `gate-dry-run`, `verify-sha-pins` (already shipped as `shepherd-bump --verify-sha-pin` — rename/alias)

**Scope:** 7 PRs. Each ships the `*_STEPS` block + the missing `*`-marked targets + updated Makefile include.

**Candidate stories:** fold into SH-044 sub-stories (one per repo).

---

### P5 — Codify Scope-Level 4 explicitly in `.shepherd.yml → blocklist`

**Why:** Brief §8.5: "A change to workflows is scope level 4 and needs a human." Today §12 blocklist enforces this — but only via a hard-coded path list in `scripts/shepherd-poc/validate.sh`. Making it explicit in each repo's `.shepherd.yml` lets operators see what's off-limits without reading shepherd internals.

**What:**
- Add to `templates/shepherd.yml`:

  ```yaml
  # Scope level 4 — human-only. Agent-produced PRs touching these paths
  # are blocked at validate.sh.
  blocklist:
    - ".github/workflows/**"
    - ".shepherd.yml"
    - "mk/**"              # P3 — the dev-cycle contract include
    - "templates/**"       # shepherd only
    - "scripts/release.sh"
    - "VERSION"
    - "*.env"
    - "*.pem"
    - "*.key"
  ```
- `scripts/shepherd-poc/validate.sh` reads this instead of hard-coding.
- `shepherd-bump --verify-shepherd-yml` (already exists) adds schema check for the new `blocklist:` field.

**Scope:** shepherd-side only. Managed repos pick it up on next template-sync.

**Candidate story:** SH-053.

---

### P6 — Close the three remaining §9 rollout items

Brief §9 rollout checklist (reproduced + current status):

| # | Item | Status |
|---|---|---|
| 1 | Add `mk/ci.mk` to healthy (reference impl) | pending → P3/P4 |
| 2 | Fix `.shepherd.yml` contract: forge, beaconry, kernel-test, homelab | **partial** — see below |
| 3 | homelab: full CI on `pull_request` only; Lint on GH-hosted runner | partial — Lint on GH-hosted (SH-021 ✅); `push: [dev, main]` still fires (see note) |
| 4 | forge: emit only affected acceptance tests in `discover` | ✅ shipped (FG-090 / SH-022) |
| 5 | beaconry: `pytest -n auto`; split `check` into `check-fast`; add nightly | ✅ shipped (BC-148 / BC-149 / yesterday's ci-nightly fix) |
| 6 | kernel-test: nightly tinyconfig build + boot with ccache | **partial** — ccache was added; qemu + cross-toolchain install still missing (but yesterday's fix sidesteps this by running framework-only) |
| 7 | shepherd: `ci.yml` running `make check` on PRs; add hooks | ✅ shipped (SH-015/016/033) |
| 8 | All: `timeout-minutes` equal to stage budget; upload `build/ci-timing.txt` | ✅ shipped (SH-039/040) — note we emit `ci-timing.json`, not `.txt` (JSON is a superset) |
| 9 | All: `make verify-contract` | ✅ shipped (SH-017 for Makefile target shape; P3 upgrades to step-level) |

**Remaining partials:**

**6.2 `.shepherd.yml` contract fix** (per brief §9):
- **forge**: `test:` should be `make test`. Current: `build: make test-fast` / `test: make test-fast`. Fix to `test: make test` per brief.
- **beaconry**: `build:` should be `make build`. Current: `build: make build` already ✅ (per BC-148 flip).
- **kernel-test**: should have `build:` and `test:`. Current: `build: make programs` / `test: make ci-test` — brief says just `build` / `test`. Minor rename.
- **homelab**: `build:` missing or wrong. Current: `build: make lint` / `test: make test`. Brief implies `build: make build` — but homelab is IaC, no artifact. Keep `build: make build` + make the target a no-op.

Each of the above is a 1-line `.shepherd.yml` edit per repo.

**6.3 homelab `push:` triggers**:
- Brief §9: full CI on `pull_request` only.
- Current: ci-branch.yml fires on `push: [dev, main]` + `pull_request`. The push trigger is the double-fire the SH-021 comment calls out but didn't fully kill.
- Fix: remove `push:` trigger from ci-branch.yml. ci-patch.yml handles post-merge.

**6.6 kernel-test full nightly**:
- Brief §9 wants "tinyconfig build and boot smoke with ccache."
- Yesterday's fix moved ci-nightly to framework-only (no qemu). To satisfy the brief, the proper fix is a `make bootstrap` step in the nightly workflow (installs qemu + cross-toolchain) then runs `make smoke`.
- Alternative: keep framework-only + separate `ci-kernel-smoke.yml` workflow that only fires when the workflow runner has the toolchain cache populated (cold-start fallback: skip-smoke-with-warning).

**Candidate stories:** SH-054 (`.shepherd.yml` contract sync × 4 repos); SH-055 (homelab push-trigger removal); SH-056 (kernel-test nightly bootstrap, optional).

---

## Delta summary — what's new in the brief vs. what we already have

| Brief concept | Already shipped | Delta |
|---|---|---|
| Six stages | ci-branch/patch/release/nightly | **+2 stages**: hook-commit (new), hook-push (new) |
| Shared include | `templates/Makefile.contract.snippet` (copied) | **Byte-identical `mk/ci.mk` + verify-contract sha256 check** (prevents drift) |
| `*_STEPS` variables | n/a | **Declarative per-repo step lists** (P4) |
| Timing emission | `build/ci-timing.json` (JSON) | Brief says `.txt` (plaintext). We can emit both — `.txt` for human-read, JSON for SH-020 digest |
| Scope level 4 | `.shepherd.yml → blocklist` hard-coded in shepherd | **Promote to per-repo `.shepherd.yml → blocklist:`** (P5) |
| Verify-contract | 9 Makefile targets present | **Upgrade to step-level: `*_STEPS` entries → real `.PHONY` targets** (P3) |

---

## Recommended sequencing

Ship in ROI order:

1. **SH-042 (P1)** — split hook-commit / hook-push. Unblocks faster local feedback. 1 shepherd PR + 7 fleet PRs.
2. **SH-044 umbrella (P3 + P4)** — `mk/ci.mk` + per-repo `*_STEPS`. Big refactor; land shepherd first as reference, then 6 managed repos. Prevents future drift.
3. **SH-054 + SH-055 (P6)** — close the two remaining §9 partials. Small PRs.
4. **SH-043 (P2)** — formalize 12 categories as docs. Zero risk.
5. **SH-053 (P5)** — explicit `blocklist:` in templates. Shepherd-only, tiny.
6. **SH-056 (P6 kernel-test)** — optional nightly bootstrap. Low priority since yesterday's fix already landed.

**Non-goals:** everything in the brief that's already shipped stays as-is. No "boil the ocean" rewrites.

---

## Open questions (not resolved by the brief)

1. **Should `test` alias be `ci-branch` or stay as the existing per-repo definition?** Brief §2 says "`make test` is an alias of `make ci-branch`." Currently shepherd has `test: test-acceptance`; healthy has `test: build + run.sh`; beaconry has `test: pytest …`. Aliasing `test → ci-branch` adds a cold-build + lint pass on every `make test` invocation — breaks fast-iteration dev loops. Keeping the status quo (`test` is the repo's native fast test) seems saner. Flag for human decision.

2. **Should timing be `.txt` (brief §4) or `.json` (current SH-020)?** JSON is strictly more useful (SH-020 digest + regression detection + DORA metrics all consume it). Emit both? Or just document the two-line shim to extract `.txt` from `.json`?

3. **"Agents may change Makefiles and scripts" vs. "Makefile is risky to change":** Brief §8.5 allows agents to touch Makefile + scripts. Current `DESIGN.md §12` blocklist doesn't restrict Makefile. OK with brief. Call out that Makefile changes trigger `verify-contract` + make `test` runs — a safety net.
