// SPDX-FileCopyrightText: © 2026 Vladyslav Khardel
// SPDX-License-Identifier: 0BSD

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const scanner = @import("wayland").Scanner.create(b, .{});
    scanner.addCustomProtocol(b.path("protocol/river-window-management-v1.xml"));
    scanner.addCustomProtocol(b.path("protocol/river-xkb-bindings-v1.xml"));
    scanner.addCustomProtocol(b.path("protocol/river-input-management-v1.xml"));
    scanner.addCustomProtocol(b.path("protocol/river-libinput-config-v1.xml"));
    scanner.generate("wl_compositor", 4);
    scanner.generate("wl_shm", 1);
    scanner.generate("river_window_manager_v1", 4);
    scanner.generate("river_xkb_bindings_v1", 3);
    scanner.generate("river_input_manager_v1", 2);
    scanner.generate("river_libinput_config_v1", 2);
    const wayland = b.createModule(.{ .root_source_file = scanner.result });

    const xkbcommon = b.dependency("xkbcommon", .{}).module("xkbcommon");

    const files = b.addWriteFiles();
    const headers = files.add("headers.h",
        \\#include <linux/input-event-codes.h>
        \\#include <fcft/fcft.h>
        \\#include <pixman.h>
    );
    const c_headers = b.addTranslateC(.{
        .root_source_file = headers,
        .optimize = optimize,
        .target = target,
        .link_libc = true,
    });
    c_headers.addIncludePath(.{ .cwd_relative = "/usr/include" });
    c_headers.addIncludePath(.{ .cwd_relative = "/usr/include/pixman-1" });

    const exe = b.addExecutable(.{
        .name = "tri",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "wayland", .module = wayland },
                .{ .name = "xkbcommon", .module = xkbcommon },
                .{ .name = "c", .module = c_headers.createModule() },
            },
        }),
    });

    exe.root_module.linkSystemLibrary("wayland-client", .{});
    exe.root_module.linkSystemLibrary("xkbcommon", .{});
    exe.root_module.linkSystemLibrary("fcft", .{});
    exe.root_module.linkSystemLibrary("pixman-1", .{});
    exe.root_module.addLibraryPath(.{ .cwd_relative = "/usr/lib64" });
    b.installArtifact(exe);

    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tests.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "xkbcommon", .module = xkbcommon },
            },
        }),
    });
    unit_tests.root_module.link_libc = true;
    unit_tests.root_module.linkSystemLibrary("xkbcommon", .{});
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&b.addRunArtifact(unit_tests).step);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
}
