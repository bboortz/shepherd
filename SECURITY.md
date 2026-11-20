# Security policy

Shepherd is a bot that opens pull requests, merges some of them automatically, and runs an AI agent against your code. Its trust boundary is the whole product. We take security reports seriously.

Full trust-boundary design: [`docs/DESIGN.md §12`](docs/DESIGN.md).

## What counts as a security issue

High-priority categories — report these first:

1. **Sandbox escape.** The smart-fix agent should run with no network except the locked gateway to the model API, and no secrets of its own. Any path that lets the agent reach the open internet, read a GitHub secret, or execute code outside its sandbox is a security issue.
2. **Budget bypass.** The gateway enforces `€5/day` + `€1/run` by default. Any way to spend past either cap without hitting the ntfy halt is a security issue.
3. **Protected-files breach.** The agent must not touch workflows, secrets, deployment config, or `.shepherd.yml` unless the repo unblocked the path. Unblocking the registration file or shepherd's own workflows must require a human-reviewed change. Any way to modify these paths from a bot-produced diff is a security issue.
4. **Gate bypass.** Required pipelines green, diff ≤50 lines, 24h waiting period, scan-not-worse. If an auto-merge lands with any of those gates not satisfied, that's a security issue.
5. **Prompt-injection leading to any of the above.** A malicious changelog, dependency README, or comment inside a diff that convinces the agent to change its own rules is a security issue.
6. **Needs-human escalation suppressed.** If a failing fix doesn't surface a needs-human issue, the human loses the ability to intervene — that's a security issue.

Normal bug categories (incorrect gate result on a single PR, template typo, confusing error message) are ordinary issues, not security reports.

## How to report

Shepherd is a pre-1.0 personal project without a dedicated advisory channel yet. Until Release 1:

- Open a **GitHub private security advisory** on `bboortz/shepherd` if the repo has that enabled.
- Otherwise, email the owner (`benjamin.boortz@gmail.com`) with `shepherd security` in the subject line.
- Please do **not** open a public issue for a vulnerability.

Once Release 1 ships, this policy will move to a dedicated `SECURITY.md` section with a GPG-signed contact.

## What to expect

- Acknowledgement within 72 hours.
- An initial assessment (confirmed / not reproducing / needs more info) within one week.
- A fix timeline shared on acknowledgement. Agent-sandbox and budget-cap issues are treated as critical.
- A coordinated disclosure window — public release of details happens after the fix is deployed and users of the Action have had a reasonable upgrade window.

## Scope

- **In scope:** this repo, the shepherd Action (once published), the templates it ships into managed repos.
- **Out of scope:** third-party dependencies (file upstream), the Anthropic API itself, your repo's content.

## Attribution

Credit is given in `CHANGELOG.md` and, where appropriate, in the public release notes. Opt out in your report if you prefer anonymity.
