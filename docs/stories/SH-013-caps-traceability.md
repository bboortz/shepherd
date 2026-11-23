---
id: SH-013
slug: caps-traceability
status: shipped
created: 2026-11-22
owner: @benni
---

# SH-013 — Capabilities-matrix traceability (port healthy/forge convention)

## 1. Who is the consumer?

Contributor extending Shepherd (humans + Claude). When they add a story they
need to know: (a) which CAPs this story delivers, (b) that the acceptance
test's `# CAPs:` header names only CAPs that exist, (c) that every CAP in
`docs/specs/CAPABILITIES.md` has at least one test pointer. Today those three
properties drift silently.

## 2. When does the story fire?

Every `make check` run — locally, in pre-commit, in CI. Also every time
someone adds or renames a CAP id, adds an acceptance test, or promotes a
story to `ready`/`in-progress`/`shipped`.

## 3. What does success look like?

Mechanically checkable:

- `scripts/verify-traceability.sh` exists, is executable, and enforces:
  - Every CAP row in `docs/specs/CAPABILITIES.md` has a non-empty test
    pointer in its `Test` column (or an explicit `see <section>` cross-ref).
  - Every `test/acceptance/test_SH_*.sh` has a `# CAPs:` header.
  - Every CAP id named in a test's `# CAPs:` header exists in
    `docs/specs/CAPABILITIES.md`.
  - Every story with `status: ready|in-progress|shipped` lists ≥ 1 CAP id in
    its §9 `Capabilities delivered or extended` section.
- `make verify-traceability` runs both the SH-012 layout+refs check AND
  the SH-013 caps-traceability check. `make check` depends on it.
- All 6 existing acceptance tests use `# CAPs:` (matching healthy + forge),
  not the former shepherd-specific `# Covers:`.
- `test/acceptance/test_SH_013_traceability.sh` exercises happy path +
  three negative fixtures (missing test pointer, unknown CAP, orphan story).

## 4. How urgent?

- [x] Quality-of-life (bidirectional drift catches silent rot)
- [ ] Security-critical
- [ ] Correctness
- [ ] Onboarding

## 5. Happy path

```
$ make verify-traceability
→ docs layout (SH-012): pass=15 fail=0
→ caps traceability (SH-013): 43 CAP(s) tracked, 6 tests, 12 story pointers — all resolve
$ echo $?
0
```

## 6. Edge cases / failure modes that matter

- A new acceptance test lands without `# CAPs:` → verify-traceability fails
  with the file path + a copy-paste line to add.
- A CAP is renamed in CAPABILITIES.md but the test still lists the old id →
  verify-traceability lists the unknown CAP id and the file that named it.
- A story moves to `ready` but §9 is still `_template.md`'s placeholder →
  verify-traceability fails with story path + line hint.
- A CAP has no test pointer because the capability is still `design`/
  `aspirational` → verify-traceability accepts it (only `active` CAPs must
  have a pointer, mirroring healthy's rule).
- CHANGELOG.md historical references stay untouched — matches SH-012's
  exclusion of historical records.

## 7. Out of scope

- Converting CAPABILITIES.md to healthy's `### <cap.id>` + `- **Covered
  by**:` section format. Shepherd's existing markdown-table format is kept
  — the parser adapts, not the data.
- Porting beaconry's ~500-line Python traceability check. Minimal 3-rule
  bash first; richer bidirectional check lands as a follow-up if drift
  justifies it.
- Breaking changes to any CAP id. All existing CAP ids stay valid.
- Enforcing `# Spec:` test headers. Component specs are deferred until the
  first one is written.

## 8. Acceptance (Gherkin → test assertions)

```gherkin
Scenario: the verify-traceability script exists and is executable
  Given the repo at HEAD
  Then  scripts/verify-traceability.sh is an executable file

Scenario: happy path — the actual repo passes
  Given the repo at HEAD
  When  scripts/verify-traceability.sh runs
  Then  exit code is 0
  And   stdout shows a summary of CAPs + tests + stories

Scenario: a CAP without a test pointer fails
  Given a fixture CAPABILITIES.md where cap.foo.bar has an empty Test column
  When  scripts/verify-traceability.sh runs on the fixture
  Then  exit code is non-zero
  And   stderr names cap.foo.bar

Scenario: a test referencing an unknown CAP fails
  Given a fixture test with `# CAPs: cap.does.not.exist`
  When  scripts/verify-traceability.sh runs
  Then  exit code is non-zero
  And   stderr names the unknown CAP + the test file

Scenario: a ready+ story without §9 CAP bullets fails
  Given a fixture story with status: ready and no `- \`cap.*\`` bullet
  When  scripts/verify-traceability.sh runs
  Then  exit code is non-zero
  And   stderr names the story file

Scenario: # CAPs header convention aligned with healthy + forge
  Given test/acceptance/test_SH_*.sh
  Then  each file has exactly one `# CAPs:` header
  And   no file has the legacy `# Covers:` header
```

## 9. Capabilities delivered or extended

- `traceability.caps-have-test-pointer` — every CAP row in
  `docs/specs/CAPABILITIES.md` with status `active` names at least one test
  (or an explicit cross-ref). Enforced by `scripts/verify-traceability.sh`.
- `traceability.tests-name-known-caps` — every acceptance test has a
  `# CAPs:` header and names only CAP ids that exist in
  `docs/specs/CAPABILITIES.md`.
- `traceability.stories-name-caps` — every story with status
  `ready|in-progress|shipped` lists ≥ 1 CAP id in §9.
- `traceability.unified-make-target` — `make verify-traceability` runs both
  the SH-012 docs-layout check and the SH-013 caps-traceability check;
  `make check` depends on it. Extends `docs.references.stable` (SH-012).

---

## Plan doc

[`docs/plan/SH-013-caps-traceability-plan.md`](../plan/SH-013-caps-traceability-plan.md).
