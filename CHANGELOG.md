# Changelog

All notable changes to `shepherd` are recorded here. The format is based on
[Keep a Changelog](https://keepachangelog.com/) and this project follows
[Semantic Versioning](https://semver.org/).

## [Unreleased]

Tracking Release 0 (POC) work in `bboortz/healthy` and the Release 1 Action
that will land back in this repo. See [`docs/DESIGN.md §13`](docs/DESIGN.md).

## [v0.0.0] — 2026-11-19

Pre-release scaffold. Not tagged or published yet.

### Security

- Pin `aquasecurity/trivy-action` to `v0.36.0` SHA (`ed142fd0673e97e23eac54620cfb913e5ce36c25`) in `.github/workflows/reusable-verify.yml`. The previous `@0.28.0` tag was in the vulnerable range of **GHSA-69fq-xp46-6x23 / CVE-2026-33634** — the TeamPCP supply-chain attack of March 2026, which force-pushed 76 of 77 `trivy-action` tags to malicious commits containing a secret-stealer. Dependabot flagged this on the very first push — the irony is noted and the lesson is Shepherd's (`docs/CAPABILITIES.md § sandbox` and `blocklist.protected-registration-files`).
- SHA-pin the remaining third-party actions in the shepherd fleet workflows. Mutable major-version tags removed in favour of resolved commit SHAs at the latest patch within each current major:
  - `actions/create-github-app-token@v1` → `d72941d7…` (`v1.12.0`) in `discover.yml`, `renovate.yml`, `digest.yml`.
  - `actions/checkout@v4` → `11d5960a…` (`v4.4.0`) in `discover.yml`, `renovate.yml`, `reusable-verify.yml`.
  - `renovatebot/github-action@v41` → `8ac70de2…` (`v41.0.22`) in `renovate.yml`.
  The Trivy advisory's generalisation applies: force-push on a mutable tag is a supply-chain entry point. Renovate's shared preset already extends `helpers:pinGitHubActionDigests`, so future bumps stay SHA-pinned.

### Added

- **Design source of truth** (`docs/DESIGN.md`): fleet layer (§1–11), trust
  boundary decisions (§12), Release 0 → Release 3 plan (§13), decisions made
  on 2026-11-19 (MIT, public, Linux-first, GitHub-only, Anthropic API).
- **Fleet layout** (§2) scaffolded: `policy/default.yml`, `renovate/default.json`,
  `templates/shepherd.yml`, `templates/caller-verify.yml`,
  `.github/workflows/{discover,renovate,digest,reusable-verify}.yml`,
  `docs/needs-human.md`. Workflow bodies described "in words" in the design
  are structural stubs — they activate from Release 1+.
- **DD-TGD scaffold**: `CLAUDE.md`, `memory/{MEMORY,project,workflow}.md`,
  `docs/stories/{_template,_9-questions}.md`, `docs/plan/{_template,IDEAS}.md`,
  `docs/CAPABILITIES.md` seeding 30 design capabilities from `docs/DESIGN.md §12`.
- **Release metadata**: `VERSION`, this `CHANGELOG.md`.
- **Contributor docs**: `CONTRIBUTING.md`, `SECURITY.md`.
- **Developer UX**: `Makefile` with `help`, `check`, `install-hooks`;
  `.yamllint`, `.markdownlint.json`; expanded `.gitignore`.
