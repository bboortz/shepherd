# Ideas backlog — shepherd

Not-yet-promoted ideas. New ideas land here immediately, even if we won't pick them up. Promote to `docs/stories/SH-NNN-<slug>.md` when a story is cut.

## Promoted

- **[SH-001](../stories/SH-001-retire-renovate.md) — Retire Renovate; add `shepherd-bump --list` for GitHub Actions.** Status: in-progress → shipping as v0.1.0 (2026-11-21). Scope narrowed to `--list` + Renovate removal. `--check` and `--pr` promoted to SH-002 and SH-003 below.

## shepherd-bump — split from SH-001

- **SH-002 — `shepherd-bump --check` (upstream resolution).** Query `GET /repos/{owner}/{repo}/tags`; dereference annotated tags to commit SHAs; pick highest patch within current major; detect orphaned pins (upstream tag force-pushed or deleted) and open a needs-human issue instead of rewriting. Needs HTTP + JSON support in Zig 0.17.1 (`std.Io.net` + `std.json`), or shell-out to `gh api`. Delivers: `bump.stay-within-major`, `bump.orphaned-pin-detection`, the "upstream resolution" half of `bump.gh-actions` / `bump.sha-pin`.
- **SH-003 — `shepherd-bump --pr` (write + open PR).** For each bumpable dep found by `--check`, write a single-line patch, commit on a branch, push, open a PR against `dev`, label `shepherd-bump` + `gh-actions`. Needs `SHEPHERD_BUMP_TOKEN` secret (fine-grained PAT; contents+pull-requests+issues write). Delivers: `bump.open-pr-grouped`.

## Open from DESIGN.md §13

- **Project name for the public release.** Keep *Shepherd* or rename. Decide before R2's README lands.

## shepherd-bump — follow-up ecosystems (after SH-001)

One story per ecosystem. Each extends `shepherd-bump` (Zig single-file budget permitting). Scope per story: discovery, version resolution, PR shape, orphan-pin handling.

- **npm.** `package.json` + `package-lock.json`. Registry: `registry.npmjs.org`. Highest user value for the public launch.
- **pip.** `requirements.txt`, `pyproject.toml`, `Pipfile.lock`. Registry: PyPI simple index.
- **Go modules.** `go.mod`. Registry: Go module proxy.
- **Docker images.** `FROM` lines in `Dockerfile` + Compose refs. Registries: Docker Hub, GHCR. Pin by digest, not tag.
- **Zig.** `build.zig.zon`. Keep internal first; interesting mostly for `healthy`.

## Supply chain — further hardening

- **Replace `aquasecurity/trivy-action` with an inline, sigstore-verified Trivy install.** The binary is fine; the Action wrapper is the vector (CVE-2026-33634). Install via `curl` + `cosign verify-blob` of the sigstore bundle in `reusable-verify.yml`. Alternative: switch scanner to osv-scanner or grype entirely. Needs a story.
- **Lint: refuse mutable action refs.** A gate (`verify-sha-pinned-actions`) that fails CI if any `uses:` line is not a 40-hex SHA. Complement to `shepherd-bump`.

## Candidates from DESIGN.md §12

- **Scope level 2 (small code changes after an upgrade).** Lands in R2 per §13, but worth a story to pin the guardrails — how to detect that a dep bump broke an API surface, what the retry/escalation ladder looks like.
- **Scope level 3 (general source fixes for security findings).** Same release, higher blast radius — needs its own story with an injection-safety section.
- **Scope level 4 (pipelines / workflows).** Explicitly requires a human-reviewed approval — the story is how the bot even surfaces it as a candidate without being able to touch the files.

## Candidates from DESIGN.md §13 principles

- **Dry-run mode as the first experience.** The Action should comment what it would do and change nothing on the very first run. Needs a story so the behaviour is tested.
- **Zero-config defaults.** `.shepherd.yml` is optional. A story should pin the exact defaults (and where they're listed, so they don't drift from DESIGN).
- **Built-in gateway with network lockdown.** The Action pins network egress to the model API only. Needs a story for the Linux runner implementation (iptables / nftables / network namespace) and the self-test that proves lockdown.
