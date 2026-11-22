# shepherd — Claude Instructions

Shepherd is a central fleet bot. It keeps registered repos patched, verified and healthy, and escalates to a human only when it must. The differentiator is the **sandboxed smart-fix agent** with hard budgets and a protected-files blocklist (`docs/specs/DESIGN.md §12`).

Public contract (eventually): `README.md` and files under `templates/`. Internals and rationale live under `memory/`. Full design is `docs/specs/DESIGN.md`.

@memory/project.md
@memory/workflow.md
@docs/specs/DESIGN.md
@/home/benni/.claude/RTK.md

---

## Repository layout

```
docs/
  specs/                 — authoritative contracts (SH-012)
    DESIGN.md            — source of truth for product, trust boundary, releases
    CAPABILITIES.md      — capability matrix; bidirectional links to tests
    docs-layout.md       — meta-spec for the docs/ layout itself
  stories/
    INDEX.md             — status board (grep-friendly), created when first story lands
    _template.md         — canonical story template (9 questions + Gherkin + CAPs)
    _9-questions.md      — canonical clarification set
    SH-NNN-<slug>.md     — one file per story
  plan/
    _template.md         — plan template w/ Shipping evidence table
    IDEAS.md             — backlog of ideas not yet promoted to stories
    SH-NNN-<slug>-plan.md — one plan per in-progress / shipped story
  FLEET.md               — repos using Shepherd (ops reference, not a spec)
  needs-human.md         — escalation issue template (consumed by shepherd-poc)
policy/
  default.yml            — global auto-merge rules, quiet hours, digest cadence
  repos/                 — per-repo overrides
renovate/
  default.json           — shared Renovate preset for the fleet
templates/
  shepherd.yml           — .shepherd.yml copied into each managed repo
  caller-verify.yml      — thin caller workflow copied into each managed repo
.github/workflows/
  discover.yml           — nightly discovery of shepherd-managed repos (stub)
  renovate.yml           — fleet-wide Renovate run (stub)
  digest.yml             — weekly digest to ntfy (stub)
  reusable-verify.yml    — called by managed repos: build + test + Trivy
memory/                  — persistent context for Claude sessions
VERSION                  — semver; bumped per push to non-main (pre-push verifies, later)
CHANGELOG.md             — Keep-a-Changelog; entry per VERSION required (later)
LICENSE                  — MIT
```

---

## Development process (DD-TGD)

Design-Driven, Test-Guarded Development. Every observable change traces back to a story, a plan, and a red acceptance test. Per feature:

0. **Consult `docs/plan/IDEAS.md`** — backlog of ideas already discussed. New ideas land here immediately, even if not picked up.
1. User-facing story → `docs/stories/SH-NNN-<slug>.md` (9 canonical questions, Gherkin acceptance). Question 9 names the CAPs the story delivers.
2. Branch `feat/SH-NNN-<slug>` from `dev` + plan doc `docs/plan/SH-NNN-<slug>-plan.md`.
3. Red acceptance test (location TBD when test harness lands; name follows `SH_NNN_<slug>`).
4. Implementation — smallest diff that turns the red test green.
5. **Register capabilities** — add or extend entries in `docs/specs/CAPABILITIES.md`; bidirectional links.
6. `make check` passes locally.
6a. **Pre-ship audit** — fill the Shipping evidence table in the plan. Three lenses: Gherkin coverage, behaviour symmetry, self-consistency. Any ⚠️/❌ blocks shipping.
7. README updated only if the public contract changed.
8. PR → `dev` → merge commit (not squash). Promotion to `main` happens through `release.yml`.

**Exceptions (no story required):** `fix/<slug>` (with repro), `refactor/<slug>`, `chore/<slug>`, `docs/<slug>`, `test/<slug>`, `ci/<slug>`.

Full gate matrix: `memory/workflow.md`. Story process & 9 questions: `docs/stories/_9-questions.md`.

Note: Shepherd has no source code yet. Early stories (SH-001+) will bring the R0 POC into `bboortz/healthy`, then land the reusable Action here from R1 onward. See `docs/specs/DESIGN.md §13`.

---

## Git workflow

- Work branches off `dev`. `main` is CI-promoted-only.
- PRs target `dev`. Promotion `dev` → `main` + tag `v<VERSION>` via `.github/workflows/release.yml` on manual `workflow_dispatch` (lands with Release 1).
- Commit format: `<type>[(<scope>)]: <description>` — conventional commits.
- Merge commits (not squash) preserve the PR boundary.
- PR title under 70 chars, same format as commits, no trailing period.
- Pushes to non-`main` branches bump `VERSION` since `origin/main` and carry a `## [v<VERSION>]` heading in `CHANGELOG.md` (enforced from Release 1).

---

## What NOT to do

- **Don't commit secrets.** The repo is public (`docs/specs/DESIGN.md §13 Decided 2026-11-19`). No API keys, hostnames, private design decisions in-tree.
- **Don't modify `templates/shepherd.yml` or `.github/workflows/*` without a story.** These are the files the bot itself cannot touch (protected-files rule, `docs/specs/DESIGN.md §12`).
- **Don't raise the agent budget caps without a story.** Defaults (`€5/day`, `€1/run`) are in `docs/specs/DESIGN.md §12`.
- **Don't add macOS/Windows paths.** Linux first (`docs/specs/DESIGN.md §13`).
- **Don't ship an observable change without an SH-NNN story + plan + CAP entry.** The traceability gate blocks this once the gates land.
- **Don't deepen `docs/specs/DESIGN.md` casually.** It's the source of truth — changes are their own `docs/` PR with rationale.
