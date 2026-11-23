#!/usr/bin/env bash
# network-restore.sh — SH-008 sandbox perimeter: tear down the lockdown
# after the agent-call step completes (success or failure). Restores the
# default OUTPUT policy to ACCEPT so later workflow steps (regen-lockfile
# → npm install; open-pr → api.github.com) can reach the internet normally.
#
# Idempotent: safe to run even if network-lockdown.sh never ran (e.g. when
# iptables wasn't installed). Never fails CI.
#
# Story: docs/stories/SH-008-sandbox-perimeter.md

set -euo pipefail

if ! command -v iptables >/dev/null 2>&1; then
    echo "network-restore: iptables not installed — nothing to restore"
    exit 0
fi
if ! command -v sudo >/dev/null 2>&1; then
    echo "network-restore: sudo missing — cannot restore; leaving as-is"
    exit 0
fi

sudo iptables -P OUTPUT ACCEPT
sudo iptables -F OUTPUT
echo "network-restore: default OUTPUT policy restored to ACCEPT"

# Leave the /etc/hosts pin in place. It's harmless (a correct IP for
# api.anthropic.com) and lets future runs on the same ephemeral runner
# skip the resolution step. Ephemeral runners are destroyed between jobs
# anyway, so this doesn't leak state across runs.
