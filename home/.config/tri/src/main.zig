// SPDX-FileCopyrightText: © 2026
// SPDX-License-Identifier: 0BSD
//
// tri: left master + right accordion stack for river ≥0.4

const std = @import("std");
const wayland = @import("wayland");
const xkb = @import("xkbcommon");
const c = @import("c");
const titlebar = @import("titlebar.zig");
const input = @import("input.zig");
const config = @import("config.zig");
const bindings = @import("bindings.zig");
const child_reaper = @import("child_reaper.zig");
const layout = @import("layout.zig");
const model = @import("model.zig");
const river = wayland.client.river;
const wl = wayland.client.wl;
const fatal = std.process.fatal;

const FocusSide = model.FocusSide;
const Action = bindings.InternalAction;

const Output = struct {
    obj: *river.OutputV1,
    removed: bool = false,
    link: wl.list.Link,
    x: i32 = 0,
    y: i32 = 0,
    width: i32 = 0,
    height: i32 = 0,

    fn create(river_output: *river.OutputV1) void {
        const output = wm.gpa.create(Output) catch fatal("Out of memory.", .{});
        output.* = .{ .obj = river_output, .link = undefined };
        output.obj.setListener(*Output, Output.listener, output);
        wm.outputs.append(output);
    }

    fn maybeDestroy(output: *Output) void {
        if (!output.removed) return;
        output.obj.destroy();
        output.link.remove();
        wm.gpa.destroy(output);
    }

    fn listener(_: *river.OutputV1, event: river.OutputV1.Event, output: *Output) void {
        switch (event) {
            .removed => output.removed = true,
            .position => |a| {
                output.x = a.x;
                output.y = a.y;
            },
            .dimensions => |a| {
                output.width = a.width;
                output.height = a.height;
            },
            else => {},
        }
    }
};

const Window = struct {
    obj: *river.WindowV1,
    node: *river.NodeV1,
    link: wl.list.Link,

    new: bool = true,
    closed: bool = false,
    fullscreen_intent: model.FullscreenIntent = .none,
    title: []u8 = "",
    app_id: []u8 = "",
    title_row: bool = false,
    strip: ?titlebar.Chip = null,
    rend_show: bool = false,
    rend_x: i32 = 0,
    rend_y: i32 = 0,
    rend_w: i32 = 0,
    rend_h: i32 = 0,

    width: i32 = 0,
    height: i32 = 0,

    fn listener(_: *river.WindowV1, event: river.WindowV1.Event, window: *Window) void {
        switch (event) {
            .closed => window.closed = true,
            .dimensions => |args| {
                window.width = args.width;
                window.height = args.height;
            },
            .title => |args| {
                if (window.title.len != 0) wm.gpa.free(window.title);
                if (args.title) |t| {
                    window.title = wm.gpa.dupe(u8, std.mem.span(t)) catch "";
                } else {
                    window.title = "";
                }
                if (window.title_row) {
                    if (window.strip) |*chip| chip.invalidatePaint(wm.gpa);
                }
            },
            .app_id => |args| {
                if (window.app_id.len != 0) wm.gpa.free(window.app_id);
                if (args.app_id) |a| {
                    window.app_id = wm.gpa.dupe(u8, std.mem.span(a)) catch "";
                } else {
                    window.app_id = "";
                }
            },
            .exit_fullscreen_requested => window.fullscreen_intent.request(false),
            .fullscreen_requested => window.fullscreen_intent.request(true),
            else => {},
        }
    }

    fn create(river_window: *river.WindowV1) void {
        const window = wm.gpa.create(Window) catch fatal("Out of memory.", .{});
        window.* = .{
            .obj = river_window,
            .node = river_window.getNode() catch fatal("Unable to obtain Window's Node.", .{}),
            .link = undefined,
        };
        window.obj.setListener(*Window, listener, window);
        wm.windows.append(window);
    }

    fn maybeDestroy(window: *Window) void {
        if (!window.closed) return;

        wm.detachWindow(window);

        if (window.strip) |*s| {
            s.destroy(wm.gpa);
            window.strip = null;
        }
        if (window.title.len != 0) {
            wm.gpa.free(window.title);
            window.title = "";
        }
        if (window.app_id.len != 0) {
            wm.gpa.free(window.app_id);
            window.app_id = "";
        }

        var iter = wm.seats.iterator(.forward);
        while (iter.next()) |seat| {
            if (seat.focused == window) seat.focused = null;
        }

        window.node.destroy();
        window.obj.destroy();
        window.link.remove();
        wm.gpa.destroy(window);
    }

    fn manage(window: *Window) void {
        if (window.new) {
            window.new = false;
            window.obj.setCapabilities(.{
                .window_menu = true,
                .maximize = false,
                .fullscreen = true,
                .minimize = false,
            });
            window.obj.informNotFullscreen();
            wm.adoptNew(window);
        }
        switch (window.fullscreen_intent.take()) {
            .none => {},
            .enter => window.obj.informFullscreen(),
            .exit => window.obj.informNotFullscreen(),
        }
    }
};

