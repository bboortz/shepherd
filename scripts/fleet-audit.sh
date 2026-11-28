#!/bin/sh
# fleet-audit.sh — SH-057 repeatable fleet arming + health audit.
#
# One command, one fixed-structure Markdown report, every time. Folds the two
# hand-written precursors into a single procedure:
#   - arming matrix            (docs/specs/fleet-consistency-audit-2026-11-28.md)
#   - best-practice matrix     (docs/specs/fleet-consistency-audit-2026-11-22.md)
#   - pipeline health          (the "all pipelines green" requirement)
#   - a mechanically-derived verdict (FULLY ARMED / DRIFT DETECTED / INCONCLUSIVE)
#
# The repo list is parsed from docs/FLEET.md's Active table — nothing is
# hardcoded. Live cells need `gh` (authenticated); `--offline` renders the same
# structure with every live cell marked ⏭ so CI can prove the procedure is
# well-formed without the network.
#
# Read-only against managed repos. Never edits a repo, adds a topic, or flips
# dry_run — remediation stays a human action (DESIGN §12 posture).
#
# Usage:
#   scripts/fleet-audit.sh [--offline] [--out PATH] [--fleet PATH] [--root DIR] [--quiet]
#
# Exit 0 whenever the audit ran (the verdict lives in the report, not $?).
# Exit 2 only on a bad argument.
#
# CAPs: fleet.audit.repeatable
# Story: docs/stories/SH-057-fleet-audit.md

set -u

OK="✅"; WARN="⚠️"; BAD="❌"; SKIP="⏭"; NA="❔"

offline=0
quiet=0
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/.." && pwd)
fleet=""
out=""

while [ $# -gt 0 ]; do
    case "$1" in
        --offline)   offline=1 ;;
        --quiet)     quiet=1 ;;
        --out)       out=${2:?--out needs a path}; shift ;;
        --out=*)     out=${1#--out=} ;;
        --fleet)     fleet=${2:?--fleet needs a path}; shift ;;
        --fleet=*)   fleet=${1#--fleet=} ;;
        --root)      root=${2:?--root needs a dir}; shift ;;
        --root=*)    root=${1#--root=} ;;
        -h|--help)
            sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *) echo "fleet-audit: unknown argument: $1" >&2; exit 2 ;;
    esac
    shift
done

[ -n "$fleet" ] || fleet="$root/docs/FLEET.md"
today=$(date +%Y-%m-%d)
[ -n "$out" ] || out="$root/docs/specs/fleet-audit-$today.md"

say() { [ "$quiet" = 1 ] || printf 'fleet-audit: %s\n' "$*" >&2; }

# ---- gh availability --------------------------------------------------------
GH=0
if [ "$offline" = 0 ] && command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    GH=1
fi

# ---- latest shepherd tag (for caller-pin freshness) -------------------------
latest_tag=""; latest_tag_sha=""
if command -v git >/dev/null 2>&1 && [ -d "$root/.git" ]; then
    latest_tag=$(git -C "$root" tag --sort=-creatordate 2>/dev/null | head -1)
    [ -n "$latest_tag" ] && latest_tag_sha=$(git -C "$root" rev-list -n1 "$latest_tag" 2>/dev/null || true)
fi

# ---- parse the FLEET.md Active table ---------------------------------------
# Only rows whose first cell is a markdown-linked backtick repo (`| [`o/r`]…`);
# take the FIRST backtick token so later-column `app/github-actions`-style
# mentions are not mistaken for fleet members.
parse_repos() {
    awk '
        /^## Active/  { act=1; next }
        /^## /        { act=0 }
        act && /^\|[[:space:]]*\[`/ {
            if (match($0, /`[^`]+`/)) {
                tok=substr($0, RSTART+1, RLENGTH-2)
                if (tok ~ /\//) print tok
            }
        }
    ' "$1"
}

repos=""
if [ -f "$fleet" ]; then
    repos=$(parse_repos "$fleet" | awk '!seen[$0]++')
fi

# ---- scratch buffers + tallies ---------------------------------------------
armbuf=$(mktemp); bpbuf=$(mktemp); pipebuf=$(mktemp); findbuf=$(mktemp)
# shellcheck disable=SC2329  # invoked indirectly via trap
cleanup() { rm -f "$armbuf" "$bpbuf" "$pipebuf" "$findbuf"; }
trap cleanup EXIT

