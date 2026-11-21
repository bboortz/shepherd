# Shepherd fleet

The list of repositories using Shepherd and the release line they track. Opt-in: a repo joins by (a) being listed here **and** (b) carrying the `shepherd-managed` GitHub topic.

This file is the fleet registry until the fleet layer activates after Release 3. At that point discovery moves to topic search (`docs/DESIGN.md §2`, `§6`) and `FLEET.md` becomes the human-readable mirror of the topic.

## Active

| Repo | Release line | Onboarded | Owner | Notes |
|---|---|---|---|---|
| [`bboortz/healthy`](https://github.com/bboortz/healthy) | R0 (pilot) | 2026-11-21 | @benni | Target of the sandboxed-agent POC (`docs/DESIGN.md §13 Release 0`). Scheduled: Fri 27 Nov 2026. |

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
