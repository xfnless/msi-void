const std = @import("std");
const config = @import("config.zig");
const layout = @import("layout.zig");
const model = @import("model.zig");
const buffer_state = @import("buffer_state.zig");
const bindings = @import("bindings.zig");
const child_reaper = @import("child_reaper.zig");

test "short-lived child is reaped by the kernel" {
    child_reaper.install();
    const child = try std.process.spawn(std.testing.io, .{ .argv = &.{ "sh", "-c", "exit 0" } });
    const pid = child.id.?;
    var path_buf: [64]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/proc/{d}/status", .{pid});
    var reaped = false;
    for (0..100) |_| {
        const file = std.Io.Dir.cwd().openFile(std.testing.io, path, .{}) catch |err| {
            if (err == error.FileNotFound) {
                reaped = true;
                break;
            }
            return err;
        };
        file.close(std.testing.io);
        try std.testing.io.sleep(.fromMilliseconds(10), .awake);
    }
    try std.testing.expect(reaped);
}

test "binding parser accepts a key from the configuration key" {
    try std.testing.expectEqual(bindings.Binding{
        .mods = .{ .super = true, .ctrl = true, .shift = true },
        .keysym = .q,
    }, try bindings.parseKey("Super+Ctrl+Shift+q"));
    try std.testing.expectEqual(bindings.Binding{
        .mods = .{},
        .keysym = .XF86AudioRaiseVolume,
    }, try bindings.parseKey("XF86AudioRaiseVolume"));
}

test "binding behavior distinguishes internal actions from commands" {
    try std.testing.expectEqual(bindings.Behavior{ .internal = .close }, try bindings.parseBehavior(":close"));
    const command = try bindings.parseBehavior("brightnessctl set 2%+");
    try std.testing.expectEqualStrings("brightnessctl set 2%+", command.command);
    try std.testing.expectError(error.InvalidBehavior, bindings.parseBehavior(":not_an_action"));
}

test "resolver ignores invalid and duplicate entries without failing" {
    const specs = [_]bindings.Spec{
        .{ .key_text = "Super+a", .behavior_text = "alacritty" },
        .{ .key_text = "Super+a", .behavior_text = "helium" },
        .{ .key_text = "Hyper+x", .behavior_text = ":close" },
    };
    var resolved = try bindings.resolve(std.testing.allocator, &specs);
    defer resolved.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), resolved.items.items.len);
    try std.testing.expectEqual(@as(usize, 1), resolved.invalid_count);
    try std.testing.expectEqual(@as(usize, 1), resolved.duplicate_count);
    try std.testing.expectEqualStrings("alacritty", resolved.items.items[0].behavior.command);
}

test "configuration stores arbitrary key to behavior bindings" {
    var cfg: config.Config = .{};
    defer cfg.deinit(std.testing.allocator);
    try cfg.apply(std.testing.allocator, "bind.Super+a", "alacritty");
    try cfg.apply(std.testing.allocator, "bind.Super+s", ":focus_toggle");
    try std.testing.expectEqual(@as(usize, 2), cfg.binding_specs.items.len);
    try std.testing.expectEqualStrings("Super+a", cfg.binding_specs.items[0].key_text);
    try std.testing.expectEqualStrings("alacritty", cfg.binding_specs.items[0].behavior_text);
}

test "configuration preserves ordered arbitrary startup commands" {
    var cfg: config.Config = .{};
    defer cfg.deinit(std.testing.allocator);
    try cfg.apply(std.testing.allocator, "start.audio", "exec pipewire");
    try cfg.apply(std.testing.allocator, "start.my_input", "exec fcitx5");
    try cfg.apply(std.testing.allocator, "start.disabled", "");
    try cfg.apply(std.testing.allocator, "bind.Super+a", "exec alacritty");
    try std.testing.expectEqual(@as(usize, 3), cfg.startup_specs.items.len);
    try std.testing.expectEqualStrings("audio", cfg.startup_specs.items[0].label);
    try std.testing.expectEqualStrings("exec pipewire", cfg.startup_specs.items[0].command);
    try std.testing.expectEqualStrings("my_input", cfg.startup_specs.items[1].label);
    try std.testing.expectEqualStrings("", cfg.startup_specs.items[2].command);
    try std.testing.expectEqual(@as(usize, 1), cfg.binding_specs.items.len);
}

