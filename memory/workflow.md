*Development workflow for shepherd. Design-Driven, Test-Guarded (DD-TGD) — every observable change traces from a story, through a plan doc, to a red acceptance test, to the merged commit.*

## Quality bar

**Every public-contract change is traceable** back to the story that motivated it (`docs/stories/SH-NNN-<slug>.md`), the plan that scoped it (`docs/plan/SH-NNN-<slug>-plan.md`), and the red acceptance test that proves it. If any link is missing, the change is not shippable.

The repo has no source code yet. These gates arrive with Release 1, once the reusable Action lands. Until then, YAML and Markdown are the artefacts, and lint + review is the gate.

## Development process: DD-TGD

```
Per feature (SH-NNN):
0. Consult IDEAS backlog    docs/plan/IDEAS.md — not-yet-promoted ideas go here immediately.
1. User-facing story        docs/stories/SH-NNN-<slug>.md
                            9 canonical questions → Gherkin acceptance + CAP list.
                            Status: draft → ready.
2. Branch + plan doc        feat/SH-NNN-<slug> from dev
                            docs/plan/SH-NNN-<slug>-plan.md:
                              - Story link, design delta, alternatives rejected
                              - Breaking changes (CLI? gates? protected-files list?)
                              - Rollout (docs updates, downstream notice)
                              - Shipping evidence table (filled at 6a)
                            Story status → in-progress.
3. Red acceptance test      (location follows the test harness, added with R1)
                            Top-of-file `Covers:` block names CAPs.
                            Must fail before implementation.
4. Implementation           Smallest change that turns the red test green.
5. Register capabilities    docs/CAPABILITIES.md — add or extend entries;
                            bidirectional links (CAP → test, test Covers: → CAP).
6. Gates                    make check (see matrix below).
6a. Pre-ship audit          Fill Shipping evidence table in the plan.
                            Three lenses: Gherkin coverage / behaviour symmetry /
                            self-consistency. Any ⚠️/❌ blocks shipping.
7. Update README            Only if the public contract changed.
8. PR → dev → merge         Merge commit (not squash). Story → shipped on merge.
                            Promotion dev → main happens via release.yml.
```

**Exceptions (no story required):**
- `fix/<slug>` — one-line fix with a repro in the commit body
- `refactor/<slug>` — acceptance tests prove behaviour invariance (run the full suite)
- `chore/<slug>` — dependency bump, GHA tweak, lint config
- `docs/<slug>` — docs-only change (`README.md`, `memory/`, `docs/`)
- `test/<slug>` — pure test addition against an existing CAP (add a pointer in `CAPABILITIES.md`)
- `ci/<slug>` — GitHub Actions only

**Definition of Done per SH-NNN (from R1 onward):**
- [ ] Red acceptance test went green via implementation
- [ ] Capabilities registered + bidirectional links present
- [ ] `make check` green
- [ ] Shipping evidence table has no ⚠️/❌ rows
- [ ] README updated if the public contract changed
- [ ] VERSION bumped + `CHANGELOG.md` entry present

## Stories — layout, format, lifecycle

```
docs/stories/
  INDEX.md             — one-line status board (grep-friendly; created when first story lands)
  _template.md         — canonical story template
  _9-questions.md      — the canonical clarification set
  SH-NNN-<slug>.md     — one file per story
```

Lifecycle: `draft → ready → in-progress → shipped` (frontmatter + INDEX).

## Capability matrix

`docs/CAPABILITIES.md` is the source of truth for what Shepherd does, with bidirectional links to the acceptance tests. Seed entries are the trust-boundary mechanisms from `docs/DESIGN.md §12`. Once code lands, every CAP needs ≥1 test pointer; every acceptance test's `Covers:` block names only known CAPs; every `ready+` story has at least one CAP in question 9.

## Blocking gates (from R1 onward)

| Gate | Command | Where |
|---|---|---|
| YAML lint | `yamllint .` | pre-commit + CI (fast-check) |
| Markdown lint | `markdownlint-cli2 "**/*.md"` | pre-commit + CI (fast-check) |
| Shell lint | `shellcheck` on `scripts/*.sh` (when scripts/ exists) | pre-commit + CI (fast-check) |
| Traceability | `make verify-traceability` | pre-commit + CI (fast-check) |
| Memory size | `memory/*.md` ≤ 150 lines; `CLAUDE.md` ≤ 150 lines | pre-commit |
| Commit format | `scripts/check-commit-msg.sh` (commit-msg hook) | local |
| VERSION bump | `make verify-version-bumped` | pre-push |
| CHANGELOG entry | `make verify-changelog` | pre-push + CI |
| Action build/test | TBD when the Action lands | pre-push + CI (full-check) |

No advisory gates — if a check isn't worth blocking, it isn't worth running.

## Branch flow

- **`dev` is the integration branch.** All work branches off `dev`.
- **`main` is CI-promoted-only.** Never push directly. Promotion happens via `.github/workflows/release.yml` on a manual `workflow_dispatch` — it asserts CI was green on `dev`, fast-forwards `main`, and tags `v<VERSION>`.
- PRs target `dev`. Merge commits (not squash) preserve the PR boundary.
- CI tiers mirror the branch roles: feature pushes → fast-check; `dev` pushes + PRs → full-check; `main` pushes → release-check (added with R1).
