# Shepherd: design draft

Zero-effort operations: a central bot that keeps registered repos and devices patched, verified and healthy. The human only handles exceptions.

Status: draft. Release 0 (POC) is in progress. Sections 1 to 11 describe the original fleet design. Section 13 supersedes the phases in section 10 for the first public version.

## 1. Repository

- **Name:** bboortz/shepherd
- **Description:** Central fleet bot: auto-onboards repos, bumps dependencies, fixes CVEs, verifies builds and tests, escalates only critical decisions.
- **Topic to set on the repo:** `shepherd-core`
- **Topic that registers any other repo:** `shepherd-managed`
- **Bot identity:** one GitHub App named `shepherd-bot` with permissions: contents write, pull requests write, issues write, workflows write, metadata read, security events read, and Dependabot alerts read. Install it on all repos of the bboortz account.
- **Secrets in the shepherd repo:** `SHEPHERD_APP_ID`, `SHEPHERD_APP_PRIVATE_KEY`, `NTFY_TOPIC_URL`, `ANTHROPIC_API_KEY` (only needed for the smart fix layer, phase 3).

## 2. Layout of the repo

```text
shepherd/
  README.md
  bump.zig                 # first-party bump engine, Zig single-file (SH-001)
  build.zig                # Zig build
  policy/
    default.yml            # global rules: what may auto-merge, quiet hours
    repos/                 # optional per-repo overrides
  .github/workflows/
    discover.yml           # finds tagged repos, opens onboarding PRs
    bump.yml               # runs shepherd-bump on cron (SH-001)
    digest.yml             # weekly digest to ntfy
    reusable-verify.yml    # reusable workflow every repo calls
  templates/
    shepherd.yml           # registration file copied into each repo
    caller-verify.yml      # tiny workflow copied into each repo
  docs/
    needs-human.md         # template for escalation issues
```

## 3. Registration file (lives in each managed repo as `.shepherd.yml`)

```yaml
version: 1
risk: low            # low | medium | high
build: make build
test: make test
auto_merge:
  patch: true
  minor: true
  major: false
security_fix: pr-only  # pr-only | auto-merge-low-risk
notify: ntfy
owner: benni
```

Risk levels: **low** means patch and minor bumps auto-merge once CI is green. **medium** means only patch auto-merges. **high** means nothing auto-merges, everything goes to the human queue.

## 4. Bump engine (`shepherd-bump`, SH-001)

Shepherd runs its own bump engine. The previous plan to use Renovate is retired
(see [SH-001](stories/SH-001-retire-renovate.md)) because no third-party
GitHub Action belongs in the fleet's critical path (§12). The engine is a Zig
single-file binary, built from `bump.zig`, with no runtime dependencies.

- **Language:** Zig (pinned to the same version as `healthy`).
- **Layout:** single source file `bump.zig` at repo root; splits only when a
  measured constraint forces it.
- **Ecosystems:** GitHub Actions first (SH-001). npm, pip, Go, Docker images and
  Zig itself follow in separate stories.
- **Discovery for `gh-actions`:** parse `uses: owner/repo@<sha>  # vX.Y.Z` lines in
  `.github/workflows/*.yml` and `.github/actions/**/action.yml`.
- **Version source:** `GET /repos/{owner}/{repo}/tags` → highest tag within the
  pinned major. Annotated tags are dereferenced to the underlying commit SHA.
- **Output:** one PR per bumpable dep against `dev`, labelled `shepherd-bump`
  and `<ecosystem>`. Orphaned pins (upstream tag deleted or force-pushed) open a
  needs-human issue instead.
- **Policy defaults:** stay within the current major; patch and minor bumps are
  eligible for auto-merge subject to the §12 gates; major bumps are needs-human.
- **Config:** no shared preset file. Per-repo overrides live in `.shepherd.yml`
  (future stories expose the knobs that matter).

## 5. Caller workflow in each managed repo (`.github/workflows/shepherd-verify.yml`)

```yaml
name: shepherd-verify
on:
  pull_request:
  workflow_dispatch:
jobs:
  verify:
    uses: bboortz/shepherd/.github/workflows/reusable-verify.yml@main
    secrets: inherit
```

The reusable workflow reads `.shepherd.yml`, runs the build and test commands, runs a Trivy filesystem scan, and fails the check if there is a fixable HIGH or CRITICAL finding.

## 6. Discovery workflow (`discover.yml`), in words

