---
id: SH-NNN
slug: short-kebab
status: draft        # draft → ready → in-progress → shipped
created: YYYY-MM-DD
owner: @benni
---

# SH-NNN — <one-line title>

## 1. Who is the consumer?

<Repo owner onboarding a repo to Shepherd / maintainer reviewing a bot-opened PR /
operator triaging a needs-human issue / smart-fix agent operator setting budgets /
contributor extending Shepherd itself. Pick one. If more than one, split the story.>

## 2. When does the story fire?

<Scheduled fleet pass (discover / renovate / digest) / PR opened by the bot /
needs-human escalation received / `.shepherd.yml` change proposed / budget cap hit / …>

## 3. What does success look like?

<Observable outcome. PR opened with a specific label, issue created with a specific
structure, exit code of the Action, ntfy note sent, protected-file block enforced.
Must be mechanically checkable — a human judgement call doesn't belong here.>

## 4. How urgent?

- [ ] Security-critical (sandbox escape, budget bypass, protected-file breach)
- [ ] Correctness (gate wrongly passes/fails, dedupe miss, wrong exit code)
- [ ] Quality-of-life (clearer needs-human template, better dry-run message)
- [ ] Onboarding (shrinks the 15-minute setup budget)

## 5. Happy path

```
<Exact sequence. Branch state, .shepherd.yml content, the CVE or dep bump at hand,
the bot's output, the resulting PR / issue / comment. Include expected exit code.>
```

## 6. Edge cases / failure modes that matter

- <Agent hits budget mid-run (per-run and per-day cases)>
- <Trivy flags a HIGH that becomes unfixable (needs-human path)>
- <A verify pipeline is renamed in the managed repo (gate.pipelines-green behaviour)>
- <A changelog contains prompt-injection payload (sandbox invariant holds)>
- <An existing needs-human issue is already open for the same problem (dedupe)>
- <…>

## 7. Out of scope

<Default-out items: macOS/Windows runners, forges other than GitHub, model providers
other than Anthropic, hosted service, mandatory GitHub App. If this story relaxes one
of those defaults, say so explicitly.>

## 8. Acceptance (Gherkin → test assertions)

```gherkin
Scenario: <name>
  Given <precondition — repo state, .shepherd.yml, scan findings>
  When  <invocation of shepherd — scheduled run, Action trigger, workflow_dispatch>
  Then  <observable: PR opened / issue created / budget note / exit code>

Scenario: <second>
  …
```

The acceptance test's location follows the test harness (lands with R1). The script
encodes each Scenario as one or more assertions against the Action.

## 9. Capabilities delivered or extended

- `cap.id.name` — <one-line description; new or extended>
- …

New CAP ids go into `docs/CAPABILITIES.md` in the same PR. Every CAP needs a
bidirectional link to its acceptance test (`make verify-traceability` enforces this
from R1 onward).

---

## Plan doc

Lives at `docs/plan/SH-NNN-<slug>-plan.md`. Created when the branch is cut (status
`ready → in-progress`). Captures the design delta, alternatives rejected, breaking
changes, rollout, and — at step 6a — the Shipping evidence table.
