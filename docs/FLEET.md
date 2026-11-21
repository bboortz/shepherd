# Shepherd fleet

The list of repositories using Shepherd and the release line they track. Opt-in: a repo joins by (a) being listed here **and** (b) carrying the `shepherd-managed` GitHub topic.

This file is the fleet registry until the fleet layer activates after Release 3. At that point discovery moves to topic search (`docs/DESIGN.md §2`, `§6`) and `FLEET.md` becomes the human-readable mirror of the topic.

## Active

Six-repo fleet as of 2026-11-21. All on shepherd v0.7.0-rc1 reusable Action + all five §12 auto-merge gates (SH-009 + SH-010) + Dependabot baseline (SH-011). Pilots 4–6 onboarded end of day for R1 soak coverage (pip + docker + shell ecosystems; multi-service + container-image + workflow-driven repo shapes).

| Repo | Release line | Onboarded | Owner | Cron | Live result |
|---|---|---|---|---|---|
| [`bboortz/healthy`](https://github.com/bboortz/healthy) | R1 | 2026-11-21 | @benni | 05:00 | R0 "no findings" exit path proven green. Migrated to reusable Action v0.5.0-rc2 (PR #18); then re-pinned to rc3→rc5→rc6→rc7 along SH-007/009/010 track. |
| [`bboortz/beaconry`](https://github.com/bboortz/beaconry) | R1 | 2026-11-21 | @benni | 05:30 | R0 clean. Opted into Dependabot auto-merge (6 of 7 patch/minor PRs auto-merged after SH-011). Gates caller installed; re-pinned along the SH-009/010 track. |
| [`bboortz/ham-radio-compass`](https://github.com/bboortz/ham-radio-compass) | R1 | 2026-11-21 | @benni | 06:00 | **Real fixes + first live auto-merge.** R0 agent produced [`#10`](https://github.com/bboortz/ham-radio-compass/pull/10) / [`#12`](https://github.com/bboortz/ham-radio-compass/pull/12) / [`#14`](https://github.com/bboortz/ham-radio-compass/pull/14) (3 critical CVEs merged autonomously). **SH-009 live canary** [`#47`](https://github.com/bboortz/ham-radio-compass/pull/47) auto-merged by `app/github-actions` (merge commit `d0524d48`). SH-005 live-drill ran against this repo. |
| [`bb-claw/homelab`](https://github.com/bb-claw/homelab) | R1 | 2026-11-21 | @bb-claw | 06:30 | New pilot — pip + docker + gh-actions. Mix of pinned + loose-pin `requirements.txt`; exercises the SH-010 waiting-period + pip-compile-or-fail IDEAS entries. Private repo. `dry_run: true` for first cycle. |
| [`bb-claw/kernel-test`](https://github.com/bb-claw/kernel-test) | R1 | 2026-11-21 | @bb-claw | 07:00 | New pilot — shell-first, gh-actions ecosystem only. Low-churn repo; validates the pipeline's clean-state exit path on a 4th pilot. `dry_run: true` for first cycle. |
| [`bboortz/forge`](https://github.com/bboortz/forge) | R1 | 2026-11-21 | @benni | 07:30 | New pilot — container-image build repo (shell + docker + gh-actions). Nightly rebuilds already stress the CI surface; shepherd adds dep hygiene. `dry_run: true` for first cycle. |

**TODO before pilots 4–6 go live:** set `ANTHROPIC_API_KEY` as a repo secret on each (`gh secret set ANTHROPIC_API_KEY -R <repo>`). Until the key is set, the shepherd agent caller fails at the agent step; the gates caller and Dependabot config run unaffected.

## Archived

*None yet.*

## Conventions

- **Release line** names the shepherd release the repo is tracking: `R0 (pilot)`, `R1`, `R2`, `R3`, `main`, or `paused`.
- **Onboarded** is the date the `shepherd-managed` topic was applied to the repo.
- Removing a repo from the fleet: remove the topic from the repo, move the row from `Active` to `Archived` with a date and one-line reason, keep history.
- This file is edited by humans. Automated reconciliation against the topic lives in a future story (the fleet layer after R3).

## Verification

List repos the user owns that carry the topic:

```sh
gh search repos "owner:bboortz topic:shepherd-managed" --json name,url
gh search repos "owner:bb-claw topic:shepherd-managed" --json name,url
```

The fleet now spans two GitHub accounts (`bboortz` and `bb-claw`). Discovery moves to topic search after R3 (DESIGN §2); until then, this file is the registry.

The output should match the `Active` section. A mismatch is the next candidate PR.
