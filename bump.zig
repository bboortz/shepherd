//! shepherd-bump — first-party dependency bumper for Shepherd (SH-001).
//!
//! Modes:
//!   shepherd-bump --list                        List pinned `uses:` refs in the repo.
//!   shepherd-bump --check                       Query upstream tags; print bump plan. (TODO)
//!   shepherd-bump --pr                          Open PRs for bumpable deps. (TODO)
//!   shepherd-bump --verify-dependabot           Verify .github/dependabot.yml presence+shape (SH-011).
//!
//! Flags:
//!   --root PATH         Repo root (default: cwd).
//!   --ecosystem NAME    Only `gh-actions` is supported (bump modes only).
//!
//! Exit codes: 0 ok, 1 cannot open root / I/O, 2 usage,
//!             3 dependabot.yml missing, 4 dependabot.yml malformed.
//!
//! See docs/stories/SH-001-retire-renovate.md and
//!     docs/stories/SH-011-dependabot-enforce-automerge.md for scope.

const std = @import("std");

const Mode = enum { list, check, pr, verify_dependabot, help };

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
        .check, .pr => blk: {
            std.debug.print("error: --{s} not yet implemented (SH-001 follow-up)\n", .{@tagName(opts.mode)});
            break :blk 2;
        },
    };
}
