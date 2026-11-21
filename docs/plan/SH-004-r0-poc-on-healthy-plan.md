---
id: SH-004
slug: r0-poc-on-healthy
story: docs/stories/SH-004-r0-poc-on-healthy.md
branch: n/a (implementation lives in bboortz/healthy as HC-008)
status: in-progress
---

# SH-004 plan — Release 0 POC on `bboortz/healthy`

**Story:** [SH-004](../stories/SH-004-r0-poc-on-healthy.md)
**Implementation:** `bboortz/healthy` branch `feat/HC-008-shepherd-poc`, PR to be opened against `dev`.

## Design delta

This story has **no shepherd-side implementation**. Only the design, CAPs and acceptance live here. The workflow, scripts, and prompt-injection fixture land in `bboortz/healthy` under `HC-008`.

Why split: R0 is in `healthy` by DESIGN §13 ("One repo, one file, one secret"). The design and traceability live in shepherd because shepherd owns the product. R1 moves the substantive code back into shepherd as the reusable Action.

## Alternatives rejected

| Alternative | Why not |
|---|---|
| Ship R0 in shepherd (reusable Action) instead of healthy | Contradicts DESIGN §13 explicitly. The staged design (R0 bespoke → R1 Action → R2+ polish) is deliberate; collapsing it costs the "one repo, one file, one secret" onboarding story. |
| Implement the sandbox perimeter in R0 (docker network isolation, nsjail, or netns) | ~2 days of work for a POC. R0's job is to prove the agent produces fixes; R1 adds the sandbox. Gap is documented in the story §7. |
| Use `aquasecurity/trivy-action` for the Trivy install | Violates SH-001 `supply-chain.no-third-party-actions-critical-path` invariant. Use the sigstore-verified release download instead. |
| Shell out to `claude` CLI | The CLI reads from `$CLAUDE_CONFIG_DIR` and has broader capabilities than a single HTTP call. `curl` to the Messages API is smaller surface. |
| Write the agent step in Zig | R0's agent step is one `curl` call + one `jq` extract. Zig would be over-engineering. R1's packaged Action may revisit. |

## Breaking changes

- **In shepherd:** none. SH-004 is docs-only on this side.
- **In healthy:** a new workflow adds a cron schedule and requires `ANTHROPIC_API_KEY` as a repo secret. Setup checklist for the operator is in HC-008's plan.

## Rollout

- [ ] In shepherd: SH-004 story + plan committed, INDEX updated, docs/FLEET.md's healthy entry promoted from "R0 pilot (scheduled)" to "R0 (active)" after HC-008 merges.
- [ ] In healthy: HC-008 branch + PR; after merge, the operator (benni) sets `ANTHROPIC_API_KEY` in healthy's repo secrets and triggers the first `workflow_dispatch` run.
- [ ] CAPABILITIES.md rows added for R0-level evidence:
  - `sandbox.no-secrets`, `sandbox.diff-only`, `blocklist.protected-files`, `gate.diff-size`, `gateway.budget-run`, `scope.level-1` → status `in-progress` (POC-level; full `active` with R1).
- [ ] `supply-chain.sha-pin-all-actions` extended: HC-008's acceptance script asserts the invariant holds for the new workflow too.

## Shipping evidence (fill at step 6a, mostly in HC-008)

Three lenses. Rows that depend on live Anthropic API runs are marked "runtime-only" — they only turn ✅ once the operator sets `ANTHROPIC_API_KEY` in healthy's secrets and the first run completes.

### Lens 1 — Gherkin coverage

| Scenario | Test pointer | Status |
|---|---|---|
| Workflow exists and is scheduled | `healthy: test/acceptance/test_HC_008_shepherd_poc.sh` | pending |
| Trivy install is sigstore-verified | `healthy: test/acceptance/test_HC_008_shepherd_poc.sh` | pending |
| Diff validator blocks protected paths | `healthy: scripts/shepherd-poc/validate.sh + fixture` | pending |
| Diff validator blocks over-size changes | `healthy: scripts/shepherd-poc/validate.sh + fixture` | pending |
| Prompt-injection drill | `healthy: workflow_dispatch + fixture branch` | runtime-only |

### Lens 2 — R0 CAP evidence

| CAP | Test | Status |
|---|---|---|
| `sandbox.no-secrets` | step `env:` block audit | pending |
| `sandbox.diff-only` | agent step outputs file; separate step applies | pending |
| `blocklist.protected-files` | `validate.sh` test fixture | pending |
| `gate.diff-size` | `validate.sh` test fixture | pending |
| `gateway.budget-run` | `max_tokens` cap in agent call | pending |
| `scope.level-1` | prompt text + injection drill | runtime-only |
| `supply-chain.sha-pin-all-actions` | 40-hex SHA assertion over workflow | pending |

### Lens 3 — Self-consistency

| Check | Status |
|---|---|
| Story obeys its own §7 (no R1 features snuck in) | pending |
| DESIGN §13 R0 exit criteria achievable on this scaffold | pending |
| Documented sandbox gap is honest + visible in the PR body | pending |

## Post-merge notes

<To fill after HC-008 merges in healthy and the first live run produces a PR.>
