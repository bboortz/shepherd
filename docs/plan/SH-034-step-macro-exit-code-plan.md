---
id: SH-034
slug: step-macro-exit-code
story: docs/stories/SH-034-step-macro-exit-code.md
branch: fix/ci-release-step-macro-exit-code
status: shipped
---

# SH-034 plan — step macro exit-code propagation

**Story:** [SH-034](../stories/SH-034-step-macro-exit-code.md)

## Design delta

One-line fix in two files; one new acceptance test; one new CAP row.

**Before:**

```make
define step
	@mkdir -p $(dir $(CI_STEPS_FILE))
	@_t0=$$(date +%s.%N); \
	 $(2); \
	 _t1=$$(date +%s.%N); \
	 _secs=$$(awk ...); \
	 printf '{"name":"%s","seconds":%s}\n' "$(1)" "$$_secs" >> $(CI_STEPS_FILE)
endef
```

The compound shell exits with the status of the last command (the `printf >>`), which is always 0 unless the steps file is read-only. `$(2)`'s non-zero exit is silently discarded.

**After:**

```make
define step
	@mkdir -p $(dir $(CI_STEPS_FILE))
	@_t0=$$(date +%s.%N); \
	 $(2); _rc=$$?; \
	 _t1=$$(date +%s.%N); \
	 _secs=$$(awk ...); \
	 printf '{"name":"%s","seconds":%s}\n' "$(1)" "$$_secs" >> $(CI_STEPS_FILE); \
	 exit $$_rc
endef
```

`_rc` captures the inner recipe's exit code before the timing emission can overwrite `$?`. The final `exit $$_rc` sets the compound's exit code to match.

### Changed files

- `Makefile` — 2 lines in the `define step` block.
- `templates/Makefile.contract.snippet` — same 2 lines + a 6-line comment above `define step` documenting the bug + why the fix is non-obvious.
- `docs/specs/CAPABILITIES.md` — new row `dev-cycle.step.exit-code-propagation`.
- `test/acceptance/test_SH_034_step_macro_exit_code.sh` — 8 assertions (source-form + end-to-end on a synthetic Makefile).
- `docs/stories/SH-034-step-macro-exit-code.md` → shipped.
- `docs/plan/SH-034-step-macro-exit-code-plan.md` (this file).

## Alternatives rejected

| Alternative | Why not |
|---|---|
| `set -e` at the top of the recipe | Make's `.ONESHELL` + `SHELLFLAGS` is non-portable across make versions (BSD vs GNU vs make 3.81 on macOS) and would affect every recipe in the file. Opt-in per-compound is cleaner. |
| Rewrite `step` to call the inner recipe as a separate rule | Loses the `$(call step,…)` ergonomics + would thread `_t0` across recipe boundaries. |
| `trap … EXIT` to emit timing on exit | Overkill; the current single-line replay is 4 chars and obvious. |
| Only fix shepherd's Makefile, not the template | The template is the propagation point to healthy/beaconry/homelab/forge/kernel-test (SH-019 rollout). Fixing only shepherd leaves 5 repos unsafe. |

## Breaking changes

- No behavioural change for repos whose inner recipes already exit 0. The only observable difference is that a *failing* inner recipe now bubbles up as a failing `make <tier>` — which was the intended behaviour all along.
- Fleet re-sync: next SH-019-style rollout PR on healthy/beaconry/homelab/forge/kernel-test will pick up the fixed snippet. Alternatively, a dedicated 5-PR sync (if the user wants it immediate).

## Rollout

- [x] Shepherd Makefile patched.
- [x] `templates/Makefile.contract.snippet` patched (with inline comment).
- [x] Acceptance test lands.
- [x] CAP registered.
- [ ] Fleet re-sync of the template to 5 managed repos — captured as a post-merge task, not blocking SH-034's ship.

## Shipping evidence

### Lens 1 — Gherkin coverage

| Scenario | Test pointer | Status |
|---|---|---|
| Script executable | `test_SH_034_step_macro_exit_code.sh:§0` | ✅ |
| `$(2); _rc=$$?;` present in Makefile + snippet | `test_SH_034_step_macro_exit_code.sh:§1` (both files) | ✅ |
| `exit $$_rc` present in Makefile + snippet | `test_SH_034_step_macro_exit_code.sh:§2` (both files) | ✅ |
| Bare `$(2); \` line gone from the step macro block | `test_SH_034_step_macro_exit_code.sh:§3` (both files, awk block-scan) | ✅ |
| End-to-end: successful inner recipe exits 0 | `test_SH_034_step_macro_exit_code.sh:§4` (synthetic Makefile `ok` target) | ✅ |
| End-to-end: failing inner recipe exits non-zero | `test_SH_034_step_macro_exit_code.sh:§4` (synthetic Makefile `fail` target) | ✅ |

### Lens 2 — Behaviour symmetry

| CAP | ≥1 test? | Exit paths tested? | Status |
|---|---|---|---|
| `dev-cycle.step.exit-code-propagation` | ✅ | ✅ (0 + non-zero) | new, active |

### Lens 3 — Self-consistency

| Check | Status |
|---|---|
| Fix applied symmetrically to both files | ✅ |
| Comment in snippet explains WHY (incident reference) | ✅ |
| `make check` green on shepherd | ✅ |
| Fleet re-sync captured as post-merge note | ✅ |

## Post-merge notes

- **Fleet template re-sync**: healthy/beaconry/homelab/forge/kernel-test still carry the old snippet. Next SH-019-style rollout picks up the fix; no immediate action unless a release is triggered before then.
