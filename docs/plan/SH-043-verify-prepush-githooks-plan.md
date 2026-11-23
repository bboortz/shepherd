---
id: SH-043
slug: verify-prepush-githooks
story: docs/stories/SH-043-verify-prepush-githooks.md
branch: feat/SH-043-verify-prepush-githooks
status: shipped
---

# SH-043 plan — `--verify-prepush` accepts `.githooks/` form

**Story:** [SH-043](../stories/SH-043-verify-prepush-githooks.md)

## Design delta

Extend `bump.zig::cmdVerifyPrepush` with a third detection branch after `.pre-commit-config.yaml` + `.husky/pre-push`. Permissive content check: file contains the string `make check`.

### Changed files

- `bump.zig` — ~15 lines added after the existing `.husky/pre-push` block.
- `test/acceptance/test_SH_033_verify_prepush.sh` — 3 new scenarios (7b .githooks/ with make check / 7c .githooks/ without / 8 error message cites all three forms); jumps from 17→21 assertions.
- `docs/specs/CAPABILITIES.md` — row refreshed.

## Alternatives rejected

| Alternative | Why not |
|---|---|
| Also read `git config core.hooksPath` | Not portable from a Zig CLI; adds subprocess call. Install-time check lives elsewhere (operator responsibility, or a future `--verify-githooks-install`). |
| Skip `.pre-commit-config.yaml` if `.githooks/` exists | Would be nice for homelab/kernel-test but introduces complex precedence. Simpler: let shadow configs pass; they *do* actually fire if pre-commit-install was run. |
| Require `.githooks/pre-push` to be executable | Executability is an install concern. Content check is enough for the verifier. |

## Breaking changes

None. Add-only to the verifier. Repos that previously passed still pass; repos that only had `.githooks/` now also pass (previously would have failed with exit 3).

## Rollout

- [x] Verifier updated.
- [x] Tests extended (3 new scenarios).
- [x] CAP row refreshed.
- [x] Dogfood: homelab + kernel-test verified green via existing shadow config (expected behaviour).

## Shipping evidence

### Lens 1 — Gherkin coverage

| Scenario | Test pointer | Status |
|---|---|---|
| .githooks/pre-push with make check → exit 0 | `test_SH_033:§7b` | ✅ |
| .githooks/pre-push without make check → exit 4 | `test_SH_033:§7c` | ✅ |
| Error on exit 3 names all three forms | `test_SH_033:§8` | ✅ |
| All previous scenarios still pass | `test_SH_033:§1..6, §9..11` | ✅ |

### Lens 2 — Behaviour symmetry

| CAP | ≥1 test? | Exit paths tested? | Status |
|---|---|---|---|
| `dev-cycle.prepush.verify` | ✅ (refreshed) | ✅ (0 / 1 / 3 / 4) | active (no status change) |

### Lens 3 — Self-consistency

| Check | Status |
|---|---|
| Add-only change (no breaking) | ✅ |
| Check order documented (pre-commit → husky → githooks) | ✅ |
| Error message cites all three forms | ✅ |
| `make check` green | ✅ |
