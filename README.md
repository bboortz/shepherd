# Shepherd

> An AI agent that fixes your vulnerable dependencies inside a locked sandbox, with a hard budget and a protected-files list. One workflow file, one secret, 15 minutes.

**Status:** draft. Release 0 (POC) is in progress on `bboortz/healthy`. The files in this repo scaffold the fleet layout from the design; it starts being used from Release 1 onward.

## Layout

```
policy/            global rules and per-repo overrides
renovate/          shared Renovate preset for the fleet
templates/         files copied into managed repos
.github/workflows/ discover, renovate, digest, reusable-verify
docs/              escalation templates
```

## License

MIT.
