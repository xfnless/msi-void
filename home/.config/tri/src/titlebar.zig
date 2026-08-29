// SPDX-License-Identifier: 0BSD
//! Collapsed stack row: shell chip + fcft (fontconfig generic families).

const std = @import("std");
const wayland = @import("wayland");
const c = @import("c");
const wl = wayland.client.wl;
const river = wayland.client.river;
const BufferState = @import("buffer_state.zig").BufferState;

pub var compositor: ?*wl.Compositor = null;
pub var shm: ?*wl.Shm = null;
pub var wm_obj: ?*river.WindowManagerV1 = null;
pub var stack_on_left: bool = false;

var font: ?*c.fcft_font = null;
var font_px: i32 = 0;

const buf_scale: i32 = 2;
const font_pt: i32 = 11;

fn ensureFont() void {
    if (font != null and font_px == font_pt * buf_scale) return;
    if (font) |f| {
        c.fcft_destroy(f);
        font = null;
    }
    font_px = font_pt * buf_scale;
    var sans_buf: [64]u8 = undefined;
    const sans = std.fmt.bufPrintZ(&sans_buf, "sans-serif:pixelsize={d}", .{font_px}) catch return;
    var serif_buf: [64]u8 = undefined;
    const serif = std.fmt.bufPrintZ(&serif_buf, "serif:pixelsize={d}", .{font_px}) catch return;
    var mono_buf: [64]u8 = undefined;
    const mono = std.fmt.bufPrintZ(&mono_buf, "monospace:pixelsize={d}", .{font_px}) catch return;
    const patterns = [_][*:0]const u8{ sans, serif, mono };
    var names: [3][*c]const u8 = .{ patterns[0], patterns[1], patterns[2] };
    font = c.fcft_from_name(3, &names, null);
    if (font == null) {
        names[0] = patterns[1];
        font = c.fcft_from_name(1, &names, null);
    }
}

pub fn init() void {
    _ = c.fcft_init(c.FCFT_LOG_COLORIZE_NEVER, false, c.FCFT_LOG_CLASS_NONE);
    ensureFont();
}

pub const ChipKind = enum {
    shell,
    browser,
    viewer,
    other,

    pub fn fillArgb(self: ChipKind) u32 {
        return switch (self) {
            .shell => 0xff2a2a2a,
            .browser => 0xff323232,
            .viewer => 0xff3a3a3a,
            .other => 0xff363636,
        };
    }
};

pub fn chipHeight() i32 {
    ensureFont();
    const f = font orelse return 16;
    const pad: i32 = 2;
    const body = @divTrunc(f.ascent + f.descent + buf_scale - 1, buf_scale);
    return body + pad * 2;
}

const BufferAllocation = struct {
    allocator: std.mem.Allocator,
    buffer: *wl.Buffer,
    pool: *wl.ShmPool,
    map: []align(std.heap.page_size_min) u8,
    fd: std.posix.fd_t,
    width: i32,
    height: i32,
    stride: i32,
    state: BufferState = .available,

    fn create(allocator: std.mem.Allocator, sh: *wl.Shm, width: i32, height: i32) !*BufferAllocation {
        const stride = std.math.mul(i32, width, 4) catch return error.InvalidDimensions;
        const signed_bytes = std.math.mul(i32, stride, height) catch return error.InvalidDimensions;
        if (signed_bytes <= 0) return error.InvalidDimensions;
        const bytes: usize = @intCast(signed_bytes);

        const allocation = try allocator.create(BufferAllocation);
        errdefer allocator.destroy(allocation);
        const fd = try std.posix.memfd_create("tri-chip", 0);
        errdefer _ = std.c.close(fd);
        if (std.c.ftruncate(fd, @intCast(bytes)) != 0) return error.TruncateFailed;
        const mapped = try std.posix.mmap(
            null,
            bytes,
            .{ .READ = true, .WRITE = true },
            .{ .TYPE = .SHARED },
            fd,
            0,
        );
        errdefer std.posix.munmap(mapped);
        const pool = try sh.createPool(fd, @intCast(bytes));
        errdefer pool.destroy();
        const buffer = try pool.createBuffer(0, width, height, stride, .argb8888);
        allocation.* = .{
            .allocator = allocator,
            .buffer = buffer,
            .pool = pool,
            .map = mapped,
            .fd = fd,
            .width = width,
            .height = height,
            .stride = stride,
        };
        buffer.setListener(*BufferAllocation, listener, allocation);
        return allocation;
    }

    fn listener(_: *wl.Buffer, event: wl.Buffer.Event, allocation: *BufferAllocation) void {
        switch (event) {
            .release => if (allocation.state.released()) allocation.destroy(),
        }
    }

    fn retire(allocation: *BufferAllocation) void {
        if (allocation.state.retire()) allocation.destroy();
    }

    fn destroy(allocation: *BufferAllocation) void {
        const allocator = allocation.allocator;
        allocation.buffer.destroy();
        allocation.pool.destroy();
        std.posix.munmap(allocation.map);
        _ = std.c.close(allocation.fd);
        allocator.destroy(allocation);
    }
};

