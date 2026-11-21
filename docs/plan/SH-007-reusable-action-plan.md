---
id: SH-007
slug: reusable-action
story: docs/stories/SH-007-reusable-action.md
branch: feat/SH-007-reusable-action
status: shipped
shipped: 2026-11-21
merge_commits: ["shepherd #9 (v0.5.0-rc1)", "healthy #18 (canary migration)"]
---

# SH-007 plan — R1-A: reusable shepherd Action (required `.shepherd.yml`)

**Story:** [SH-007](../stories/SH-007-reusable-action.md). Umbrella: [SH-006](../stories/SH-006-r1-reusable-action.md).

## Design delta

**Three new files on shepherd, one DESIGN.md flip, one canary migration.**

### New files

- **`.github/workflows/reusable-shepherd.yml`** — the reusable workflow. Shape:

  ```yaml
  on:
    workflow_call:
      secrets:
        ANTHROPIC_API_KEY:
          required: true
  permissions:
    contents: write
    pull-requests: write
  jobs:
    shepherd-agent:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@<sha>         # the caller's repo (default)
        - uses: actions/checkout@<sha>         # the shepherd scripts (second checkout)
          with: {repository: bboortz/shepherd, ref: <sha-matching-this-workflow>, path: _shepherd}
        - run: ./_shepherd/scripts/shepherd-poc/verify-shepherd-yml.sh
        - run: ./_shepherd/scripts/shepherd-poc/install-trivy.sh
        - run: trivy fs --severity HIGH,CRITICAL ...   # unchanged from SH-004
        - run: ./_shepherd/scripts/shepherd-poc/agent-call.sh
          env: {ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}}
        - run: ./_shepherd/scripts/shepherd-poc/validate.sh "$DIFF_PATH"
        - uses: actions/setup-node@<sha>
        - run: ./_shepherd/scripts/shepherd-poc/regen-lockfile.sh
        - run: ./_shepherd/scripts/shepherd-poc/validate.sh "$DIFF_PATH"
        - run: ./_shepherd/scripts/shepherd-poc/open-pr.sh "$DIFF_PATH"
          env: {GH_TOKEN: ${{ github.token }}}
  ```

- **`templates/caller-shepherd.yml`** — the thin caller template dropped into managed repos:

  ```yaml
  name: shepherd
  "on":
    schedule: [{cron: "0 6 * * *"}]
    workflow_dispatch: {}
  permissions:
    contents: write
    pull-requests: write
  jobs:
    agent:
      uses: bboortz/shepherd/.github/workflows/reusable-shepherd.yml@<sha>
      secrets:
        ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
  ```

  Target: ≤ 20 lines, SHA-pinned reusable-workflow ref, explicit secret-pass (not `secrets: inherit` — tighter audit trail).

- **`scripts/shepherd-poc/verify-shepherd-yml.sh`** — new helper. Exits 0 if `.shepherd.yml` exists in the caller's checkout; exits 1 with `::error::` annotation otherwise.

### Modified files

- `docs/DESIGN.md §13` — two edits:
  - R1 scope line: "Optional `.shepherd.yml` with per-repo overrides" → "**Required** `.shepherd.yml` with per-repo overrides".
  - Onboarding principles: "Zero config by default" line removed; "copy one workflow file, add one secret, push" → "copy one workflow file **+ `.shepherd.yml`**, add one secret, push". Add a new principle: "Required config, templated — `.shepherd.yml` is mandatory in each managed repo; `templates/shepherd.yml` is the copyable baseline."
  - A "2026-11-21" dated decision entry naming the required-yml flip and its rationale.

- `docs/CAPABILITIES.md`:
  - New `r1.reusable-action` CAP under a new "R1 — Reusable Action (SH-007)" section.
  - `onboarding.one-workflow`: status `aspirational → active`, test-linked.
  - `onboarding.default-github-token`: status `aspirational → active`, test-linked.
  - `config.required-per-repo` (new) replaces `onboarding.zero-config-default` (deprecated).

- `CHANGELOG.md`: v0.4.0 → v0.5.0-rc1 entry.

- `VERSION`: `0.4.0` → `0.5.0-rc1`.

