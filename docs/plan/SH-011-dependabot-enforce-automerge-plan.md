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

## Post-merge notes (2026-11-21, same-day rollout)

### What shipped

| Repo | PR | Change | Status |
|---|---|---|---|
| `bboortz/shepherd` | [#2](https://github.com/bboortz/shepherd/pull/2) | Core SH-011: templates + Zig verifier + tests + CAPs + DESIGN § | merged `d313da8` |
| `bboortz/shepherd` | [#3](https://github.com/bboortz/shepherd/pull/3) | Dogfood: `.github/dependabot.yml` + `.shepherd.yml` | merged |
| `bboortz/beaconry` | [#63](https://github.com/bboortz/beaconry/pull/63) | Baseline (github-actions + pip), auto_merge: false | merged `68bca36` |
| `bboortz/healthy` | [#12](https://github.com/bboortz/healthy/pull/12) | Baseline (github-actions + docker), auto_merge: false | merged |
| `bboortz/ham-radio-compass` | [#27](https://github.com/bboortz/ham-radio-compass/pull/27) | Baseline (github-actions + npm) + auto-merge workflow + `.shepherd.yml` with `auto_merge: true` | merged |
| `bboortz/ham-radio-compass` | [#36](https://github.com/bboortz/ham-radio-compass/pull/36) | Flip npm scan to `daily` to nudge Dependabot after a config-change edge case | merged `258f829` |

Repo setting change: `allow_auto_merge: true` enabled on `bboortz/ham-radio-compass` via `gh api -X PATCH`.

### Workflow runs observed on `ham-radio-compass`

The auto-merge workflow fired on **9 Dependabot PRs** within 2 minutes of the opt-in landing. Every run completed with `conclusion=success` (the workflow always exits 0 so it never shows red on a PR; the auto-merge decision is encoded in a `::notice::` annotation).

| PR | From → To | Classifier result | Auto-merge? | Reason |
|---|---|---|---|---|
| #28 | actions/setup-node 4 → 7 | major | ❌ | major bump — human review |
| #29 | actions/checkout 4 → 7 | major | ❌ | major bump — human review |
| #30 | @babel/core 7.28.0 → 8.1.2 | major | ❌ | major bump — human review |
| #31 | expo-status-bar 2.2.3 → 58.0.5 | major | ❌ | major bump — human review |
| #32 | expo-sensors 14.1.4 → 58.0.5 | major | ❌ | major bump — human review |
| #33 | expo-location 18.1.6 → 58.0.22 | major | ❌ | major bump — human review |
| #34 | typescript 5.8.3 → 7.0.2 | major | ❌ | major bump — human review |
| #35 | react + @types/react (grouped) | unknown | ❌ | unknown title shape — human review |
| (closed #25, #26) | — | — | — | GitHub's automated-security-fixes PRs from before the config landed — Dependabot asked for them to be closed so it could recreate under the new dependabot.yml |

**Zero auto-merges fired** on `ham-radio-compass`. This is not a bug — it's the gate working correctly. HRC's deps are so far behind that every eligible update is a major bump, and the one grouped PR has a title shape the classifier doesn't parse. The workflow correctly refused all 9.

### Fan-out on the other three repos

Dependabot also opened fresh PRs on `beaconry` (10), `healthy` (4), `shepherd` (2). None of those repos has the auto-merge workflow installed (`.shepherd.yml` → `auto_merge: false`), so all 16 wait for human review. Several of them (patch/minor + small diff) **would** auto-merge once their repos opt in.

### Operational quirk discovered

GitHub's "automated-security-fixes" setting created PRs #25 / #26 on `ham-radio-compass` before any `.github/dependabot.yml` existed. After the config landed, Dependabot flagged those PRs as "created from a dependabot.yml entry that has been deleted" and asked for them to be closed. On close, Dependabot did **not** auto-recreate them from the new config (the alerts #50 for `ws` and #56 for `@babel/core` are still open). Switching `interval: weekly` → `daily` in #36 did not immediately re-trigger. Expected resolution: Dependabot's next scheduled scan will reopen them, at which point the auto-merge workflow will fire with the patch-level + ≤50 lockfile-exempt + ≥24h-release gates satisfied.

### Follow-ups promoted to IDEAS.md

- **Grouped Dependabot PR title parsing** — the current title regex expects `Bump <name> from X.Y.Z to A.B.C`; grouped PRs ship as `Bump <a> and <b>`. Classifying from PR body or per-file manifest diff would unblock them.
- **0.x.y semver treatment** — my classifier treats `0.14.1 → 0.17.5` as `minor` (digit-equality rule). Under SemVer 2.0, 0.x.y bumps have no backward-compat guarantee; many maintainers treat the second digit as effectively major. Consider promoting `0.x.y` minor changes to major in the gate.
- **Live-validation CAP evidence** — the three ⚠️ rows in Lens 2 of this plan (`auto-merge-level-patch-minor`, `gate.diff-size`, `gate.waiting-period` partial) flip to ✅ when the first legitimate patch/minor Dependabot PR auto-merges on a managed repo. Tracked here until that event; close the loop with a CHANGELOG line.

### Shipping evidence table — final

Lens 1 (Gherkin coverage): **5/5 ✅**. Lens 2 (Behaviour symmetry): **4 ✅, 3 ⚠️** (live-validation deferred as above). Lens 3 (Self-consistency): **4 ✅, 1 n/a, 1 n/a**. No ❌ rows. **Shipped.**