- Trigger: nightly schedule plus manual dispatch.
- Create an installation token from the GitHub App.
- List all repos in the org with the topic `shepherd-managed`.
- For each repo without `.shepherd.yml`, open a branch `shepherd/onboard`, copy in `.shepherd.yml` and the caller workflow, and open a PR titled "Onboard to Shepherd".
- For repos that lost the topic, open an issue suggesting offboarding. Never delete anything automatically.

## 7. Bump workflow (`bump.yml`), in words

- Trigger: daily schedule (04:00 UTC) plus manual dispatch.
- Checks out the shepherd repo, runs `make build` to produce `bin/shepherd-bump`,
  then invokes `./bin/shepherd-bump --ecosystem gh-actions` against the target
  repo(s).
- Authenticated with `SHEPHERD_BUMP_TOKEN` — a fine-grained PAT scoped to the
  target repo(s) with `Contents: write`, `Pull requests: write`, `Issues: write`.
  No GitHub App on the default path (§13).
- Fleet-wide bump (autodiscovery by `shepherd-managed` topic) activates with the
  fleet layer after Release 3. Until then, `bump.yml` only operates on the
  shepherd repo itself (dogfood).

## 8. Escalation template (`docs/needs-human.md`)

Every needs-human issue or PR contains: what happened in one sentence, what the bot tried, what was tested and the result, the risk, the bot's recommendation, and the exact one-step actions available (approve, reject, comment with instruction).

## 9. Policy file (`policy/default.yml`)

```yaml
auto_merge_default:
  patch: true
  minor: true
  major: false
always_human:
  - major-version
  - cve-without-fix
  - failed-rollback
  - data-migration
quiet_hours: "22:00-07:00 Europe/Berlin"
page_immediately:
  - critical-cve-no-fix
  - rollback-failed
  - ladder-exhausted
digest: weekly
```

## 10. Rollout phases

1. **Phase 1 – Foundation:** create repo, GitHub App, secrets, shared Renovate preset, reusable verify workflow. Onboard one pilot repo, for example `bboortz/healthy`.
2. **Phase 2 – Fleet:** discovery workflow, topic-based onboarding, ntfy notifications, weekly digest.
3. **Phase 3 – Smart fixes:** Claude Code job in a sandbox for fixes Renovate cannot do. Opens PRs only, never merges on its own.
4. **Phase 4 – Devices:** connect the host side: pull-based apply, snapshots, rollback, and monitoring feeding the Shepherd dashboard.

## 11. Setup checklist

1. Create `bboortz/shepherd` as a public repo.
2. Create the GitHub App `shepherd-bot`, install it on the org, store its ID and private key as secrets.
3. Create an ntfy topic and store its URL as a secret.
4. Add the files from sections 3 to 9.
5. Tag one pilot repo with `shepherd-managed` and run discovery manually.
6. Watch the first onboarding PR and the first `shepherd-bump` PR go through.

## 12. Trust boundary (decisions so far)

The bot may only merge on its own where a repo allows it, and only when every gate below passes. All values are defaults and can be overridden per repo in `.shepherd.yml`.

**Auto-merge permission**

- Configurable repository by repository. Without it, the bot only opens PRs.

**Auto-merge gates**

- **Required pipelines:** every configured build and test pipeline is green. The list of monitored pipelines is configurable per repo.
- **Diff size:** at most 50 changed lines per PR by default.
- **Waiting period:** 24 hours by default, counted from the release date of the new version, not from the PR. Can be increased or disabled.
- **Scan not worse:** no new findings compared to the base branch. Default scope is high and critical findings only. Can be widened to all findings. A PR labelled as a security fix must also remove at least one finding.

**Smart fix agent**

- Runs with no network access and no secrets of its own. It can only read the repo checkout and produce a diff. A separate trusted step commits the diff and opens the PR.
- Reaches the Claude API only through one locked gateway. A local model was considered and rejected for now because it fixes code less well.
- The gateway enforces a hard budget: 5 euros per day by default, configurable. A per-run cap of 1 euro applies by default, also configurable. Hitting either cap stops the run and sends an ntfy note.

**Path blocklist**

- By default the agent may not touch workflows, secrets, deployment config, or the Shepherd registration file, so it cannot change its own rules.
- Each repo can unblock specific paths.
- Planned safeguard: the registration file and the workflows that run the bot can only be unblocked through a human-reviewed change, never by the bot or by a setting the bot can edit.

**Failed fixes**

- When a fix fails verification, the agent gets the error output and retries 3 times by default, configurable per repo.
- After the last failed attempt, or whenever the bot needs human help, it always opens a needs-human issue in the repo, for security fixes and routine bumps alike. There is no quiet logging.
- If a needs-human issue for the same problem is already open, the bot comments on it instead of opening a duplicate.

