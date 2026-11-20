# Ideas backlog — shepherd

Not-yet-promoted ideas. New ideas land here immediately, even if we won't pick them up. Promote to `docs/stories/SH-NNN-<slug>.md` when a story is cut.

## Open from DESIGN.md §13

- **Supported ecosystems for R2 / 1.0.** Candidates: Docker images, GitHub Actions, npm, pip, Go, Zig. Final list is still open. Needs its own story once the agent prototype in R0 tells us which ecosystems are cheap to support.
- **Project name for the public release.** Keep *Shepherd* or rename. Decide before R2's README lands.

## Candidates from DESIGN.md §12

- **Scope level 2 (small code changes after an upgrade).** Lands in R2 per §13, but worth a story to pin the guardrails — e.g. how to detect that a dep bump broke an API surface, what the retry/escalation ladder looks like.
- **Scope level 3 (general source fixes for security findings).** Same release, higher blast radius — needs its own story with an injection-safety section.
- **Scope level 4 (pipelines / workflows).** Explicitly requires a human-reviewed approval — the story is how the bot even surfaces it as a candidate without being able to touch the files.

## Candidates from DESIGN.md §13 principles

- **Dry-run mode as the first experience.** The Action should comment what it would do and change nothing on the very first run. Needs a story so the behaviour is tested.
- **Zero-config defaults.** `.shepherd.yml` is optional. A story should pin the exact defaults (and where they're listed, so they don't drift from DESIGN).
- **Built-in gateway with network lockdown.** The Action pins network egress to the model API only. Needs a story for the Linux runner implementation (iptables / nftables / network namespace) and the self-test that proves lockdown.
