# Shepherd fleet

The list of repositories using Shepherd and the release line they track. Opt-in: a repo joins by (a) being listed here **and** (b) carrying the `shepherd-managed` GitHub topic.

This file is the fleet registry until the fleet layer activates after Release 3. At that point discovery moves to topic search (`docs/DESIGN.md §2`, `§6`) and `FLEET.md` becomes the human-readable mirror of the topic.

## Active

| Repo | Release line | Onboarded | Owner | Notes |
|---|---|---|---|---|
| [`bboortz/healthy`](https://github.com/bboortz/healthy) | R0 (pilot 1) | 2026-11-21 | @benni | First R0 pilot ([HC-008](https://github.com/bboortz/healthy/blob/main/docs/stories/HC-008-shepherd-poc.md)). Zig single file, zero deps → Trivy finds nothing; first dispatch green against the "no findings" exit path. |
| [`bboortz/beaconry`](https://github.com/bboortz/beaconry) | R0 (pilot 2) | 2026-11-21 | @benni | Second R0 pilot ([BC-145](https://github.com/bboortz/beaconry/blob/main/docs/stories/BC-145-shepherd-poc.md)). Python + Docker — real dependency surface so the agent-fix path gets real exercise. Cron offset 30 min from healthy. |

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
