# Shepherd fleet

The list of repositories using Shepherd and the release line they track. Opt-in: a repo joins by (a) being listed here **and** (b) carrying the `shepherd-managed` GitHub topic.

This file is the fleet registry until the fleet layer activates after Release 3. At that point discovery moves to topic search (`docs/DESIGN.md §2`, `§6`) and `FLEET.md` becomes the human-readable mirror of the topic.

## Active

R0 shipped 2026-11-21 across all three pilots. Pipeline + supply-chain hygiene + validator gates proven end-to-end; three real CVE fixes merged into `ham-radio-compass/main` autonomously.

| Repo | Release line | Onboarded | Owner | Live result on R0 |
|---|---|---|---|---|
| [`bboortz/healthy`](https://github.com/bboortz/healthy) | R0 shipped | 2026-11-21 | @benni | Zero fixable findings (single Zig file, no deps) — pipeline exercised, "no findings" exit path proven green. HC-008 shipped. |
| [`bboortz/beaconry`](https://github.com/bboortz/beaconry) | R0 shipped | 2026-11-21 | @benni | Zero fixable findings (Python surface kept clean). Pipeline proven green on the second pilot. BC-145 shipped; cron offset 05:30 UTC. |
| [`bboortz/ham-radio-compass`](https://github.com/bboortz/ham-radio-compass) | R0 shipped | 2026-11-21 | @benni | **Real fixes.** Three agent-produced PRs merged autonomously: [`#10`](https://github.com/bboortz/ham-radio-compass/pull/10) CVE-2025-7783 form-data, [`#12`](https://github.com/bboortz/ham-radio-compass/pull/12) CVE-2026-9277 shell-quote, [`#14`](https://github.com/bboortz/ham-radio-compass/pull/14) CVE-2026-102422 shell-quote. Cron offset 06:00 UTC. |

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
```

The output should match the `Active` section. A mismatch is the next candidate PR.