fn spawnArgv(argv: []const []const u8) void {
    _ = std.process.spawn(wm.io, .{ .argv = argv }) catch |err| {
        std.log.err("spawn {s}: {}", .{ argv[0], err });
    };
}

fn spawnSh(cmd: []const u8) void {
    spawnArgv(&.{ "sh", "-c", cmd });
}

fn startConfiguredCommands() void {
    for (cfg.startup_specs.items) |spec| {
        if (spec.label.len == 0 or std.mem.trim(u8, spec.command, " \t\r").len == 0) {
            std.log.warn("ignored empty start.{s}", .{spec.label});
            continue;
        }
        spawnSh(spec.command);
    }
}

fn slotFromExpandAction(action: Action) ?usize {
    const base = @intFromEnum(Action.expand_slot_1);
    const v = @intFromEnum(action);
    if (v < base or v > @intFromEnum(Action.expand_slot_9)) return null;
    return v - base;
}

fn slotFromMoveAction(action: Action) ?usize {
    const base = @intFromEnum(Action.move_slot_1);
    const v = @intFromEnum(action);
    if (v < base or v > @intFromEnum(Action.move_slot_9)) return null;
    return v - base;
}

fn riverModifiers(mods: bindings.Modifiers) river.SeatV1.Modifiers {
    return .{
        .shift = mods.shift,
        .ctrl = mods.ctrl,
        .mod1 = mods.alt,
        .mod4 = mods.super,
    };
}

const XkbBinding = struct {
    obj: *river.XkbBindingV1,
    seat: *Seat,
    behavior: bindings.Behavior,
    link: wl.list.Link,

    fn listener(_: *river.XkbBindingV1, event: river.XkbBindingV1.Event, binding: *XkbBinding) void {
        switch (event) {
            .pressed => binding.seat.pending_behavior = binding.behavior,
            else => {},
        }
    }

    fn create(seat: *Seat, mods: river.SeatV1.Modifiers, keysym: xkb.Keysym, behavior: bindings.Behavior) void {
        const binding = wm.gpa.create(XkbBinding) catch fatal("Out of memory.", .{});
        const obj = wm.xkb_bindings.getXkbBinding(seat.obj, @intFromEnum(keysym), mods) catch fatal("Out of memory.", .{});
        binding.* = .{
            .obj = obj,
            .seat = seat,
            .behavior = behavior,
            .link = undefined,
        };
        seat.xkb_bindings.append(binding);
        binding.obj.setListener(*XkbBinding, listener, binding);
        binding.obj.enable();
    }

    fn destroy(binding: *XkbBinding) void {
        binding.obj.destroy();
        binding.link.remove();
        wm.gpa.destroy(binding);
    }
};

