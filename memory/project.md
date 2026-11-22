*What shepherd is, the trust-boundary invariants that make it worth trusting, and the scope it lives inside.*

## What it is

Shepherd is a fleet bot that keeps registered repos patched, verified and healthy. It auto-opens PRs for dependency bumps and security fixes, verifies them against each repo's own build/test, and escalates to a human issue when it can't. The novel piece is the **smart-fix agent**: a sandboxed Claude run that produces a diff a trusted step then commits.

Full design: [`docs/specs/DESIGN.md`](../docs/specs/DESIGN.md). Public pitch: [`README.md`](../README.md).

## Trust-boundary invariants (do not violate casually)

From `docs/specs/DESIGN.md §12`:

1. **Auto-merge is per-repo, off by default.** Without an explicit opt-in in `.shepherd.yml`, the bot only opens PRs.
2. **Agent runs with no network and no secrets of its own.** It reads the checkout, produces a diff. The Claude API is reached only through one locked gateway.
3. **Hard budget enforced by the gateway.** `€5/day` + `€1/run` by default. Hitting either stops the run and emits an ntfy note.
4. **Path blocklist is enforced by the trusted step, not the agent.** By default the agent may not touch workflows, secrets, deployment config, or `.shepherd.yml` — it cannot change its own rules. Unblocking the registration file or the shepherd workflows requires a human-reviewed change.
5. **Failed fixes always open a needs-human issue.** No quiet logging. If an issue for the same problem exists, the bot comments instead of duplicating.
6. **Fix scope is per-repo, defaults to level 1.** Level 4 (pipelines) always needs a human-reviewed approval.
7. **Gates before auto-merge.** Required pipelines green, diff ≤ 50 lines, 24h waiting period from release date, scan not worse (default: HIGH+CRITICAL).
8. **No third-party GitHub Actions in shepherd's critical path (SH-001).** Exceptions: `actions/*` (GitHub-native), SHA-pinned only. Dependency bumps go through `shepherd-bump` (first-party Zig binary), not Renovate or Dependabot.

## Release trajectory (from `docs/specs/DESIGN.md §13`)

- **R0 POC** — single workflow in `bboortz/healthy`. Sandboxed agent produces 3 real PRs + one prompt-injection test passes. Not in this repo yet.
- **R1 MVP 1** — reusable GitHub Action in `bboortz/shepherd` with gates, budgets, needs-human issues. 3 of your own repos run it for 2 weeks.
- **R2 MVP 2** — README, demo, security docs, scope levels 1–3, 5 friendly outside testers.
- **R3 1.0-rc1 → public launch mid-January** — goal is 100 stars + 20 feedback issues within three months.

The fleet layout in `docs/specs/DESIGN.md §2` (discover.yml, central bot, GitHub App) is **superseded** for the first public version. It stays scaffolded here so the shape is obvious, but it doesn't activate until after Release 3.

## Fleet registry

[`docs/FLEET.md`](../docs/FLEET.md) is the canonical list of repos using Shepherd. Each entry also carries the `shepherd-managed` GitHub topic (DESIGN.md §2). Until the fleet layer activates after R3, FLEET.md *is* the registry; after that, topic search takes over and FLEET.md becomes the human-readable mirror.

## What is NOT in scope

- No macOS or Windows runners. Linux only.
- No forge besides GitHub (repos, issues, PRs, Actions).
- No model provider besides Anthropic (Claude API via the locked gateway) at the start.
- No central hosted service and no mandatory GitHub App in the default path for R1/R2. The App is advanced-mode, announced from R3.
- No closed or paid core. MIT, everything in the open.
- No secrets, hostnames or private data in-tree — the repo is public.

## Open questions (as of 2026-11-19)

- Which package ecosystems the fix agent supports in R2 and 1.0 (Docker images, GitHub Actions, npm, pip, Go, Zig).
- Whether the project keeps the name *Shepherd* for the public release.

Track new open questions in [`docs/plan/IDEAS.md`](../docs/plan/IDEAS.md).
