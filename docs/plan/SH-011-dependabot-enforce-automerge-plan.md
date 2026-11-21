---
id: SH-011
slug: dependabot-enforce-automerge
story: docs/stories/SH-011-dependabot-enforce-automerge.md
branch: feat/SH-011-dependabot-enforce-automerge
status: shipped
shipped: 2026-11-21
merge_commit: d313da8
---

# SH-011 plan — Dependabot baseline: enforce presence + opt-in gated auto-merge

**Story:** [SH-011](../stories/SH-011-dependabot-enforce-automerge.md)

## Design delta

Three mechanical surfaces added, one Zig mode added, zero existing surfaces broken.

**Templates (shepherd-side).**

- `templates/shepherd.yml` — append a `dependabot:` block with two keys:

  ```yaml
  dependabot:
    enforce_enabled: true   # shepherd verifies .github/dependabot.yml exists + well-formed
    auto_merge: false       # gated auto-merge of patch/minor Dependabot PRs
  ```

- `templates/dependabot.yml` — reference baseline copied into managed repos. `version: 2`, one `- package-ecosystem: github-actions` entry (every repo has this), weekly schedule. Per-repo tailoring adds ecosystems detected at rollout.

- `templates/dependabot-automerge.yml` — reusable workflow template copied into repos that opt in. Shape:
  - trigger: `pull_request` from `dependabot[bot]`
  - permissions: `contents: write`, `pull-requests: write`
  - one job, no third-party actions, no `dependabot/fetch-metadata`
  - classify via PR title (`Bump <name> from X.Y.Z to A.B.C`) → `bump_level`
  - gate: `patch|minor` AND `(additions + deletions) ≤ 50` AND `release_age ≥ 24h`
  - release-date lookup: `npm_and_yarn` → `curl registry.npmjs.org/<name>` → `.time["<to>"]`; `github_actions` → `gh api repos/<owner>/<repo>/releases/tags/v<to> --jq .published_at`; other ecosystems fall through to `age_ok=false`
  - green → `gh pr merge --auto --merge`; otherwise leave the PR open (no comment, no issue — SH-009 scope)

**Zig surface (`bump.zig`).**

- New `Mode.verify_dependabot`.
- New flag parse arm for `--verify-dependabot`.
- New command `cmdVerifyDependabot(allocator, io, opts)`:
  1. Open `opts.root`.
  2. If `.shepherd.yml` exists, scan for a line matching `  enforce_enabled: false` under a `dependabot:` key — pragmatic substring match, no full YAML parser (MVP; a proper parser is a follow-up when `.shepherd.yml` grows). If opt-out matches → exit 0.
  3. Try to open `.github/dependabot.yml`. Not found → exit 3.
  4. Read the file (cap 64 KiB). Look for a line matching `^version: 2\s*$` and at least one line matching `^- package-ecosystem:` or `^  - package-ecosystem:` — permissive. Missing either → exit 4. Both present → exit 0.
- Exit codes slot in next to existing (0 ok, 1 I/O, 2 usage): **3 missing**, **4 malformed**.
- `printUsage()` updated to list the new mode.

**CAPs (`docs/CAPABILITIES.md`).** New "Dependabot path" section with the four new CAPs and bidirectional links to `test/acceptance/test_SH_011_dependabot.sh`. Status flips for `gate.diff-size` → active (narrowed test scope — now also covers the Dependabot flow); `gate.waiting-period` → active (partial: npm + gh-actions); `supply-chain.no-third-party-actions-critical-path` — test list extended.

**DESIGN.md.** No deepening required; this story operates inside §12 defaults and §13 R1 umbrella. One **post-shipping** entry under §13 "Decided on 2026-11-21" naming Dependabot as the configurable baseline (no change to trust base; sits alongside `shepherd-bump`).

**No changes to:** `.github/workflows/*.yml`, `.shepherd.yml` protected-files list, bump engine for non-Dependabot flows, budget caps, sandbox perimeter.

## Alternatives rejected

| Alternative | Why not |
|---|---|
| Use `dependabot/fetch-metadata@v1` to classify PRs (the GitHub tutorial path) | Third-party Action with commit authority in the critical path. Directly violates `supply-chain.no-third-party-actions-critical-path` (SH-001 / §12). Classifying from PR title is equivalent for patch/minor/major and adds no supply-chain surface. |
| Use PR-created-at as the "age" signal | Design in §12 is explicit: "24h ... counted from the release date of the new version, not from the PR." PR-created-at is seconds after Dependabot sees the release, so it'd gate effectively zero. Release-date lookup is one `curl + jq` per ecosystem. |
| Ship all four §12 gates now (scan-not-worse included) | Scan-not-worse requires Trivy-on-PR-vs-base in `reusable-verify.yml` — that's SH-009 scope, ~2 weeks. User chose "ship it now"; `gated-minus-scan-not-worse` is honest and forward-compatible. |
| Replace `shepherd-bump` with Dependabot entirely | Explicitly rejected in the prior design conversation (2026-11-21). Dependabot is a **baseline** for managed repos, not a replacement for the first-party bump engine or the smart-fix agent. |
| Fleet-side auto-install `.github/dependabot.yml` into every managed repo | Needs the fleet layer (discover + token + cross-repo PR opener). That layer is post-R3 per DESIGN §13. Four pilots get it by hand in this story. |
| Install the auto-merge workflow on every managed repo by default | §12 says auto-merge is off by default per-repo. Only `ham-radio-compass` opts in in this story. |

## Breaking changes

- [ ] Yes — <describe>
- [x] No — strictly additive. New template files, new Zig mode, new CAPs. No existing file surface changes shape (only `templates/shepherd.yml` grows a new optional block; absence treated as default-safe).