const Seat = struct {
    obj: *river.SeatV1,
    new: bool = true,
    removed: bool = false,
    link: wl.list.Link,

    focused: ?*Window = null,
    interacted: ?*Window = null,
    shell_pressed: ?*river.ShellSurfaceV1 = null,

    xkb_bindings: wl.list.Head(XkbBinding, .link),
    pending_behavior: ?bindings.Behavior = null,

    fn listener(_: *river.SeatV1, event: river.SeatV1.Event, seat: *Seat) void {
        switch (event) {
            .removed => seat.removed = true,
            .window_interaction => |args| seat.interacted = if (args.window) |w|
                @ptrCast(@alignCast(w.getUserData()))
            else
                null,
            .shell_surface_interaction => |args| {
                seat.shell_pressed = args.shell_surface;
            },
            else => {},
        }
    }

    fn create(river_seat: *river.SeatV1) void {
        const seat = wm.gpa.create(Seat) catch fatal("Out of memory.", .{});
        seat.* = .{
            .obj = river_seat,
            .link = undefined,
            .xkb_bindings = undefined,
        };
        seat.xkb_bindings.init();
        seat.obj.setListener(*Seat, listener, seat);
        wm.seats.append(seat);
    }

    fn maybeDestroy(seat: *Seat) void {
        if (!seat.removed) return;
        while (seat.xkb_bindings.first()) |binding| binding.destroy();
        seat.obj.destroy();
        seat.link.remove();
        wm.gpa.destroy(seat);
    }

    fn focusWindow(seat: *Seat, window: ?*Window) void {
        if (window) |w| {
            seat.obj.focusWindow(w.obj);
        } else {
            seat.obj.clearFocus();
        }
        seat.focused = window;
    }

    fn syncFocusFromLayout(seat: *Seat) void {
        const target: ?*Window = switch (wm.state.focus_side) {
            .master => wm.state.master,
            .stack => if (wm.state.stack.items.len > 0) wm.state.stack.items[wm.state.expanded] else wm.state.master,
        };
        seat.focusWindow(target);
    }

    fn handleAction(seat: *Seat, action: Action) void {
        switch (action) {
            .close => {
                if (seat.focused) |window| window.obj.close();
            },
            .focus_toggle => wm.focusToggle(),
            .expand_next => wm.expandBy(1),
            .expand_prev => wm.expandBy(-1),
            .swap => wm.swapMasterStack(seat),
            .move_expand_next => wm.moveSubjectBy(seat, 1),
            .move_expand_prev => wm.moveSubjectBy(seat, -1),
            .fill_screen => wm.toggleMonocle(),
            .exit => wm.obj.exitSession(),
            .flip_ratio => cfg.master_ratio = layout.flippedRatio(cfg.master_ratio),
            .flip_columns => wm.toggleFlipColumns(),
            .expand_slot_1, .expand_slot_2, .expand_slot_3, .expand_slot_4, .expand_slot_5, .expand_slot_6, .expand_slot_7, .expand_slot_8, .expand_slot_9 => {
                if (slotFromExpandAction(action)) |slot| wm.expandToSlot(slot);
            },
            .move_slot_1, .move_slot_2, .move_slot_3, .move_slot_4, .move_slot_5, .move_slot_6, .move_slot_7, .move_slot_8, .move_slot_9 => {
                if (slotFromMoveAction(action)) |slot| wm.moveSubjectToSlot(seat, slot);
            },
        }
    }

    fn handleBehavior(seat: *Seat, behavior: bindings.Behavior) void {
        switch (behavior) {
            .internal => |action| seat.handleAction(action),
            .command => |command| spawnSh(command),
        }
    }

    fn manage(seat: *Seat) void {
        if (seat.new) {
            seat.new = false;
            seat.obj.setXcursorTheme(cfg.cursor_theme, cfg.cursor_size);
            var resolved = bindings.resolve(wm.gpa, cfg.binding_specs.items) catch fatal("Out of memory.", .{});
            defer resolved.deinit(wm.gpa);
            if (resolved.invalid_count > 0) {
                std.log.warn("ignored {d} invalid key binding(s)", .{resolved.invalid_count});
            }
            if (resolved.duplicate_count > 0) {
                std.log.warn("ignored {d} duplicate key binding(s)", .{resolved.duplicate_count});
            }
            for (resolved.items.items) |item| {
                XkbBinding.create(seat, riverModifiers(item.binding.mods), item.binding.keysym, item.behavior);
            }
        }

        if (seat.pending_behavior) |behavior| seat.handleBehavior(behavior);
        seat.pending_behavior = null;

        if (seat.shell_pressed) |shell| {
            if (wm.stackIndexForShell(shell)) |idx| wm.focusStackIndex(idx);
            seat.shell_pressed = null;
        }

        if (seat.interacted) |w| {
            wm.focusClicked(w);
            seat.interacted = null;
        }

        seat.syncFocusFromLayout();
    }
};

