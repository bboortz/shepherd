---
id: SH-007
slug: reusable-action
status: shipped
created: 2026-11-21
shipped: 2026-11-21
owner: @benni
parent: SH-006
---

# SH-007 — R1-A: reusable shepherd Action (required `.shepherd.yml`)

> **Sub-story of [SH-006](SH-006-r1-reusable-action.md).** Owns the "reusable Action" deliverable from R1 per `docs/specs/DESIGN.md §13`. Sibling sub-stories SH-008 (sandbox perimeter), SH-009 (auto-merge gates), SH-010 (waiting-period) layer on top. This story also carries the **required-`.shepherd.yml` decision** (2026-11-21, from user) that flips DESIGN §13 R1 scope and the onboarding principles.

## 1. Who is the consumer?

Repo owner onboarding a new repo to shepherd. In R0, they copied five scripts + one workflow + created labels + enabled Actions-PR permission — learned over 14 PRs across three pilots. In R1-A, they get:

- **One caller workflow** (`.github/workflows/shepherd.yml`, ≤ 20 lines) that `uses:` shepherd's reusable workflow.
- **One `.shepherd.yml`** copied from `templates/shepherd.yml` — now **required**, not optional (see §7 for rationale).
- **One secret** (`ANTHROPIC_API_KEY`).
- Total setup: ≤ 15 minutes (DESIGN §13 headline — budget intact after the required-yml change).

## 2. When does the story fire?

- A new repo onboards to shepherd.
- An existing R0 pilot (`healthy` / `beaconry` / `ham-radio-compass`) migrates from the copied-scripts model to the reusable Action.
- A caller workflow dispatches (schedule or `workflow_dispatch`) and the reusable Action runs the trusted-step chain.

## 3. What does success look like?

Mechanically checkable:

- `bboortz/shepherd/.github/workflows/reusable-shepherd.yml` exists and declares `on: workflow_call` with `secrets.ANTHROPIC_API_KEY: required: true`.
- The reusable workflow **checks out the caller** (default `actions/checkout`) **and the shepherd scripts** (second checkout at a pinned ref), then runs the trusted-step chain: install-trivy → scan → agent → validate → regen-lockfile → validate-combined → open-pr.
- The reusable workflow **fails fast** (exit 1, named error annotation) if the caller's checkout has no `.shepherd.yml` at the repo root.
- `templates/caller-shepherd.yml` exists, is ≤ 20 lines, references the reusable workflow by **SHA-pinned** ref, requests `secrets: inherit`.
- `bboortz/healthy` (the SH-007 canary) has its `.github/workflows/shepherd-poc.yml` replaced by the thin caller **and** `scripts/shepherd-poc/` deleted (the whole point of the migration: pilots no longer carry the scripts).
- `test/acceptance/test_SH_007_reusable.sh` passes: shape assertions on the reusable workflow + caller template + required-yml behaviour.
- `docs/specs/DESIGN.md §13` R1 scope line "Optional `.shepherd.yml`" → "**Required** `.shepherd.yml`"; onboarding principle "Zero config by default" → "Required config, templated" (same ≤ 15 min target).
- A tagged pre-release `v0.5.0-rc1` on shepherd.

## 4. How urgent?

- [x] Launch-schedule bound (R1 target Fri 4 Dec per DESIGN §13 — 13 days from today). R1-A is the critical-path piece of R1; the other three sub-stories layer on top.
- [x] Reduces onboarding surface by ~80% vs R0 (one caller workflow + one yml + one secret vs. five scripts + one workflow + labels + settings tweaks).
- [x] Public-facing — the caller-workflow template is the *first thing* a public user copy-pastes once we launch.

## 5. Happy path

```
# Onboard a new repo (public user, R1-A):
cp ~/git/shepherd/templates/caller-shepherd.yml .github/workflows/shepherd.yml
cp ~/git/shepherd/templates/shepherd.yml .shepherd.yml
# edit cron / schedule / risk tier if needed; commit; push
gh secret set ANTHROPIC_API_KEY -R <org>/<repo>
# Done. 15 minutes total.

# Daily cron on an onboarded repo:
#   1. Caller workflow fires on its schedule.
#   2. uses: bboortz/shepherd/.github/workflows/reusable-shepherd.yml@<sha> with secrets: inherit
#   3. Reusable workflow:
#        a. actions/checkout (caller)
#        b. actions/checkout bboortz/shepherd → ./_shepherd/
#        c. Verify .shepherd.yml present (exit 1 + ::error:: if missing — required)
#        d. install-trivy → scan → agent-call → validate → regen-lockfile → validate → open-pr
#   4. A PR is opened on the caller repo; caller workflow terminates.
```

## 6. Edge cases / failure modes that matter

- **Caller has no `.shepherd.yml`.** → Reusable action exits 1 at the verify step with `::error::shepherd requires .shepherd.yml in your repo` and a link to `templates/shepherd.yml`. The rest of the pipeline never runs. No partial PR, no secret exposure.
- **Caller's `.shepherd.yml` is malformed.** → Out of scope for SH-007. A YAML-parse step is a follow-up (SH-009 territory — gates read schema fields).
- **Shepherd scripts drift from the workflow version.** → Second checkout of `bboortz/shepherd` must pin to the same ref as the reusable workflow was invoked at. For rc1 we pin to a specific SHA; later tags use their own SHA.
- **Caller delegates to the reusable workflow but doesn't pass `secrets: inherit`.** → `ANTHROPIC_API_KEY` is `required: true` at the reusable workflow level — GitHub rejects the call with a clear validation error before any step runs.
- **Pilot migration leaves the old `scripts/shepherd-poc/` behind.** → Canary migration PR deletes the directory in the same commit. The caller workflow replaces, not augments.
- **Reusable workflow is dispatched manually on shepherd itself.** → Not supported; shepherd isn't a managed repo of itself under this architecture. `workflow_dispatch` is only accepted on the caller side.

