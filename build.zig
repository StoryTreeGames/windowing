const std = @import("std");
const Tag = std.Target.Os.Tag;
const builtin = @import("builtin");

const NAME = "storytree-core";
const EXAMPLES = "examples";

const examples = [_]Example {
    .{ .name = "dev", .path = EXAMPLES ++ "/dev.zig",  },
    .{ .name = "wgpu", .path = EXAMPLES ++ "/wgpu/main.zig",  },
    .{ .name = "dialog", .path = EXAMPLES ++ "/dialog.zig",  },
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ========================================================================
    //                             module
    // ========================================================================

    const module = b.addModule(NAME, .{ .root_source_file = b.path("src/root.zig") });

    const zigwin32 = b.dependency("zigwin32", .{});
    const uuid = b.dependency("uuid", .{});
    const wgpu_native = b.dependency("wgpu_native_zig", .{});

    module.addImport("uuid", uuid.module("uuid"));
    if (builtin.target.os.tag == .windows) {
        // Note: To build exe so a console window doesn't appear
        // Add this to any exe build: `exe.subsystem = .Windows;`
        module.addImport("win32", zigwin32.module("win32"));
    }

    // ========================================================================
    //                                  Tests
    // ========================================================================

    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    // ========================================================================
    //                                 examples
    // ========================================================================

    inline for (examples) |example| {
        addExample(b, target, optimize, example, &[_]ModuleMap{
            .{ NAME, module },
            .{ "win32", zigwin32.module("win32") },
            .{ "uuid", uuid.module("uuid") },
            .{ "wgpu", wgpu_native.module("wgpu") }
        });
    }
}

const ModuleMap = std.meta.Tuple(&[_]type{ []const u8, *std.Build.Module });
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
) void {
    const exe = b.addExecutable(.{
        .name = example.name,
        .root_source_file = b.path(example.path),
        .target = target,
        .optimize = optimize,
    });

    for (modules) |module| {
        exe.root_module.addImport(module[0], module[1]);
    }

    const ecmd = b.addRunArtifact(exe);
    ecmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        ecmd.addArgs(args);
    }

    const estep = b.step("example-" ++ example.name, "Run example-" ++ example.name);
    estep.dependOn(&ecmd.step);
}
