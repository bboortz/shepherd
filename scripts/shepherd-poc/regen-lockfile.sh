#!/bin/sh
# regen-lockfile.sh — apply the agent's manifest-only diff, then deterministically
# regenerate the lockfile by running the ecosystem's package manager. Writes the
# combined diff (manifest + lockfile) back to $DIFF_PATH.
#
# Required env:
#   DIFF_PATH   path to the agent's manifest-only diff (default /tmp/diff.patch)
#
# Exit codes:
#   0  combined diff written; $DIFF_PATH now contains manifest + lockfile changes
#   2  manifest diff did not apply; or regen produced no changes; or ecosystem unsupported
#   3  usage / tool missing

set -eu

DIFF_PATH="${DIFF_PATH:-/tmp/diff.patch}"
if [ ! -f "$DIFF_PATH" ]; then
  echo "regen-lockfile: no diff at $DIFF_PATH" >&2
  exit 3
fi

command -v git >/dev/null || { echo "git missing" >&2; exit 3; }

# Apply the manifest diff in the working tree (no commit yet). LLM-generated
# diffs routinely miscount hunks AND misplace the starting line number, so
# cascade through increasingly forgiving modes:
#   1. strict                              — well-formed diffs
#   2. --recount                           — rebuild hunk counts from content
#   3. --recount --ignore-whitespace       — whitespace drift inside context
#   4. --recount --3way                    — synthesise a 3-way merge
#   5. --recount --3way --ignore-whitespace
#   6. patch -p1 -F 3                      — Unix `patch` with fuzz, slides
#                                            the hunk to match context when
#                                            the LLM's starting line is off
#                                            by a few lines
# `-F 3` is GNU patch's default fuzz; made explicit for clarity. `patch`
# writes the file in-place (no extra flag needed) and exits non-zero on
# genuine content mismatch.
#
# The previous `-p0` mode is intentionally gone: the agent's diffs always
# include `a/` / `b/` prefixes, and `-p0` made git treat those as literal
# filenames, producing a misleading "b/package.json does not exist in
# index" error on an otherwise-valid diff.
apply_tried() {
  _diff=$1
  _log=$2
  # Accumulate per-mode output into $_log so operators can see which modes
  # failed and why — the previous version used `2>$_log` which overwrites
  # on each attempt, leaving only the LAST mode's stderr. Line-offset bugs
  # that --recount handles are then invisible when the final mode (--3way)
  # reports the separate "lacks necessary blob" error.
  : > "$_log"
  _try() {
    name=$1; shift
    printf -- "---- mode: %s ----\n" "$name" >> "$_log"
    if "$@" 2>>"$_log"; then
      printf "  → %s succeeded\n" "$name" >> "$_log"
      echo "$name"
      return 0
    fi
    return 1
  }
  _try "strict"                   git apply                                       "$_diff" && return 0
  _try "recount"                  git apply --recount                             "$_diff" && return 0
  _try "recount+ignore-ws"        git apply --recount --ignore-whitespace         "$_diff" && return 0
  _try "recount+3way"             git apply --recount --3way                      "$_diff" && return 0
  _try "recount+3way+ignore-ws"   git apply --recount --3way --ignore-whitespace  "$_diff" && return 0
  if command -v patch >/dev/null; then
    _try "patch+fuzz=3"           patch -p1 -F 3 --no-backup-if-mismatch --silent -i "$_diff" && return 0
  fi
  return 1
}

