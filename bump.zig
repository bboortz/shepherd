//! shepherd-bump — first-party dependency bumper for Shepherd (SH-001).
//!
//! Modes:
//!   shepherd-bump --list                        List pinned `uses:` refs in the repo.
//!   shepherd-bump --check                       Query upstream tags; print bump plan. (TODO)
//!   shepherd-bump --pr                          Open PRs for bumpable deps. (TODO)
//!   shepherd-bump --verify-dependabot           Verify .github/dependabot.yml presence+shape (SH-011).
//!   shepherd-bump --verify-contract             Verify Makefile exposes the 8 SH-014 contract targets (SH-017).
//!   shepherd-bump --verify-sha-pin              Verify every uses: ref in .github/ is 40-hex SHA-pinned (SH-030).
//!   shepherd-bump --verify-prepush              Verify .pre-commit-config.yaml or .husky/pre-push runs `make check` (SH-033).
//!   shepherd-bump --verify-timeouts             Verify ci-{branch,patch,release,nightly}.yml jobs cap timeout-minutes to tier budgets (SH-039).
//!
//! Flags:
//!   --root PATH         Repo root (default: cwd).
//!   --ecosystem NAME    Only `gh-actions` is supported (bump modes only).
//!
//! Exit codes: 0 ok, 1 cannot open root / I/O, 2 usage,
//!             3 dependabot.yml OR Makefile missing OR no pre-push config file OR tier workflow missing,
//!             4 dependabot.yml malformed OR contract target missing OR unpinned uses: ref OR pre-push doesn't call `make check` OR timeout-minutes missing/over-budget.
//!
//! See docs/stories/SH-001-retire-renovate.md,
//!     docs/stories/SH-011-dependabot-enforce-automerge.md,
//!     docs/stories/SH-017-verify-contract.md,
//!     docs/stories/SH-030-fleet-sha-pin-sweep.md,
//!     docs/stories/SH-033-fleet-prepush-convergence.md,
//!     docs/stories/SH-039-verify-timeouts.md.

const std = @import("std");

const Mode = enum { list, check, pr, verify_dependabot, verify_contract, verify_sha_pin, verify_prepush, verify_timeouts, help };

const Options = struct {
    mode: Mode = .help,
    root: []const u8 = ".",
    ecosystem: []const u8 = "gh-actions",
};

const UsesRef = struct {
    file: []u8,
    owner: []u8,
    repo: []u8,
    sha: []u8,
    version: []u8,

    fn deinit(self: UsesRef, allocator: std.mem.Allocator) void {
        allocator.free(self.file);
        allocator.free(self.owner);
        allocator.free(self.repo);
        allocator.free(self.sha);
        allocator.free(self.version);
    }
};

fn printUsage() void {
    const msg =
        \\usage: shepherd-bump --list                 [--root PATH] [--ecosystem gh-actions]
        \\       shepherd-bump --check                [--root PATH] [--ecosystem gh-actions]  (TODO)
        \\       shepherd-bump --pr                   [--root PATH] [--ecosystem gh-actions]  (TODO)
        \\       shepherd-bump --verify-dependabot    [--root PATH]
        \\       shepherd-bump --verify-contract      [--root PATH]
        \\       shepherd-bump --verify-sha-pin       [--root PATH]
        \\       shepherd-bump --verify-prepush       [--root PATH]
        \\       shepherd-bump --verify-timeouts      [--root PATH]
        \\
    ;
    std.debug.print("{s}", .{msg});
}

fn parseArgs(args: []const []const u8) !Options {
    var opts = Options{};
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const a = args[i];
        if (std.mem.eql(u8, a, "--list")) {
            opts.mode = .list;
        } else if (std.mem.eql(u8, a, "--check")) {
            opts.mode = .check;
        } else if (std.mem.eql(u8, a, "--pr")) {
            opts.mode = .pr;
        } else if (std.mem.eql(u8, a, "--verify-dependabot")) {
            opts.mode = .verify_dependabot;
        } else if (std.mem.eql(u8, a, "--verify-contract")) {
            opts.mode = .verify_contract;
        } else if (std.mem.eql(u8, a, "--verify-sha-pin")) {
            opts.mode = .verify_sha_pin;
        } else if (std.mem.eql(u8, a, "--verify-prepush")) {
            opts.mode = .verify_prepush;
        } else if (std.mem.eql(u8, a, "--verify-timeouts")) {
            opts.mode = .verify_timeouts;
        } else if (std.mem.eql(u8, a, "--help") or std.mem.eql(u8, a, "-h")) {
            opts.mode = .help;
        } else if (std.mem.eql(u8, a, "--root")) {
            i += 1;
            if (i >= args.len) return error.MissingArgValue;
            opts.root = args[i];
        } else if (std.mem.eql(u8, a, "--ecosystem")) {
            i += 1;
            if (i >= args.len) return error.MissingArgValue;
            opts.ecosystem = args[i];
        } else {
            return error.UnknownArg;
        }
    }
    return opts;
}

fn isHex40(s: []const u8) bool {
    if (s.len != 40) return false;
    for (s) |c| {
        const hex = (c >= '0' and c <= '9') or (c >= 'a' and c <= 'f');
        if (!hex) return false;
    }
    return true;
}