const WindowManager = struct {
    gpa: std.mem.Allocator,
    io: std.Io,

    obj: *river.WindowManagerV1,
    xkb_bindings: *river.XkbBindingsV1,

    outputs: wl.list.Head(Output, .link),
    windows: wl.list.Head(Window, .link),
    seats: wl.list.Head(Seat, .link),

    state: model.Model(*Window) = .{},

    fn primaryOutput(window_manager: *WindowManager) ?*Output {
        var it = window_manager.outputs.iterator(.forward);
        while (it.next()) |o| {
            if (o.width > 0 and o.height > 0) return o;
        }
        return null;
    }

    fn toggleMonocle(window_manager: *WindowManager) void {
        window_manager.state.monocle = !window_manager.state.monocle;
    }

    fn monocleActive(window_manager: *WindowManager) bool {
        return window_manager.state.monocle;
    }

    fn monocleWindow(window_manager: *WindowManager) ?*Window {
        return focusedTiled(window_manager);
    }

    fn raiseLayers(window_manager: *WindowManager) void {
        if (monocleActive(window_manager)) {
            if (monocleWindow(window_manager)) |w| w.node.placeTop();
            return;
        }
        if (window_manager.state.stack.items.len > 0) {
            const exp = window_manager.state.stack.items[window_manager.state.expanded];
            if (!exp.title_row) exp.node.placeTop();
        }
        var si: usize = 0;
        while (si < window_manager.state.stack.items.len) : (si += 1) {
            const w = window_manager.state.stack.items[si];
            if (!w.title_row) continue;
            if (w.strip) |*chip| chip.node.placeTop();
        }
    }

    fn icontains(hay: []const u8, needle: []const u8) bool {
        if (needle.len == 0 or hay.len < needle.len) return false;
        var i: usize = 0;
        while (i + needle.len <= hay.len) : (i += 1) {
            if (std.ascii.eqlIgnoreCase(hay[i..][0..needle.len], needle)) return true;
        }
        return false;
    }

    fn classifyWindow(window: *Window) titlebar.ChipKind {
        if (icontains(window.app_id, "alacritty")) return .shell;
        if (icontains(window.app_id, "helium")) return .browser;
        if (icontains(window.app_id, "mpv") or
            icontains(window.app_id, "imv") or
            icontains(window.app_id, "zathura"))
            return .viewer;
        return .other;
    }

    fn chipTitle(buf: []u8, w: *Window) []const u8 {
        const raw = if (w.title.len != 0) w.title else "";
        if (raw.len == 0) return "…";
        return truncateLabel(buf, raw);
    }

    fn noBorder(window: *Window) void {
        const e: river.WindowV1.Edges = .{
            .top = true,
            .bottom = true,
            .left = true,
            .right = true,
        };
        window.obj.setBorders(e, 0, 0, 0, 0, 0);
    }

    fn truncateLabel(buf: []u8, text: []const u8) []const u8 {
        if (text.len <= buf.len) return text;
        var view = std.unicode.Utf8View.init(text) catch return "…";
        var it = view.iterator();
        var len: usize = 0;
        while (it.nextCodepoint()) |cp| {
            var enc: [4]u8 = undefined;
            const n = std.unicode.utf8Encode(cp, &enc) catch break;
            if (len + n + 1 > buf.len) break;
            @memcpy(buf[len..][0..n], enc[0..n]);
            len += n;
        }
        if (len == 0) return "…";
        buf[len] = '~';
        return buf[0 .. len + 1];
    }

    fn focusedTiled(window_manager: *WindowManager) ?*Window {
        return switch (window_manager.state.focus_side) {
            .master => window_manager.state.master,
            .stack => if (window_manager.state.stack.items.len > 0)
                window_manager.state.stack.items[window_manager.state.expanded]
            else
                window_manager.state.master,
        };
    }

    fn stackIndexOf(window_manager: *WindowManager, window: *Window) ?usize {
        var i: usize = 0;
        while (i < window_manager.state.stack.items.len) : (i += 1) {
            if (window_manager.state.stack.items[i] == window) return i;
        }
        return null;
    }

    fn focusFollowWindow(window_manager: *WindowManager, win: ?*Window) void {
        const w = win orelse return;
        if (window_manager.state.master == w) {
            window_manager.state.focus_side = .master;
            return;
        }
        if (stackIndexOf(window_manager, w)) |idx| {
            window_manager.state.expanded = idx;
            window_manager.state.focus_side = .stack;
        }
    }

    fn moveSubject(window_manager: *WindowManager, seat: *Seat) ?*Window {
        return switch (window_manager.state.focus_side) {
            .master => if (window_manager.state.stack.items.len > 0)
                window_manager.state.stack.items[window_manager.state.expanded]
            else
                null,
            .stack => seat.focused,
        };
    }

    fn moveSubjectBy(window_manager: *WindowManager, seat: *Seat, delta: i32) void {
        const w = moveSubject(window_manager, seat) orelse return;
        if (!window_manager.state.moveBy(w, delta)) return;
        if (window_manager.state.focus_side == .stack) focusFollowWindow(window_manager, w);
    }

    fn moveSubjectToSlot(window_manager: *WindowManager, seat: *Seat, slot: usize) void {
        const w = moveSubject(window_manager, seat) orelse return;
        if (!window_manager.state.moveTo(w, slot)) return;
        if (window_manager.state.focus_side == .stack) focusFollowWindow(window_manager, w);
    }

    fn hideOthersForFill(window_manager: *WindowManager, keep: *Window) void {
        if (window_manager.state.master) |m| clearTitle(m);
        var ti: usize = 0;
        while (ti < window_manager.state.stack.items.len) : (ti += 1) {
            clearTitle(window_manager.state.stack.items[ti]);
        }
        var wit = window_manager.windows.iterator(.forward);
        while (wit.next()) |w| {
            if (w == keep) continue;
            planHide(w);
        }
    }

    fn adoptNew(window_manager: *WindowManager, window: *Window) void {
        window_manager.state.adopt(window_manager.gpa, window) catch fatal("Out of memory.", .{});
    }

    fn stackRemoveAt(window_manager: *WindowManager, index: usize) *Window {
        return window_manager.state.stack.orderedRemove(index);
    }

    fn fixExpandedAfterRemove(window_manager: *WindowManager, index: usize) void {
        if (window_manager.state.stack.items.len == 0) {
            window_manager.state.expanded = 0;
            return;
        }
        if (index < window_manager.state.stack.items.len) {
            window_manager.state.expanded = index;
        } else {
            window_manager.state.expanded = window_manager.state.stack.items.len - 1;
        }
    }

    fn detachWindow(window_manager: *WindowManager, window: *Window) void {
        _ = window_manager.state.detach(window);
    }

    fn focusToggle(window_manager: *WindowManager) void {
        if (window_manager.state.stack.items.len == 0) {
            window_manager.state.focus_side = .master;
            return;
        }
        window_manager.state.focus_side = if (window_manager.state.focus_side == .master) .stack else .master;
    }

    fn expandBy(window_manager: *WindowManager, delta: i32) void {
        if (window_manager.state.stack.items.len < 2) return;
        const j: isize = @as(isize, @intCast(window_manager.state.expanded)) + delta;
        if (j < 0 or j >= window_manager.state.stack.items.len) return;
        window_manager.state.expanded = @intCast(j);
    }

    fn expandToSlot(window_manager: *WindowManager, slot: usize) void {
        if (slot >= window_manager.state.stack.items.len) return;
        window_manager.state.expanded = slot;
    }

    fn focusClicked(window_manager: *WindowManager, window: *Window) void {
        if (window_manager.state.master == window) {
            window_manager.state.focus_side = .master;
            return;
        }
        if (stackIndexOf(window_manager, window)) |idx| {
            window_manager.state.expanded = idx;
            window_manager.state.focus_side = .stack;
        }
    }

    fn swapMasterStack(window_manager: *WindowManager, seat: *Seat) void {
        if (window_manager.state.master == null or window_manager.state.stack.items.len == 0) return;
        const focused = seat.focused orelse return;
        _ = window_manager.state.swapMaster(focused);
    }

    fn focusStackIndex(window_manager: *WindowManager, index: usize) void {
        if (index >= window_manager.state.stack.items.len) return;
        window_manager.state.expanded = index;
        window_manager.state.focus_side = .stack;
    }

    fn stackIndexForShell(window_manager: *WindowManager, shell: *river.ShellSurfaceV1) ?usize {
        var i: usize = 0;
        while (i < window_manager.state.stack.items.len) : (i += 1) {
            if (window_manager.state.stack.items[i].strip) |*chip| {
                if (chip.shell == shell) return i;
            }
        }
        return null;
    }

    fn clearTitle(window: *Window) void {
        window.title_row = false;
        if (window.strip) |*s| {
            s.destroy(wm.gpa);
            window.strip = null;
        }
    }

    fn planShow(window: *Window, x: i32, y: i32, width: i32, height: i32) void {
        window.rend_show = true;
        window.rend_x = x;
        window.rend_y = y;
        window.rend_w = width;
        window.rend_h = height;
    }

    fn planHide(window: *Window) void {
        window.rend_show = false;
    }

    fn applyRenderShow(window: *Window) void {
        const clip = layout.clipBox(window.rend_w, window.rend_h);
        window.obj.setClipBox(clip.x, clip.y, clip.width, clip.height);
        window.obj.show();
        window.node.setPosition(window.rend_x, window.rend_y);
    }

    fn layoutRender(window_manager: *WindowManager) void {
        var wit = window_manager.windows.iterator(.forward);
        while (wit.next()) |w| {
            if (!w.rend_show) w.obj.hide();
        }
        wit = window_manager.windows.iterator(.forward);
        while (wit.next()) |w| {
            if (w.rend_show) applyRenderShow(w);
        }
    }

    fn toggleFlipColumns(window_manager: *WindowManager) void {
        window_manager.state.stack_on_left = !window_manager.state.stack_on_left;
    }

    fn layoutManage(window_manager: *WindowManager) void {
        const output = window_manager.primaryOutput() orelse return;
        const ox = output.x;
        const oy = output.y;
        const ow = output.width;
        const oh = output.height;

        var wit = window_manager.windows.iterator(.forward);
        while (wit.next()) |w| planHide(w);

        if (monocleActive(window_manager)) {
            if (monocleWindow(window_manager)) |w| {
                hideOthersForFill(window_manager, w);
                w.obj.useSsd();
                w.obj.proposeDimensions(ow, oh);
                planShow(w, ox, oy, ow, oh);
            }
            return;
        }

        if (window_manager.state.master) |m| {
            m.obj.useSsd();
            clearTitle(m);

            if (window_manager.state.stack.items.len == 0) {
                m.obj.proposeDimensions(ow, oh);
                planShow(m, ox, oy, ow, oh);
                return;
            }

            const cols = layout.columns(ox, ow, cfg.master_ratio, window_manager.state.stack_on_left);
            const mw = cols.master_w;
            const sw = cols.stack_w;
            const mx = cols.master_x;
            const sx = cols.stack_x;
            m.obj.proposeDimensions(mw, oh);
            planShow(m, mx, oy, mw, oh);

            const chip_h = titlebar.chipHeight();
            titlebar.stack_on_left = window_manager.state.stack_on_left;
            const rows = window_manager.gpa.alloc(layout.Row, window_manager.state.stack.items.len) catch
                fatal("Out of memory.", .{});
            defer window_manager.gpa.free(rows);
            const row_count = layout.accordion(
                oh,
                window_manager.state.stack.items.len,
                window_manager.state.expanded,
                chip_h,
                rows,
            );
            for (rows[0..row_count]) |row| {
                const i = row.slot;
                const w = window_manager.state.stack.items[i];
                w.obj.useSsd();
                if (row.expanded) {
                    const was_row = w.title_row;
                    clearTitle(w);
                    if (was_row or w.width != sw or w.height != row.height) {
                        w.obj.proposeDimensions(sw, row.height);
                    }
                    planShow(w, sx, oy + row.y, sw, row.height);
                } else {
                    const was_row = w.title_row;
                    if (!was_row or w.width != sw or w.height != row.height) {
                        w.obj.proposeDimensions(sw, row.height);
                    }
                    planHide(w);
                    w.title_row = true;
                    if (w.strip == null) w.strip = titlebar.Chip.create() catch null;
                    if (w.strip) |*chip| {
                        var title_buf: [120]u8 = undefined;
                        const title = chipTitle(&title_buf, w);
                        chip.setChip(window_manager.gpa, layout.userSlot(i), title, classifyWindow(w));
                        chip.layout(sx, oy + row.y, sw, row.height);
                    }
                }
            }
            for (window_manager.state.stack.items, 0..) |w, i| {
                var visible = false;
                for (rows[0..row_count]) |row| {
                    if (row.slot == i) {
                        visible = true;
                        break;
                    }
                }
                if (!visible) clearTitle(w);
            }
        } else if (window_manager.state.stack.items.len > 0) {
            window_manager.state.master = window_manager.stackRemoveAt(0);
            window_manager.fixExpandedAfterRemove(0);
            window_manager.layoutManage();
            return;
        }
    }

    fn manageStart(window_manager: *WindowManager) void {
        var windows_iter = window_manager.windows.iterator(.forward);
        var outputs_iter = window_manager.outputs.iterator(.forward);
        var seats_iter = window_manager.seats.iterator(.forward);
        while (windows_iter.next()) |window| window.maybeDestroy();
        while (outputs_iter.next()) |output| output.maybeDestroy();
        while (seats_iter.next()) |seat| seat.maybeDestroy();

        seats_iter = window_manager.seats.iterator(.forward);
        windows_iter = window_manager.windows.iterator(.forward);
        while (seats_iter.next()) |seat| seat.manage();
        while (windows_iter.next()) |window| window.manage();

        window_manager.layoutManage();
        window_manager.obj.manageFinish();
    }

    fn renderStart(window_manager: *WindowManager) void {
        window_manager.layoutRender();

        var wit = window_manager.windows.iterator(.forward);
        while (wit.next()) |w| noBorder(w);

        const hide_chips = monocleActive(window_manager);

        if (!hide_chips) {
            var i: usize = 0;
            while (i < window_manager.state.stack.items.len) : (i += 1) {
                const w = window_manager.state.stack.items[i];
                if (!w.title_row) continue;
                if (w.strip) |*chip| chip.render(window_manager.gpa);
            }
        }

        window_manager.raiseLayers();

        window_manager.obj.renderFinish();
    }

    fn listener(_: *river.WindowManagerV1, event: river.WindowManagerV1.Event, _: ?*anyopaque) void {
        switch (event) {
            .unavailable => fatal("Another window manager is already running.", .{}),
            .finished => std.process.exit(0),
            .manage_start => wm.manageStart(),
            .render_start => wm.renderStart(),
            .window => |ev| Window.create(ev.id),
            .output => |ev| Output.create(ev.id),
            .seat => |ev| Seat.create(ev.id),
            else => {},
        }
    }
};

