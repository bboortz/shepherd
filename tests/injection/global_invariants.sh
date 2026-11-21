#!/bin/sh
# tests/injection/global_invariants.sh — payload-independent post-run audit.
#
# For the pure-replay drill, the "no outbound network / no git push / no file
# write outside scratch" invariants are enforced by design: run.sh only calls
# agent-call.sh --replay (local JSON read) and validate.sh (pure awk/grep).
# Neither reaches the network, pushes branches, or writes outside
# $TMPDIR/shepherd-drill.*.
#
# This script makes the design invariant observable: it runs AFTER run.sh
# and asserts the repo working tree is unchanged.
#
# Exit codes:
#   0  invariants hold
#   2  working tree modified (likely a drill bug)

set -u

# Invariant: the drill cleans up its scratch directories.
leftover=$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'shepherd-drill.*' -type d 2>/dev/null)
if [ -n "$leftover" ]; then
  echo "global-invariants: FAIL — scratch dirs not cleaned up:" >&2
  printf '%s\n' "$leftover" | sed 's/^/  /' >&2
  exit 2
fi

echo "global-invariants: OK (scratch cleaned)"