## 7. Out of scope

- **Sandbox perimeter** (network lockdown, gateway budget caps) — SH-008.
- **Auto-merge gates** (pipelines-green, diff-size, scan-not-worse, security-fix-removes-finding) — SH-009.
- **Waiting-period** — SH-010.
- **Migrating `beaconry` and `ham-radio-compass`** — follow-up ship after `healthy` has produced at least one live run through the Action (canary-first).
- **GitHub App identity** — R3.
- **Topic-based auto-discovery** — post-R3.
- **Scope levels 2–4** — R2.
- **A full YAML schema validator** for `.shepherd.yml` — SH-009.
- **Public quickstart docs** — R2.

## 7a. Why required, not optional

Flipping from DESIGN §13's original "Optional `.shepherd.yml`" to **required** (user decision 2026-11-21):

- **Explicitness beats magic.** Managed repos declare their own risk tier, auto-merge policy, build/test commands rather than inheriting invisible defaults. A grep in the repo tells you shepherd's config. A grep in shepherd tells you the schema.
- **Auditable at the repo boundary.** A security review of a managed repo doesn't need to cross-reference shepherd's defaults — everything is in the repo being reviewed.
- **Preconditions become observable.** SH-011 already requires `.github/dependabot.yml` for Dependabot verification; SH-007 continues the pattern for the agent flow. "Shepherd-managed" means "has `.shepherd.yml`."
- **Cost: one extra file in the quickstart.** Still ≤ 15 min. The file is a 12-line copy-paste.

Reframed principles (land in DESIGN §13):

- "Required config, templated." replaces "Zero config by default." Each managed repo ships `.shepherd.yml`; defaults live in `templates/shepherd.yml` and are mechanically copyable.
- "15-min setup: copy one workflow **+ one yml**, add one secret, push." (was "copy one workflow file, add one secret, push").

## 8. Acceptance (Gherkin → shell + CI assertions)

```gherkin
Scenario: Reusable workflow shape
  Given .github/workflows/reusable-shepherd.yml on shepherd
  Then it declares `on: workflow_call`
  And it declares `secrets.ANTHROPIC_API_KEY: required: true`
  And it declares `permissions: contents: write, pull-requests: write`
  And every `uses:` line is SHA-pinned and references `actions/*` only

Scenario: Caller template shape
  Given templates/caller-shepherd.yml on shepherd
  Then it is ≤ 20 lines
  And it references `bboortz/shepherd/.github/workflows/reusable-shepherd.yml@<sha>` SHA-pinned
  And it declares `secrets: inherit` or passes `ANTHROPIC_API_KEY` explicitly

Scenario: Required-yml check missing — fail fast
  Given a managed-repo fixture at /tmp/fx with no .shepherd.yml
  When the reusable action's verify-shepherd-yml step runs against that fixture
  Then it exits 1
  And its error annotation names ".shepherd.yml" as missing

Scenario: Required-yml check present — pass
  Given a managed-repo fixture at /tmp/fx with .shepherd.yml
  When the verify-shepherd-yml step runs against that fixture
  Then it exits 0

Scenario: Canary migration (healthy)
  Given bboortz/healthy at main
  When PR replaces .github/workflows/shepherd-poc.yml with the thin caller
  And deletes scripts/shepherd-poc/ in the same commit
  And a workflow_dispatch fires the new caller
  Then the reusable Action runs on shepherd side
  And completes with the same step list as the pre-migration shepherd-poc.yml
  And (if there are findings) opens a PR on bboortz/healthy

Scenario: DESIGN language reflects the required-yml decision
  Given docs/specs/DESIGN.md
  Then §13 R1 scope lists "Required `.shepherd.yml`" (no "Optional")
  And the onboarding principles do NOT say "Zero config by default"
  And the onboarding principles DO say the 15-min setup covers the extra yml file
```

## 9. Capabilities delivered or extended

New / flipped `design → active`:

- `r1.reusable-action` (new) — the reusable workflow + caller template exist and a pilot (healthy) is using them in production.
- `onboarding.one-workflow` — now mechanically true (one caller workflow file, ≤ 20 lines).
- `onboarding.default-github-token` — the reusable workflow uses only `GITHUB_TOKEN` (and `ANTHROPIC_API_KEY`); no App identity required.
- `config.required-per-repo` (new) — replaces the `onboarding.zero-config-default` CAP; `.shepherd.yml` is mandatory and the Action fails fast without it.

Deprecated:

- `onboarding.zero-config-default` — status flips to `deprecated` with a one-line note pointing to `config.required-per-repo`. Historical only.

Still `design` after this story (deferred to sub-siblings):

- `sandbox.no-network-except-model` → SH-008.
- `gateway.*` → SH-008.
- `gate.pipelines-green`, `gate.scan-not-worse`, `gate.security-fix-removes-finding`, `gate.waiting-period` (agent flow) → SH-009 / SH-010.
- `auto-merge.*` → SH-009.
- `blocklist.unblock-per-repo`, `blocklist.protected-registration-files` → SH-009.
- `onboarding.dry-run-first` → SH-009 (gated behind `.shepherd.yml` `dry_run: true`).

---

## Plan doc

Lives at [`docs/plan/SH-007-reusable-action-plan.md`](../plan/SH-007-reusable-action-plan.md).
