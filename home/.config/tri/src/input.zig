// SPDX-License-Identifier: 0BSD
//! Keyboard repeat + touchpad/pointer settings (aligned with niri).

const std = @import("std");
const wayland = @import("wayland");
const river = wayland.client.river;
const wl = wayland.client.wl;

const repeat_rate: i32 = 30;
const repeat_delay: i32 = 200;
const scroll_factor: f64 = 0.85;
const accel_speed: f64 = 0.2;

pub fn bindFromRegistry(registry: *wl.Registry, name: u32, interface: [*:0]const u8, version: u32) void {
    if (std.mem.orderZ(u8, river.InputManagerV1.interface.name, interface) == .eq) {
        const ver = @min(version, 2);
        const mgr = registry.bind(name, river.InputManagerV1, ver) catch return;
        mgr.setListener(?*anyopaque, inputManagerListener, null);
    } else if (std.mem.orderZ(u8, river.LibinputConfigV1.interface.name, interface) == .eq) {
        const ver = @min(version, 2);
        const cfg = registry.bind(name, river.LibinputConfigV1, ver) catch return;
        cfg.setListener(?*anyopaque, libinputConfigListener, null);
    }
}

fn inputManagerListener(
    _: *river.InputManagerV1,
    event: river.InputManagerV1.Event,
    _: ?*anyopaque,
) void {
    switch (event) {
        .input_device => |args| {
            args.id.setListener(?*anyopaque, inputDeviceListener, null);
        },
        else => {},
    }
}

fn inputDeviceListener(
    device: *river.InputDeviceV1,
    event: river.InputDeviceV1.Event,
    _: ?*anyopaque,
) void {
    switch (event) {
        .type => |args| {
            switch (args.type) {
                .keyboard => device.setRepeatInfo(repeat_rate, repeat_delay),
                .pointer => device.setScrollFactor(wl.Fixed.fromDouble(scroll_factor)),
                else => {},
            }
        },
        .removed => device.destroy(),
        else => {},
    }
}

fn libinputConfigListener(
    _: *river.LibinputConfigV1,
    event: river.LibinputConfigV1.Event,
    _: ?*anyopaque,
) void {
    switch (event) {
        .libinput_device => |args| {
            args.id.setListener(?*anyopaque, libinputDeviceListener, null);
        },
        else => {},
    }
}

fn libinputDeviceListener(
    device: *river.LibinputDeviceV1,
    event: river.LibinputDeviceV1.Event,
    _: ?*anyopaque,
) void {
    switch (event) {
        .tap_support => |args| {
            if (args.finger_count > 0) applyTouchpad(device);
        },
        .accel_profiles_support => applyAccel(device),
        .removed => device.destroy(),
        else => {},
    }
}

fn ignoreResult(result: *river.LibinputResultV1) void {
    result.setListener(?*anyopaque, struct {
        fn l(_: *river.LibinputResultV1, event: river.LibinputResultV1.Event, _: ?*anyopaque) void {
            switch (event) {
                .success => {},
                .unsupported => std.log.warn("libinput setting unsupported", .{}),
                .invalid => std.log.warn("libinput setting rejected as invalid", .{}),
            }
        }
    }.l, null);
}

fn applyTouchpad(device: *river.LibinputDeviceV1) void {
    ignoreResult(device.setTap(.enabled) catch return);
    ignoreResult(device.setTapButtonMap(.lrm) catch return);
    ignoreResult(device.setDrag(.enabled) catch return);
    ignoreResult(device.setDragLock(.enabled_timeout) catch return);
    ignoreResult(device.setNaturalScroll(.enabled) catch return);
    ignoreResult(device.setClickMethod(.clickfinger) catch return);
    ignoreResult(device.setScrollMethod(.two_finger) catch return);
    ignoreResult(device.setDwt(.enabled) catch return);
    ignoreResult(device.setDwtp(.enabled) catch return);
}

fn applyAccel(device: *river.LibinputDeviceV1) void {
    ignoreResult(device.setAccelProfile(.adaptive) catch return);
    var speed: f64 align(8) = accel_speed;
    var arr = wl.Array{
        .size = @sizeOf(f64),
        .alloc = @sizeOf(f64),
        .data = &speed,
    };
    ignoreResult(device.setAccelSpeed(&arr) catch return);
}