### Canary migration

- **`bboortz/healthy`** — single PR in that repo:
  1. Replace `.github/workflows/shepherd-poc.yml` with a copy of `templates/caller-shepherd.yml` (edited only for cron offset).
  2. Delete `scripts/shepherd-poc/` entirely.
  3. Keep `.shepherd.yml` in place (healthy already has one post-SH-011).
  4. Merge → dispatch → observe one run end-to-end.

### What stays unchanged

- The `scripts/shepherd-poc/*.sh` logic — reused verbatim; the only new helper is `verify-shepherd-yml.sh`.
- The §12 trust boundary — no new attack surface.
- SH-011 Dependabot workflow — orthogonal; still runs independently in each pilot.
- SH-005 injection drill — still runs on shepherd's PRs; unaffected.
- beaconry and ham-radio-compass — their `shepherd-poc.yml` migrations are a **follow-up ship**, after healthy proves the shape. Avoids a 3-repo migration landing simultaneously with unreviewed real-world input.

## Alternatives rejected

| Alternative | Why not |
|---|---|
| **Composite action** (`.github/actions/shepherd-agent/action.yml`) instead of a reusable workflow | Composite actions can't declare `secrets.<X>.required: true`; secrets have to be passed as `inputs` (plaintext, less safe) or env (worse). Reusable workflow treats secrets natively. |
| **Pulling scripts via git submodule in the caller** | Submodules are a per-clone concern — managed repos would need to `git submodule update --init` in their workflow, which is operational friction. Second-checkout step is one line of YAML. |
| **Inlining scripts into the workflow YAML** | Loses the `make injection-drill` invariant (the drill tests the actual scripts). Ugly and duplicated. |
| **Keeping `.shepherd.yml` optional** | User decision 2026-11-21: required beats "zero-config" for explicitness + auditability + symmetry with SH-011's `enforce_enabled`. The 15-min budget survives. |
| **Floating main ref** for the reusable workflow in the caller template | Supply chain risk — a mutable-ref pin lets anyone with commit access to shepherd silently change what runs on every pilot. Use SHA-pinning (consistent with SH-001). |
| **`secrets: inherit` in the caller template** | Passes every secret from the caller to the reusable workflow. Explicit `secrets: {ANTHROPIC_API_KEY: ...}` is tighter — the reusable only sees what it needs. |

## Breaking changes

- [x] **Yes**: `.shepherd.yml` is now **required** in managed repos. All 3 pilots already have one (post-SH-011); the migration-to-reusable PR for `healthy` adds the required-yml check as a hard gate. Future pilots must copy `templates/shepherd.yml`.
- [x] **Yes (deprecation only)**: `onboarding.zero-config-default` CAP flips to `deprecated` in favour of `config.required-per-repo`.