fn isIdentChar(c: u8) bool {
    return (c >= 'a' and c <= 'z') or
        (c >= 'A' and c <= 'Z') or
        (c >= '0' and c <= '9') or
        c == '-' or c == '_' or c == '.';
}

/// Parse a single workflow line for a pinned `uses:` reference.
/// Returns null if the line is not a (SHA-)pinned uses: line.
/// Shapes accepted (whitespace flexible):
///     - uses: owner/repo@<40hex>  # vX.Y.Z
///       uses: owner/repo@<40hex>
fn parseUsesLine(
    allocator: std.mem.Allocator,
    file_path: []const u8,
    line: []const u8,
) !?UsesRef {
    var p: usize = 0;

    // Skip leading whitespace.
    while (p < line.len and (line[p] == ' ' or line[p] == '\t')) p += 1;

    // Optional leading "- "
    if (p < line.len and line[p] == '-') {
        p += 1;
        while (p < line.len and (line[p] == ' ' or line[p] == '\t')) p += 1;
    }

    // "uses:"
    const keyword = "uses:";
    if (p + keyword.len > line.len) return null;
    if (!std.mem.eql(u8, line[p .. p + keyword.len], keyword)) return null;
    p += keyword.len;

    // Whitespace.
    var saw_ws = false;
    while (p < line.len and (line[p] == ' ' or line[p] == '\t')) : (p += 1) saw_ws = true;
    if (!saw_ws) return null;

    // owner
    const owner_start = p;
    while (p < line.len and isIdentChar(line[p])) p += 1;
    if (p == owner_start) return null;
    const owner = line[owner_start..p];

    // "/"
    if (p >= line.len or line[p] != '/') return null;
    p += 1;

    // repo
    const repo_start = p;
    while (p < line.len and isIdentChar(line[p])) p += 1;
    if (p == repo_start) return null;
    const repo = line[repo_start..p];

    // "@"
    if (p >= line.len or line[p] != '@') return null;
    p += 1;

    // sha / ref — lowercase hex 40 is pinned; anything else we skip for --list.
    const sha_start = p;
    while (p < line.len and
        line[p] != ' ' and line[p] != '\t' and
        line[p] != '#' and line[p] != '\r' and line[p] != '\n') p += 1;
    const sha = line[sha_start..p];
    if (!isHex40(sha)) return null;

    // Optional "  # vX.Y.Z" — permissive, take the token after '#'.
    var version: []const u8 = "";
    while (p < line.len and (line[p] == ' ' or line[p] == '\t')) p += 1;
    if (p < line.len and line[p] == '#') {
        p += 1;
        while (p < line.len and (line[p] == ' ' or line[p] == '\t')) p += 1;
        const ver_start = p;
        while (p < line.len and
            line[p] != ' ' and line[p] != '\t' and
            line[p] != '\r' and line[p] != '\n') p += 1;
        version = line[ver_start..p];
    }

    return UsesRef{
        .file = try allocator.dupe(u8, file_path),
        .owner = try allocator.dupe(u8, owner),
        .repo = try allocator.dupe(u8, repo),
        .sha = try allocator.dupe(u8, sha),
        .version = try allocator.dupe(u8, version),
    };
}

fn listUsesInFile(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    rel_path: []const u8,
    refs: *std.ArrayList(UsesRef),
) !void {
    const contents = try root.readFileAlloc(io, rel_path, allocator, .limited(1 * 1024 * 1024));
    defer allocator.free(contents);

    var it = std.mem.splitScalar(u8, contents, '\n');
    while (it.next()) |line| {
        if (try parseUsesLine(allocator, rel_path, line)) |ref| {
            try refs.append(allocator, ref);
        }
    }
}

fn scanWorkflowsDir(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    refs: *std.ArrayList(UsesRef),
) !void {
    var dir = root.openDir(io, ".github/workflows", .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound => return,
        else => return err,
    };
    defer dir.close(io);

    var it = dir.iterate();
    while (try it.next(io)) |entry| {
        if (entry.kind != .file) continue;
        if (!(std.mem.endsWith(u8, entry.name, ".yml") or std.mem.endsWith(u8, entry.name, ".yaml"))) continue;
        const rel = try std.fmt.allocPrint(allocator, ".github/workflows/{s}", .{entry.name});
        defer allocator.free(rel);
        try listUsesInFile(allocator, io, root, rel, refs);
    }
}

fn scanActionsDir(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    refs: *std.ArrayList(UsesRef),
) !void {
    var top = root.openDir(io, ".github/actions", .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound => return,
        else => return err,
    };
    defer top.close(io);

    var walker = try top.walk(allocator);
    defer walker.deinit();

    while (try walker.next(io)) |entry| {
        if (entry.kind != .file) continue;
        if (!(std.mem.eql(u8, entry.basename, "action.yml") or std.mem.eql(u8, entry.basename, "action.yaml"))) continue;
        const rel = try std.fmt.allocPrint(allocator, ".github/actions/{s}", .{entry.path});
        defer allocator.free(rel);
        try listUsesInFile(allocator, io, root, rel, refs);
    }
}

