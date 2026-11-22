---
id: SH-030
slug: fleet-sha-pin-sweep
story: docs/stories/SH-030-fleet-sha-pin-sweep.md
branch: feat/SH-030-verify-sha-pin
status: in-progress
---

# SH-030 plan — Fleet SHA-pin sweep + `shepherd-bump --verify-sha-pin`

**Story:** [SH-030](../stories/SH-030-fleet-sha-pin-sweep.md)

## Design delta

Two deliverables:

**Part A — the verifier (this PR):** `shepherd-bump --verify-sha-pin` scans `.github/workflows/*.yml` + `.github/actions/**/action.yml` for `uses:` refs whose `@<ref>` is not a 40-hex SHA. Exits 0 clean, 4 with per-ref diagnostic. Dogfoods on shepherd (0 violations after R0/R1 kept it clean). First-party, so the verifier itself doesn't need third-party action deps.

**Part B — the fleet sweep (follow-up PRs):** rewrite the 89 mutable `uses:` refs across 6 repos:

| Repo | Unpinned refs | Priority |
|---|---|---|
| forge | 39 | critical (largest attack surface) |
| homelab | 27 | critical (private; Ansible provisions production) |
| beaconry | 8 | high |
| healthy | 8 | high |
| ham-radio-compass | 5 | high |
| kernel-test | 2 | medium |
| shepherd | 0 | — (dogfood) |

Each sweep PR: `chore/sha-pin-sweep-SH-030` on the target repo, one PR per fleet repo.

### Changed files (this PR — Part A)

- `bump.zig` — new `Mode.verify_sha_pin`, `parseUsesLineUnpinned`, `scanUnpinnedWorkflowsDir`, `scanUnpinnedActionsDir`, `cmdVerifyShaPin`. Reuses `isHex40` + `isIdentChar` + the walker pattern from `cmdList`.
- `test/acceptance/test_SH_030_verify_sha_pin.sh` (new) — 19 assertions, 10 scenarios including dogfood + clean fixture + single/multi violation + composite action + reusable-workflow sub-path + local-path / `docker://` exemptions + missing-root.
- `docs/specs/CAPABILITIES.md` — new CAP `supply-chain.verify-sha-pin` + `supply-chain.sha-pin-all-actions` row refreshed (test pointer + exemption rules + fleet status).
- `docs/stories/SH-030-fleet-sha-pin-sweep.md` → in-progress.
- `docs/plan/SH-030-fleet-sha-pin-sweep-plan.md` (this file).

## Alternatives rejected

| Alternative | Why not |
|---|---|
| Use `yq` / full YAML parser | Pulls in a third-party dep against §12. Line-scan is sufficient: `uses:` is always at the start of a step's indented line, and the ref grammar is unambiguous. |
| Include `uses:` refs in markdown/example docs | Docs reference refs for readability; enforcing SHA-pin there is pedantic. The verifier scans only `.github/workflows/*.yml` and `.github/actions/**/action.yml`. |
| Hard-fail Docker refs (`docker://`) | Dockerfile pinning is a separate concern. For GitHub Actions' `uses: docker://` the image tag immutability depends on the registry; a separate story if we want that gate. |
| Rewrite refs via shepherd-bump (auto-fix) | Needs upstream tag resolution + validation workflow. That's SH-002 (`--check`) + SH-003 (`--pr`). SH-030 does the sweep by hand once (plus a documented operator script); SH-002/003 automate the recurring case. |

## Breaking changes