pub const Chip = struct {
    surface: *wl.Surface,
    shell: *river.ShellSurfaceV1,
    node: *river.NodeV1,
    width: i32 = 0,
    height: i32 = 0,
    buffers: [2]?*BufferAllocation = .{ null, null },
    x: i32 = 0,
    y: i32 = 0,
    pending_w: i32 = 0,
    pending_h: i32 = 0,
    slot_num: usize = 0,
    label: []u8 = "",
    painted_key: []u8 = "",
    pending_kind: ChipKind = .other,
    paint_error_logged: bool = false,

    pub fn create() !Chip {
        const comp = compositor orelse return error.NoCompositor;
        const wm = wm_obj orelse return error.NoWm;
        const surface = try comp.createSurface();
        errdefer surface.destroy();
        const shell = try wm.getShellSurface(surface);
        errdefer shell.destroy();
        const node = try shell.getNode();
        return .{ .surface = surface, .shell = shell, .node = node };
    }

    pub fn destroy(self: *Chip, gpa: std.mem.Allocator) void {
        for (&self.buffers) |*slot| {
            if (slot.*) |allocation| allocation.retire();
            slot.* = null;
        }
        if (self.label.len != 0) gpa.free(self.label);
        self.label = "";
        if (self.painted_key.len != 0) gpa.free(self.painted_key);
        self.painted_key = "";
        self.node.destroy();
        self.shell.destroy();
        self.surface.destroy();
    }

    pub fn invalidatePaint(self: *Chip, gpa: std.mem.Allocator) void {
        if (self.painted_key.len != 0) {
            gpa.free(self.painted_key);
            self.painted_key = "";
        }
    }

    pub fn setChip(
        self: *Chip,
        gpa: std.mem.Allocator,
        slot_num: usize,
        title: []const u8,
        kind: ChipKind,
    ) void {
        const slot_changed = self.slot_num != slot_num;
        const kind_changed = self.pending_kind != kind;
        self.pending_kind = kind;
        self.slot_num = slot_num;
        if (!kind_changed and !slot_changed and std.mem.eql(u8, self.label, title)) return;
        if (self.label.len != 0) gpa.free(self.label);
        self.label = gpa.dupe(u8, title) catch "";
        if (kind_changed or slot_changed) self.invalidatePaint(gpa);
    }

    pub fn layout(self: *Chip, x: i32, y: i32, w: i32, h: i32) void {
        self.x = x;
        self.y = y;
        self.pending_w = w;
        self.pending_h = h;
    }

    pub fn render(self: *Chip, gpa: std.mem.Allocator) void {
        const w = self.pending_w;
        const h = self.pending_h;
        if (w < 8 or h < 8) return;

        self.node.setPosition(self.x, self.y);

        const title = if (self.label.len != 0) self.label else "…";
        var key_buf: [160]u8 = undefined;
        const key = std.fmt.bufPrint(&key_buf, "{d}|{d}|{d}|{s}|{d}x{d}@{d}", .{
            @intFromEnum(self.pending_kind),
            self.slot_num,
            @intFromBool(stack_on_left),
            title,
            w,
            h,
            buf_scale,
        }) catch return;
        if (std.mem.eql(u8, self.painted_key, key)) return;

        self.paint(gpa, w, h, self.slot_num, title, self.pending_kind) catch |err| {
            if (err != error.BuffersBusy and !self.paint_error_logged) {
                std.log.err("chip paint failed: {}", .{err});
                self.paint_error_logged = true;
            }
            return;
        };
        self.paint_error_logged = false;

        if (self.painted_key.len != 0) gpa.free(self.painted_key);
        self.painted_key = gpa.dupe(u8, key) catch "";
    }

    fn paint(
        self: *Chip,
        gpa: std.mem.Allocator,
        width: i32,
        height: i32,
        slot_num: usize,
        title: []const u8,
        kind: ChipKind,
    ) !void {
        const sh = shm orelse return error.NoShm;
        ensureFont();
        const bw = width * buf_scale;
        const bh = height * buf_scale;
        var selected: ?*BufferAllocation = null;
        for (&self.buffers) |*slot| {
            const allocation = slot.* orelse continue;
            if (!allocation.state.canPaint()) continue;
            if (allocation.width == bw and allocation.height == bh) {
                selected = allocation;
                break;
            }
            allocation.retire();
            slot.* = null;
        }
        if (selected == null) {
            for (&self.buffers) |*slot| {
                if (slot.* != null) continue;
                const allocation = try BufferAllocation.create(gpa, sh, bw, bh);
                slot.* = allocation;
                selected = allocation;
                break;
            }
        }
        const allocation = selected orelse return error.BuffersBusy;
        const stride = allocation.stride;

        const pix = allocation.map;
        const fill = kind.fillArgb();
        var py: i32 = 0;
        while (py < bh) : (py += 1) {
            var px: i32 = 0;
            while (px < bw) : (px += 1) {
                putPixel(pix, stride, px, py, fill);
            }
        }

        if (font) |f| {
            drawChipLabel(pix, bw, bh, stride, slot_num, title, f, stack_on_left);
        }

        self.surface.setBufferScale(buf_scale);
        self.shell.syncNextCommit();
        allocation.state.attached();
        self.surface.attach(allocation.buffer, 0, 0);
        self.surface.damage(0, 0, bw, bh);
        self.surface.commit();
    }
};

