// SPDX-License-Identifier: 0BSD
//! Simple key=value config for tri (~/.config/tri/config or $TRI_CONFIG).

const std = @import("std");
const bindings = @import("bindings.zig");

pub const CommandSpec = struct {
    label: []const u8,
    command: []const u8,
};

pub const Config = struct {
    const default_master_ratio: f32 = 0.62;
    const default_cursor_size: u32 = 28;

    master_ratio: f32 = 0.62,
    cursor_size: u32 = 28,
    cursor_theme: [:0]const u8 = "Adwaita",
    binding_specs: std.ArrayListUnmanaged(bindings.Spec) = .empty,
    startup_specs: std.ArrayListUnmanaged(CommandSpec) = .empty,

    strings: std.ArrayListUnmanaged([]const u8) = .empty,

    pub const Validation = packed struct {
        master_ratio: bool = false,
        cursor_size: bool = false,

        pub fn any(self: Validation) bool {
            return self.master_ratio or self.cursor_size;
        }
    };

    pub fn validate(self: *Config) Validation {
        var changed: Validation = .{};
        if (!std.math.isFinite(self.master_ratio) or self.master_ratio <= 0 or self.master_ratio >= 1) {
            self.master_ratio = default_master_ratio;
            changed.master_ratio = true;
        }
        if (self.cursor_size == 0 or self.cursor_size > 512) {
            self.cursor_size = default_cursor_size;
            changed.cursor_size = true;
        }
        return changed;
    }

    fn validateAndLog(self: *Config) void {
        const changed = self.validate();
        if (changed.master_ratio) std.log.warn("invalid master_ratio; using {d}", .{default_master_ratio});
        if (changed.cursor_size) std.log.warn("invalid cursor_size; using {d}", .{default_cursor_size});
    }

    pub fn deinit(self: *Config, gpa: std.mem.Allocator) void {
        for (self.strings.items) |s| gpa.free(s);
        self.strings.deinit(gpa);
        self.binding_specs.deinit(gpa);
        self.startup_specs.deinit(gpa);
    }

    fn dup(self: *Config, gpa: std.mem.Allocator, value: []const u8) ![]const u8 {
        const copy = try gpa.dupe(u8, value);
        errdefer gpa.free(copy);
        try self.strings.append(gpa, copy);
        return copy;
    }

    fn dupZ(self: *Config, gpa: std.mem.Allocator, value: []const u8) ![:0]const u8 {
        const copy = try gpa.allocSentinel(u8, value.len, 0);
        errdefer gpa.free(copy);
        @memcpy(copy, value);
        try self.strings.append(gpa, copy);
        return copy;
    }

    pub fn apply(self: *Config, gpa: std.mem.Allocator, key: []const u8, value: []const u8) !void {
        if (std.mem.eql(u8, key, "master_ratio")) {
            self.master_ratio = try std.fmt.parseFloat(f32, value);
        } else if (std.mem.eql(u8, key, "cursor_size")) {
            self.cursor_size = try std.fmt.parseInt(u32, value, 10);
        } else if (std.mem.eql(u8, key, "cursor_theme")) {
            self.cursor_theme = try self.dupZ(gpa, value);
        } else if (std.mem.startsWith(u8, key, "start.")) {
            const label = try self.dup(gpa, key["start.".len..]);
            const command = try self.dup(gpa, value);
            try self.startup_specs.append(gpa, .{ .label = label, .command = command });
        } else if (std.mem.startsWith(u8, key, "bind.")) {
            const key_text = try self.dup(gpa, key["bind.".len..]);
            const behavior_text = try self.dup(gpa, value);
            try self.binding_specs.append(gpa, .{ .key_text = key_text, .behavior_text = behavior_text });
        }
    }

    pub fn load(gpa: std.mem.Allocator, io: std.Io) Config {
        var cfg: Config = .{};
        if (std.c.getenv("TRI_CONFIG")) |raw| {
            const path = std.mem.span(raw);
            _ = loadFile(gpa, io, &cfg, path);
            cfg.validateAndLog();
            return cfg;
        }
        if (std.c.getenv("HOME")) |raw| {
            const home = std.mem.span(raw);
            var buf: [512]u8 = undefined;
            if (std.fmt.bufPrint(&buf, "{s}/.config/tri/config", .{home})) |path| {
                if (loadFile(gpa, io, &cfg, path)) {
                    cfg.validateAndLog();
                    return cfg;
                }
            } else |_| {}
        }
        cfg.validateAndLog();
        return cfg;
    }

    fn loadFile(gpa: std.mem.Allocator, io: std.Io, cfg: *Config, path: []const u8) bool {
        const file = std.Io.Dir.cwd().openFile(io, path, .{}) catch return false;
        defer file.close(io);
        const stat = file.stat(io) catch return false;
        if (stat.size > 64 * 1024) return false;
        const size: usize = @intCast(stat.size);
        const data = gpa.alloc(u8, size) catch return false;
        defer gpa.free(data);
        const n = file.readPositionalAll(io, data, 0) catch return false;
        var lines = std.mem.splitScalar(u8, data[0..n], '\n');
        while (lines.next()) |raw| {
            const line = std.mem.trim(u8, raw, " \t\r");
            if (line.len == 0 or line[0] == '#') continue;
            const eq = std.mem.indexOfScalar(u8, line, '=') orelse continue;
            const key = std.mem.trim(u8, line[0..eq], " \t");
            const value = std.mem.trim(u8, line[eq + 1 ..], " \t");
            cfg.apply(gpa, key, value) catch continue;
        }
        return true;
    }
};
