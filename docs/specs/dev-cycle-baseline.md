# Dev-cycle baseline — frozen snapshot of pre-adoption fleet timings

> **Captured 2026-11-22T13:43:26Z by `scripts/measure-baseline.sh`.** Re-run on the
> same day produces slightly different numbers (new runs since capture time);
> this snapshot is the reference for SH-022 / SH-023 / SH-024 Shipping evidence
> tables. See `docs/stories/SH-026-baseline-capture.md`.

**Scope**: 100 most-recent runs per repo; wall-clock computed as
`(updatedAt - createdAt)` in minutes; median = sorted[n/2];
p90 = sorted[(int)(n × 0.9)]; pct_green = count(conclusion="success") × 100 / n.

**MIN_SAMPLES threshold**: 10. Rows below the threshold are flagged ⚠️.

| Repo | Workflow | Event | n | median (min) | p90 (min) | green % |
|---|---|---|---:|---:|---:|---:|
| bboortz/shepherd | Dependabot Updates | dynamic | 3 ⚠️ | 0.7 | 0.7 | 33 |
| bboortz/shepherd | bump | schedule | 1 ⚠️ | 1.9 | 1.9 | 100 |
| bboortz/shepherd | ci-branch | pull_request | 1 ⚠️ | 0.1 | 0.1 | 0 |
| bboortz/shepherd | discover | schedule | 3 ⚠️ | 0.1 | 0.2 | 0 |
| bboortz/shepherd | injection-drill | pull_request | 17 | 0.2 | 0.2 | 100 |
| bboortz/shepherd | injection-drill | schedule | 1 ⚠️ | 0.2 | 0.2 | 100 |
| bboortz/shepherd | renovate | schedule | 10 | 0.1 | 1 | 0 |
| bboortz/healthy | CI | pull_request | 19 | 3 | 3.7 | 89 |
| bboortz/healthy | CI | push | 30 | 0.4 | 3.8 | 93 |
| bboortz/healthy | Dependabot Updates | dynamic | 2 ⚠️ | 0.7 | 0.7 | 100 |
| bboortz/healthy | Release | workflow_dispatch | 8 ⚠️ | 1.5 | 2.1 | 62 |
| bboortz/healthy | dependabot-automerge | pull_request | 10 | 0 | 0.2 | 0 |
| bboortz/healthy | shepherd-gates | pull_request | 16 | 0.1 | 0.4 | 93 |
| bboortz/healthy | shepherd-gates | workflow_run | 8 ⚠️ | 0.2 | 0.2 | 100 |
| bboortz/healthy | shepherd | schedule | 1 ⚠️ | 0.4 | 0.4 | 100 |
| bboortz/healthy | shepherd | workflow_dispatch | 6 ⚠️ | 0.4 | 0.5 | 100 |
| bboortz/beaconry | CI | pull_request | 15 | 4 | 4.2 | 53 |
| bboortz/beaconry | CI | push | 24 | 0.6 | 4.3 | 87 |
| bboortz/beaconry | Dependabot Updates | dynamic | 10 | 0.8 | 0.8 | 100 |
| bboortz/beaconry | Dependency Graph | dynamic | 2 ⚠️ | 1.3 | 1.3 | 50 |
| bboortz/beaconry | Release | workflow_dispatch | 8 ⚠️ | 0.3 | 1.2 | 87 |
| bboortz/beaconry | dependabot-automerge | pull_request | 15 | 0 | 0.2 | 0 |
| bboortz/beaconry | shepherd-gates | pull_request | 16 | 0.1 | 0.2 | 100 |
| bboortz/beaconry | shepherd-gates | workflow_run | 5 ⚠️ | 0.1 | 0.2 | 100 |
| bboortz/beaconry | shepherd | schedule | 1 ⚠️ | 0.3 | 0.3 | 100 |
| bboortz/beaconry | shepherd | workflow_dispatch | 4 ⚠️ | 0.3 | 0.3 | 100 |
| bboortz/ham-radio-compass | Code Quality Checks | pull_request | 15 | 0.7 | 27.7 | 86 |
| bboortz/ham-radio-compass | Code Quality Checks | push | 19 | 0.6 | 0.8 | 100 |
| bboortz/ham-radio-compass | Dependabot Updates | dynamic | 1 ⚠️ | 0.9 | 0.9 | 0 |
| bboortz/ham-radio-compass | Release | workflow_dispatch | 14 | 0.3 | 0.7 | 78 |
| bboortz/ham-radio-compass | dependabot-automerge | pull_request | 15 | 0.1 | 27.3 | 6 |
| bboortz/ham-radio-compass | shepherd-gates | pull_request | 15 | 0.3 | 27.8 | 93 |
| bboortz/ham-radio-compass | shepherd-gates | workflow_run | 10 | 0.2 | 0.4 | 100 |
| bboortz/ham-radio-compass | shepherd | schedule | 1 ⚠️ | 0.7 | 0.7 | 100 |
| bboortz/ham-radio-compass | shepherd | workflow_dispatch | 10 | 0.7 | 1.3 | 60 |
| bboortz/forge | Build — daily publish (cron + manual) | schedule | 1 ⚠️ | 22.7 | 22.7 | 100 |
| bboortz/forge | CI | pull_request | 16 | 11.8 | 18.4 | 50 |
| bboortz/forge | CI | push | 29 | 1.1 | 13.2 | 93 |
| bboortz/forge | Dependabot Updates | dynamic | 3 ⚠️ | 0.6 | 2.4 | 66 |
| bboortz/forge | Nightly check-strict | schedule | 1 ⚠️ | 50.6 | 50.6 | 0 |
| bboortz/forge | Release | workflow_dispatch | 12 | 0.3 | 0.8 | 50 |
| bboortz/forge | dependabot-automerge | pull_request | 14 | 0 | 0.2 | 0 |
| bboortz/forge | shepherd-gates | pull_request | 16 | 0.1 | 0.8 | 93 |
| bboortz/forge | shepherd-gates | workflow_run | 4 ⚠️ | 0.2 | 0.3 | 100 |
| bboortz/forge | shepherd | schedule | 1 ⚠️ | 0.3 | 0.3 | 100 |
| bboortz/forge | shepherd | workflow_dispatch | 3 ⚠️ | 0.4 | 0.6 | 100 |
| bb-claw/homelab | CD — deploy to server | push | 11 | 0.7 | 2.7 | 100 |
| bb-claw/homelab | CI — lint and dry-run | pull_request | 17 | 7.1 | 14.7 | 82 |
| bb-claw/homelab | CI — lint and dry-run | push | 24 | 4.2 | 9.6 | 75 |
| bb-claw/homelab | Dependabot Updates | dynamic | 4 ⚠️ | 0.8 | 1.2 | 100 |
| bb-claw/homelab | dependabot-automerge | pull_request | 19 | 0 | 0.2 | 21 |
| bb-claw/homelab | shepherd-gates | pull_request | 19 | 0.1 | 0.1 | 100 |
| bb-claw/homelab | shepherd-gates | workflow_run | 3 ⚠️ | 0.1 | 0.1 | 100 |
| bb-claw/homelab | shepherd | workflow_dispatch | 3 ⚠️ | 0.5 | 0.5 | 100 |
| bb-claw/kernel-test | CI | pull_request | 72 | 1.7 | 2.1 | 70 |
| bb-claw/kernel-test | Dependabot Updates | dynamic | 2 ⚠️ | 0.7 | 0.7 | 100 |
| bb-claw/kernel-test | shepherd-gates | pull_request | 16 | 0.1 | 0.1 | 100 |
| bb-claw/kernel-test | shepherd-gates | workflow_run | 5 ⚠️ | 0.1 | 0.1 | 100 |
| bb-claw/kernel-test | shepherd | workflow_dispatch | 5 ⚠️ | 0.3 | 0.4 | 100 |

---

**Captured on**: Linux-x86_64
**Tool chain**: gh gh version 2.102.0 (2026-09-30), jq jq-1.8.2
