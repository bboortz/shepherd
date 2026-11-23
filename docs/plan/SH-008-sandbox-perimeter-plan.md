---
id: SH-008
slug: sandbox-perimeter
story: docs/stories/SH-008-sandbox-perimeter.md
branch: feat/SH-008-sandbox-perimeter
status: in-progress
---

# SH-008 plan — sandbox perimeter

**Story:** [SH-008](../stories/SH-008-sandbox-perimeter.md)

## Design delta

Three new artefacts + one workflow edit:

1. **`scripts/shepherd-poc/network-lockdown.sh`** — new. Pre-resolves `api.anthropic.com`, pins the IP in `/etc/hosts`, flushes `iptables OUTPUT`, sets default policy DROP, ACCEPTs loopback + established/related + resolved anthropic IPs on tcp/443.
2. **`scripts/shepherd-poc/network-restore.sh`** — new. Flips OUTPUT back to ACCEPT, flushes rules. Idempotent + never-fails.
3. **`.github/workflows/reusable-shepherd.yml`** — edit. Wraps the `Agent call` step in the lockdown → trap-restore pattern. Adds an inline live-check (`curl api.openai.com` + `curl github.com`) that fires `exit 90/91` if either succeeds — the sandbox's acceptance test runs inside the enforcement step.
4. **`test/acceptance/test_SH_008_sandbox_perimeter.sh`** — new. Source-form test: scripts exist + executable; workflow invokes them around the agent step with the live-check in place.

CAP changes:
- `sandbox.no-network-except-model` — `design → active`, point to new script + workflow.
- `gateway.model-only` — `design → active`, same pointers.

Why iptables not Docker `--network`:
- The reusable workflow runs directly on ubuntu-latest, not inside a container. Switching to a `container:` directive is a larger change that affects path layout (checkouts go into the container filesystem) and complicates secret passing.
- Iptables on ubuntu-latest has `sudo` + `iptables` available out of the box.
- Lockdown happens in step scope only; later steps get full network back.

Why pin `/etc/hosts`:
- DNS egress has to be dropped (otherwise `connect api.openai.com` resolves and we'd need to block by IP after the fact). Pinning the resolved anthropic IP lets the agent's curl reach the model without live DNS.

## Alternatives rejected

| Alternative | Why not |
|---|---|
| Run the agent step in a `container: ghcr.io/anthropic/shepherd-sandbox` with `--network` locked | Larger change to the workflow + requires maintaining a container image + complicates secret mount + checkout path. The iptables approach is 70 lines of shell with no container-image pipeline to feed. |
| Keep DNS open; block by resolved IP after the fact | Race: the agent could resolve anything → connect before we see the DNS query. Default-DROP the moment DNS is pinned is water-tight. |
| Use a userland HTTP proxy that only forwards to anthropic | ≥200 lines of code + proxy maintenance + TLS re-termination. The kernel firewall is cheaper + more trustworthy. |
| Allow api.github.com during the agent step (for `gh issue comment` escalation) | Breaks the invariant — an injected agent could post secrets via issue comments. Needs-human issue creation happens in later steps AFTER restore. |

## Breaking changes

- [ ] Yes
- [x] No — strictly additive on shepherd. Managed repos' caller workflows don't change. The Agent-call step gains the lockdown; everything else keeps full network access.

## Rollout

- [x] README updated — N/A (the trust boundary is documented in `docs/specs/DESIGN.md §12`; CAPABILITIES.md carries the public-facing evidence).
- [x] `memory/project.md` invariants updated — Trust-boundary invariant #2 already states "agent runs with no network and no secrets of its own." SH-008 is the implementation that makes this literally true (was aspirational before).
- [ ] `docs/specs/DESIGN.md` reconciled — N/A; §12 already names the invariant.
- [x] CAPABILITIES rows updated: `sandbox.no-network-except-model` + `gateway.model-only` flip `design → active`.
- [x] Acceptance test wired: `test/acceptance/test_SH_008_sandbox_perimeter.sh`.

Live validation: the next time any managed repo's `.shepherd.yml` cron dispatches `reusable-shepherd.yml`, the inline `curl api.openai.com` check fires. A passing run proves the perimeter is up on real CI. Shepherd's own CI doesn't invoke `reusable-shepherd.yml` (that's a reusable callable, not triggered on push), so the source-form test is the shepherd-side shipping evidence; live evidence lands post-merge as PRs on managed repos dispatch the Action.

## Shipping evidence

| Lens | Evidence | ✅ / ⚠️ / ❌ |
|---|---|---|
| Gherkin coverage | `test_SH_008_sandbox_perimeter.sh` asserts script shape + workflow wiring for all four scenarios (lockdown present, restore present, live-check inline in workflow, CAP flip in CAPABILITIES) | ✅ |
| Behaviour symmetry | Lockdown always paired with restore via `trap EXIT` in the workflow; restore is idempotent so belt-and-braces call from any later step is safe | ✅ |
| Self-consistency | Story Q9 + test Covers: block + CAPABILITIES.md all name `sandbox.no-network-except-model` + `gateway.model-only`; story links to plan; plan links to story; workflow references exist on disk | ✅ |
