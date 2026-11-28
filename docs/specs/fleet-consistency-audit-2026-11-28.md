# Fleet arming audit — 2026-11-28

Scope: the shepherd core repo plus all six "armed" (managed) repositories in
`docs/FLEET.md`. Question answered: **is every listed repo actually, fully
armed** — opt-in topic, config, caller workflows, Dependabot baseline, the
agent secret, and a live cron? Method: read-only `gh` + `git` against the real
GitHub state on each repo's `dev` branch (not FLEET.md's claims).

**Verdict: 3 of 6 repos are fully armed; 3 are half-armed.** No repo is broken,
but `homelab`, `kernel-test`, and `forge` are missing the `shepherd-managed`
topic *and* still in `dry_run`, so they are not valid fleet members under the
opt-in contract and the agent does nothing on them yet. The whole fleet is also
pinned ~3 minor releases behind current shepherd.

---

## Arming matrix

Legend: ✓ present / green · ✗ missing · ⚠ present but inactive

| Repo | Topic | `.shepherd.yml` | dependabot | Makefile | shepherd caller | gates caller | automerge | `ANTHROPIC_API_KEY` | shepherd cron | `dry_run` |
|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| `bboortz/healthy` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ green | live |
| `bboortz/beaconry` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ green | live |
| `bboortz/ham-radio-compass` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ green | live |
| `bb-claw/homelab` | **✗** | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ green | **⚠ true** |
| `bb-claw/kernel-test` | **✗** | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ green | **⚠ true** |
| `bboortz/forge` | **✗** | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ green | **⚠ true** |

All six share one reusable-Action pin: `a0733f7` for both the `shepherd` and
`shepherd-gates` callers. `dependabot-automerge.yml` is a local pure-`gh`
workflow on every repo (no reusable pin) — **correct**, this matches SH-011's
"no `fetch-metadata` action" decision, not a gap.

---

## Findings

### F1 — HIGH · Three repos carry no `shepherd-managed` topic

`homelab`, `kernel-test`, and `forge` have `repositoryTopics: null`.
`gh search repos --owner bb-claw --topic shepherd-managed` returns `[]`.

The opt-in contract (`FLEET.md` line 3, `DESIGN §2`) requires a repo to be
**both** listed in FLEET.md **and** carry the topic. These three satisfy only
half. Consequences:

- They are **not valid fleet members** by the project's own definition.
- After R3, discovery moves to topic search — these repos become **invisible**
  to it. The migration from "FLEET.md is the registry" to "topic search is the
  registry" would silently drop them.
- FLEET.md's own Verification block (`gh search repos … topic:shepherd-managed`)
  is advertised to "match the Active section." It does not — a drift the file
  says should be "the next candidate PR."

### F2 — MEDIUM · Whole fleet pinned ~3 minor releases behind

Every caller pins `a0733f789845723b17afa5181d23c1f1fbcce058`. That commit is
`Merge PR #20 fix/open-pr-body-diff-size` — it predates tag `v0.7.1-rc1` and is
**84 commits** behind current `main`. Shepherd's `VERSION` is now
`0.10.2-rc1`.

- FLEET.md claims the fleet runs **"v0.7.0-rc1"** — there is no such tag
  (the tag list jumps `v0.7.1-rc1` → `v0.8.0-rc1`). The real pin is an
  **untagged raw SHA**, roughly v0.7.0-era.
- SHA-pinning itself satisfies §12 (mutable tags are forbidden), so the
  *mechanism* is fine — but the fleet is stuck pre-SH-014/SH-017, i.e. **before
  the dev-cycle contract and `--verify-contract` enforcement shipped** (0.8–0.10).
  The pilots were onboarded with contract Makefiles the running Action can't yet
  verify.

### F3 — MEDIUM · Pilots 4–6 still in `dry_run` after a week of green cycles

`homelab`, `kernel-test`, and `forge` were onboarded 2026-11-21 with
`dry_run: true` "for the first cycle." Seven days later all three have **green
`shepherd` schedule runs** (homelab 11-27, kernel-test 11-27, forge 11-28), yet
all three are still `dry_run: true`. The onboarding principle is dry-run-first,
**flip after the first clean cycle** — that cycle has happened. The agent is
therefore reporting-only on these repos; they contribute nothing to the R1 soak
beyond proving the clean-exit path. Combined with F1, they are half-armed on two
axes at once.

### F4 — LOW · FLEET.md "TODO" is stale (already done)

FLEET.md line 20: *"TODO before pilots 4–6 go live: set `ANTHROPIC_API_KEY`…"*.
Verified set on **all six** repos. The TODO is complete and should be removed so
it stops reading as outstanding work.

