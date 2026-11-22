# `build/ci-timing.json` — schema

*Machine-readable timing emitted by every `make ci-*` target. Consumed by
SH-020 (digest), optionally by `shepherd-bump --verify-contract` as a side
check, and by the human reading the artifact.*

> **Status:** draft (SH-014). Promoted to active when SH-020 (emission +
> digest consumption) ships. Until then this spec is the forward-looking
> shape; repos may ship `ci-*` targets without the JSON file and the
> verifier will tolerate its absence (warn-only).

## Why machine-readable

The one-pipeline model (`dev-cycle-contract.md`) sets a hard 5-min / 5-min /
15-min cap per tier. A human can eyeball a workflow run; a bot cannot.
`build/ci-timing.json` is the artifact the bot reads to answer:

- Did any tier exceed its budget?
- Has any tier's median wall-clock grown 25 % over the last 14 days?
- Which step within the tier is the slowest?

## File location + format

- **Path (per repo):** `build/ci-timing.json` relative to the repo root.
  `build/` is already a conventional ignore-path; shepherd adds it to the
  workflow upload artifact under the name `ci-timing-<target>`.
- **One file per `ci-*` invocation.** `make ci-branch` writes one file. If
  a workflow runs `ci-branch` and then `ci-patch` in the same job, each
  invocation overwrites the previous `build/ci-timing.json`; the workflow
  uploads both as named artifacts before the second invocation starts.
- **Format:** JSON. UTF-8. Trailing newline. Pretty-printed is fine (the
  parser must accept minified too).

## Schema

```json
{
  "schema_version": 1,
  "target": "ci-branch",
  "budget_seconds": 300,
  "total_seconds": 174,
  "steps": [
    {"name": "yaml-lint", "seconds": 4.1},
    {"name": "md-lint", "seconds": 3.6},
    {"name": "verify-memory-size", "seconds": 0.2},
    {"name": "verify-traceability", "seconds": 0.8},
    {"name": "build", "seconds": 42.0},
    {"name": "test-acceptance", "seconds": 118.3},
    {"name": "injection-drill", "seconds": 5.0}
  ],
  "git_sha": "f33cb89",
  "runner": "ubuntu-24.04",
  "started_at": "2026-11-22T10:33:27Z",
  "finished_at": "2026-11-22T10:36:21Z"
}
```

### Fields

| Field | Type | Required | Meaning |
|---|---|---|---|
| `schema_version` | int | yes | `1` for now. Future changes bump the number + add a migration note here. |
| `target` | string | yes | One of `ci-branch`, `ci-patch`, `ci-release`, `ci-nightly`. Also accepts `build` / `test` for repos that want to instrument those directly. |
| `budget_seconds` | int | yes | Tier budget in seconds (matches `timeout-minutes` × 60 in the workflow). `null` for `ci-nightly`. |
| `total_seconds` | number | yes | Wall-clock seconds from target start to target finish. Floats OK. |
| `steps` | array | yes | Ordered list of substeps. Each step is `{"name": string, "seconds": number}`. Empty array allowed for targets that don't instrument substeps. |
| `git_sha` | string | yes | Short (7-char) or full (40-char) commit SHA this ran against. |
| `runner` | string | yes | Short identifier of the runner image (`ubuntu-24.04`, `ubuntu-22.04`, `self-hosted-linux-x64`, …). Lets the digest group by runner when comparing. |
| `started_at` | string (ISO 8601) | yes | UTC timestamp when the target entered. |
| `finished_at` | string (ISO 8601) | yes | UTC timestamp when the target exited. |

Unknown fields are allowed and ignored — consumers must forward-compat.

## How to emit it

Each repo's `make ci-*` target wraps its real work in a tiny shell helper
(shipped as `templates/Makefile.contract.snippet`). Sketch:

```sh
# emit-timing.sh target budget_seconds
target=$1; budget=$2
started_at=$(date -u +%FT%TZ)
: > build/ci-steps.jsonl              # one line per step

# ... each step appends: {"name":"...", "seconds": N}
# via `time` or a wrapping function

finished_at=$(date -u +%FT%TZ)
total=$( jq -s 'map(.seconds) | add' build/ci-steps.jsonl )
git_sha=$(git rev-parse --short HEAD)
runner=${RUNNER_OS:+${RUNNER_OS}-${RUNNER_ARCH}}
runner=${runner:-$(uname -s)-$(uname -m)}

jq -n \
  --arg target "$target" \
  --argjson budget "$budget" \
  --argjson total "$total" \
  --slurpfile steps build/ci-steps.jsonl \
  --arg git_sha "$git_sha" \
  --arg runner "$runner" \
  --arg started_at "$started_at" \
  --arg finished_at "$finished_at" \
  '{schema_version: 1, target: $target, budget_seconds: $budget, total_seconds: $total, steps: $steps, git_sha: $git_sha, runner: $runner, started_at: $started_at, finished_at: $finished_at}' \
  > build/ci-timing.json
```

The real snippet ships with SH-016. Non-Linux emitters (there are none in
scope today — DESIGN §13 is Linux-first) would substitute the runner-detect
line.

## How it is consumed

- **SH-020 digest.** Downloads the artifact after each workflow run; stores
  per-repo rolling medians; opens a needs-human issue when any `ci-*` target
  exceeds its `budget_seconds` or grows 25 % over its 14-day median.
- **`shepherd-bump --verify-contract` (SH-017).** The verifier does NOT
  require the file to exist — SH-020 owns emission. But it does read the
  file when present and warns if `total_seconds > budget_seconds` (warn,
  not fail, to avoid duplicate signals).
- **Humans.** Download from the GitHub Actions run page; inspect the
  slowest step; refactor.

## Forward compatibility

- Schema bumps: `schema_version: 2` adds a migration note here; consumers
  must accept any `schema_version >= 1` and tolerate unknown fields on
  version 1 payloads.
- Tier renames: not allowed (SH-014 fixes the four tier names). A rename
  would be its own SH story and a `schema_version` bump.
- Added tiers: allowed (future `ci-smoke` or similar). Consumers treat
  unknown `target` values as warn-only.