fn refLess(_: void, a: UsesRef, b: UsesRef) bool {
    if (!std.mem.eql(u8, a.file, b.file)) return std.mem.order(u8, a.file, b.file) == .lt;
    if (!std.mem.eql(u8, a.owner, b.owner)) return std.mem.order(u8, a.owner, b.owner) == .lt;
    return std.mem.order(u8, a.repo, b.repo) == .lt;
}

fn trimLeadingWs(s: []const u8) []const u8 {
    var i: usize = 0;
    while (i < s.len and (s[i] == ' ' or s[i] == '\t')) : (i += 1) {}
    return s[i..];
}

fn trimTrailingWs(s: []const u8) []const u8 {
    var end = s.len;
    while (end > 0 and (s[end - 1] == ' ' or s[end - 1] == '\t' or s[end - 1] == '\r')) : (end -= 1) {}
    return s[0..end];
}

/// Matches `enforce_enabled:` with any amount of whitespace, followed by `false`.
/// Used to honour the `.shepherd.yml` → `dependabot.enforce_enabled: false` opt-out.
/// Deliberately permissive (not a full YAML parser): if the user writes it
/// anywhere in the file at zero-or-more leading indent, we treat it as opt-out.
fn lineIsEnforceDisabled(line: []const u8) bool {
    const t = trimLeadingWs(trimTrailingWs(line));
    const key = "enforce_enabled:";
    if (!std.mem.startsWith(u8, t, key)) return false;
    const rest = trimLeadingWs(t[key.len..]);
    return std.mem.eql(u8, rest, "false");
}

fn lineIsVersionTwo(line: []const u8) bool {
    const t = trimLeadingWs(trimTrailingWs(line));
    // Must match exactly `version: 2` (allow spaces after the colon).
    const key = "version:";
    if (!std.mem.startsWith(u8, t, key)) return false;
    const rest = trimLeadingWs(t[key.len..]);
    return std.mem.eql(u8, rest, "2");
}

fn lineIsPackageEcosystem(line: []const u8) bool {
    const t = trimLeadingWs(trimTrailingWs(line));
    // Accept both `- package-ecosystem: NAME` and (less common) `package-ecosystem: NAME`.
    const bare = "package-ecosystem:";
    const bulleted = "- package-ecosystem:";
    return std.mem.startsWith(u8, t, bulleted) or std.mem.startsWith(u8, t, bare);
}

fn cmdVerifyDependabot(allocator: std.mem.Allocator, io: std.Io, opts: Options) !u8 {
    var root = std.Io.Dir.cwd().openDir(io, opts.root, .{}) catch |err| {
        std.debug.print("error: cannot open root '{s}': {s}\n", .{ opts.root, @errorName(err) });
        return 1;
    };
    defer root.close(io);

    // --- Opt-out check via .shepherd.yml -----------------------------------
    if (root.readFileAlloc(io, ".shepherd.yml", allocator, .limited(64 * 1024))) |shepherd_cfg| {
        defer allocator.free(shepherd_cfg);
        var it = std.mem.splitScalar(u8, shepherd_cfg, '\n');
        while (it.next()) |line| {
            if (lineIsEnforceDisabled(line)) {
                std.debug.print("verify-dependabot: opted out via .shepherd.yml (enforce_enabled: false)\n", .{});
                return 0;
            }
        }
    } else |err| switch (err) {
        error.FileNotFound => {}, // no .shepherd.yml — default is enforce_enabled: true
        else => return err,
    }

    // --- Presence check ----------------------------------------------------
    const contents = root.readFileAlloc(io, ".github/dependabot.yml", allocator, .limited(64 * 1024)) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("verify-dependabot: .github/dependabot.yml is missing (exit 3)\n", .{});
            return 3;
        },
        else => {
            std.debug.print("verify-dependabot: cannot read .github/dependabot.yml: {s}\n", .{@errorName(err)});
            return 1;
        },
    };
    defer allocator.free(contents);

    // --- Shape check: version: 2 AND ≥1 package-ecosystem entry -----------
    var has_version_two = false;
    var has_updates_entry = false;
    var it = std.mem.splitScalar(u8, contents, '\n');
    while (it.next()) |line| {
        if (lineIsVersionTwo(line)) has_version_two = true;
        if (lineIsPackageEcosystem(line)) has_updates_entry = true;
    }
    if (!has_version_two or !has_updates_entry) {
        std.debug.print(
            "verify-dependabot: malformed — version_two={} updates_entry={} (exit 4)\n",
            .{ has_version_two, has_updates_entry },
        );
        return 4;
    }

    std.debug.print("verify-dependabot: ok\n", .{});
    return 0;
}

// --- verify-contract (SH-017) ----------------------------------------------
//
// Checks each managed repo's Makefile for the 8 SH-014 contract targets:
//   build, test, test-affected, smoke, release-artifacts,
//   ci-branch, ci-patch, ci-release, ci-nightly
//
// (That's 9 — `build` + `test` are the long-standing hooks from .shepherd.yml;
// the other 7 are SH-014's additions. The CAP description says "eight
// contract targets"; `build` + `test` + 7 tiered/entry-point targets.)
//
// Opt-out: `.shepherd.yml` → `contract: { enforce_enabled: false }`. The
// check is section-aware (so a `dependabot: { enforce_enabled: false }`
// does NOT silently opt out the contract verifier).

