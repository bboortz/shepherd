#!/bin/sh
# auto-revert.sh — SH-028 decision helper for opt-in auto-revert on ci-patch failure.
#
# Separates two concerns so the decision logic stays testable offline:
#
#   decide   : pure function. Reads .shepherd.yml + the list of files
#              touched by the failing commit, returns one of
#                SKIP:disabled              (auto_revert.enabled != true)
#                SKIP:touches-blocklist     (revert would touch a §12 path)
#                REVERT:comment-only        (open PR, don't auto-merge)
#                REVERT:auto-merge          (open PR + gh pr merge --auto)
#              Exit 0 on any decision; 3 on usage error.
#
#   execute  : side-effecting. Called by ci-patch.yml on failure once `decide`
#              returned a REVERT:* line. Not covered by the offline test suite —
#              real behaviour is exercised in the healthy canary PR per SH-028
#              plan post-merge notes.
#
# Usage:
#   auto-revert.sh decide  <shepherd.yml> <files-list.txt>
#   auto-revert.sh execute <failed-sha> <comment-only|auto-merge>
#
# `execute` needs env: REPO (owner/repo), GH_TOKEN. Script exits 4 if missing.

set -eu

cmd="${1:-}"
case "$cmd" in
  decide)
    shift
    cfg="${1:-}"
    files="${2:-}"
    [ -n "$cfg" ] && [ -n "$files" ] || {
      echo "usage: $0 decide <shepherd.yml> <files-list.txt>" >&2
      exit 3
    }

    enabled=$(awk '
      /^auto_revert:/ { in_block = 1; next }
      in_block && /^[a-zA-Z]/ { exit }
      in_block && /^[[:space:]]+enabled:[[:space:]]+/ {
        sub(/^[[:space:]]+enabled:[[:space:]]+/, "");
        gsub(/[[:space:]]*#.*$/, "");
        print; exit
      }
    ' "$cfg" 2>/dev/null || true)

    if [ "$enabled" != "true" ]; then
      echo "SKIP:disabled"
      exit 0
    fi

    comment_only=$(awk '
      /^auto_revert:/ { in_block = 1; next }
      in_block && /^[a-zA-Z]/ { exit }
      in_block && /^[[:space:]]+comment_only:[[:space:]]+/ {
        sub(/^[[:space:]]+comment_only:[[:space:]]+/, "");
        gsub(/[[:space:]]*#.*$/, "");
        print; exit
      }
    ' "$cfg" 2>/dev/null || true)
    # Phase-1 default: comment_only is true unless caller explicitly says false.
    [ "$comment_only" = "false" ] || comment_only=true

    # §12 blocklist short-circuit. If the revert would touch any blocklisted
    # path, refuse to open the revert PR; the caller opens a needs-human issue
    # only. Keeps the "agent cannot change its own rules" invariant intact
    # even on the revert path.
    blocklist=$(awk '
      /^blocklist:/ { in_block = 1; next }
      in_block && /^[a-zA-Z]/ { exit }
      in_block && /^[[:space:]]+-[[:space:]]+/ {
        sub(/^[[:space:]]+-[[:space:]]+/, "");
        gsub(/[[:space:]]*#.*$/, "");
        gsub(/^"|"$/, "");
        gsub(/^'"'"'|'"'"'$/, "");
        print
      }
    ' "$cfg" 2>/dev/null || true)
    # Default blocklist (synced with validate.sh) — applies when
    # .shepherd.yml → blocklist is absent.
    if [ -z "$blocklist" ]; then
      blocklist='.github/workflows/**
.shepherd.yml
templates/**
scripts/release.sh
scripts/shepherd-poc/**
VERSION
secrets/**'
    fi

    matches=""
    while IFS= read -r glob; do
      [ -z "$glob" ] && continue
      while IFS= read -r f; do
        [ -z "$f" ] && continue
        # shellcheck disable=SC2254
        case "$f" in $glob) matches="${matches}${f}
" ;; esac
      done < "$files"
    done <<EOF
$blocklist
EOF

    if [ -n "$matches" ]; then
      echo "SKIP:touches-blocklist"
      printf '%s' "$matches" | grep . | sort -u
      exit 0
    fi

    if [ "$comment_only" = "true" ]; then
      echo "REVERT:comment-only"
    else
      echo "REVERT:auto-merge"
    fi
    ;;

  execute)
    shift
    sha="${1:-}"
    mode="${2:-}"
    [ -n "$sha" ] && [ -n "$mode" ] || {
      echo "usage: $0 execute <failed-sha> <comment-only|auto-merge>" >&2
      exit 3
    }
    case "$mode" in comment-only|auto-merge) ;; *)
      echo "mode must be comment-only or auto-merge" >&2; exit 3 ;;
    esac
    : "${REPO:?REPO must be set (owner/repo)}"
    command -v gh >/dev/null || { echo "gh CLI missing" >&2; exit 4; }

    short=$(printf '%s' "$sha" | cut -c1-7)
    branch="shepherd-revert/$short"

    git fetch origin --depth=50
    git checkout -b "$branch"

    # Handle merge-commit case: `git revert -m 1` when the SHA has ≥2 parents.
    parent_count=$(git rev-list --parents -n 1 "$sha" | wc -w)
    if [ "$parent_count" -ge 3 ]; then
      git revert --no-edit -m 1 "$sha"
    else
      git revert --no-edit "$sha"
    fi

    git push -u origin "$branch"

    pr_body="Auto-revert of $short because ci-patch failed on $short.

See the [failed ci-patch run](https://github.com/$REPO/actions) for details.

Opened by SH-028 auto-revert."
    gh pr create -R "$REPO" \
      --title "[shepherd] auto-revert $short" \
      --body "$pr_body" \
      --label "shepherd-auto-revert" >/dev/null

    if [ "$mode" = "auto-merge" ]; then
      gh pr merge --auto --merge "$branch" -R "$REPO" >/dev/null || true
    fi
    echo "auto-revert: PR opened on branch $branch (mode=$mode)"
    ;;

  *)
    echo "usage: $0 decide <shepherd.yml> <files-list.txt>" >&2
    echo "       $0 execute <failed-sha> <comment-only|auto-merge>" >&2
    exit 3
    ;;
esac