total=0; n_fully=0; n_bad=0; n_warn=0; n_skip=0
TAB=$(printf '\t')

record() { # symbol colname note  -> tally + findings row
    _sym=$1; _col=$2; _note=$3
    case "$_sym" in
        "$BAD")  n_bad=$((n_bad + 1));  rbad=$((rbad + 1));   printf '1%s%s%s%s%s%s\n' "$TAB" "$r" "$TAB" "$_col" "$TAB" "$_note" >>"$findbuf" ;;
        "$WARN") n_warn=$((n_warn + 1)); rwarn=$((rwarn + 1)); printf '2%s%s%s%s%s%s\n' "$TAB" "$r" "$TAB" "$_col" "$TAB" "$_note" >>"$findbuf" ;;
        "$SKIP") n_skip=$((n_skip + 1)) ;;
    esac
}

add() { # colname "SYM|NOTE"  -> record + append cell to $ROW
    _col=$1; _pair=$2
    _sym=${_pair%%|*}; _note=${_pair#*|}
    record "$_sym" "$_col" "$_note"
    ROW="$ROW $_sym |"
}

# ---- gh helpers (current repo is $r, branch is $ref) ------------------------
get_content() { gh api "repos/$r/contents/$1?ref=$ref" --jq '.content' 2>/dev/null | base64 -d 2>/dev/null; }

# ---- probes -----------------------------------------------------------------
probe_topic() {
    [ "$GH" = 1 ] || { echo "$SKIP|"; return; }
    [ "$reachable" = 1 ] || { echo "$NA|unreachable"; return; }
    if printf '%s\n' "$topics" | grep -Fxq "shepherd-managed"; then echo "$OK|"
    else echo "$BAD|no shepherd-managed topic (opt-in needs listing AND topic)"; fi
}

probe_file() { # path
    [ "$GH" = 1 ] || { echo "$SKIP|"; return; }
    [ "$reachable" = 1 ] || { echo "$NA|unreachable"; return; }
    if gh api "repos/$r/contents/$1?ref=$ref" --jq '.name' >/dev/null 2>&1; then echo "$OK|"
    else echo "$BAD|$1 missing"; fi
}

probe_secret() {
    [ "$GH" = 1 ] || { echo "$SKIP|"; return; }
    names=$(gh secret list -R "$r" --json name --jq '.[].name' 2>/dev/null); rc=$?
    [ "$rc" = 0 ] || { echo "$NA|secret list not accessible"; return; }
    if printf '%s\n' "$names" | grep -Fxq "ANTHROPIC_API_KEY"; then echo "$OK|"
    else echo "$BAD|ANTHROPIC_API_KEY not set"; fi
}

probe_dry_run() {
    [ "$GH" = 1 ] || { echo "$SKIP|"; return; }
    [ "$reachable" = 1 ] || { echo "$NA|unreachable"; return; }
    c=$(get_content .shepherd.yml)
    [ -n "$c" ] || { echo "$BAD|.shepherd.yml missing"; return; }
    if printf '%s\n' "$c" | grep -Eq '^[[:space:]]*dry_run:[[:space:]]*true'; then echo "$WARN|dry_run:true (reporting-only; flip after first clean cycle)"
    else echo "$OK|live"; fi
}

probe_pin() {
    [ "$GH" = 1 ] || { echo "$SKIP|"; return; }
    [ "$reachable" = 1 ] || { echo "$NA|unreachable"; return; }
    c=$(get_content .github/workflows/shepherd.yml)
    [ -n "$c" ] || { echo "$BAD|no shepherd caller workflow"; return; }
    sha=$(printf '%s\n' "$c" | grep -oE 'reusable-shepherd\.yml@[A-Za-z0-9._-]+' | head -1 | sed 's/.*@//')
    [ -n "$sha" ] || { echo "$WARN|caller not pinned to reusable-shepherd.yml"; return; }
    len=$(printf '%s' "$sha" | wc -c | tr -d ' ')
    [ "$len" = 40 ] || { echo "$BAD|mutable ref @$sha (not a 40-hex SHA)"; return; }
    if [ -n "$latest_tag_sha" ]; then
        if [ "$sha" = "$latest_tag_sha" ]; then echo "$OK|$latest_tag"
        else
            behind=$(git -C "$root" rev-list --count "$sha..$latest_tag_sha" 2>/dev/null || echo "?")
            echo "$WARN|behind $latest_tag by $behind commits"
        fi
    else echo "$OK|pinned (no local tag to compare)"; fi
}

probe_default_dev() {
    [ "$GH" = 1 ] || { echo "$SKIP|"; return; }
    [ "$reachable" = 1 ] || { echo "$NA|unreachable"; return; }
    if [ "$def" = "dev" ]; then echo "$OK|"; else echo "$BAD|default branch is '$def', not dev"; fi
}

probe_branches() {
    [ "$GH" = 1 ] || { echo "$SKIP|"; return; }
    [ "$reachable" = 1 ] || { echo "$NA|unreachable"; return; }
    d=$(gh api "repos/$r/branches/dev"  --jq '.name' 2>/dev/null)
    m=$(gh api "repos/$r/branches/main" --jq '.name' 2>/dev/null)
    if [ "$d" = "dev" ] && [ "$m" = "main" ]; then echo "$OK|"
    elif [ "$d" = "dev" ]; then echo "$WARN|main branch missing"
    elif [ "$m" = "main" ]; then echo "$WARN|dev branch missing"
    else echo "$BAD|neither dev nor main present"; fi
}

makefile_blob() { # echoes Makefile (+ mk/ci.mk if included) once; cached in $mkblob
    [ -n "${mkblob+x}" ] && { printf '%s' "$mkblob"; return; }
    mkblob=$(get_content Makefile)
    if printf '%s' "$mkblob" | grep -q 'include mk/ci.mk'; then
        mkblob="$mkblob
$(get_content mk/ci.mk)"
    fi
    printf '%s' "$mkblob"
}

probe_make_targets() {
    [ "$GH" = 1 ] || { echo "$SKIP|"; return; }
    [ "$reachable" = 1 ] || { echo "$NA|unreachable"; return; }
    c=$(makefile_blob)
    [ -n "$c" ] || { echo "$BAD|Makefile missing"; return; }
    n=0; miss=""
    for t in build test test-affected smoke release-artifacts ci-branch ci-patch ci-release ci-nightly; do
        if printf '%s\n' "$c" | grep -qE "^$t:"; then n=$((n + 1)); else miss="$miss $t"; fi
    done
    if [ "$n" = 9 ]; then echo "$OK|9/9"
    elif [ "$n" -gt 0 ]; then echo "$WARN|$n/9 (missing:$miss)"
    else echo "$BAD|0/9 contract targets"; fi
}

probe_schema_v1() {
    [ "$GH" = 1 ] || { echo "$SKIP|"; return; }
    [ "$reachable" = 1 ] || { echo "$NA|unreachable"; return; }
    c=$(get_content .shepherd.yml)
    [ -n "$c" ] || { echo "$BAD|.shepherd.yml missing"; return; }
    miss=""
    for k in version risk build test auto_merge; do
        printf '%s\n' "$c" | grep -qE "^$k:" || miss="$miss $k"
    done
    [ -z "$miss" ] && echo "$OK|" || echo "$WARN|missing field(s):$miss"
}

probe_ci_tiered() {
    [ "$GH" = 1 ] || { echo "$SKIP|"; return; }
    [ "$reachable" = 1 ] || { echo "$NA|unreachable"; return; }
    miss=""
    for w in ci-branch.yml ci-patch.yml ci-release.yml; do
        case " $wfs " in *" $w "*) : ;; *) miss="$miss $w" ;; esac
    done
    if [ -z "$miss" ]; then echo "$OK|"
    elif [ "$miss" = " ci-branch.yml ci-patch.yml ci-release.yml" ]; then echo "$BAD|no ci-tiered workflows"
    else echo "$WARN|missing:$miss"; fi
}