### F5 — LOW · FLEET.md header drift

The "Active" preamble (line 9) states the wrong version string ("v0.7.0-rc1",
see F2), and the matrix does not reflect that the three bb-claw/forge pilots
never got the topic. The header reads as "six-repo fleet, all armed" when the
real state is "three fully armed, three half-armed."

### F6 — INFO · Managed repos' own CI is red (not shepherd's doing)

Surfaced while reading run history, outside shepherd's arming but worth an
owner's eyes:

- `bboortz/forge` — `ci-nightly` **failing** (latest 2026-11-28 02:32).
- `bb-claw/homelab` — one `Dependabot Updates` job **failing** (2026-11-28 04:02).

These are the managed repos' pipelines, not shepherd workflows. But a healthy
fleet shouldn't have red nightlies sitting unaddressed — this is exactly what
the weekly digest / needs-human path is meant to catch, so a secondary question
is *why these haven't been escalated.*

---

## Recommendations

Ordered by impact. Commands are copy-paste ready.

### 1. Arm the three half-armed repos (closes F1 + F3)

Add the topic, then — after confirming the next scheduled run is green in
non-dry mode — flip `dry_run`.

```sh
# Topic (forge is on your bboortz token; the two bb-claw repos need a bb-claw token)
gh repo edit bboortz/forge     --add-topic shepherd-managed
gh repo edit bb-claw/homelab   --add-topic shepherd-managed
gh repo edit bb-claw/kernel-test --add-topic shepherd-managed

# Then, per repo, in .shepherd.yml on dev: dry_run: true -> false  (small PR each)
```

Note: the current `gh` session is authenticated as **bboortz**. Editing the two
`bb-claw` repos needs a token with access to that account — do those two from a
bb-claw-scoped session or confirm the bboortz token has org rights.

### 2. Re-pin the fleet to a current tagged release (closes F2)

Bump all callers from `a0733f7` to the SHA of `v0.10.2-rc1` (or whichever tag
the next soak targets), in one coordinated pass. This is a `chore/` change per
repo touching `.github/workflows/{shepherd,shepherd-gates}.yml`. Benefits:
brings SH-017 `--verify-contract` into the loop so the contract Makefiles the
pilots already carry actually get verified. Pin to the **tagged** SHA, not a
floating one, and record the tag next to the SHA in a comment.

### 3. Correct FLEET.md drift (closes F4 + F5)

One `docs/` PR: remove the completed `ANTHROPIC_API_KEY` TODO, fix the version
string to the real pinned tag, and mark the three pilots' topic/`dry_run` state
honestly until recommendation 1 lands. FLEET.md's own rule says a topic↔Active
mismatch "is the next candidate PR" — this is that PR.

### 4. Investigate the two red pipelines (F6)

Triage `forge` `ci-nightly` and the `homelab` Dependabot job. Separately, ask
why a week of red nightlies didn't produce a needs-human issue — if the digest
path is meant to surface fleet health, this is a gap in that path, not just two
broken builds.

### 5. Consider a standing reconciliation check

F1 and F5 are the same class of bug: FLEET.md (the registry) drifted from
GitHub reality with nothing to catch it. The "automated reconciliation against
the topic" is parked for the post-R3 fleet layer, but a lightweight CI check now
— assert every Active-table repo returns from the topic search — would have
caught all three missing topics the day they were onboarded. Worth an IDEAS
entry if not already there.

---

## Appendix — evidence

- Topics: `gh repo view <r> --json repositoryTopics` → null on homelab,
  kernel-test, forge; present on the three bboortz public repos.
- Topic search: `gh search repos --owner bb-claw --topic shepherd-managed` → `[]`.
- Files (all six, `dev`): `.shepherd.yml`, `.github/dependabot.yml`, `Makefile`,
  `.github/workflows/{shepherd,shepherd-gates,dependabot-automerge}.yml` all present.
- Secret: `gh secret list -R <r>` shows `ANTHROPIC_API_KEY` on all six.
- Pin: `a0733f7` on all callers; `git describe` → no tag; contained in
  `v0.7.1-rc1`+; 84 commits behind `origin/main`; `VERSION` = `0.10.2-rc1`.
- Crons: last `shepherd` schedule run green on all six (homelab 2026-11-27,
  kernel-test 2026-11-27, forge 2026-11-28, bboortz trio 2026-11-28).
- Red own-CI: forge `ci-nightly` 2026-11-28; homelab `Dependabot Updates` 2026-11-28.