const CONTRACT_TARGETS = [_][]const u8{
    "build",
    "test",
    "test-affected",
    "smoke",
    "release-artifacts",
    "ci-branch",
    "ci-patch",
    "ci-release",
    "ci-nightly",
};

/// Count the leading-whitespace cells (space or tab). Used to detect YAML
/// section boundaries (a key at indent 0 ends the previous section).
fn leadingWsLen(line: []const u8) usize {
    var i: usize = 0;
    while (i < line.len and (line[i] == ' ' or line[i] == '\t')) : (i += 1) {}
    return i;
}

/// Honours `.shepherd.yml → contract: { enforce_enabled: false }`. Walks
/// the file, tracks whether we're inside the `contract:` section (indented
/// child of a top-level `contract:` key), returns true if an
/// `enforce_enabled: false` line appears inside it.
fn isContractOptOut(contents: []const u8) bool {
    var it = std.mem.splitScalar(u8, contents, '\n');
    var in_contract: bool = false;
    while (it.next()) |line| {
        const trimmed = trimTrailingWs(line);
        const ws = leadingWsLen(trimmed);
        const bare = trimLeadingWs(trimmed);
        if (bare.len == 0 or bare[0] == '#') continue; // blank or comment
        if (ws == 0) {
            // Top-level key: enters (or leaves) a section.
            in_contract = std.mem.startsWith(u8, bare, "contract:");
            continue;
        }
        if (in_contract) {
            if (std.mem.startsWith(u8, bare, "enforce_enabled:")) {
                const rest = trimLeadingWs(bare["enforce_enabled:".len..]);
                if (std.mem.eql(u8, rest, "false")) return true;
            }
        }
    }
    return false;
}

/// Returns true if the Makefile declares `<target>:` (recipe definition)
/// OR lists it after `.PHONY:` or `.PHONY`. Scan is permissive (not a
/// full Make parser): a line starting with `<target>:` at indent 0 is
/// a recipe; a `.PHONY:` line listing the target counts too.
fn makefileHasTarget(contents: []const u8, target: []const u8) bool {
    var it = std.mem.splitScalar(u8, contents, '\n');
    while (it.next()) |line| {
        const stripped = trimTrailingWs(line);
        // Recipe definition: "<target>:" at the start of a line (no leading
        // whitespace). Accept trailing ":" or ": <deps>...".
        if (std.mem.startsWith(u8, stripped, target)) {
            const rest = stripped[target.len..];
            if (rest.len > 0 and rest[0] == ':') return true;
        }
        // .PHONY declaration: look for target as a whitespace-separated token
        // after `.PHONY:` (possibly spanning multi-line with `\`).
        if (std.mem.indexOf(u8, stripped, ".PHONY:") != null) {
            var tok_it = std.mem.tokenizeAny(u8, stripped, " \t\\");
            while (tok_it.next()) |tok| {
                if (std.mem.eql(u8, tok, target)) return true;
            }
        }
    }
    return false;
}

fn cmdVerifyContract(allocator: std.mem.Allocator, io: std.Io, opts: Options) !u8 {
    var root = std.Io.Dir.cwd().openDir(io, opts.root, .{}) catch |err| {
        std.debug.print("error: cannot open root '{s}': {s}\n", .{ opts.root, @errorName(err) });
        return 1;
    };
    defer root.close(io);

    // --- Opt-out check via .shepherd.yml (contract section) --------------
    if (root.readFileAlloc(io, ".shepherd.yml", allocator, .limited(64 * 1024))) |shepherd_cfg| {
        defer allocator.free(shepherd_cfg);
        if (isContractOptOut(shepherd_cfg)) {
            std.debug.print("verify-contract: opted out via .shepherd.yml (contract.enforce_enabled: false)\n", .{});
            return 0;
        }
    } else |err| switch (err) {
        error.FileNotFound => {}, // no .shepherd.yml — default is enforce_enabled: true
        else => return err,
    }

    // --- Presence check: Makefile ----------------------------------------
    const contents = root.readFileAlloc(io, "Makefile", allocator, .limited(512 * 1024)) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("verify-contract: Makefile is missing (exit 3)\n", .{});
            return 3;
        },
        else => {
            std.debug.print("verify-contract: cannot read Makefile: {s}\n", .{@errorName(err)});
            return 1;
        },
    };
    defer allocator.free(contents);

    // --- Also read mk/ci.mk if the Makefile `include`s it (SH-044) --------
    // Targets defined in the master include count toward contract coverage.
    var combined: []const u8 = contents;
    var owned: ?[]u8 = null;
    defer if (owned) |b| allocator.free(b);
    if (std.mem.indexOf(u8, contents, "include mk/ci.mk") != null) {
        if (root.readFileAlloc(io, "mk/ci.mk", allocator, .limited(256 * 1024))) |mk| {
            defer allocator.free(mk);
            const merged = try allocator.alloc(u8, contents.len + 1 + mk.len);
            @memcpy(merged[0..contents.len], contents);
            merged[contents.len] = '\n';
            @memcpy(merged[contents.len + 1 ..], mk);
            owned = merged;
            combined = merged;
        } else |err| switch (err) {
            error.FileNotFound => {}, // include line present but file missing — fall through; targets will show as missing
            else => return err,
        }
    }

    // --- Target coverage -------------------------------------------------
    var missing_count: usize = 0;
    for (CONTRACT_TARGETS) |t| {
        if (!makefileHasTarget(combined, t)) {
            std.debug.print("verify-contract: missing target `{s}`\n", .{t});
            missing_count += 1;
        }
    }
    if (missing_count > 0) {
        std.debug.print(
            "verify-contract: {d} of {d} SH-014 contract target(s) missing (exit 4)\n",
            .{ missing_count, CONTRACT_TARGETS.len },
        );
        return 4;
    }

    std.debug.print("verify-contract: ok ({d}/{d} contract targets present)\n", .{ CONTRACT_TARGETS.len, CONTRACT_TARGETS.len });
    return 0;
}

