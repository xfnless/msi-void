//! Lifecycle state for a wl_buffer owned by a client.

pub const BufferState = enum {
    available,
    busy,
    retired,

    pub fn canPaint(self: BufferState) bool {
        return self == .available;
    }

    pub fn attached(self: *BufferState) void {
        std.debug.assert(self.* == .available);
        self.* = .busy;
    }

    /// Returns true when the backing storage may be freed now.
    pub fn retire(self: *BufferState) bool {
        if (self.* == .available) return true;
        self.* = .retired;
        return false;
    }

    /// Returns true when a retired allocation may now be freed.
    pub fn released(self: *BufferState) bool {
        return switch (self.*) {
            .busy => blk: {
                self.* = .available;
                break :blk false;
            },
            .retired => true,
            .available => false,
        };
    }
};

const std = @import("std");
