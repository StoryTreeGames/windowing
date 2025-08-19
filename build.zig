const std = @import("std");
const Tag = std.Target.Os.Tag;
const builtin = @import("builtin");

const Scanner = @import("wayland").Scanner;

const NAME = "storytree-core";
const EXAMPLES = "examples";

const examples = [_]Example{
    .{
        .name = "dev",
        .path = EXAMPLES ++ "/dev.zig",
    },
    .{
        .name = "wgpu",
        .path = EXAMPLES ++ "/wgpu/main.zig",
    },
    .{
        .name = "dialog",
        .path = EXAMPLES ++ "/dialog.zig",
    },
    .{
        .name = "window_menu",
        .path = EXAMPLES ++ "/menu.zig",
    },
    .{
        .name = "linux",
        .path = EXAMPLES ++ "/linux.zig",
    },
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const module = b.addModule(NAME, .{ .root_source_file = b.path("src/root.zig"), .target = target, .optimize = optimize });

    const zigwin32 = b.dependency("zigwin32", .{});
    const uuid = b.dependency("uuid", .{});
    const wgpu_native = b.dependency("wgpu_native_zig", .{});

    var scanner: ?*Scanner = null;
    var wayland: ?*std.Build.Module = null;
    if (builtin.target.os.tag == .linux) {
        scanner = Scanner.create(b, .{});
        wayland = b.createModule(.{ .root_source_file = scanner.?.result });
        scanner.?.addSystemProtocol("stable/xdg-shell/xdg-shell.xml");
        scanner.?.generate("wl_compositor", 1);
        scanner.?.generate("wl_shm", 1);
        scanner.?.generate("xdg_wm_base", 1);
    }

    module.addImport("uuid", uuid.module("uuid"));
    if (builtin.target.os.tag == .windows) {
        // Note: To build exe so a console window doesn't appear
        // Add this to any exe build: `exe.subsystem = .Windows;`
        module.addImport("win32", zigwin32.module("win32"));
    }

    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    inline for (examples) |example| {
        addExample(
            b,
            target,
            optimize,
            example,
            &.{
                .{ NAME, module },
                .{ "wayland", wayland },
                .{ "uuid", uuid.module("uuid") },
                .{ "wgpu", wgpu_native.module("wgpu") },
            },
            builtin.target.os.tag == .linux,
            &.{
                .{ "wayland-client", .linux },
            },
        );
    }
}

const ModuleMap = std.meta.Tuple(&[_]type{ []const u8, ?*std.Build.Module });
const Example = struct {
    name: []const u8,
    path: []const u8,
};

pub fn addExample(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    comptime example: Example,
    modules: []const ModuleMap,
    link_lib_c: bool,
    system_libraries: []const std.meta.Tuple(&.{ []const u8, Tag }),
) void {
    const exe = b.addExecutable(.{
        .name = example.name,
        .root_source_file = b.path(example.path),
        .target = target,
        .optimize = optimize,
    });

    if (link_lib_c) exe.linkLibC();
    for (system_libraries) |library| {
        if (library[1] == builtin.target.os.tag) {
            exe.linkSystemLibrary(library[0]);
        }
    }

    for (modules) |module| {
        if (module[1]) |mod| {
            exe.root_module.addImport(module[0], mod);
        }
    }

    const ecmd = b.addRunArtifact(exe);
    ecmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        ecmd.addArgs(args);
    }

    const estep = b.step("example-" ++ example.name, "Run example-" ++ example.name);
    estep.dependOn(&ecmd.step);
}
