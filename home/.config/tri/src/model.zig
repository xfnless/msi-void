//! Compositor-independent tri window state.

const std = @import("std");

pub const FocusSide = enum { master, stack };

pub const FullscreenIntent = enum {
    none,
    enter,
    exit,

    pub fn request(self: *FullscreenIntent, fullscreen: bool) void {
        self.* = if (fullscreen) .enter else .exit;
    }

    pub fn take(self: *FullscreenIntent) FullscreenIntent {
        const pending = self.*;
        self.* = .none;
        return pending;
    }
};

pub fn Model(comptime WindowId: type) type {
    return struct {
        const Self = @This();

        master: ?WindowId = null,
        stack: std.ArrayListUnmanaged(WindowId) = .empty,
        expanded: usize = 0,
        focus_side: FocusSide = .master,
        stack_on_left: bool = false,
        monocle: bool = false,

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            self.stack.deinit(allocator);
        }

        pub fn normalize(self: *Self) void {
            if (self.stack.items.len == 0) {
                self.expanded = 0;
                self.focus_side = .master;
            } else if (self.expanded >= self.stack.items.len) {
                self.expanded = self.stack.items.len - 1;
            }
        }

        pub fn indexOf(self: *const Self, id: WindowId) ?usize {
            for (self.stack.items, 0..) |candidate, i| {
                if (candidate == id) return i;
            }
            return null;
        }

        pub fn adopt(self: *Self, allocator: std.mem.Allocator, id: WindowId) !void {
            if (self.master == id or self.indexOf(id) != null) return error.DuplicateWindow;
            if (self.master == null and self.stack.items.len == 0) {
                self.master = id;
                self.focus_side = .master;
                return;
            }
            const insertion = @min(self.expanded + 1, self.stack.items.len);
            try self.stack.insert(allocator, insertion, id);
            self.expanded = insertion;
            self.focus_side = .stack;
            self.normalize();
        }

        pub fn detach(self: *Self, id: WindowId) bool {
            if (self.master == id) {
                if (self.stack.items.len == 0) {
                    self.master = null;
                } else {
                    self.master = self.stack.orderedRemove(self.expanded);
                }
                self.focus_side = .master;
                self.normalize();
                return true;
            }
            const index = self.indexOf(id) orelse return false;
            _ = self.stack.orderedRemove(index);
            if (self.expanded > index) self.expanded -= 1;
            self.normalize();
            return true;
        }

        pub fn moveTo(self: *Self, id: WindowId, destination: usize) bool {
            const source = self.indexOf(id) orelse return false;
            if (destination >= self.stack.items.len) return false;
            if (source == destination) return true;
            const item = self.stack.orderedRemove(source);
            self.stack.insertAssumeCapacity(destination, item);
            if (self.expanded == source) {
                self.expanded = destination;
            } else if (source < self.expanded and destination >= self.expanded) {
                self.expanded -= 1;
            } else if (source > self.expanded and destination <= self.expanded) {
                self.expanded += 1;
            }
            return true;
        }

        pub fn moveBy(self: *Self, id: WindowId, delta: i32) bool {
            const source = self.indexOf(id) orelse return false;
            const destination = @as(isize, @intCast(source)) + delta;
            if (destination < 0 or destination >= self.stack.items.len) return false;
            return self.moveTo(id, @intCast(destination));
        }

        pub fn swapMaster(self: *Self, focused: WindowId) bool {
            const master = self.master orelse return false;
            if (self.stack.items.len == 0) return false;
            const index = if (focused == master) self.expanded else self.indexOf(focused) orelse return false;
            const stack_item = self.stack.items[index];
            self.master = stack_item;
            self.stack.items[index] = master;
            if (focused == master) {
                self.expanded = index;
                self.focus_side = .stack;
            } else {
                self.focus_side = .master;
            }
            return true;
        }
    };
}
