//! Pure, saturating geometry for tri.

const std = @import("std");

pub const Columns = struct {
    master_x: i32,
    master_w: i32,
    stack_x: i32,
    stack_w: i32,
};

pub const ClipBox = struct {
    x: i32 = 0,
    y: i32 = 0,
    width: i32,
    height: i32,
};

pub fn clipBox(width: i32, height: i32) ClipBox {
    return .{ .width = @max(0, width), .height = @max(0, height) };
}

pub fn userSlot(index: usize) usize {
    return index + 1;
}

pub fn flippedRatio(ratio: f32) f32 {
    return 1.0 - ratio;
}

pub const Row = struct {
    slot: usize,
    y: i32,
    height: i32,
    expanded: bool,
};

pub fn columns(origin_x: i32, width: i32, ratio: f32, mirrored: bool) Columns {
    const safe_width = @max(0, width);
    const raw: i32 = @intFromFloat(@as(f32, @floatFromInt(safe_width)) * ratio);
    const master_w = std.math.clamp(raw, 0, safe_width);
    const stack_w = safe_width - master_w;
    return if (mirrored)
        .{ .master_x = origin_x + stack_w, .master_w = master_w, .stack_x = origin_x, .stack_w = stack_w }
    else
        .{ .master_x = origin_x, .master_w = master_w, .stack_x = origin_x + master_w, .stack_w = stack_w };
}

pub fn accordion(
    output_height: i32,
    count: usize,
    expanded_index: usize,
    preferred_chip_height: i32,
    out: []Row,
) usize {
    if (output_height <= 0 or count == 0 or out.len == 0) return 0;
    const visible_count = @min(count, @min(out.len, @as(usize, @intCast(output_height))));
    const expanded_slot = @min(expanded_index, count - 1);
    const normal_start = @min(expanded_slot, count - visible_count);
    const expanded_row = expanded_slot - normal_start;
    const chip_h = @max(1, @min(preferred_chip_height, @divTrunc(output_height, @as(i32, @intCast(visible_count)))));

    const expanded_h: i32 = output_height - @as(i32, @intCast(visible_count - 1)) * chip_h;

    var used: i32 = 0;
    for (0..visible_count) |i| {
        const remaining = output_height - used;
        const h = @min(if (i == expanded_row) expanded_h else chip_h, remaining);
        const slot = normal_start + i;
        out[i] = .{ .slot = slot, .y = used, .height = h, .expanded = i == expanded_row };
        used += h;
    }
    if (used < output_height) out[visible_count - 1].height += output_height - used;
    return visible_count;
}