// ---------------------------------------------------------------------------
// --verify-prepush (SH-033): verify a pre-push gate is wired on this repo.
// Accepts two forms:
//   (a) .pre-commit-config.yaml containing a hook with `entry: make check`
//       inside a `stages: [pre-push]` block (or a stages wildcard).
//   (b) .husky/pre-push script that invokes `make check`.
// Exit 3 if neither file exists; exit 4 if present but doesn't call `make check`.
// ---------------------------------------------------------------------------

/// Return true if the pre-commit config has a hook whose entry is `make check`
/// AND whose stages list includes `pre-push`. Permissive block-scanning
/// (not a full YAML parser): look for consecutive lines matching the two
/// invariants within the same hook.
fn preCommitHasMakeCheck(contents: []const u8) bool {
    var it = std.mem.splitScalar(u8, contents, '\n');
    var saw_make_check_entry = false;
    var saw_pre_push_stage = false;
    while (it.next()) |raw| {
        const line = trimTrailingWs(raw);
        // Reset on a new `- id:` line (next hook).
        const t = trimLeadingWs(line);
        if (std.mem.startsWith(u8, t, "- id:")) {
            if (saw_make_check_entry and saw_pre_push_stage) return true;
            saw_make_check_entry = false;
            saw_pre_push_stage = false;
            continue;
        }
        // `entry: ... make check ...` — permissive: accept wrappers like
        // `bash -c 'source .venv/bin/activate && make check'`.
        if (std.mem.startsWith(u8, t, "entry:")) {
            const rest = t[6..];
            if (std.mem.indexOf(u8, rest, "make check") != null) {
                saw_make_check_entry = true;
            }
        }
        // `stages: [pre-push]` or `stages: [pre-push, ...]`.
        if (std.mem.startsWith(u8, t, "stages:")) {
            const rest = trimLeadingWs(t[7..]);
            if (std.mem.indexOf(u8, rest, "pre-push") != null) {
                saw_pre_push_stage = true;
            }
        }
    }
    return saw_make_check_entry and saw_pre_push_stage;
}

fn huskyPrePushHasMakeCheck(contents: []const u8) bool {
    // Any line containing `make check` (comments stripped by substring match).
    return std.mem.indexOf(u8, contents, "make check") != null;
}