probe_sha_pin() {
    [ "$GH" = 1 ] || { echo "$SKIP|"; return; }
    [ "$reachable" = 1 ] || { echo "$NA|unreachable"; return; }
    [ -n "$wfs" ] || { echo "$NA|no workflows"; return; }
    blob=""
    for w in $wfs; do blob="$blob
$(get_content ".github/workflows/$w")"; done
    unpinned=$(printf '%s\n' "$blob" | awk '
        /^[[:space:]]*uses:/ {
            if ($0 ~ /\.\//)                 next   # local ref
            if ($0 ~ /@[0-9a-fA-F]{40}/)     next   # sha-pinned
            print
        }' | head -3)
    if [ -z "$unpinned" ]; then echo "$OK|workflows SHA-pinned"
    else
        ex=$(printf '%s' "$unpinned" | sed 's/^[[:space:]]*uses:[[:space:]]*//' | tr '\n' ';' )
        echo "$BAD|mutable uses: $ex (workflows only — composite actions via --verify-sha-pin)"
    fi
}

probe_prepush() {
    [ "$GH" = 1 ] || { echo "$SKIP|"; return; }
    [ "$reachable" = 1 ] || { echo "$NA|unreachable"; return; }
    pc=$(get_content .pre-commit-config.yaml)
    if printf '%s\n' "$pc" | grep -q 'make check' && printf '%s\n' "$pc" | grep -q 'pre-push'; then echo "$OK|.pre-commit-config.yaml"; return; fi
    hk=$(get_content .husky/pre-push)
    if printf '%s\n' "$hk" | grep -q 'make check'; then echo "$OK|.husky/pre-push"; return; fi
    gh2=$(get_content .githooks/pre-push)
    if printf '%s\n' "$gh2" | grep -q 'make check'; then echo "$OK|.githooks/pre-push"; return; fi
    echo "$BAD|no pre-push hook running 'make check'"
}

probe_test_affected() {
    [ "$GH" = 1 ] || { echo "$SKIP|"; return; }
    [ "$reachable" = 1 ] || { echo "$NA|unreachable"; return; }
    c=$(makefile_blob)
    [ -n "$c" ] || { echo "$BAD|Makefile missing"; return; }
    rec=$(printf '%s\n' "$c" | awk '/^test-affected:/{f=1; print; next} f&&/^\t/{print; next} f&&/^[^\t]/{f=0}')
    [ -n "$rec" ] || { echo "$BAD|no test-affected target"; return; }
    if printf '%s\n' "$rec" | grep -qE 'scripts/|\.sh'; then echo "$OK|diff-aware (script)"
    elif printf '%s\n' "$rec" | grep -qiE 'test-updates|affected|changed'; then echo "$OK|diff-aware"
    else
        dep=$(printf '%s\n' "$rec" | head -1 | sed 's/test-affected:[[:space:]]*//')
        echo "$WARN|identity alias → ${dep:-none} (contract-permitted when no module graph)"
    fi
}

run_concl() { # workflow-file
    [ "$GH" = 1 ] || { echo "$SKIP|"; return; }
    [ "$reachable" = 1 ] || { echo "$NA|unreachable"; return; }
    case " $wfs " in *" $1 "*) : ;; *) echo "$NA|absent"; return ;; esac
    c=$(gh run list -R "$r" --workflow "$1" -L 1 --json conclusion,status --jq '.[0].conclusion // .[0].status' 2>/dev/null)
    case "$c" in
        success)                                      echo "$OK|" ;;
        "")                                           echo "$NA|no runs" ;;
        failure|cancelled|timed_out|startup_failure)  echo "$BAD|last run: $c" ;;
        *)                                            echo "$WARN|$c" ;;
    esac
}