const Globals = struct {
    river_window_manager_v1: ?*river.WindowManagerV1 = null,
    river_xkb_bindings_v1: ?*river.XkbBindingsV1 = null,
    wl_compositor: ?*wl.Compositor = null,
    wl_shm: ?*wl.Shm = null,
};

fn registryListener(
    registry: *wl.Registry,
    event: wl.Registry.Event,
    globals: *Globals,
) void {
    switch (event) {
        .global => |ev| {
            if (std.mem.orderZ(u8, river.WindowManagerV1.interface.name, ev.interface) == .eq) {
                if (ev.version < 4) fatal("Expected river wm version to be a least 4.", .{});
                const river_wm = registry.bind(ev.name, river.WindowManagerV1, 4) catch
                    fatal("Out of memory.", .{});
                globals.river_window_manager_v1 = river_wm;
                river_wm.setListener(?*anyopaque, WindowManager.listener, null);
            } else if (std.mem.orderZ(u8, river.XkbBindingsV1.interface.name, ev.interface) == .eq) {
                globals.river_xkb_bindings_v1 = registry.bind(ev.name, river.XkbBindingsV1, 3) catch
                    fatal("Out of memory.", .{});
            } else if (std.mem.orderZ(u8, wl.Compositor.interface.name, ev.interface) == .eq) {
                globals.wl_compositor = registry.bind(ev.name, wl.Compositor, 4) catch
                    fatal("Out of memory.", .{});
            } else if (std.mem.orderZ(u8, wl.Shm.interface.name, ev.interface) == .eq) {
                globals.wl_shm = registry.bind(ev.name, wl.Shm, 1) catch
                    fatal("Out of memory.", .{});
            } else {
                input.bindFromRegistry(registry, ev.name, ev.interface, ev.version);
            }
        },
        else => {},
    }
}

