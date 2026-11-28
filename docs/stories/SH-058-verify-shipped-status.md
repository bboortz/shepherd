---
id: SH-058
slug: verify-shipped-status
status: shipped        # draft → ready → in-progress → shipped
created: 2026-11-28
owner: @benni
---

# SH-058 — `verify-shipped-status`: a released story must be marked shipped

## 1. Who is the consumer?

The **contributor** maintaining Shepherd's own docs traceability. SH-056's
`verify-index-status` keeps `INDEX.md` and story frontmatter *in agreement* —
but it cannot tell when they agree on the **wrong** value. SH-056 itself proved
the gap: it shipped in `v0.10.1-rc1`, yet both its INDEX row and frontmatter sat
at `in-progress` for days, mutually consistent, so the checker stayed silent.

## 2. When does the story fire?

Every `make check` / pre-push / `ci-branch` — the same commit-time docs gate
that runs `verify-index-status`. It reads the repo's own `CHANGELOG.md` and
`docs/stories/`, no network.

## 3. What does success look like?

`scripts/verify-shipped-status.sh` fails when a story that a **released**
CHANGELOG version heading names is not `status: shipped`. Concretely: for each
`## [vX.Y.Z] …` heading (the `[Unreleased]` section is exempt), every `SH-NNN`
token with a matching `docs/stories/SH-NNN-*.md` must have frontmatter
`status: shipped`. Exit 0 clean, exit 1 on any violation naming the story and
the version that released it. No-ops when `CHANGELOG.md` is absent.

Mechanically checkable, deterministic, offline. Wired into `check-docs` so it
rides the existing docs gate.

## 4. How urgent?

- [ ] Security-critical
- [x] Correctness (closes a real blind spot in the traceability gate — a shipped
      story silently stuck at `in-progress` misreports project state)
- [x] Quality-of-life (catches the drift at commit time, not at audit time)
- [ ] Onboarding

## 5. Happy path

```
$ make verify-shipped-status
verify-shipped-status: ok (every CHANGELOG-released story is shipped)
$ echo $?
0

# After a story ships in CHANGELOG but its frontmatter wasn't flipped:
$ make verify-shipped-status
verify-shipped-status: SH-056 released in v0.10.1-rc1 but frontmatter status='in-progress'
verify-shipped-status: released stories must be status: shipped; flip the frontmatter + INDEX.
$ echo $?
1
```

## 6. Edge cases / failure modes that matter

- **`[Unreleased]` section** — a story named only under `[Unreleased]` is NOT
  required shipped (it's in flight). Only `## [vX.Y.Z]` headings count.
- **SH-NNN with no story file** — a heading may name a story that lives in
  another repo or predates the stories dir; skip it, don't fail.
- **Slash-abbreviated lists** (`SH-012/013/016`) — only the fully-prefixed
  token (`SH-012`) is checked; the bare suffixes are intentionally ignored
  (conservative — no false positives).
- **Same story in several headings** — checked once; duplicates don't multiply
  errors.
- **`CHANGELOG.md` absent** — no-op exit 0 (symmetric with `verify-index-status`
  when INDEX is absent), so the script is portable to repos without one.

## 7. Out of scope

- No scan of released-section **bodies** — only the version heading line. Bodies
  mention follow-ups and related stories that may legitimately be unshipped;
  heading = what that version delivered.
- No git-tag cross-check (a heading-vs-tag consistency check is a possible
  follow-up; this story trusts the CHANGELOG headings).
- No auto-fix — it reports; the human flips the status (one-line docs change).
- No new forge / OS / model provider.

## 8. Acceptance (Gherkin → test assertions)

```gherkin
Scenario: script exists and is executable
  Then scripts/verify-shipped-status.sh is present and +x

Scenario: shepherd itself passes (dogfood)
  When scripts/verify-shipped-status.sh runs in this repo
  Then it exits 0 with an "ok" message

Scenario: a released-but-unshipped story fails
  Given a story named in a `## [vX]` heading is flipped to in-progress
  When the script runs
  Then it exits 1 naming the story and the version

Scenario: the [Unreleased] section is exempt
  Given a fixture CHANGELOG naming SH-999 only under [Unreleased]
  And   story SH-999 has status in-progress
  Then the script exits 0

Scenario: a heading-named story with no file is skipped
  Given a fixture CHANGELOG `## [v1]` heading names SH-998 with no story file
  Then the script exits 0

Scenario: Makefile exposes verify-shipped-status and check-docs runs it
  Then `make -n verify-shipped-status` invokes the script
  And  check-docs depends on verify-shipped-status
```

The acceptance test is `test/acceptance/test_SH_058_verify_shipped_status.sh`.

## 9. Capabilities delivered or extended

- `dev-cycle.verify-shipped-status` — `scripts/verify-shipped-status.sh` asserts
  every story named in a released `CHANGELOG.md` version heading has frontmatter
  `status: shipped`; closes the `verify-index-status` blind spot where INDEX and
  frontmatter agree on a stale status. Wired into `check-docs`. No-ops without a
  CHANGELOG.

New CAP id goes into `docs/specs/CAPABILITIES.md` in this PR, bidirectionally
linked to the acceptance test.

---

## Plan doc

[`docs/plan/SH-058-verify-shipped-status-plan.md`](../plan/SH-058-verify-shipped-status-plan.md).
