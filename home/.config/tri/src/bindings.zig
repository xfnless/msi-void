//! Generic key-to-command bindings plus tri's small internal action set.

const std = @import("std");
const xkb = @import("xkbcommon");

pub const InternalAction = enum {
    close,
    focus_toggle,
    expand_next,
    expand_prev,
    swap,
    move_expand_next,
    move_expand_prev,
    fill_screen,
    exit,
    flip_ratio,
    flip_columns,
    expand_slot_1,
    expand_slot_2,
    expand_slot_3,
    expand_slot_4,
    expand_slot_5,
    expand_slot_6,
    expand_slot_7,
    expand_slot_8,
    expand_slot_9,
    move_slot_1,
    move_slot_2,
    move_slot_3,
    move_slot_4,
    move_slot_5,
    move_slot_6,
    move_slot_7,
    move_slot_8,
    move_slot_9,
};

pub const Modifiers = packed struct(u4) {
    shift: bool = false,
    ctrl: bool = false,
    alt: bool = false,
    super: bool = false,
};

pub const Binding = struct { mods: Modifiers, keysym: xkb.Keysym };
pub const Behavior = union(enum) { internal: InternalAction, command: []const u8 };
pub const Spec = struct { key_text: []const u8, behavior_text: []const u8 };
pub const ResolvedItem = struct { binding: Binding, behavior: Behavior };

pub const Resolved = struct {
    items: std.ArrayListUnmanaged(ResolvedItem) = .empty,
    invalid_count: usize = 0,
    duplicate_count: usize = 0,

    pub fn deinit(self: *Resolved, gpa: std.mem.Allocator) void {
        self.items.deinit(gpa);
    }
};

pub fn parseKey(raw: []const u8) !Binding {
    const text = std.mem.trim(u8, raw, " \t\r");
    if (text.len == 0) return error.InvalidBinding;
    var mods: Modifiers = .{};
    var keysym: ?xkb.Keysym = null;
    var tokens = std.mem.splitScalar(u8, text, '+');
    while (tokens.next()) |raw_token| {
        const token = std.mem.trim(u8, raw_token, " \t");
        if (token.len == 0) return error.InvalidBinding;
        if (std.ascii.eqlIgnoreCase(token, "Super")) {
            if (mods.super) return error.InvalidBinding;
            mods.super = true;
        } else if (std.ascii.eqlIgnoreCase(token, "Ctrl")) {
            if (mods.ctrl) return error.InvalidBinding;
            mods.ctrl = true;
        } else if (std.ascii.eqlIgnoreCase(token, "Shift")) {
            if (mods.shift) return error.InvalidBinding;
            mods.shift = true;
        } else if (std.ascii.eqlIgnoreCase(token, "Alt")) {
            if (mods.alt) return error.InvalidBinding;
            mods.alt = true;
        } else {
            if (keysym != null or token.len >= 128) return error.InvalidBinding;
            var name_buf: [128]u8 = undefined;
            const name = std.fmt.bufPrintZ(&name_buf, "{s}", .{token}) catch return error.InvalidBinding;
            const parsed = xkb.Keysym.fromName(name, .case_insensitive);
            if (@intFromEnum(parsed) == 0) return error.InvalidBinding;
            keysym = parsed;
        }
    }
    return .{ .mods = mods, .keysym = keysym orelse return error.InvalidBinding };
}

pub fn parseBehavior(raw: []const u8) !Behavior {
    const text = std.mem.trim(u8, raw, " \t\r");
    if (text.len == 0) return error.InvalidBehavior;
    if (text[0] != ':') return .{ .command = text };
    const name = std.mem.trim(u8, text[1..], " \t");
    return .{ .internal = std.meta.stringToEnum(InternalAction, name) orelse return error.InvalidBehavior };
}

pub fn resolve(gpa: std.mem.Allocator, specs: []const Spec) !Resolved {
    var result: Resolved = .{};
    errdefer result.deinit(gpa);
    for (specs) |spec| {
        const binding = parseKey(spec.key_text) catch {
            result.invalid_count += 1;
            continue;
        };
        const behavior = parseBehavior(spec.behavior_text) catch {
            result.invalid_count += 1;
            continue;
        };
        for (result.items.items) |existing| {
            if (std.meta.eql(binding, existing.binding)) break;
        } else {
            try result.items.append(gpa, .{ .binding = binding, .behavior = behavior });
            continue;
        }
        result.duplicate_count += 1;
    }
    return result;
}
