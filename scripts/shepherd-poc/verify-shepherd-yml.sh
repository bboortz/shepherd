#!/bin/sh
# verify-shepherd-yml.sh — gate: the caller's repo must ship a .shepherd.yml.
#
# Part of the SH-007 required-config decision (2026-11-21). The reusable
# Action calls this first; if it fails, the rest of the pipeline never runs.
#
# Why required (not optional):
#   - Explicit beats magic: each managed repo declares its risk tier,
#     auto-merge policy, build/test commands in the open.
#   - Auditable at the repo boundary: no cross-referencing shepherd's defaults.
#   - Symmetric with SH-011's `.github/dependabot.yml` enforcement.
#
# Usage:  verify-shepherd-yml.sh [path-to-repo-root]
#
# Exit codes:
#   0  .shepherd.yml exists (content not validated here; SH-009 adds schema)
#   1  .shepherd.yml missing — emits a GitHub Actions ::error:: annotation
#      with a pointer to templates/shepherd.yml.

set -eu

root=${1:-.}
cfg="$root/.shepherd.yml"

if [ -f "$cfg" ]; then
  echo "verify-shepherd-yml: OK ($cfg)"
  exit 0
fi

echo "::error title=shepherd config missing::shepherd requires .shepherd.yml at the repo root. Copy the baseline from https://github.com/bboortz/shepherd/blob/main/templates/shepherd.yml, edit risk/auto_merge/build/test, commit, and re-run."
exit 1
