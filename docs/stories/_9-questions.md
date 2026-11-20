*The nine canonical clarification questions asked for every new story in `shepherd`. Copy these into `docs/stories/SH-NNN-<slug>.md` before promoting to `ready`.*

1. **Who** is the consumer in this moment?
   Repo owner onboarding a repo / maintainer reviewing a bot PR / operator triaging a
   needs-human issue / smart-fix agent operator setting budgets / contributor extending
   Shepherd itself. Pick one. If more than one, split the story.

2. **When** does the story fire?
   Scheduled fleet pass (discover / renovate / digest) / PR opened by the bot /
   needs-human escalation received / `.shepherd.yml` change proposed / budget cap hit.

3. **What** does success look like?
   Observable outcome. PR opened with a specific label, issue created with a specific
   structure, exit code of the Action, ntfy note sent, protected-file block enforced.
   Must be mechanically checkable — a human judgement call doesn't belong here.

4. **How urgent?** Impact tier:
   - security-critical (sandbox escape, budget bypass, protected-file breach)
   - correctness (gate wrongly passes/fails, dedupe miss, wrong exit code)
   - quality-of-life (clearer needs-human template, better dry-run message)
   - onboarding (shrinks the 15-minute setup budget)

5. **Happy path** — exact branch state, `.shepherd.yml`, CVE or dep bump, expected PR/
   issue/comment, expected exit code?

6. **Edge cases / failure modes** that matter?
   Agent hits budget mid-run, Trivy flags an unfixable HIGH, verify pipeline renamed in
   managed repo, prompt-injection in changelog, existing needs-human issue (dedupe), …

7. **Out of scope** — what could creep in but shouldn't?
   Default-out: macOS/Windows runners, forges besides GitHub, model providers besides
   Anthropic, hosted service, mandatory GitHub App. If this story relaxes a default,
   say so explicitly.

8. **How do we know it's done?** Acceptance = Gherkin.
   Every Scenario encodes as one or more test assertions against the Action (location
   follows the test harness, lands with R1).

9. **What capabilities does this story deliver or extend?**
   Name new CAP ids; link to existing ones. The capability matrix
   (`docs/CAPABILITIES.md`) is the source of truth — update it in the same PR.