fn cmdVerifyPrepush(allocator: std.mem.Allocator, io: std.Io, opts: Options) !u8 {
    var root = std.Io.Dir.cwd().openDir(io, opts.root, .{}) catch |err| {
        std.debug.print("error: cannot open root '{s}': {s}\n", .{ opts.root, @errorName(err) });
        return 1;
    };
    defer root.close(io);

    // --- Opt-out check via .shepherd.yml (dev-cycle section) ------------
    if (root.readFileAlloc(io, ".shepherd.yml", allocator, .limited(64 * 1024))) |cfg| {
        defer allocator.free(cfg);
        var it = std.mem.splitScalar(u8, cfg, '\n');
        var in_dev_cycle = false;
        while (it.next()) |raw| {
            const t = trimLeadingWs(trimTrailingWs(raw));
            if (std.mem.startsWith(u8, t, "dev_cycle:")) {
                in_dev_cycle = true;
                continue;
            }
            // Leaving the block: a non-indented key-like line.
            if (in_dev_cycle and raw.len > 0 and raw[0] != ' ' and raw[0] != '\t') {
                in_dev_cycle = false;
            }
            if (in_dev_cycle and std.mem.startsWith(u8, t, "prepush_enforce:")) {
                const rest = trimLeadingWs(t["prepush_enforce:".len..]);
                if (std.mem.eql(u8, rest, "false")) {
                    std.debug.print("verify-prepush: opted out via .shepherd.yml (dev_cycle.prepush_enforce: false)\n", .{});
                    return 0;
                }
            }
        }
    } else |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    }

    // --- Try .pre-commit-config.yaml first ------------------------------
    if (root.readFileAlloc(io, ".pre-commit-config.yaml", allocator, .limited(256 * 1024))) |cfg| {
        defer allocator.free(cfg);
        if (preCommitHasMakeCheck(cfg)) {
            std.debug.print("verify-prepush: ok (.pre-commit-config.yaml wires `make check` at pre-push)\n", .{});
            return 0;
        }
        std.debug.print("verify-prepush: .pre-commit-config.yaml present but no hook with `entry: make check` + `stages: [pre-push]` (exit 4)\n", .{});
        return 4;
    } else |err| switch (err) {
        error.FileNotFound => {}, // fall through to husky check
        else => return err,
    }

    // --- Then try .husky/pre-push --------------------------------------
    if (root.readFileAlloc(io, ".husky/pre-push", allocator, .limited(256 * 1024))) |cfg| {
        defer allocator.free(cfg);
        if (huskyPrePushHasMakeCheck(cfg)) {
            std.debug.print("verify-prepush: ok (.husky/pre-push invokes `make check`)\n", .{});
            return 0;
        }
        std.debug.print("verify-prepush: .husky/pre-push present but doesn't invoke `make check` (exit 4)\n", .{});
        return 4;
    } else |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    }

    // --- Finally try .githooks/pre-push (SH-043) ------------------------
    // Pattern used by homelab + kernel-test: git config core.hooksPath = .githooks.
    // We cannot read `git config` from a Zig CLI, so we accept the file's presence
    // + content as evidence. The hook-install step must point core.hooksPath at
    // .githooks separately; the verifier does not enforce that git-config value.
    if (root.readFileAlloc(io, ".githooks/pre-push", allocator, .limited(256 * 1024))) |cfg| {
        defer allocator.free(cfg);
        if (huskyPrePushHasMakeCheck(cfg)) {
            std.debug.print("verify-prepush: ok (.githooks/pre-push invokes `make check`; ensure `git config core.hooksPath .githooks` is set)\n", .{});
            return 0;
        }
        std.debug.print("verify-prepush: .githooks/pre-push present but doesn't invoke `make check` (exit 4)\n", .{});
        return 4;
    } else |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    }

    std.debug.print("verify-prepush: no pre-push config found (.pre-commit-config.yaml, .husky/pre-push, or .githooks/pre-push) (exit 3)\n", .{});
    return 3;
}

// ---------------------------------------------------------------------------
// --verify-sha-pin (SH-030): scan .github/workflows/*.yml + .github/actions/
// for any `uses:` ref whose `@<ref>` is NOT a 40-hex SHA. This is the §12
// supply-chain invariant (CVE-2026-33634 — TeamPCP mutable-tag attack).
// ---------------------------------------------------------------------------

const UnpinnedRef = struct {
    file: []u8,
    line_number: usize,
    owner_repo: []u8,  // "owner/repo"
    ref: []u8,          // the non-40-hex ref (e.g. "v4", "main", "sha-xxxxxxx")

    fn deinit(self: UnpinnedRef, allocator: std.mem.Allocator) void {
        allocator.free(self.file);
        allocator.free(self.owner_repo);
        allocator.free(self.ref);
    }
};

/// Parse a line like `uses: owner/repo@<ref>` and return an UnpinnedRef iff
/// the ref is NOT a 40-hex SHA. Returns null for SHA-pinned refs and non-uses
/// lines.
fn parseUsesLineUnpinned(
    allocator: std.mem.Allocator,
    file_path: []const u8,
    line_number: usize,
    line: []const u8,
) !?UnpinnedRef {
    var p: usize = 0;
    while (p < line.len and (line[p] == ' ' or line[p] == '\t')) p += 1;
    if (p < line.len and line[p] == '-') {
        p += 1;
        while (p < line.len and (line[p] == ' ' or line[p] == '\t')) p += 1;
    }

    const keyword = "uses:";
    if (p + keyword.len > line.len) return null;
    if (!std.mem.eql(u8, line[p .. p + keyword.len], keyword)) return null;
    p += keyword.len;

    var saw_ws = false;
    while (p < line.len and (line[p] == ' ' or line[p] == '\t')) : (p += 1) saw_ws = true;
    if (!saw_ws) return null;

    // Local-repo refs + docker:// refs: exempt.
    if (p < line.len and line[p] == '.') return null;
    if (p + 9 <= line.len and std.mem.eql(u8, line[p .. p + 9], "docker://")) return null;

    const owner_start = p;
    while (p < line.len and isIdentChar(line[p])) p += 1;
    if (p == owner_start) return null;

    if (p >= line.len or line[p] != '/') return null;
    p += 1;

    while (p < line.len and isIdentChar(line[p])) p += 1;

    // Internal sub-path: `owner/repo/path/to/workflow.yml@ref`.
    while (p < line.len and line[p] == '/') {
        p += 1;
        while (p < line.len and isIdentChar(line[p])) p += 1;
    }

    if (p >= line.len or line[p] != '@') return null;
    const owner_repo_end = p;
    p += 1;

    const ref_start = p;
    while (p < line.len and
        line[p] != ' ' and line[p] != '\t' and
        line[p] != '#' and line[p] != '\r' and line[p] != '\n') p += 1;
    const ref = line[ref_start..p];
    if (ref.len == 0) return null;
    if (isHex40(ref)) return null;

    return UnpinnedRef{
        .file = try allocator.dupe(u8, file_path),
        .line_number = line_number,
        .owner_repo = try allocator.dupe(u8, line[owner_start..owner_repo_end]),
        .ref = try allocator.dupe(u8, ref),
    };
}