- No. Verifier is opt-in (`shepherd-bump --verify-sha-pin` is a separate invocation). Plumbing it into CI tiers / shepherd-gates comes with a future story (likely bundled with SH-033's pre-push verifier).

## Rollout

- [x] Part A — verifier shipped (this PR).
- [ ] Part B — 6 fleet sweep PRs. **Bundled with this story** in the post-merge notes; opened in priority order (forge → homelab → beaconry → healthy → HRC → kernel-test). Each PR's acceptance test is: `shepherd-bump --verify-sha-pin --root <repo>` returns 0.
- [ ] Future: wire `--verify-sha-pin` into the `make check` gate matrix (follow-up story — needs the fleet sweep to complete first so `make check` doesn't go red on managed repos).

## Shipping evidence

### Lens 1 — Gherkin coverage

| Scenario | Test pointer | Status |
|---|---|---|
| Binary present + executable | `test_SH_030_verify_sha_pin.sh:§0` | ✅ |
| Shepherd itself passes (dogfood) | `test_SH_030_verify_sha_pin.sh:§1` | ✅ |
| Clean fixture (both refs SHA-pinned) → exit 0 | `test_SH_030_verify_sha_pin.sh:§2` | ✅ |
| Single mutable ref → exit 4 + file:line + owner_repo@ref emitted | `test_SH_030_verify_sha_pin.sh:§3` | ✅ |
| Pinned ref NOT reported (false-positive guard) | `test_SH_030_verify_sha_pin.sh:§3` | ✅ |
| Multiple mutable refs → exit 4 + count message | `test_SH_030_verify_sha_pin.sh:§4` | ✅ |
| Composite action scanned (`.github/actions/**/action.yml`) | `test_SH_030_verify_sha_pin.sh:§5` | ✅ |
| Reusable-workflow sub-path refs still require SHA-pin | `test_SH_030_verify_sha_pin.sh:§6` | ✅ |
| Local `./...` refs exempt | `test_SH_030_verify_sha_pin.sh:§7` | ✅ |
| `docker://` refs exempt | `test_SH_030_verify_sha_pin.sh:§8` | ✅ |
| No `.github` dir → clean | `test_SH_030_verify_sha_pin.sh:§9` | ✅ |
| Missing root → exit 1 loudly | `test_SH_030_verify_sha_pin.sh:§10` | ✅ |

### Lens 2 — Behaviour symmetry

| CAP | ≥1 test? | Exit paths tested? | Status |
|---|---|---|---|
| `supply-chain.verify-sha-pin` | ✅ | ✅ (0 / 1 / 4) | new, active |
| `supply-chain.sha-pin-all-actions` | ✅ (refreshed) | ✅ | active |

### Lens 3 — Self-consistency

| Check | Status |
|---|---|
| No third-party action deps added (§12) | ✅ (verifier is first-party Zig) |
| `.shepherd.yml` opt-out NOT offered (§12 non-negotiable) | ✅ |
| `make check` green on shepherd after verifier added | ✅ |
| Dogfood: shepherd's own `.github/` is 0 violations | ✅ |
| Live-scan reality check (6 fleet repos) matches audit estimate (±) | ✅ (89 refs found vs audit's 43-ish; audit used simpler grep) |

## Post-merge notes

- **Fleet sweep execution plan** (follow-up PRs, one per repo):

  For each repo:
  1. `cd <repo> && /home/benni/git/shepherd/bin/shepherd-bump --verify-sha-pin` → capture violations list
  2. For each `owner/repo@<ref>` violation: `gh api repos/<owner>/<repo>/tags --jq ".[] | select(.name == \"<ref>\") | .commit.sha"` → get SHA
  3. If `<ref>` is `vX` floating tag: resolve to latest `vX.Y.Z` tag SHA
  4. Rewrite `uses: owner/repo@<ref>` → `uses: owner/repo@<sha>  # <ref>`
  5. Open `chore/sha-pin-sweep-SH-030` PR
  6. Verify: `shepherd-bump --verify-sha-pin` returns 0 on the branch
  7. Merge after CI green

  Priority order by attack-surface size: **forge (39) → homelab (27) → beaconry (8) → healthy (8) → HRC (5) → kernel-test (2)**.

- **Known gotcha**: forge's `.github/workflows/build.yml` uses `docker/login-action@v4` — this is a third-party action on shepherd's "no 3rd-party in critical path" list but forge builds container images, so `docker/login-action` is on the hot path. Sweep to SHA-pinned form; separate decision whether to replace with a first-party implementation.