test "app fullscreen requests stay pending until manage" {
    var intent: model.FullscreenIntent = .none;
    intent.request(true);
    try std.testing.expectEqual(model.FullscreenIntent.enter, intent.take());
    try std.testing.expectEqual(model.FullscreenIntent.none, intent.take());

    intent.request(false);
    try std.testing.expectEqual(model.FullscreenIntent.exit, intent.take());
}

test "configuration validation restores safe defaults" {
    const cases = [_]struct { master: f32, cursor: u32 }{
        .{ .master = 0, .cursor = 0 },
        .{ .master = 1, .cursor = 0 },
        .{ .master = -1, .cursor = 0 },
        .{ .master = std.math.nan(f32), .cursor = 0 },
    };
    for (cases) |case| {
        var cfg: config.Config = .{
            .master_ratio = case.master,
            .cursor_size = case.cursor,
        };
        const changed = cfg.validate();
        try std.testing.expect(changed.master_ratio);
        try std.testing.expect(changed.cursor_size);
        try std.testing.expectEqual(@as(f32, 0.62), cfg.master_ratio);
        try std.testing.expectEqual(@as(u32, 28), cfg.cursor_size);
    }
}

test "buffer state prevents reuse until compositor release" {
    var state: buffer_state.BufferState = .available;
    try std.testing.expect(state.canPaint());
    state.attached();
    try std.testing.expect(!state.canPaint());
    try std.testing.expect(!state.released());
    try std.testing.expect(state.canPaint());
}

test "retired busy buffer frees only when released" {
    var state: buffer_state.BufferState = .available;
    state.attached();
    try std.testing.expect(!state.retire());
    try std.testing.expect(state == .retired);
    try std.testing.expect(state.released());
}

test "available buffer can be retired immediately" {
    var state: buffer_state.BufferState = .available;
    try std.testing.expect(state.retire());
}

test "model preserves insertion and close promotion behavior" {
    var state: model.Model(u8) = .{};
    defer state.deinit(std.testing.allocator);
    try state.adopt(std.testing.allocator, 1);
    try state.adopt(std.testing.allocator, 2);
    try state.adopt(std.testing.allocator, 3);
    try std.testing.expectEqual(@as(?u8, 1), state.master);
    try std.testing.expectEqualSlices(u8, &.{ 2, 3 }, state.stack.items);
    try std.testing.expectEqual(@as(usize, 1), state.expanded);
    try std.testing.expectEqual(model.FocusSide.stack, state.focus_side);

    try std.testing.expect(state.detach(1));
    try std.testing.expectEqual(@as(?u8, 3), state.master);
    try std.testing.expectEqualSlices(u8, &.{2}, state.stack.items);
    try std.testing.expectEqual(model.FocusSide.master, state.focus_side);
}

test "model movement and swap preserve focused item" {
    var state: model.Model(u8) = .{};
    defer state.deinit(std.testing.allocator);
    for (1..5) |id| try state.adopt(std.testing.allocator, @intCast(id));
    state.focus_side = .stack;
    try std.testing.expect(state.moveTo(4, 0));
    try std.testing.expectEqualSlices(u8, &.{ 4, 2, 3 }, state.stack.items);
    try std.testing.expectEqual(@as(usize, 0), state.expanded);
    try std.testing.expect(state.swapMaster(4));
    try std.testing.expectEqual(@as(?u8, 4), state.master);
    try std.testing.expectEqual(@as(u8, 1), state.stack.items[0]);
    try std.testing.expectEqual(model.FocusSide.master, state.focus_side);
}

test "model normalization enforces empty stack invariants" {
    var state: model.Model(u8) = .{ .expanded = 99 };
    defer state.deinit(std.testing.allocator);
    state.normalize();
    try std.testing.expectEqual(@as(usize, 0), state.expanded);
}

