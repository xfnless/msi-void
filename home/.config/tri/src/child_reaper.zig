//! Prevent fire-and-forget commands from becoming zombie children of tri.
//! All direct children are owned here; callers must not wait for them elsewhere.

const std = @import("std");

pub fn install() void {
    const action: std.posix.Sigaction = .{
        .handler = .{ .handler = reap },
        .mask = std.posix.sigemptyset(),
        .flags = std.posix.SA.RESTART | std.posix.SA.NOCLDSTOP,
    };
    std.posix.sigaction(.CHLD, &action, null);
}

fn reap(_: std.posix.SIG) callconv(.c) void {
    const saved_errno = std.c._errno().*;
    defer std.c._errno().* = saved_errno;
    var status: c_int = 0;
    while (std.c.waitpid(-1, &status, std.c.W.NOHANG) > 0) {}
}