**Supply chain (SH-001)**

- **No third-party GitHub Actions in shepherd's critical path.** Exceptions: GitHub-native `actions/*` and the Trivy install step, SHA-pinned only. Reason: CVE-2026-33634 (TeamPCP, March 2026) proved mutable-tag attacks on `aquasecurity/trivy-action` are live — the same vector applies to any third-party Action with commit authority.
- **First-party bump engine.** Dependency bumps are produced by `shepherd-bump` (Zig, single file, no runtime deps) running inside the shepherd workflow. Renovate and similar services are not in the trust base. Dependabot remains useful as a second-opinion signal for CVE surfacing but is not on the critical path.
- **SHA-pin all `uses:` lines.** Every `uses: owner/repo@...` reference in `.github/workflows/*.yml` and `.github/actions/**/action.yml` resolves to a 40-character commit SHA. Mutable tag refs fail verification (a lint from Release 1 onward).
- **Orphaned pins fail loud.** When `shepherd-bump` finds a pinned SHA that no longer resolves to any upstream tag (force-pushed or deleted), it opens a needs-human issue; it does not silently rewrite.

**Fix scope levels**

What the bot may fix automatically is configurable per repo. The default is level 1.

1. Version bumps and lockfiles.
2. Dependency fixes that need small code changes, such as an API change after an upgrade.
3. General source code fixes for security findings.
4. Pipelines and workflows. This always needs a human-reviewed approval, because of the protected-files rule.

## 13. Release plan: Release 0 to Release 3

This plan supersedes the phases in section 10 for the first public version. Four releases, each with a clear scope and exit criteria. The fleet layer and device side move to after Release 3.

**Goal:** 100 GitHub stars within three months of launch, plus 20 open issues with feedback from other people.

**Sharp pitch (draft):** An AI agent that fixes your vulnerable dependencies inside a locked sandbox, with a hard budget and a protected-files list. One workflow file, one secret, 15 minutes.

**Design principles for onboarding**

- Onboarding in 15 minutes: copy one workflow file, add one secret, push.
- No GitHub App on the default path. Use the built-in `GITHUB_TOKEN` or a fine-grained token. The App is an advanced option later.
- No central repo and no hosted service at the start. One repo, one file, one secret (the Claude API key).
- The gateway is built into the action: network locked to the model API only, budget cap enforced inside it.
- Zero config by default. The config file is optional, defaults are the ones already decided.
- Notifications through GitHub itself (needs-human issues). ntfy is optional and comes later.
- Dry-run mode is the first experience: the bot comments what it would fix and changes nothing.

### Release 0: POC

**Purpose:** prove the core idea works on one real repo, for you only. No polish.

**In scope**

- A single workflow in `bboortz/healthy` that reads vulnerability findings from a scan (Trivy).
- The sandboxed agent step: no secrets, no network except the model API, produces a diff only.
- A separate trusted step that applies the diff on a branch and opens a PR.
- Verification: the repo's own build and test pipelines run on that PR.
- Hard-coded defaults: 50 lines max, 3 retries, 1 euro per run, level 1 (dependencies and lockfiles only).

**Out of scope:** config file, auto-merge, waiting period, other repos, notifications, docs.

**Exit criteria**

- At least 3 real vulnerable-dependency fixes produced as PRs in healthy, with green pipelines.
- One deliberate prompt-injection test (a malicious changelog or comment) shows the agent cannot leak anything or change protected files.
- You can state in one sentence why this beats plain Renovate.

### Release 1: MVP 1 (usable by you, safe by default)

**Purpose:** make it a reusable GitHub Action with the safety gates, still only for your own repos.

**In scope**

- Packaged as a reusable GitHub Action in `bboortz/shepherd`, used by a copied caller workflow.
- Optional `.shepherd.yml` with per-repo overrides for the existing defaults.
- Dry-run mode, on by default for the first run.
- Gates: required pipelines green, diff size limit, scan not worse (high and critical by default), retries.
- Path blocklist enforced by the trusted step, so the agent cannot change its own rules.
- Budget caps: 5 euros per day and 1 euro per run, enforced in the action.
- Needs-human issues with the agreed template, comment instead of duplicates.
- Auto-merge switch per repo, off by default, plus the 24-hour waiting period counted from the release date.
- Used on 3 of your own repos, including `healthy`.

**Out of scope:** discovery of repos, central bot, GitHub App, ntfy, device monitoring, scope levels above 1.