mode=$(apply_tried "$DIFF_PATH" /tmp/regen-apply.log) || {
  echo "regen-lockfile: agent's manifest diff did not apply in any mode:" >&2
  cat /tmp/regen-apply.log >&2
  echo "---- DIFF CONTENT ----" >&2
  cat "$DIFF_PATH" >&2
  echo "---- END DIFF ----" >&2
  # Escalate: when all apply modes fail, the agent produced a diff we can't
  # salvage. Open (or comment on) a needs-human issue so the operator sees
  # the broken fix without having to spelunk the Actions log.
  #
  # Pre-conditions: REPO + GH_TOKEN are set by the caller workflow. Failure
  # of the escalation itself is non-fatal — the primary exit code is what
  # matters to the caller workflow.
  if [ -n "${REPO:-}" ] && [ -n "${GH_TOKEN:-}" ]; then
    _here=$(cd "$(dirname "$0")" && pwd)
    if [ -x "$_here/open-needs-human.sh" ]; then
      {
        echo "Pre-PR failure — the shepherd agent produced a diff that no apply mode could land cleanly."
        echo ""
        echo "Apply log:"
        cat /tmp/regen-apply.log 2>/dev/null || true
        echo ""
        echo "Diff that failed to apply:"
        cat "$DIFF_PATH"
      } > /tmp/regen-apply-extra.log
      "$_here/open-needs-human.sh" regen-lockfile 0 \
        "shepherd agent produced a manifest diff that no git-apply mode could land" \
        /tmp/regen-apply-extra.log \
        || echo "regen-lockfile: needs-human issue open attempt failed (non-fatal)" >&2
    fi
  fi
  exit 2
}
echo "→ agent diff applied in mode: $mode"

# Detect the ecosystem from what the agent touched. `git diff --name-only`
# against the un-staged working tree captures the manifest the agent edited.
touched=$(git diff --name-only -- . | sort -u)
echo "→ Touched manifests: $(printf '%s' "$touched" | tr '\n' ' ')"

ecosystem=""
case "$touched" in
  *package.json*)    ecosystem=npm ;;
  *pyproject.toml*|*requirements.txt*) ecosystem=pip ;;
  *go.mod*)          ecosystem=go ;;
  "")
    echo "regen-lockfile: agent diff touched nothing — the patch applied but was a no-op (lines already match target state?)" >&2
    echo "---- DIFF CONTENT ----" >&2
    cat "$DIFF_PATH" >&2
    echo "---- END DIFF ----" >&2
    exit 2
    ;;
  *)
    echo "regen-lockfile: ecosystem not yet supported for: $touched" >&2
    # Keep the manifest-only diff as-is — tolerable R0 behaviour.
    echo "→ Keeping manifest-only diff (no lockfile regen)."
    git diff -- . > "$DIFF_PATH.tmp" && mv "$DIFF_PATH.tmp" "$DIFF_PATH"
    exit 0
    ;;
esac

echo "→ Ecosystem: $ecosystem — regenerating lockfile"

case "$ecosystem" in
  npm)
    command -v npm >/dev/null || { echo "npm missing — install Node.js in the workflow" >&2; exit 3; }
    # --package-lock-only: don't install node_modules; only touch package-lock.json.
    # --ignore-scripts: refuse to run any package install-scripts (big R0 safety win).
    npm install --package-lock-only --ignore-scripts 2>/tmp/regen-npm.log || {
      echo "regen-lockfile: npm install --package-lock-only failed:" >&2
      cat /tmp/regen-npm.log >&2
      exit 2
    }
    ;;
  pip|go)
    echo "regen-lockfile: ecosystem $ecosystem not yet implemented (R1 scope)" >&2
    exit 2
    ;;
esac

# Capture the combined diff (manifest + lockfile) and replace the agent's
# manifest-only diff with it. validate.sh re-runs after this step.
combined_lines=$(git diff -- . | wc -l)
if [ "$combined_lines" = 0 ]; then
  echo "regen-lockfile: no changes after regen — nothing to open a PR for" >&2
  exit 2
fi

git diff -- . > "$DIFF_PATH.tmp" && mv "$DIFF_PATH.tmp" "$DIFF_PATH"
echo "→ Combined diff written: $DIFF_PATH ($combined_lines lines)"

# Reset the working tree so the later open-pr.sh can apply $DIFF_PATH onto a
# clean branch. Safe here: this is a CI runner, no human work exists.
git checkout -- .
echo "→ Working tree reset; combined diff preserved at $DIFF_PATH"
