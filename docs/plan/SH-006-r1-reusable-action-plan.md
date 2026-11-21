---
id: SH-006
slug: r1-reusable-action
story: docs/stories/SH-006-r1-reusable-action.md
branch: n/a (umbrella; sub-stories cut their own branches)
status: ready
---

# SH-006 plan — R1 umbrella decomposition

**Story:** [SH-006](../stories/SH-006-r1-reusable-action.md)

R1 is too big for one branch. Breaking it into four sub-stories that each ship independently and gate the next. Order is deliberate: moving the scripts into a reusable Action first (SH-007) unlocks the sandbox and gates work because there's one code site to change instead of three.

## Design delta

R1 lands as four stories in series, with SH-005 (prompt-injection) running in parallel as the pre-R1 security gate.

```
SH-007  ←  move scripts into a reusable Action, migrate the 3 pilots
   ↓
SH-008  ←  sandbox perimeter (network lockdown for the agent step)
   ↓
SH-009  ←  auto-merge gates: .shepherd.yml schema, pipelines-green, diff-size,
            scan-not-worse, security-fix-removes-finding
   ↓
SH-010  ←  waiting-period gate (upstream release-date lookup per ecosystem)
   ↓
SH-006 ships  — all four CAP groups are active, 5 repos soaked for 2 weeks

(parallel)
SH-005  ←  prompt-injection drill — must be green in CI before SH-007 merges
```

### SH-007 — Reusable Action + pilot migration

**Design:**

- Convert `scripts/shepherd-poc/*` into `scripts/shepherd/*` under shepherd.
- Create `.github/workflows/reusable-shepherd.yml` (or `action.yml` composite — decide after one spike). Inputs: `base-branch`, `anthropic-model`, `scope-level`. Secrets: `anthropic-api-key`.
- `templates/caller-shepherd.yml` is the thin caller (≤ 20 lines).
- Each pilot replaces its full workflow + scripts dir with: the caller workflow + optional `.shepherd.yml`.
- SHA-pin the `uses:` from each pilot to a shepherd release tag (`v1.0.0-rc1`, then `v1.0.0`).

**Acceptance (sub-story):**

- All 3 pilots have `scripts/shepherd-poc/` deleted.
- All 3 pilots' caller workflow is ≤ 20 lines + SHA-pinned.
- One live dispatch on each pilot still produces (or declines to produce, for healthy/beaconry) the expected result.
- `bboortz/shepherd/tags/v1.0.0-rc1` exists.

**Alternatives rejected:**

- Composite action (`action.yml`) without a reusable workflow — simpler surface, but loses GitHub's job-level `permissions:` scoping which matters for the sandbox step. Reusable workflow wins for R1.
- Publish to GitHub Marketplace in R1 — defer to R3; R1 is "for you + friendlies only".

### SH-008 — Sandbox perimeter

**Design:**

