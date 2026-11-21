---
id: SH-001
slug: retire-renovate
story: docs/stories/SH-001-retire-renovate.md
branch: feat/SH-001-retire-renovate
status: in-progress
---

# SH-001 plan — Retire Renovate; add shepherd-bump for GitHub Actions

**Story:** [SH-001](../stories/SH-001-retire-renovate.md)

## Design delta

Remove the Renovate scaffold from `shepherd` and replace it with a first-party Zig tool.

**Files removed**

- `.github/workflows/renovate.yml`
- `renovate/default.json`
- `renovate/` (empty directory after removal)

**Files added**

- `.github/workflows/bump.yml` — cron (`0 4 * * *`) + `workflow_dispatch`. Steps: checkout → `make build` → `./bin/shepherd-bump --ecosystem gh-actions`.
- `bump.zig` at repo root — single-file Zig source, matching healthy's "one source file" invariant. Split only if a measured constraint forces it.
- `build.zig` — Zig build script (cross-compile + release flags).
- Zig version pin to **0.17.1** (match `healthy`'s `memory/zig-pitfalls.md § API churn`).
- `Makefile` targets: `build`, `test`, `test-acceptance`. `check` extends to cover `zig fmt --check` + the acceptance script.
- `scripts/check-commit-msg.sh`, `scripts/verify-traceability.sh` — ported from healthy, retargeted to `SH-` prefixes and shepherd's story/plan/CAP layout.
- `.shepherd.yml` at repo root — dogfood. `risk: low`, `build: make build`, `test: make check`.
- `test/acceptance/test_SH_001_retire_renovate.sh` — shell assertions, one per Gherkin scenario.

**Files updated**

- `docs/DESIGN.md §2` — layout tree loses `renovate/`, renames `renovate.yml` → `bump.yml`, adds `bump.zig` + `build.zig`.
- `docs/DESIGN.md §4` — "Shared Renovate preset" → "Bump engine (shepherd-bump)". Short section: language, ecosystems, schedule, PR shape.
- `docs/DESIGN.md §7` — "Renovate workflow" → "Bump workflow". Short section matching the new workflow.
- `docs/DESIGN.md §12` — add invariant: *"No third-party GitHub Actions in shepherd's critical path. Exceptions: `actions/*` (GitHub-native), SHA-pinned only."*
- `docs/CAPABILITIES.md` — new Supply chain + Bump engine sections (see story §9).
- `memory/project.md` — append the new invariant.
- `README.md` — layout block loses the `renovate/` line.
- `CHANGELOG.md` — `## [v0.1.0]` with Added / Removed / Changed.
- `VERSION` — `0.0.0` → `0.1.0` (first real feature).

**New directory layout (deltas only)**

```
.github/workflows/
  bump.yml                   # was renovate.yml
  discover.yml               # unchanged
  digest.yml                 # unchanged
  reusable-verify.yml        # unchanged
bump.zig                     # the bump engine (one file first)
build.zig                    # Zig build
bin/                         # gitignored; shepherd-bump binary lands here
scripts/
  check-commit-msg.sh        # ported from healthy
  verify-traceability.sh     # ported from healthy, retargeted to SH-
test/acceptance/
  test_SH_001_retire_renovate.sh
.shepherd.yml                # dogfood
```

**Core data flow (`shepherd-bump --ecosystem gh-actions`)**

1. `list_manifests()` — enumerate `.github/workflows/*.yml` + `.github/actions/**/action.yml` via local checkout (no API call needed).
2. `parse_uses_lines(path)` — regex-match `uses:\s+([A-Za-z0-9._-]+)/([A-Za-z0-9._-]+)@([a-f0-9]{40})(?:\s*#\s*(v?[\d.]+))?`.
3. `fetch_latest_tag_in_major(owner, repo, current_major)` — `GET /repos/{owner}/{repo}/tags?per_page=100`, filter by SemVer within major, pick highest.
4. `resolve_tag_to_commit(owner, repo, tag_name)` — `GET /repos/{owner}/{repo}/git/ref/tags/{tag}`. If `object.type == "tag"` (annotated), follow `GET /repos/{owner}/{repo}/git/tags/{sha}` to obtain the commit SHA.
5. `detect_orphan(owner, repo, current_sha)` — if no tag resolves to `current_sha`, flag as orphan.
6. `write_patch(path, old_sha, new_sha, new_version_label)` — exact single-line replacement, preserve column and the trailing comment.
7. `open_pr(branch, title, body)` — git commit + push + `POST /repos/{owner}/{repo}/pulls`.

Group policy for v1: **one PR per bump**. Grouping per ecosystem per schedule is a follow-up story.

**Authentication**

- Secret: `SHEPHERD_BUMP_TOKEN` (fine-grained PAT, scoped to the shepherd repo only, with `Contents: write`, `Pull requests: write`, `Issues: write`).
- The App token path from `renovate.yml` is **not** reused. Minimal credential surface in R0/R1 per DESIGN §13 ("No GitHub App on the default path").

## Alternatives rejected

| Alternative | Why not |
|---|---|
| Keep Renovate, SHA-pin `renovatebot/github-action` | Narrows the window; doesn't eliminate upstream commit authority. The trust base still contains the Renovate maintainers. The user's explicit reason to drop it is to not depend on third-party services. |
| Build in Go / Python / Rust | Breaks the house-Zig principle (healthy already uses Zig; shepherd is adjacent). Zig gives us one source file, one static binary, no runtime deps — the strongest supply-chain story we can tell. |
| Use Dependabot's PRs instead of a new engine | GitHub-native, so acceptable in the trust base, but (a) does not SHA-pin, (b) limited grouping, (c) opaque schedule. We would still need our own tooling on top. |
| Start with npm instead of GitHub Actions | npm is more valuable for the public launch, but GitHub Actions is the smallest-surface MVP (one manifest shape, GitHub itself is the registry) and lets shepherd eat its own food on this very repo. npm comes in a follow-up story. |
| Split into `src/` from day one | Healthy's "one source file" invariant has been a forcing function. Start single-file; split only when a measured constraint forces it. |
| Move to the App token path for `bump.yml` | DESIGN §13 says "No GitHub App on the default path" for R0–R3. Fine-grained PAT is sufficient and smaller-blast-radius. |

## Breaking changes

- [x] **Yes** — `.github/workflows/renovate.yml` and `renovate/default.json` are removed. No external users yet, so blast radius is zero today, but the public DESIGN moves.
- [x] **Yes** — `docs/DESIGN.md §2, §4, §7, §12` reshape. The design is public, so this is a visible change.
- [x] **Yes** — new `.github/workflows/bump.yml` requires a `SHEPHERD_BUMP_TOKEN` secret to be created on the repo before the first scheduled run. The setup checklist in DESIGN.md §11 must be updated to mention it in the same PR.

README must be updated in the same PR. The PR body must call out the removal and the new secret.

## Rollout

- [ ] README updated — remove the `renovate/` line from the layout block.
- [ ] `memory/project.md` invariants updated — add the new §12 invariant.
- [ ] `docs/DESIGN.md` reconciled — §2, §4, §7, §11, §12 (also §13 "Risks to watch" bullet about Renovate is re-phrased).
- [ ] `docs/CAPABILITIES.md` — new Supply chain + Bump engine sections.
- [ ] `CHANGELOG.md` entry under `[v0.1.0]` with Added / Removed / Changed sections.
- [ ] `SHEPHERD_BUMP_TOKEN` secret created on the repo before the first scheduled run.
- [ ] First manual `workflow_dispatch` of `bump.yml` observes zero bumps (all SHAs are fresh as of merge day).
- [ ] Second run after an upstream bump produces a real PR; the PR is reviewed; shipping evidence row checks it.

## Shipping evidence (fill at step 6a)

Three lenses. Any ⚠️/❌ row blocks shipping — cycle back to step 4.

### Lens 1 — Gherkin coverage

| Scenario (from story §8) | Test pointer | Status |
|---|---|---|
| Renovate removed from the scaffold | `test/acceptance/test_SH_001_retire_renovate.sh:LN` | ✅ / ⚠️ / ❌ |
| shepherd-bump discovers pinned actions | `test/acceptance/test_SH_001_retire_renovate.sh:LN` | ✅ / ⚠️ / ❌ |
| shepherd-bump opens a PR for a newer patch within major | `test/acceptance/test_SH_001_retire_renovate.sh:LN` | ✅ / ⚠️ / ❌ |
| annotated tag resolves to commit SHA | `test/acceptance/test_SH_001_retire_renovate.sh:LN` | ✅ / ⚠️ / ❌ |
| orphaned pin opens a needs-human issue | `test/acceptance/test_SH_001_retire_renovate.sh:LN` | ✅ / ⚠️ / ❌ |
| major-version bump refused by default | `test/acceptance/test_SH_001_retire_renovate.sh:LN` | ✅ / ⚠️ / ❌ |

### Lens 2 — Behaviour symmetry

| CAP delivered | ≥1 test? | Exit / failure paths tested? | Status |
|---|---|---|---|
| `supply-chain.no-third-party-actions-critical-path` | | repo-tree assertion | ✅ / ⚠️ / ❌ |
| `supply-chain.first-party-bump-engine` | | bump.yml present, no renovatebot/ | ✅ / ⚠️ / ❌ |
| `bump.gh-actions` | | happy-path PR | ✅ / ⚠️ / ❌ |
| `bump.sha-pin` | | annotated-tag scenario | ✅ / ⚠️ / ❌ |
| `bump.stay-within-major` | | major-refused scenario | ✅ / ⚠️ / ❌ |
| `bump.orphaned-pin-detection` | | orphan scenario + exit 2 | ✅ / ⚠️ / ❌ |

### Lens 3 — Self-consistency

| Check | Status |
|---|---|
| Story obeys its own §7 (out-of-scope) — no npm/pip/etc. snuck in | ✅ / ⚠️ / ❌ |
| New CAPs in §9 all appear in `docs/CAPABILITIES.md` | ✅ / ⚠️ / ❌ |
| Protected-files invariant intact (DESIGN §12) | ✅ / ⚠️ / ❌ |
| Budget caps unchanged, or escalated to a human-reviewed change | ✅ / ⚠️ / ❌ / n/a |
| `make verify-traceability` green | ✅ / ⚠️ / ❌ |
| `make check` green (incl. `zig fmt --check` + acceptance) | ✅ / ⚠️ / ❌ |
| VERSION bumped to 0.1.0; CHANGELOG has the entry | ✅ / ⚠️ / ❌ |

## Post-merge notes

<Filled after the PR merges. One paragraph: what we learned, what bit us, what to carry into the next story — notably SH-002 for npm.>