README is not updated (public contract hasn't launched yet; SH-004/011 docs still cover the state). Will be rewritten for R2.

## Rollout

- [ ] `make check` green locally (SH-001 + SH-011 + SH-005 injection drill regression-clean; SH-007 red test green).
- [ ] CI green on the shepherd PR (including the injection drill).
- [ ] Tagged pre-release `v0.5.0-rc1` on shepherd (`git tag v0.5.0-rc1 && git push --tags`).
- [ ] `bboortz/healthy` migration PR merged.
- [ ] Manual `workflow_dispatch` on `bboortz/healthy` fires the new caller → reusable workflow runs end-to-end → produces the same outcome as the pre-migration shepherd-poc.yml (either PR opened or "no findings").
- [ ] `docs/plan/SH-007-reusable-action-plan.md` post-merge notes record the live-canary outcome.
- [ ] Beaconry + HRC migrations are the **follow-up ship** — not in this PR.

## Shipping evidence (fill at step 6a)

### Lens 1 — Gherkin coverage

| Scenario | Test pointer | Status |
|---|---|---|
| Reusable workflow shape | `test/acceptance/test_SH_007_reusable.sh` (scenario 1) | TBD |
| Caller template shape | `test/acceptance/test_SH_007_reusable.sh` (scenario 2) | TBD |
| Required-yml check missing — fail fast | `test/acceptance/test_SH_007_reusable.sh` (scenario 3) | TBD |
| Required-yml check present — pass | `test/acceptance/test_SH_007_reusable.sh` (scenario 4) | TBD |
| Canary migration (healthy) | live workflow_dispatch run on `bboortz/healthy` | TBD |
| DESIGN language reflects required-yml decision | `test/acceptance/test_SH_007_reusable.sh` (scenario 6) | TBD |

### Lens 2 — CAP evidence

| CAP | ≥1 fixture? | Status |
|---|---|---|
| `r1.reusable-action` | reusable-shepherd.yml + caller-shepherd.yml + canary run | TBD |
| `onboarding.one-workflow` | caller template ≤ 20 lines | TBD |
| `onboarding.default-github-token` | reusable workflow uses only `GITHUB_TOKEN` + `ANTHROPIC_API_KEY` | TBD |
| `config.required-per-repo` | verify-shepherd-yml.sh + red-test scenarios 3/4 | TBD |

### Lens 3 — Self-consistency

| Check | Status |
|---|---|
| Story obeys §7 (no sandbox, no gates, no beaconry/HRC migration) | TBD |
| New CAPs listed in §9 all appear in `docs/CAPABILITIES.md` | TBD |
| Protected-files invariant intact | TBD |
| SHA-pinning everywhere in both templates (SH-001 invariant) | TBD |
| `make injection-drill` still green (no regression in SH-005) | TBD |
| `make check` green | TBD |

## Post-merge notes (2026-11-21)

### What shipped

| PR | Repo | Content |
|---|---|---|
| [shepherd #9](https://github.com/bboortz/shepherd/pull/9) | shepherd | reusable workflow + caller template + verify-shepherd-yml.sh + red test + CAPs + DESIGN §13 flip. v0.5.0-rc1. |
| [healthy #18](https://github.com/bboortz/healthy/pull/18) | healthy | Canary migration: 17-line caller SHA-pinned to `bboortz/shepherd@3550c80`; `scripts/shepherd-poc/` deleted. |

### Live canary result

Dispatched [`shepherd-poc.yml` on `bboortz/healthy`](https://github.com/bboortz/healthy/actions/runs/44938249380) at 18:56 UTC. Steps:

| Step | Outcome |
|---|---|
| Set up job | ✅ |
| Checkout caller repo | ✅ |
| Checkout shepherd scripts (`ref: github.job_workflow_sha`) | ✅ |
| **Verify `.shepherd.yml` present** | ✅ — `verify-shepherd-yml: OK (./.shepherd.yml)` |
| Install Trivy (sigstore-verified) | ✅ |
| Trivy fs scan | ✅ (no HIGH/CRITICAL findings — healthy is clean) |
| Agent call | ✅ exit 1 — "No findings. Nothing to do." |
| Validate diff / Setup Node / Regen lockfile / Validate combined / Open PR | ⏭ skipped (rc=1 short-circuit) |
| Post Checkout shepherd scripts / Post Checkout caller repo / Complete job | ✅ |

**End-to-end result:** the reusable Action successfully runs on a managed repo via a thin caller. The `github.job_workflow_sha` inner-checkout pinning works in practice. The clean-state short-circuit path is intact. No PR opened (correctly — no findings). No regressions vs the pre-migration flow.

### Follow-ups

- **Migrate `beaconry` + `ham-radio-compass`** to the reusable Action. Same pattern as the healthy canary: thin caller SHA-pinned to `bboortz/shepherd@3550c80` + delete `scripts/shepherd-poc/`. Next ship.
- **Validate the agent-produces-diff path** — the canary ran on a clean repo (rc=1 short-circuit). Still need a run where `rc=0` so the remaining 5 steps actually execute. Easiest: wait for HRC to produce a finding (daily cron at 06:00 UTC) and watch that run. If none within a day, reintroduce one of the known fixed CVEs on a scratch branch of HRC.
- **R1 release tagging (`v1.0.0`)** — after SH-008 (sandbox), SH-009 (gates), SH-010 (waiting-period) ship. Caller templates will then switch from `@main` / `@<sha>` to `@v1.0.0`.