fn listUnpinnedInFile(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    rel_path: []const u8,
    refs: *std.ArrayList(UnpinnedRef),
) !void {
    const contents = try root.readFileAlloc(io, rel_path, allocator, .limited(1 * 1024 * 1024));
    defer allocator.free(contents);

    var it = std.mem.splitScalar(u8, contents, '\n');
    var line_number: usize = 0;
    while (it.next()) |line| {
        line_number += 1;
        if (try parseUsesLineUnpinned(allocator, rel_path, line_number, line)) |ref| {
            try refs.append(allocator, ref);
        }
    }
}

fn scanUnpinnedWorkflowsDir(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    refs: *std.ArrayList(UnpinnedRef),
) !void {
    var dir = root.openDir(io, ".github/workflows", .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound => return,
        else => return err,
    };
    defer dir.close(io);

    var it = dir.iterate();
    while (try it.next(io)) |entry| {
        if (entry.kind != .file) continue;
        const name = entry.name;
        const is_yaml = std.mem.endsWith(u8, name, ".yml") or std.mem.endsWith(u8, name, ".yaml");
        if (!is_yaml) continue;
        const rel = try std.fmt.allocPrint(allocator, ".github/workflows/{s}", .{name});
        defer allocator.free(rel);
        try listUnpinnedInFile(allocator, io, root, rel, refs);
    }
}

fn scanUnpinnedActionsDir(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    refs: *std.ArrayList(UnpinnedRef),
) !void {
    var top = root.openDir(io, ".github/actions", .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound => return,
        else => return err,
    };
    defer top.close(io);

    var walker = try top.walk(allocator);
    defer walker.deinit();

    while (try walker.next(io)) |entry| {
        if (entry.kind != .file) continue;
        if (!(std.mem.eql(u8, entry.basename, "action.yml") or std.mem.eql(u8, entry.basename, "action.yaml"))) continue;
        const rel = try std.fmt.allocPrint(allocator, ".github/actions/{s}", .{entry.path});
        defer allocator.free(rel);
        try listUnpinnedInFile(allocator, io, root, rel, refs);
    }
}

fn cmdVerifyShaPin(allocator: std.mem.Allocator, io: std.Io, opts: Options) !u8 {
    var root = std.Io.Dir.cwd().openDir(io, opts.root, .{}) catch |err| {
        std.debug.print("error: cannot open root '{s}': {s}\n", .{ opts.root, @errorName(err) });
        return 1;
    };
    defer root.close(io);

    var refs: std.ArrayList(UnpinnedRef) = .empty;
    defer {
        for (refs.items) |r| r.deinit(allocator);
        refs.deinit(allocator);
    }

    try scanUnpinnedWorkflowsDir(allocator, io, root, &refs);
    try scanUnpinnedActionsDir(allocator, io, root, &refs);

    if (refs.items.len == 0) {
        std.debug.print("verify-sha-pin: ok (all uses: refs are SHA-pinned)\n", .{});
        return 0;
    }

    for (refs.items) |r| {
        std.debug.print(
            "verify-sha-pin: unpinned uses: ref {s}:{d} — {s}@{s}\n",
            .{ r.file, r.line_number, r.owner_repo, r.ref },
        );
    }
    std.debug.print(
        "verify-sha-pin: {d} unpinned uses: ref(s) (exit 4) — supply-chain invariant §12 violated\n",
        .{refs.items.len},
    );
    return 4;
}

// ---------------------------------------------------------------------------
// --verify-timeouts (SH-039): each tier workflow's `jobs.<name>.timeout-minutes`
// must be present and within the tier budget. Tier budgets from SH-014:
//   ci-branch.yml  → ≤ 5  min
//   ci-patch.yml   → ≤ 5  min
//   ci-release.yml → ≤ 15 min
//   ci-nightly.yml → ≤ 120 min (soft cap; unbounded by contract but workflows
//                   should still carry a timeout to prevent zombie runs)
// Missing workflow file: exit 3. Missing timeout-minutes: or over-budget: exit 4.
// Workflows not in the tier set are ignored.
// ---------------------------------------------------------------------------

const TierBudget = struct {
    workflow: []const u8,
    max_minutes: u32,
};

const TIER_BUDGETS = [_]TierBudget{
    .{ .workflow = "ci-branch.yml", .max_minutes = 5 },
    .{ .workflow = "ci-patch.yml", .max_minutes = 5 },
    .{ .workflow = "ci-release.yml", .max_minutes = 15 },
    .{ .workflow = "ci-nightly.yml", .max_minutes = 120 },
};

