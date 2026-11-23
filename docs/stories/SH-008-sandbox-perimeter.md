---
id: SH-008
slug: sandbox-perimeter
status: shipped
created: 2026-11-23
owner: @benni
---

# SH-008 — Sandbox perimeter: lock agent-step network to api.anthropic.com only

> **Sub-story of [SH-006](SH-006-r1-reusable-action.md).** Owns the R1-B "sandbox perimeter" deliverable per DESIGN §12 (Smart fix agent). Closes `sandbox.no-network-except-model` + `gateway.model-only` CAPs — from `design` to `active`.

## 1. Who is the consumer?

- Repo owner trusting the sandboxed smart-fix agent to not exfiltrate secrets or call unauthorised APIs. Before SH-008 the only mechanism was hope (the agent didn't know any other URLs) + prompt-injection drill (which catches *some* attempts). After SH-008 the OS-level firewall is the backstop: even a successfully-injected agent cannot reach any host other than `api.anthropic.com:443`.
- `shepherd-bump` + `scripts/shepherd-poc/validate.sh` consumers — already trusted outputs, now doubly backed by network-level isolation of the process that produced them.

## 2. When does the story fire?

- Every invocation of `.github/workflows/reusable-shepherd.yml` → `Agent call (sandboxed network)` step. The lockdown runs just before `agent-call.sh`; the restore fires on step exit (success or failure) via `trap`.

## 3. What does success look like?

Mechanically checkable **live in CI** (the sandbox's acceptance test runs inside the step itself before the agent):

- `curl -m 5 https://api.openai.com/` exits non-zero (connection refused or timeout).
- `curl -m 5 https://github.com/` exits non-zero.
- `curl -m 5 https://api.anthropic.com/v1/messages` reaches the server (401 unauth without a key is reachable; `connection failed` is NOT).
- After the agent step, the restore script tears down the perimeter so subsequent steps (`regen-lockfile` → npm install; `open-pr` → api.github.com) work normally.
- CAPs `sandbox.no-network-except-model` + `gateway.model-only` flip `design → active` with evidence pointers to this story and `test_SH_008_sandbox_perimeter.sh`.

## 4. How urgent?

- [x] Security-critical (trust-boundary invariant — DESIGN §12 names it)
- [x] Correctness (gaps are quiet failures: an injected agent reaches wherever it wants with no audit trail)
- [ ] Quality-of-life
- [ ] Onboarding

## 5. Happy path

```
# In the reusable Action, the Agent call step:
./_shepherd/scripts/shepherd-poc/network-lockdown.sh
trap './_shepherd/scripts/shepherd-poc/network-restore.sh' EXIT

# Sandbox live-check — fails loudly if the perimeter has a hole:
curl -sS -m 5 --fail https://api.openai.com/ >/dev/null 2>&1 && exit 90  # should be unreachable

# Agent runs with the perimeter up:
./_shepherd/scripts/shepherd-poc/agent-call.sh
# ↑ reaches api.anthropic.com (pinned in /etc/hosts; iptables allowed its IPs)
# ↑ cannot reach anything else

# trap fires: network-restore.sh flips OUTPUT back to ACCEPT.
# Regen-lockfile + open-pr run with full network access.
```

## 6. Edge cases / failure modes that matter

- **`api.anthropic.com` has multiple IPs behind a CDN.** The lockdown pre-resolves ALL IPv4 A records and ACCEPTs each on tcp/443, then pins the first in `/etc/hosts` so the agent's curl doesn't need DNS. If anthropic rotates IPs mid-workflow, the pinned IP stays valid for the duration of the run (CDN IPs are long-lived).
- **`iptables` missing on a managed repo's runner.** `network-lockdown.sh` exits 1 with a loud error. Caller workflow fails. Operator installs iptables or chooses a different runner — not a quiet degradation.
- **A managed repo runs on `macos-latest` or `windows-latest`.** Out of scope per DESIGN §13 ("Linux first"). The lockdown exits 1 cleanly.
- **Agent step fails before the trap can fire.** `trap '... EXIT'` fires on every exit path (including `set -e` kills), so restore always runs.
- **Later-step (regen-lockfile) finds the lockdown still active.** Guarded by the trap. Belt-and-braces: `network-restore.sh` is idempotent and callable from any step.
- **An injected agent tries `nc` or `ping` to exfiltrate.** `iptables` default-DROP catches TCP/UDP on all other destinations. ICMP: not currently blocked, but ICMP cannot carry an API call (no response channel for secrets).

## 7. Out of scope

- IPv6 lockdown. The lockdown currently ACCEPTs ipv4 only; ip6tables rules could be added in a follow-up if IPv6 egress becomes a concern. GitHub-hosted runners have IPv4 primary and anthropic's IPv6 endpoint isn't required for the API.
- UDP egress to api.anthropic.com. The API is HTTPS/TCP only; no quic/http3 support, so blocking UDP is harmless.
- Per-domain budgets (bytes/sec cap on the one allowed destination). Would require a userland proxy; too much for R1.
- Egress from containers nested inside the step. Not used today.

## 8. Acceptance (Gherkin → test assertions)

The sandbox's acceptance test runs **live in the workflow**, in the same step that enforces it:

```gherkin
Scenario: non-anthropic outbound blocked after lockdown
  Given the reusable-shepherd workflow Agent-call step
  When  network-lockdown.sh has run
  And   the step's inline live-check fires
  Then  `curl -m 5 https://api.openai.com/` exits non-zero
  And   `curl -m 5 https://github.com/`     exits non-zero
  And   the workflow exits 90 or 91 on either breach

Scenario: anthropic outbound still reaches the API
  Given the perimeter is up
  When  agent-call.sh runs `curl https://api.anthropic.com/v1/messages`
  Then  the request reaches anthropic (401 unauth without a real key is OK;
        "connection refused" would be a sandbox hole)

Scenario: network is restored after the agent step
  Given the perimeter was up
  When  the step exits (success or failure)
  Then  network-restore.sh fires via trap
  And   `iptables -L OUTPUT` shows policy ACCEPT
  And   the next workflow step (regen-lockfile → npm install) succeeds
```

**Source-form acceptance test** at `test/acceptance/test_SH_008_sandbox_perimeter.sh` asserts:

1. `scripts/shepherd-poc/network-lockdown.sh` exists, is executable, declares shebang + `set -euo pipefail`.
2. Script pre-resolves `api.anthropic.com` (contains `getent ahostsv4 api.anthropic.com`).
3. Script pins the IP in `/etc/hosts` (contains `tee -a /etc/hosts`).
4. Script sets OUTPUT policy DROP (contains `iptables -P OUTPUT DROP`).
5. Script whitelists loopback + anthropic IPs on 443 (contains `ACCEPT`).
6. `network-restore.sh` exists, executable, restores OUTPUT to ACCEPT.
7. `.github/workflows/reusable-shepherd.yml` invokes both scripts around the agent step.
8. The workflow has the live acceptance check (`curl ... api.openai.com` guarded by `exit 90`).

**Live verification** occurs the next time any managed repo's scheduled cron dispatches `reusable-shepherd.yml`. The inline check fails the run loudly if the perimeter has a hole. No separate live test needed — the enforcement IS the test.

## 9. Capabilities delivered or extended

- `sandbox.no-network-except-model` — `design → active`. Evidence: `scripts/shepherd-poc/network-lockdown.sh` + `.github/workflows/reusable-shepherd.yml` inline curl live-check.
- `gateway.model-only` — `design → active`. Same evidence; the firewall rule is the gateway's egress enforcement.

---

## Plan doc

See `docs/plan/SH-008-sandbox-perimeter-plan.md`.