**Exit criteria**

- 3 repos run for 2 weeks without you touching the bot except for needs-human issues.
- At least 10 merged fixes, zero broken main branches.
- Setup measured at under 15 minutes on a fresh repo by following the draft README.

### Release 2: MVP 2 (ready for strangers)

**Purpose:** make it understandable and safe for people who are not you, and test it with a few friendly outside users before going public.

**In scope**

- README with the sharp pitch, a 15-minute quickstart, and a short "why not just Renovate?" section.
- A demo repo with real fixed CVEs, visible PRs and a recorded run, so the value is clear in a minute.
- Security documentation: the trust boundary, sandbox design, budget caps, protected files, and an honest threat model. This is the main differentiator and the story for the launch post.
- Configurable fix scope levels 1 to 3 per repo, with level 4 behind human-reviewed approval.
- Configurable gate settings fully documented: monitored pipelines, diff size, waiting period, scan scope, retries, budgets.
- Issue templates for bug reports and feedback, a contributing guide, and a security policy.
- Support for the most common ecosystems first. Proposal: npm, pip and Docker. Final list is still open.
- 5 friendly testers run it on their own repos, and their friction points are fixed.

**Out of scope:** central fleet bot, discovery, GitHub App, device monitoring, dashboards.

**Exit criteria**

- 5 outside users completed the quickstart in under 15 minutes without help.
- No open security issue in the sandbox or path-blocklist design.
- Launch post and demo are reviewed and ready.

### Release 3: 1.0 (public launch)

**Purpose:** the public launch that aims at the goal of 100 stars and 20 feedback issues within three months.

**In scope**

- Tagged 1.0 release, versioned action, and a changelog.
- Listing in the GitHub Marketplace.
- One launch moment: a Show HN post, a post in the selfhosted and devops communities, and one in-depth blog post on the trust boundary design.
- Visible roadmap in the repo that names the fleet layer as the next step, so people can vote and comment.
- A feedback loop: issues labelled and answered within 48 hours for the first month.
- Optional advanced mode announced but not required: GitHub App identity and ntfy notifications.

**Out of scope:** the full fleet and device layer. It follows after 1.0 and is steered by the feedback.

**Exit criteria and success measures**

- 100 GitHub stars within three months of the launch.
- 20 open issues with feedback from other people.
- At least 5 repos of outside users running it.

### Risks to watch

- Plain Renovate or Dependabot is considered good enough. Counter: the sandboxed AI fixer with hard budget, protected files, and a first-party bump path (no third-party Actions in the critical path, SH-001) is the clear difference.
- Setup takes longer than 15 minutes. Counter: measure it with outside testers in Release 2.
- Launch gets no attention. Counter: prepare the demo and the story before launching, and choose the day deliberately.
- A prompt injection incident damages trust. Counter: threat model and injection tests are published and part of the exit criteria.

### Decided on 2026-11-19

- License: MIT. Everything is open source, with no closed or paid core.
- Visibility: public. The repo is public, so no secrets, hostnames or private data may ever land in it.
- Platform: Linux first. Supported runners are GitHub-hosted Linux and self-hosted Linux. Deployment targets for the later fleet and device layer are AWS, Hetzner and plain Linux hosts. No macOS or Windows at the start.
- Forge: GitHub only for repos, issues, PRs and Actions.
- Model provider: Anthropic API first, through the locked gateway. Other providers can come later.

### Release schedule

One release per week, first release candidate by Christmas (proposed 2026-11-19).

| Release | Date | Ships |
| --- | --- | --- |
| Release 0: POC | Fri 27 Nov | Sandboxed agent on `healthy`: three real fixes as PRs, one prompt-injection test |
| Release 1: MVP 1 | Fri 4 Dec | Reusable Action with gates, budgets and needs-human issues; starts a soak on three repos |
| Release 2: MVP 2 | Fri 11 Dec | README, demo repo, security docs; five outside testers start the quickstart |
| Release 3: 1.0-rc1 | Fri 18 Dec | First release candidate, tester fixes included |
| Buffer | 21 to 23 Dec | Fixes only, no new scope |
| 1.0 public launch | Mid January | One launch moment, after the holidays |

The two-week soak from Release 1 now overlaps Releases 2 and 3 instead of coming before them.

### Still open

- Which package ecosystems the fix agent supports in Release 2 and 1.0 (for example Docker images, GitHub Actions, npm, pip, Go, Zig).
- Whether the project keeps the name Shepherd for the public release.
