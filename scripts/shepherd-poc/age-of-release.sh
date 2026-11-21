#!/bin/bash
# age-of-release.sh — print the upstream release timestamp of a package@version.
#
# Shared helper for SH-010 (agent flow `gate.waiting-period`) and SH-011
# (Dependabot flow). Keeps a single owner of the ecosystem→API mapping.
#
# Usage:
#   age-of-release.sh <ecosystem> <package> <version>
#
#   ecosystem ∈ {npm, pip, gh-actions, gomod}
#
# Writes an ISO-8601 timestamp (e.g. 2026-10-27T21:30:19) to stdout on success.
#
# Exit codes:
#   0  release timestamp emitted
#   2  version not found on the registry (hard fail → waiting-period gate blocks)
#   3  unknown ecosystem (fail-open signal → waiting-period gate skips with warning)
#   4  usage / IO error

set -euo pipefail

if [ $# -ne 3 ]; then
  echo "usage: $0 <ecosystem> <package> <version>" >&2
  exit 4
fi
ECO=$1
PKG=$2
VER=$3

command -v jq >/dev/null || { echo "jq missing" >&2; exit 4; }
command -v curl >/dev/null || { echo "curl missing" >&2; exit 4; }

case "$ECO" in
  npm|npm_and_yarn)
    # @scope/pkg needs its slash URL-encoded.
    enc=${PKG//\//%2F}
    ts=$(curl -sfL "https://registry.npmjs.org/$enc" 2>/dev/null \
      | jq -r --arg v "$VER" '.time[$v] // empty')
    ;;
  pip|pypi)
    ts=$(curl -sfL "https://pypi.org/pypi/$PKG/json" 2>/dev/null \
      | jq -r --arg v "$VER" '.releases[$v][0].upload_time // empty')
    ;;
  gh-actions|github_actions|github-actions)
    # package is owner/repo. Try v-prefix first, then bare.
    ts=$(gh api "repos/$PKG/releases/tags/v$VER" --jq '.published_at // empty' 2>/dev/null || true)
    if [ -z "$ts" ]; then
      ts=$(gh api "repos/$PKG/releases/tags/$VER" --jq '.published_at // empty' 2>/dev/null || true)
    fi
    ;;
  gomod|go)
    # sum.golang.org returns a 2-line response: hash, then RFC3339 timestamp.
    body=$(curl -sfL "https://sum.golang.org/lookup/$PKG@v$VER" 2>/dev/null || true)
    ts=$(printf '%s\n' "$body" | sed -n '2p')
    ;;
  *)
    echo "unknown ecosystem: $ECO" >&2
    exit 3
    ;;
esac

if [ -z "${ts:-}" ]; then
  echo "version not found on $ECO registry: $PKG@$VER" >&2
  exit 2
fi
printf '%s\n' "$ts"