- Use a dedicated job for the agent step; inside, run the agent-call in a Docker container with `--network=none` + a custom side network that only reaches `api.anthropic.com:443`.
- Alternative: `nsjail` / `bwrap`. Docker is the most portable on `ubuntu-latest`.
- Pre-flight assertion: inside the container, `curl -m 3 https://api.openai.com/` MUST fail. If it succeeds, abort the run (would mean the perimeter didn't apply).
- Post-flight assertion: `/proc/<pid>/net/tcp` audit at the end of the agent step: no connections outside the allowlist.

**Acceptance (sub-story):**

- Live run: openai.com unreachable, anthropic.com reachable (HTTP 401 unauth, which proves the TLS tunnel completed).
- Pre-flight-fail scenario: deliberately break the firewall rules, verify the step aborts.
- Audit log of network connections from the agent step is emitted as a workflow artefact.

**Alternatives rejected:**

- Trust the host-level firewall only — a bug in agent-call.sh could leak before we trust the host. Container-level is defence in depth.
- Full VPN / proxy to Anthropic — overkill for R1; iptables + DNS allowlist is enough.

### SH-009 — Auto-merge gates

**Design:**

- Publish `.shepherd.yml` schema v1 (`templates/shepherd.yml` with every knob documented).
- Four gates, each a shell script under `scripts/shepherd/gates/`:
  - `pipelines-green.sh` — polls `gh pr checks`; pass only if all required checks are `success`.
  - `diff-size.sh` — existing `validate.sh` behaviour, carried forward.
  - `scan-not-worse.sh` — re-run Trivy; diff findings by `(pkg, installed, cve)` tuple; new HIGH/CRITICAL fails.
  - `security-fix-removes-finding.sh` — for PRs labelled `shepherd-security-fix`, require the pre-scan to contain ≥ 1 finding that the post-scan no longer contains.
- Orchestrator: `scripts/shepherd/gates/run-all.sh` — runs all gates, logs pass/fail per gate, exits 0 only if all pass and the repo opts into auto-merge.
- Merge driver: on pass + opt-in, `gh pr merge --merge` (preserves the shepherd-poc commit history; squash would erase the step-by-step commits).
- Soak period: run on ham-radio-compass for 2 weeks; expect ≥ 10 auto-merges, zero broken main.

**Acceptance (sub-story):**

- Each gate has at least one fixture-based test that exercises pass + fail.
- Live soak on ham-radio-compass: one real auto-merge happens from end-to-end.
- Dashboard-like summary: after a soak week, list PRs by gate that blocked them.

**Alternatives rejected:**

- GitHub's own auto-merge feature — doesn't integrate with our scan-not-worse gate; we'd be double-gating. Native + ours in sequence is a redundancy we can afford, but our gates must still exist as the authoritative source.
- Separate `shepherd-merge-bot` workflow — single orchestrator is simpler.

### SH-010 — Waiting-period gate

**Design:**

- `scripts/shepherd/gates/waiting-period.sh` — resolves the new dep's upstream release date per ecosystem, compares against now, exits non-zero if < 24h (configurable).
- Ecosystem adapters:
  - npm: `curl https://registry.npmjs.org/<pkg>` → `.time[<version>]`.
  - PyPI: `curl https://pypi.org/pypi/<pkg>/<version>/json` → `.urls[0].upload_time_iso_8601`.
  - Go: `curl https://proxy.golang.org/<pkg>/@v/<version>.info` → `.Time`.
  - Docker: `curl https://registry.hub.docker.com/v2/repositories/<pkg>/tags/<version>` → `.last_updated`.
  - Unknown ecosystem: fail-open (warn, don't block).
- Cached per-run: no need to hit the registry on every gate pass.

**Acceptance (sub-story):**

- Fixture: PR for a dep released 2 hours ago → gate blocks with clear bot comment.
- Fixture: PR for a dep released 25 hours ago → gate passes.
- Fixture: PR for a dep from an unsupported ecosystem → gate passes with "unknown ecosystem" log.

**Alternatives rejected:**

- Treat the PR's `created-at` as the waiting-period anchor — doesn't reflect the design intent ("24h since the new version's release date, not the PR"). Would also let an attacker push a malicious version and have the gate clear in 24h even if we caught it the same hour.

## Alternatives rejected (R1 umbrella)

| Alternative | Why not |
|---|---|
| Ship R1 as one giant branch | Reviewability + bisectability; 4 narrower sub-stories have 4 narrower risk envelopes. |
| Skip the auto-merge gates (open PRs only in R1, auto-merge in R2) | Then R1 doesn't differ from R0 in the user-visible shape. Auto-merge is the headline. |
| Skip the sandbox (document as "R2 gap") | The sandbox is the trust-boundary promise the launch story makes. Shipping R1 without it would be dishonest. |
| Build a `shepherd` binary in Zig (like shepherd-bump) for the whole Action | Interesting for size but doesn't match where the complexity actually is (gh API + registry adapters). Shell + minimal JSON stays agile. R2 can revisit. |

## Breaking changes

- [x] **Yes** — pilots' `shepherd-poc.yml` is replaced by a `shepherd.yml` caller workflow. Rename + path change. Operator action required at each pilot.
- [x] **Yes** — `.shepherd.yml` schema v1 is introduced. The template in `templates/shepherd.yml` is already in place; it becomes **the** schema under R1 and future edits require a story.
- [x] **Yes** — labels standardised: `shepherd-managed`, `shepherd-poc` (kept for history), `shepherd-security-fix` (new), `shepherd-hold` (new).

## Rollout

- [ ] SH-005 green in CI (prompt-injection drill is a precondition).
- [ ] SH-007 ships: reusable Action published at `v1.0.0-rc1`.
- [ ] 3 pilots migrated; their old workflows + scripts deleted.
- [ ] SH-008 ships: sandbox perimeter live; pre-flight-fail scenario green.
- [ ] SH-009 ships: at least one real auto-merge on ham-radio-compass.
- [ ] SH-010 ships: waiting-period gate blocks a same-day CVE auto-merge in the live soak.
- [ ] 2-week soak: 5 repos (the 3 pilots + 2 friendly outsiders), ≥ 10 auto-merges, zero broken `main` branches.
- [ ] Setup timed: fresh repo → first dispatch in ≤ 15 minutes.
- [ ] `v1.0.0` tag on shepherd; `docs/FLEET.md` repos' release-line column reads "R1".

## Shipping evidence

Rolls up from sub-story Shipping Evidence tables. Filled when each sub-story ships.

## Post-merge notes

<To fill after R1 ships (expected Fri 4 Dec 2026 per DESIGN §13). Named insights from R0 to re-check: lockfile size cap (path-aware already), LLM file hallucination (hybrid flow preserved), hunk-line-count errors (--recount default), Actions-PR permission (now set during SH-007 onboarding migration), deterministic top-1 picker (keep).>
