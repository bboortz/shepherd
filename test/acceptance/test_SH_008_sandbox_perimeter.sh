#!/bin/sh
# test_SH_008_sandbox_perimeter.sh — SH-008 sandbox perimeter (source form)
# Story:  docs/stories/SH-008-sandbox-perimeter.md
# Plan:   docs/plan/SH-008-sandbox-perimeter-plan.md
# CAPs:   sandbox.no-network-except-model, gateway.model-only
#
# Source-form validation: scripts + workflow wiring exist, shapes are
# correct. Live validation happens the next time any managed repo
# dispatches .github/workflows/reusable-shepherd.yml — the inline
# `curl api.openai.com` check in that step fires exit 90 on a hole.

set -u
pass=0; fail=0

assert_rc() { want=$1; shift; "$@" >/dev/null 2>&1; rc=$?
  if [ "$rc" = "$want" ]; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL want=$want got=$rc: $*"; fi; }

assert_grep() { pattern=$1; file=$2; label=$3
  if grep -Fq -- "$pattern" "$file"; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL $label: '$pattern' not found in $file"; fi; }

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
cd "$repo" || exit 1

LOCK=scripts/shepherd-poc/network-lockdown.sh
REST=scripts/shepherd-poc/network-restore.sh
WF=.github/workflows/reusable-shepherd.yml

# ----- Scenario 1 — scripts exist, executable, strict mode ---------------
assert_rc 0 test -f "$LOCK"
assert_rc 0 test -x "$LOCK"
assert_grep "#!/usr/bin/env bash" "$LOCK" "lockdown shebang"
assert_grep "set -euo pipefail"   "$LOCK" "lockdown strict mode"
assert_rc 0 test -f "$REST"
assert_rc 0 test -x "$REST"
assert_grep "#!/usr/bin/env bash" "$REST" "restore shebang"

# ----- Scenario 2 — lockdown pre-resolves anthropic + pins /etc/hosts -----
assert_grep "getent ahostsv4 api.anthropic.com" "$LOCK" "lockdown pre-resolves anthropic"
assert_grep "tee -a /etc/hosts"                "$LOCK" "lockdown pins /etc/hosts"

# ----- Scenario 3 — lockdown flushes OUTPUT and sets DROP policy ---------
assert_grep "iptables -F OUTPUT"       "$LOCK" "lockdown flushes OUTPUT"
assert_grep "iptables -P OUTPUT DROP"  "$LOCK" "lockdown sets DROP policy"

# ----- Scenario 4 — lockdown ACCEPTs loopback + anthropic:443 ------------
assert_grep "lo -j ACCEPT"       "$LOCK" "lockdown ACCEPTs loopback"
assert_grep "--dport 443 -j ACCEPT" "$LOCK" "lockdown ACCEPTs anthropic :443"
assert_grep "ESTABLISHED,RELATED"   "$LOCK" "lockdown ACCEPTs established/related"

# ----- Scenario 5 — restore flips policy back + flushes ------------------
assert_grep "iptables -P OUTPUT ACCEPT" "$REST" "restore sets ACCEPT policy"
assert_grep "iptables -F OUTPUT"        "$REST" "restore flushes OUTPUT"

# ----- Scenario 6 — workflow wires lockdown + trap-restore around agent --
assert_grep "network-lockdown.sh"                      "$WF" "workflow invokes lockdown"
assert_grep "trap './_shepherd/scripts/shepherd-poc/network-restore.sh' EXIT" "$WF" "workflow traps restore"

# ----- Scenario 7 — inline live-check is in the Agent-call step ----------
# Live acceptance: non-anthropic outbound must fail. The step exits 90/91
# on breach so a sandbox hole is loud, not silent.
assert_grep "curl -sS -m 5 --fail https://api.openai.com/" "$WF" "workflow checks openai unreachable"
assert_grep "curl -sS -m 5 --fail https://github.com/"     "$WF" "workflow checks github unreachable"
assert_grep "SH-008 sandbox breach"                        "$WF" "workflow prints breach message"
assert_grep "exit 90"                                      "$WF" "workflow exits 90 on openai reachable"
assert_grep "exit 91"                                      "$WF" "workflow exits 91 on github reachable"

# ----- Scenario 8 — CAP flips present in CAPABILITIES.md -----------------
CAPS=docs/specs/CAPABILITIES.md
# Both CAP ids should now be status: active (not design).
# Line-wise: find the row for each CAP and assert `active` is on it.
if awk -F'|' '/^\| `sandbox.no-network-except-model`/ { if ($5 ~ /active/) found=1 } END { exit !found }' "$CAPS"; then
  pass=$((pass + 1))
else
  fail=$((fail + 1)); echo "FAIL sandbox.no-network-except-model is not 'active' in $CAPS"
fi
if awk -F'|' '/^\| `gateway.model-only`/ { if ($5 ~ /active/) found=1 } END { exit !found }' "$CAPS"; then
  pass=$((pass + 1))
else
  fail=$((fail + 1)); echo "FAIL gateway.model-only is not 'active' in $CAPS"
fi

# ---------------------------------------------------------------------------
echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