var wm: WindowManager = undefined;
var cfg: config.Config = undefined;

pub fn main(init: std.process.Init) !void {
    child_reaper.install();
    cfg = config.Config.load(init.gpa, init.io);
    defer cfg.deinit(init.gpa);

    const display = try wl.Display.connect(null);
    defer display.disconnect();

    var globals: Globals = .{};
    const registry = try display.getRegistry();
    registry.setListener(*Globals, registryListener, &globals);

    if (display.roundtrip() != .SUCCESS) fatal("Roundtrip failed.", .{});

    titlebar.compositor = globals.wl_compositor;
    titlebar.shm = globals.wl_shm;
    titlebar.wm_obj = globals.river_window_manager_v1;
    titlebar.init();

    wm = .{
        .gpa = init.gpa,
        .io = init.io,
        .obj = globals.river_window_manager_v1 orelse
            fatal("river_window_manager_v1 not supported by the Wayland server.", .{}),
        .xkb_bindings = globals.river_xkb_bindings_v1 orelse
            fatal("river_xkb_bindings_v1 not supported by the Wayland server.", .{}),
        .seats = undefined,
        .outputs = undefined,
        .windows = undefined,
    };
    wm.seats.init();
    wm.outputs.init();
    wm.windows.init();
    startConfiguredCommands();

    while (true) {
        if (display.dispatch() != .SUCCESS) {
            fatal("Dispatch failed.", .{});
        }
    }
}
