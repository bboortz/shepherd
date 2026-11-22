---
id: SH-030
slug: fleet-sha-pin-sweep
status: shipped
created: 2026-11-22
owner: @benni
---

# SH-030 — Fleet-wide SHA-pin sweep + `shepherd-bump --verify-sha-pin`

> **Follow-up from the [2026-11-22 fleet consistency audit](../specs/fleet-consistency-audit-2026-11-22.md) — critical severity.** Every non-shepherd fleet repo violates §12's `supply-chain.sha-pin-all-actions` invariant: 42 total mutable-tag `uses:` refs across healthy/beaconry/HRC/homelab/kernel-test/forge. Shepherd itself dogfoods the rule but doesn't yet enforce it on managed repos.

## 1. Who is the consumer?

- Repo maintainer who wants protection from CVE-2026-33634-class (TeamPCP) mutable-tag-attack supply-chain incidents — the vector that motivated SH-001.
- `shepherd-bump` operator: today `--verify-contract` + `--verify-dependabot` form a sub-verifier set; `--verify-sha-pin` completes the §12 trifecta.

## 2. When does the story fire?

- Once as a fleet-wide sweep (one PR per repo rewriting `@vN` → 40-hex SHA).
- Thereafter: every shepherd-bump cron on each managed repo. Any new mutable `uses:` ref fails fast and opens needs-human (matching the existing orphaned-pin invariant).

## 3. What does success look like?

Mechanically checkable:

- `shepherd-bump --verify-sha-pin --root <repo>` returns exit 0 ("all N `uses:` refs are SHA-pinned") or exit 4 with per-ref `missing sha-pin: <file>:<line> <owner/repo@<tag>>` lines.
- `.shepherd.yml` grows an optional opt-out: `supply_chain.sha_pin_enforce: true` (default). Setting `false` is a documented opt-out with a reason.
- The sweep lands as one PR per repo (6 repos × roughly 3–17 refs each) rewriting mutable tags to the current-tag SHA + a trailing `# vX.Y.Z` comment.
- Audit cell column 9 flips 6❌ → 7✅ after the sweep.
- Follow-up SH-031 handles orphaned-pin discoveries uncovered during the sweep.

## 4. How urgent?

- [x] Security-critical (§12 trust-boundary invariant)
- [x] Correctness (CVE-2026-33634 proved the vector is live)
- [ ] Quality-of-life
- [ ] Onboarding

## 5. Happy path

_TBD — filled when picked up. Rough shape:_

1. `shepherd-bump --verify-sha-pin --root healthy` → exit 4 with 3 refs listed.
2. For each ref, resolve `owner/repo@vX.Y.Z` to its current tag SHA via `gh api repos/{owner}/{repo}/tags`.
3. Rewrite in place: `uses: actions/foo@v4` → `uses: actions/foo@<sha>  # v4.X.Y`.
4. Open PR per repo; auto-merge gated by the usual SH-009 gates.
5. Re-run `--verify-sha-pin`; expect exit 0.

## 6. Edge cases / failure modes that matter

- **Orphaned pin.** A listed tag doesn't resolve to any upstream tag (force-pushed or deleted). Delegate to SH-031: open needs-human; do not rewrite.
- **Vendor archived.** The repo (`owner/repo`) is gone or 404. Same path — needs-human.
- **Already-pinned.** The verifier must not rewrite 40-hex refs; no-op by design.
- **Chained action with internal `uses:`.** The verifier scans all `.yml`/`.yaml` under `.github/`; composite actions in `.github/actions/*/action.yml` are included.
- **Our own internal refs.** Allow `uses: ./.github/actions/*`, `uses: bboortz/shepherd/.github/workflows/*@<sha>`. Mutable `@main` on cross-repo shepherd refs is NOT allowed; existing uses must SHA-pin.

## 7. Out of scope

- Mutable-ref guardrails outside `.github/` (e.g. Dockerfile `FROM alpine:latest`) — separate story if needed.
- Non-GitHub-native third-party actions in the non-critical path (e.g. ntfy). Still must SHA-pin; just not banned.
- Auto-updating pins (that's `shepherd-bump --check --ecosystem gh-actions`, SH-002).

## 8. Acceptance (Gherkin → test assertions)

```gherkin
Scenario: Clean repo passes
  Given a repo where every uses: ref is 40-hex SHA-pinned
  When  shepherd-bump --verify-sha-pin runs
  Then  exit 0 and stdout contains "verify-sha-pin: ok (N refs pinned)"

Scenario: Single mutable ref fails loud
  Given a workflow with `uses: actions/cache@v4`
  When  shepherd-bump --verify-sha-pin runs
  Then  exit 4
  And   stderr contains `.github/workflows/ci.yml` and `actions/cache@v4`

Scenario: Internal shepherd ref is allowed when SHA-pinned
  Given `uses: bboortz/shepherd/.github/workflows/reusable-shepherd.yml@<sha>`
  When  shepherd-bump --verify-sha-pin runs
  Then  exit 0

Scenario: Composite action in .github/actions/*/action.yml is scanned
  Given a composite action using `uses: actions/setup-node@v4`
  When  shepherd-bump --verify-sha-pin runs
  Then  exit 4 and the composite action path is named in stderr
```

Test: `test/acceptance/test_SH_030_verify_sha_pin.sh` (new), mirrors the fixture-scenario shape of `test_SH_017_verify_contract.sh`.

## 9. Capabilities delivered or extended

- `supply-chain.sha-pin-all-actions` — `active (shepherd dogfood)` → `active (fleet-enforced)`.
- `supply-chain.verify-sha-pin` — new CAP, bidirectional link to the test.

---

## Plan doc

Lands when this story moves from `draft → ready → in-progress`.