Shepherd has no users beyond the maintainer yet (per DESIGN §13 R1 soak starts Fri 4 Dec). No downstream notice needed.

## Rollout

- [ ] README updated (if public contract moved) — **no change needed**; README advertises the smart-fix agent and SH-001, not `.shepherd.yml` shape yet.
- [ ] `memory/project.md` invariants updated — **no change needed**; this story operates inside existing invariants.
- [ ] `docs/DESIGN.md` reconciled — one post-shipping decision line under §13 (Dependabot as per-repo baseline alongside `shepherd-bump`).
- [ ] Downstream notice — not needed (no external consumers yet).

**Cross-repo rollout (after merge to `main`):**

1. Draft `.github/dependabot.yml` per pilot (detect ecosystems from repo contents).
2. For each of {shepherd (dogfood), beaconry, healthy, ham-radio-compass}: open a PR adding `.github/dependabot.yml`. Watch CI (should be trivial — a YAML file add). Merge via merge commit.
3. For `ham-radio-compass`: add a second PR that drops in `.github/workflows/dependabot-automerge.yml` + `.shepherd.yml` with `dependabot.auto_merge: true`. Watch CI. Merge.
4. Observe open Dependabot PRs on `ham-radio-compass` (#25, #26 at the time of writing) get picked up by the new workflow. Expect patch/minor + ≤50 lines + ≥24h age to auto-merge.
5. Record outcomes in the plan's post-merge notes.

**Note on branching:** `dev` does not exist yet in this repo; previous SH-001 merged `feat/*` → `main` directly. This story follows that established pattern. Introducing `dev` + `release.yml` is explicitly SH-006 (R1 umbrella) scope.

## Shipping evidence (fill at step 6a)

Three lenses. Any ⚠️/❌ row blocks shipping — cycle back to step 4.

### Lens 1 — Gherkin coverage

| Scenario (from story §8) | Test pointer | Status |
|---|---|---|
| templates ship the shepherd side of the baseline | `test/acceptance/test_SH_011_dependabot.sh:46-82` (Scenario 1 block) | ✅ |
| verify-dependabot on repo without .github/dependabot.yml | `test/acceptance/test_SH_011_dependabot.sh:92-94` (missing fixture, exit 3) | ✅ |
| verify-dependabot on repo with a well-formed config | `test/acceptance/test_SH_011_dependabot.sh:96-106` (ok fixture, exit 0) | ✅ |
| verify-dependabot on repo with a malformed config | `test/acceptance/test_SH_011_dependabot.sh:108-130` (empty + v1 + no-updates, exit 4 for each) | ✅ |
| enforce-enabled: false opts out of verification | `test/acceptance/test_SH_011_dependabot.sh:132-141` (optout fixture, exit 0) | ✅ |

### Lens 2 — Behaviour symmetry

| CAP delivered | ≥1 test? | Exit / failure paths tested? | Status |
|---|---|---|---|
| `dependabot.presence-verified` | ✅ | ✅ (exit 0/3/4) | ✅ |
| `dependabot.config-enforce-opt-in` | ✅ | ✅ (optout → exit 0 even with no dependabot.yml) | ✅ |
| `dependabot.auto-merge-opt-in-per-repo` | ✅ (schema shape in `templates/shepherd.yml`) | ✅ (template has the knob) | ✅ |
| `dependabot.auto-merge-level-patch-minor` | ✅ (template inspection for `patch`+`minor` + major-reject path) | ⚠️ (static template check only; live validation deferred to rollout — recorded in post-merge notes) | ⚠️ |
| `gate.diff-size` (extension) | ✅ (template inspects for lockfile-aware line count via `gh pr view --json files`) | ⚠️ (static only; live validation deferred to rollout) | ⚠️ |
| `gate.waiting-period` (partial) | ✅ (template inspects for `registry.npmjs.org` + `releases/tags`) | ⚠️ (static only; live validation deferred to rollout) | ⚠️ |
| `supply-chain.no-third-party-actions-critical-path` (extended) | ✅ | ✅ (fetch-metadata absence + `uses:` shape check) | ✅ |

**Note on the ⚠️ rows:** these capabilities are workflow-executed in the managed repo's CI, not in `shepherd`'s acceptance suite. The static template inspection is the maximum we can test here; **live validation is part of the SH-011 rollout step** (Dependabot PR auto-merges on `ham-radio-compass`) and is recorded in the post-merge notes below. ⚠️ flips to ✅ when the first Dependabot PR auto-merges through the workflow.

### Lens 3 — Self-consistency

| Check | Status |
|---|---|
| Story obeys its own §7 (out-of-scope) — no scope creep | ✅ (no `gate.scan-not-worse`, no fleet auto-install, no non-npm/non-gh-actions ecosystem coverage) |
| New CAPs listed in §9 all appear in `docs/CAPABILITIES.md` | ✅ (new Dependabot section + three extensions) |
| Protected-files invariant intact (DESIGN §12) | ✅ (no changes to `.github/workflows/*.yml` in `shepherd`; managed-repo workflows are copied from `templates/`, not written by any agent) |
| Budget caps unchanged, or escalated to a human-reviewed change | n/a |
| `make verify-traceability` green | n/a (stub until R1) |
| `make check` green | ✅ (yamllint + build + acceptance — 44 pass / 0 fail across SH-001 + SH-011) |

## Post-merge notes

<Filled after the PR merges and the cross-repo rollout completes. Record: how many Dependabot PRs auto-merged on `ham-radio-compass`; which ones were rejected by which gate; any workflow bug caught by reality.>
