# Contributing to shepherd

Shepherd is a pre-1.0 personal project with a public roadmap. External PRs are welcome once it reaches Release 2 (friendly testers). Until then, please open an issue or discussion before writing code — the design is moving and we'd like to avoid wasted work.

Full product design: [`docs/DESIGN.md`](docs/DESIGN.md).
Internal development process: [`CLAUDE.md`](CLAUDE.md) + [`memory/workflow.md`](memory/workflow.md).

---

## Development process (summary)

Shepherd follows **DD-TGD** — Design-Driven, Test-Guarded Development. Every observable change traces from a story, through a plan doc, to a red acceptance test, to the merged commit.

```
Per feature (SH-NNN):
0. Consult IDEAS backlog        docs/plan/IDEAS.md
1. User-facing story            docs/stories/SH-NNN-<slug>.md (9 questions)
2. Branch + plan doc            feat/SH-NNN-<slug> from dev
3. Red acceptance test          (location follows the test harness, R1+)
4. Implementation
5. Register capabilities        docs/CAPABILITIES.md
6. Local gates                  make check
6a. Pre-ship audit              fill Shipping evidence table in the plan
7. Update README (if contract changed)
8. PR → dev → merge
```

**Exceptions (no story required):** `fix/`, `refactor/`, `chore/`, `docs/`, `test/`, `ci/` branches.

## Git conventions

- Base branch is `dev`. `main` is CI-promoted via `.github/workflows/release.yml` (lands with R1).
- Branches: `feat/SH-NNN-<slug>`, `fix/<slug>`, `refactor/<slug>`, `chore/<slug>`, `docs/<slug>`, `test/<slug>`, `ci/<slug>`.
- Commits: conventional format `<type>[(<scope>)]: <description>`. The commit-msg hook will enforce this from R1 onward.
- PR titles under 70 chars, same format as commits, no trailing period.
- Merge commits (not squash) preserve the PR boundary.

## Security

Please read [`SECURITY.md`](SECURITY.md) before reporting a vulnerability. The sandboxed smart-fix agent and its budget / protected-files rules are the trust boundary (`docs/DESIGN.md §12`); any report that affects them is high priority.

## Scope reminders

- Linux only. No macOS / Windows paths.
- GitHub only (repos, issues, PRs, Actions).
- Anthropic API only, through the locked gateway.
- MIT, everything in the open. No secrets, hostnames or private data in-tree.