test "model rejects duplicate window ids" {
    var state: model.Model(u8) = .{};
    defer state.deinit(std.testing.allocator);
    try state.adopt(std.testing.allocator, 1);
    try std.testing.expectError(error.DuplicateWindow, state.adopt(std.testing.allocator, 1));
    try state.adopt(std.testing.allocator, 2);
    try std.testing.expectError(error.DuplicateWindow, state.adopt(std.testing.allocator, 2));
}

test "columns preserve configured geometry and mirror positions" {
    const normal = layout.columns(100, 1000, 0.62, false);
    try std.testing.expectEqual(layout.Columns{ .master_x = 100, .master_w = 620, .stack_x = 720, .stack_w = 380 }, normal);
    const mirror = layout.columns(100, 1000, 0.62, true);
    try std.testing.expectEqual(layout.Columns{ .master_x = 480, .master_w = 620, .stack_x = 100, .stack_w = 380 }, mirror);
}

test "column ratio swaps the two widths" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.38), layout.flippedRatio(0.62), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.62), layout.flippedRatio(layout.flippedRatio(0.62)), 0.0001);
}

test "stack slots are displayed one based" {
    try std.testing.expectEqual(@as(usize, 1), layout.userSlot(0));
    try std.testing.expectEqual(@as(usize, 9), layout.userSlot(8));
}

test "window clip is limited to its assigned tile" {
    try std.testing.expectEqual(layout.ClipBox{ .x = 0, .y = 0, .width = 620, .height = 1000 }, layout.clipBox(620, 1000));
    try std.testing.expectEqual(layout.ClipBox{ .x = 0, .y = 0, .width = 0, .height = 0 }, layout.clipBox(-5, -1));
}

test "accordion rows fit output even when chips do not" {
    var rows: [10]layout.Row = undefined;
    const n = layout.accordion(100, 10, 5, 20, &rows);
    try std.testing.expectEqual(@as(usize, 10), n);
    try std.testing.expect(rows[5].expanded);
    try std.testing.expectEqual(@as(i32, 100), rows[9].y + rows[9].height);
    for (rows[0..n]) |row| try std.testing.expect(row.height > 0);
}

test "accordion handles tiny and empty outputs without invalid geometry" {
    var rows: [3]layout.Row = undefined;
    try std.testing.expectEqual(@as(usize, 0), layout.accordion(0, 3, 1, 20, &rows));
    const n = layout.accordion(2, 3, 1, 20, &rows);
    try std.testing.expectEqual(@as(usize, 2), n);
    try std.testing.expectEqual(@as(usize, 1), rows[0].slot);
    try std.testing.expectEqual(@as(usize, 2), rows[1].slot);
    try std.testing.expectEqual(@as(i32, 2), rows[1].y + rows[1].height);
}

test "overflow accordion always includes expanded slot" {
    var rows: [3]layout.Row = undefined;
    const n = layout.accordion(3, 10, 8, 20, &rows);
    try std.testing.expectEqual(@as(usize, 3), n);
    try std.testing.expectEqual(@as(usize, 7), rows[0].slot);
    try std.testing.expectEqual(@as(usize, 8), rows[1].slot);
    try std.testing.expect(rows[1].expanded);
}

test "configured output preserves ordinary accordion geometry" {
    var rows: [10]layout.Row = undefined;
    const cases = [_]usize{ 1, 2, 5, 10 };
    for (cases) |count| {
        const expanded = count / 2;
        const n = layout.accordion(1600, count, expanded, 20, &rows);
        try std.testing.expectEqual(count, n);
        try std.testing.expectEqual(@as(i32, 1600) - @as(i32, @intCast(count - 1)) * 20, rows[expanded].height);
        try std.testing.expectEqual(@as(i32, 1600), rows[n - 1].y + rows[n - 1].height);
    }
}

test "configuration validation preserves valid values" {
    var cfg: config.Config = .{
        .master_ratio = 0.7,
        .cursor_size = 32,
    };
    const changed = cfg.validate();
    try std.testing.expect(!changed.any());
    try std.testing.expectEqual(@as(f32, 0.7), cfg.master_ratio);
    try std.testing.expectEqual(@as(u32, 32), cfg.cursor_size);
}
