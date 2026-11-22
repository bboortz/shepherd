# Shepherd

> An AI agent that fixes your vulnerable dependencies inside a locked sandbox, with a hard budget and a protected-files list. One workflow file, one secret, 15 minutes.

**Status:** draft. Release 0 (POC) is in progress on [`bboortz/healthy`](https://github.com/bboortz/healthy) ([`docs/FLEET.md`](docs/FLEET.md)). The files in this repo scaffold the fleet layout from the design; most of it activates from Release 1 onward.

## Layout

```
bump.zig           first-party bump engine (shepherd-bump, SH-001)
build.zig          Zig build script
policy/            global rules and per-repo overrides
templates/         files copied into managed repos
.github/workflows/ discover, bump, digest, reusable-verify
docs/              specs/ (DESIGN, CAPABILITIES, …), stories/, plan/, FLEET, needs-human
memory/            persistent context for Claude sessions
test/acceptance/   DD-TGD acceptance tests per SH-NNN story
```

## Build

```sh
make build         # compiles bump.zig → bin/shepherd-bump
make test          # runs the acceptance suite
make check         # yaml-lint + md-lint + memory-size + build + test
```

Zig 0.17.1 required (pinned; `healthy` uses the same).

## License

MIT.