fn drawChipLabel(
    pix: []u8,
    width: i32,
    height: i32,
    stride: i32,
    slot_num: usize,
    title: []const u8,
    font_ptr: *c.fcft_font,
    mirror: bool,
) void {
    var slot_buf: [8]u8 = undefined;
    const slot_label = std.fmt.bufPrint(&slot_buf, "{d}", .{slot_num}) catch "0";
    drawTextRun(pix, width, height, stride, slot_label, font_ptr, if (mirror) .right else .left);
    drawTextRun(pix, width, height, stride, title, font_ptr, if (mirror) .left else .right);
}

const HAlign = enum { left, right };

fn drawTextRun(
    pix: []u8,
    width: i32,
    height: i32,
    stride: i32,
    text: []const u8,
    font_ptr: *c.fcft_font,
    halign: HAlign,
) void {
    var cps: [128]u32 = undefined;
    var cp_len: usize = 0;
    var view = std.unicode.Utf8View.init(text) catch return;
    var it = view.iterator();
    while (it.nextCodepoint()) |cp| {
        if (cp_len >= cps.len) break;
        cps[cp_len] = cp;
        cp_len += 1;
    }
    if (cp_len == 0) return;

    const run = c.fcft_rasterize_text_run_utf32(
        font_ptr,
        cp_len,
        &cps,
        c.FCFT_SUBPIXEL_NONE,
    );
    if (run == null) return;
    defer c.fcft_text_run_destroy(run);

    const dest = c.pixman_image_create_bits(
        c.PIXMAN_a8r8g8b8,
        width,
        height,
        @ptrCast(@alignCast(pix.ptr)),
        stride,
    );
    if (dest == null) return;
    defer _ = c.pixman_image_unref(dest);

    var fg: c.pixman_color_t = .{
        .red = 0xf5f5,
        .green = 0xf5f5,
        .blue = 0xf5f5,
        .alpha = 0xffff,
    };
    const color = c.pixman_image_create_solid_fill(&fg);
    if (color == null) return;
    defer _ = c.pixman_image_unref(color);

    const pad_x: i32 = 4 * buf_scale;
    const pad_y: i32 = 2 * buf_scale;
    const baseline = pad_y + font_ptr.*.ascent;

    var text_w: i32 = 0;
    var gi: usize = 0;
    while (gi < run.*.count) : (gi += 1) {
        text_w += run.*.glyphs[gi].*.advance.x;
    }

    const inner = width - pad_x * 2;
    var pen: i32 = switch (halign) {
        .left => pad_x,
        .right => pad_x + @max(0, inner - text_w),
    };

    gi = 0;
    while (gi < run.*.count) : (gi += 1) {
        const g = run.*.glyphs[gi];
        if (g.*.pix == null) {
            pen += g.*.advance.x;
            continue;
        }
        const gx = pen + g.*.x;
        const gy = baseline - g.*.y;
        if (halign == .left and gx + g.*.width > width - pad_x) break;
        if (halign == .right and gx < pad_x) {
            pen += g.*.advance.x;
            continue;
        }

        if (g.*.is_color_glyph) {
            c.pixman_image_composite32(
                c.PIXMAN_OP_OVER,
                g.*.pix,
                null,
                dest,
                0,
                0,
                0,
                0,
                gx,
                gy,
                @intCast(g.*.width),
                @intCast(g.*.height),
            );
        } else {
            c.pixman_image_composite32(
                c.PIXMAN_OP_OVER,
                color,
                g.*.pix,
                dest,
                0,
                0,
                0,
                0,
                gx,
                gy,
                @intCast(g.*.width),
                @intCast(g.*.height),
            );
        }
        pen += g.*.advance.x;
    }
}

fn putPixel(pix: []u8, stride: i32, x: i32, y: i32, color: u32) void {
    if (x < 0 or y < 0) return;
    const i: usize = @intCast(y * stride + x * 4);
    if (i + 4 > pix.len) return;
    @as(*align(1) u32, @ptrCast(pix.ptr + i)).* = color;
}
