#!/usr/bin/env bash
# network-lockdown.sh — SH-008 sandbox perimeter. Locks outbound traffic
# to api.anthropic.com:443 only (plus loopback). All other egress —
# including DNS, OpenAI, GitHub API, npm registry — is DROP'd by iptables.
#
# Design:
#   1. Pre-resolve api.anthropic.com via live DNS (allowed during setup).
#   2. Pin the resolved IP in /etc/hosts so the agent-call can reach the
#      model API without needing live DNS at run time.
#   3. Flush OUTPUT chain; set default policy DROP.
#   4. ACCEPT established/related, loopback, and each resolved
#      api.anthropic.com IP on tcp/443.
#
# Only safe to run inside a disposable runner (resets default OUTPUT policy
# for the whole process host). Pair with network-restore.sh to revert.
#
# Exit: 0 ok, 1 iptables/sudo missing, 2 DNS resolution failed.
#
# CAP: sandbox.no-network-except-model, gateway.model-only
# Story: docs/stories/SH-008-sandbox-perimeter.md

set -euo pipefail

if ! command -v iptables >/dev/null 2>&1; then
    echo "::error::network-lockdown: iptables not installed" >&2
    exit 1
fi
if ! command -v sudo >/dev/null 2>&1; then
    echo "::error::network-lockdown: sudo required (CAP_NET_ADMIN needed)" >&2
    exit 1
fi

# --- 1. Pre-resolve the model API --------------------------------------------
ips=$(getent ahostsv4 api.anthropic.com | awk '{print $1}' | sort -u || true)
if [ -z "$ips" ]; then
    echo "::error::network-lockdown: could not resolve api.anthropic.com" >&2
    exit 2
fi
ip_count=$(printf '%s\n' "$ips" | wc -l | tr -d ' ')
echo "network-lockdown: resolved api.anthropic.com → $ip_count IP(s)"

# --- 2. Pin the first IP in /etc/hosts ---------------------------------------
# The agent-call's curl will reach api.anthropic.com without needing DNS,
# since we're about to drop DNS egress.
first_ip=$(printf '%s\n' "$ips" | head -1)
if ! grep -q "api.anthropic.com" /etc/hosts; then
    echo "$first_ip api.anthropic.com" | sudo tee -a /etc/hosts >/dev/null
    echo "network-lockdown: pinned api.anthropic.com → $first_ip in /etc/hosts"
fi

# --- 3. Flush OUTPUT; default DROP -------------------------------------------
sudo iptables -F OUTPUT
sudo iptables -P OUTPUT DROP

# --- 4. ACCEPT rules ---------------------------------------------------------
# Established/related: return traffic for already-open connections.
sudo iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Loopback: shepherd scripts occasionally hit localhost (mock servers).
sudo iptables -A OUTPUT -o lo -j ACCEPT

# api.anthropic.com :443 only.
while IFS= read -r ip; do
    [ -z "$ip" ] && continue
    sudo iptables -A OUTPUT -d "$ip" -p tcp --dport 443 -j ACCEPT
done <<EOF
$ips
EOF

echo "network-lockdown: active — OUTPUT policy DROP; only api.anthropic.com:443 allowed"