/// Scan a workflow file for the highest `timeout-minutes:` value present in
/// any job. Returns null if the key is absent. Permissive YAML scan (not a
/// full parser) — matches `    timeout-minutes: <N>` at any indent.
fn readMaxTimeout(contents: []const u8) ?u32 {
    var max: ?u32 = null;
    var it = std.mem.splitScalar(u8, contents, '\n');
    while (it.next()) |raw| {
        const line = trimTrailingWs(raw);
        const t = trimLeadingWs(line);
        const key = "timeout-minutes:";
        if (!std.mem.startsWith(u8, t, key)) continue;
        var rest = trimLeadingWs(t[key.len..]);
        // Strip inline comment.
        if (std.mem.indexOfScalar(u8, rest, '#')) |hash_pos| {
            rest = trimTrailingWs(rest[0..hash_pos]);
        }
        const val = std.fmt.parseInt(u32, rest, 10) catch continue;
        if (max == null or val > max.?) max = val;
    }
    return max;
}

fn cmdVerifyTimeouts(allocator: std.mem.Allocator, io: std.Io, opts: Options) !u8 {
    var root = std.Io.Dir.cwd().openDir(io, opts.root, .{}) catch |err| {
        std.debug.print("error: cannot open root '{s}': {s}\n", .{ opts.root, @errorName(err) });
        return 1;
    };
    defer root.close(io);

    var fail = false;
    var missing = false;

    for (TIER_BUDGETS) |b| {
        const rel = try std.fmt.allocPrint(allocator, ".github/workflows/{s}", .{b.workflow});
        defer allocator.free(rel);

        const contents = root.readFileAlloc(io, rel, allocator, .limited(1 * 1024 * 1024)) catch |err| switch (err) {
            error.FileNotFound => {
                std.debug.print("verify-timeouts: {s} missing (exit 3)\n", .{rel});
                missing = true;
                continue;
            },
            else => return err,
        };
        defer allocator.free(contents);

        const maybe_max = readMaxTimeout(contents);
        if (maybe_max == null) {
            std.debug.print(
                "verify-timeouts: {s} has no `timeout-minutes:` key — budget {d} min unenforced\n",
                .{ rel, b.max_minutes },
            );
            fail = true;
            continue;
        }
        const max = maybe_max.?;
        if (max > b.max_minutes) {
            std.debug.print(
                "verify-timeouts: {s} timeout-minutes={d} > budget {d} min\n",
                .{ rel, max, b.max_minutes },
            );
            fail = true;
            continue;
        }
        std.debug.print(
            "verify-timeouts: ok {s} timeout-minutes={d} (budget {d})\n",
            .{ rel, max, b.max_minutes },
        );
    }

    if (missing) return 3;
    if (fail) return 4;
    return 0;
}

fn cmdList(allocator: std.mem.Allocator, io: std.Io, opts: Options) !u8 {
    if (!std.mem.eql(u8, opts.ecosystem, "gh-actions")) {
        std.debug.print("error: ecosystem '{s}' not supported (only 'gh-actions')\n", .{opts.ecosystem});
        return 2;
    }

    var root = std.Io.Dir.cwd().openDir(io, opts.root, .{}) catch |err| {
        std.debug.print("error: cannot open root '{s}': {s}\n", .{ opts.root, @errorName(err) });
        return 1;
    };
    defer root.close(io);

    var refs: std.ArrayList(UsesRef) = .empty;
    defer {
        for (refs.items) |r| r.deinit(allocator);
        refs.deinit(allocator);
    }

    try scanWorkflowsDir(allocator, io, root, &refs);
    try scanActionsDir(allocator, io, root, &refs);

    std.sort.block(UsesRef, refs.items, {}, refLess);

    var buf: [4096]u8 = undefined;
    const stdout_file = std.Io.File.stdout();
    var stdout_writer = stdout_file.writer(io, &buf);
    const w = &stdout_writer.interface;
    for (refs.items) |r| {
        try w.print("{s}\t{s}/{s}\t{s}\t{s}\n", .{ r.file, r.owner, r.repo, r.sha, r.version });
    }
    try w.flush();
    return 0;
}

pub fn main(init: std.process.Init) !u8 {
    const allocator = init.gpa;
    const io = init.io;

    // Collect argv into an owned slice so parseArgs can be index-based.
    var argv: std.ArrayList([]const u8) = .empty;
    defer argv.deinit(allocator);
    var it = init.minimal.args.iterate();
    while (it.next()) |a| try argv.append(allocator, a);

    const opts = parseArgs(argv.items) catch {
        printUsage();
        return 2;
    };

    return switch (opts.mode) {
        .help => blk: {
            printUsage();
            break :blk 0;
        },
        .list => try cmdList(allocator, io, opts),
        .verify_dependabot => try cmdVerifyDependabot(allocator, io, opts),
        .verify_contract => try cmdVerifyContract(allocator, io, opts),
        .verify_sha_pin => try cmdVerifyShaPin(allocator, io, opts),
        .verify_prepush => try cmdVerifyPrepush(allocator, io, opts),
        .verify_timeouts => try cmdVerifyTimeouts(allocator, io, opts),
        .check, .pr => blk: {
            std.debug.print("error: --{s} not yet implemented (SH-001 follow-up)\n", .{@tagName(opts.mode)});
            break :blk 2;
        },
    };
}