# ---- per-repo loop ----------------------------------------------------------
for r in $repos; do
    total=$((total + 1))
    rbad=0; rwarn=0
    unset mkblob 2>/dev/null || true

    def="dev"; topics=""; reachable=1; wfs=""
    if [ "$GH" = 1 ]; then
        def=$(gh repo view "$r" --json defaultBranchRef --jq '.defaultBranchRef.name' 2>/dev/null)
        if [ -z "$def" ]; then reachable=0; def=""; fi
        topics=$(gh repo view "$r" --json repositoryTopics --jq '.repositoryTopics[].name' 2>/dev/null)
        ref=${def:-dev}
        # Space-separated so `case " $wfs " in *" name "*` membership tests work.
        [ "$reachable" = 1 ] && wfs=$(gh api "repos/$r/contents/.github/workflows?ref=$ref" --jq '.[].name' 2>/dev/null | tr '\n' ' ')
    else
        ref="dev"
    fi

    # Arming matrix row
    ROW="| \`$r\` |"
    add "Topic"        "$(probe_topic)"
    add "Config"       "$(probe_file .shepherd.yml)"
    add "Dependabot"   "$(probe_file .github/dependabot.yml)"
    add "Makefile"     "$(probe_file Makefile)"
    add "Caller"       "$(probe_file .github/workflows/shepherd.yml)"
    add "Gates"        "$(probe_file .github/workflows/shepherd-gates.yml)"
    add "Secret"       "$(probe_secret)"
    add "dry_run"      "$(probe_dry_run)"
    add "Pin"          "$(probe_pin)"
    printf '%s\n' "$ROW" >>"$armbuf"

    # Best-practice matrix row
    ROW="| \`$r\` |"
    add "default=dev"   "$(probe_default_dev)"
    add "dev+main"      "$(probe_branches)"
    add "9 targets"     "$(probe_make_targets)"
    add "schema v1"     "$(probe_schema_v1)"
    add "dependabot"    "$(probe_file .github/dependabot.yml)"
    add "ci-tiered"     "$(probe_ci_tiered)"
    add "shepherd"      "$(probe_file .github/workflows/shepherd.yml)"
    add "gates"         "$(probe_file .github/workflows/shepherd-gates.yml)"
    add "SHA-pin"       "$(probe_sha_pin)"
    add "pre-push"      "$(probe_prepush)"
    add "test-affected" "$(probe_test_affected)"
    printf '%s\n' "$ROW" >>"$bpbuf"

    # Pipeline-health row
    ROW="| \`$r\` |"
    add "shepherd cron" "$(run_concl shepherd.yml)"
    add "ci-branch"     "$(run_concl ci-branch.yml)"
    add "ci-patch"      "$(run_concl ci-patch.yml)"
    add "ci-release"    "$(run_concl ci-release.yml)"
    add "ci-nightly"    "$(run_concl ci-nightly.yml)"
    printf '%s\n' "$ROW" >>"$pipebuf"

    if [ "$GH" = 1 ]; then
        if [ "$rbad" = 0 ] && [ "$rwarn" = 0 ]; then
            n_fully=$((n_fully + 1)); say "  $r  armed $OK  pipelines $OK"
        else
            say "  $r  DRIFT ($rbad gaps, $rwarn warnings)"
        fi
    else
        say "  $r  (offline — skipped)"
    fi
done

# ---- verdict ----------------------------------------------------------------
if [ "$GH" = 0 ]; then
    verdict="INCONCLUSIVE — offline mode, live checks skipped ($n_skip cells)"
elif [ "$total" = 0 ]; then
    verdict="INCONCLUSIVE — no repositories parsed"
elif [ "$n_bad" = 0 ] && [ "$n_warn" = 0 ]; then
    verdict="FULLY ARMED — all $total repos armed, all pipelines green"
else
    verdict="DRIFT DETECTED — $n_fully of $total fully armed ($n_bad gaps, $n_warn warnings)"
fi
say "VERDICT — $verdict"

# ---- render report ----------------------------------------------------------
mkdir -p "$(dirname "$out")" 2>/dev/null || true
{
    echo "# Fleet audit — $today"
    echo
    echo "Generated by \`scripts/fleet-audit.sh\` (SH-057). Registry: \`$(printf '%s' "$fleet" | sed "s#^$root/##")\`."
    if [ "$GH" = 1 ]; then echo "Mode: **live** (\`gh\` authenticated)."; else echo "Mode: **offline** — live cells skipped; run with \`gh\` authenticated for a real verdict."; fi
    echo
    echo "## Verdict"
    echo
    echo "**VERDICT:** $verdict"
    echo
    echo "Legend: ✅ conformant · ⚠️ partial / contract-permitted alias · ❌ missing or violating · ⏭ not checked (offline) · ❔ unreachable / no access."
    echo

    if [ "$total" = 0 ]; then
        echo "_No repositories parsed from the Active table of \`$fleet\`._"
        echo
    fi

    echo "## Arming matrix"
    echo
    echo "Is every listed repo actually armed? (2026-11-28 workflow.)"
    echo
    echo "| Repo | Topic | Config | Dependabot | Makefile | Caller | Gates | Secret | dry_run | Pin |"
    echo "|---|---|---|---|---|---|---|---|---|---|"
    cat "$armbuf"
    echo

    echo "## Best-practice conformance matrix"
    echo
    echo "The 11 fleet-contract checks (2026-11-22 workflow)."
    echo
    echo "| Repo | default=dev | dev+main | 9 targets | schema v1 | dependabot | ci-tiered | shepherd | gates | SHA-pin | pre-push | test-affected |"
    echo "|---|---|---|---|---|---|---|---|---|---|---|---|"
    cat "$bpbuf"
    echo

    echo "## Pipeline health"
    echo
    echo "Last conclusion of each repo's shepherd cron and ci-* tiers. All green is the bar."
    echo
    echo "| Repo | shepherd cron | ci-branch | ci-patch | ci-release | ci-nightly |"
    echo "|---|---|---|---|---|---|"
    cat "$pipebuf"
    echo

    echo "## Findings"
    echo
    if [ -s "$findbuf" ]; then
        echo "Ranked most-severe first. ❌ = gap, ⚠️ = warning."
        echo
        sort -t"$TAB" -k1,1 "$findbuf" | while IFS="$TAB" read -r sev repo col note; do
            mark="❌"; [ "$sev" = 2 ] && mark="⚠️"
            # shellcheck disable=SC2016  # literal backticks + %s format, not expansion
            printf -- '- %s **%s** · `%s` — %s\n' "$mark" "$col" "$repo" "$note"
        done
    elif [ "$GH" = 0 ]; then
        echo "_None recorded — offline run (procedure validated, no live state inspected)._"
    else
        echo "_None — every checked cell is conformant._"
    fi
    echo

    echo "## Appendix — method"
    echo
    echo "Each check and how it is probed (all read-only):"
    echo
    echo "- **Topic** — \`gh repo view --json repositoryTopics\`; opt-in requires the repo be listed here AND carry \`shepherd-managed\` (DESIGN §2)."
    echo "- **Config / Dependabot / Makefile / Caller / Gates** — \`gh api repos/<r>/contents/<path>?ref=<default>\`."
    echo "- **Secret** — \`gh secret list\`; needs admin on the repo, else ❔."
    echo "- **dry_run** — \`dry_run: true\` in \`.shepherd.yml\` ⇒ ⚠️ (reporting-only)."
    echo "- **Pin** — \`reusable-shepherd.yml@<sha>\` in the caller; compared to the newest local shepherd tag ($latest_tag). Mutable (non-40-hex) ref ⇒ ❌; behind-latest ⇒ ⚠️."
    echo "- **default=dev / dev+main** — \`gh repo view --json defaultBranchRef\` + \`gh api .../branches/{dev,main}\`."
    echo "- **9 targets** — Makefile (+ \`mk/ci.mk\` when included) exposes build, test, test-affected, smoke, release-artifacts, ci-branch, ci-patch, ci-release, ci-nightly."
    echo "- **schema v1** — \`.shepherd.yml\` has version, risk, build, test, auto_merge."
    echo "- **ci-tiered** — ci-branch.yml + ci-patch.yml + ci-release.yml present."
    echo "- **SHA-pin** — every \`uses:\` in \`.github/workflows/*\` is a 40-hex SHA or a local \`./\` ref. Composite actions under \`.github/actions/**\` are NOT deep-scanned here — \`shepherd-bump --verify-sha-pin\` is the authoritative check."
    echo "- **pre-push** — a \`make check\` pre-push hook via \`.pre-commit-config.yaml\`, \`.husky/pre-push\`, or \`.githooks/pre-push\`."
    echo "- **test-affected** — the Makefile recipe is diff-aware (script / changed-file selection) vs an identity alias (⚠️, contract-permitted when a repo has no module graph)."
    echo "- **Pipeline health** — \`gh run list --workflow <wf> -L 1\` conclusion."
    echo
    echo "Overlap: Dependabot / shepherd caller / gates caller appear in both the arming"
    echo "and best-practice matrices by design — the two matrices are distinct lenses"
    echo "(is-it-armed vs does-it-follow-the-contract) folded from the two precursor audits."
    echo
    echo "**Not inspected:** managed repos' own non-shepherd CI (e.g. a repo's \`ci-nightly\`"
    echo "failing for its own reasons) is reported under pipeline health but triaging it"
    echo "belongs to that repo's owner / the SH-020 digest."
} > "$out"

say "wrote $out"
exit 0
