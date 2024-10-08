const std = @import("std");
const Tag = std.Target.Os.Tag;
const builtin = @import("builtin");

const NAME = "storytree-core";
const EXAMPLES = "examples";

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // const VERSION = std.SemanticVersion{ .major = 0, .minor = 0, .patch = 0 };
    const LIB_PATH = b.path("src/root.zig");

    // ========================================================================
    //                             module
    // ========================================================================

    const module = b.addModule(NAME, .{ .root_source_file = LIB_PATH });

    module.addImport("uuid", b.dependency("uuid", .{}).module("uuid"));

    // Add platform specific dependencies
    switch (builtin.target.os.tag) {
        Tag.windows => {
            // Note: To build exe so a console window doesn't appear
            // Add this to any exe build: `exe.subsystem = .Windows;`
            module.addImport(
                "win32",
                // zigwin32 doesn't work well with target and optimize variables passed in
                // this could change if the library updates after zig 0.12
                b.dependency("zigwin32", .{}).module("zigwin32"),
            );
        },
        else => {},
    }

    try b.modules.put(b.dupe(NAME), module);

    // ========================================================================
    //                                  Tests
    // ========================================================================

    const lib_unit_tests = b.addTest(.{
        .root_source_file = LIB_PATH,
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    // ========================================================================
    //                                 examples
    // ========================================================================

    const v4_example = addExample(b, module, "dev-example", "examples/dev.zig", target);

    const run_dev_example = b.step("run-dev-example", "Run the dev example");
    run_dev_example.dependOn(&v4_example.step);
}

fn addExample(b: *std.Build, uuid_module: *std.Build.Module, exeName: []const u8, sourceFile: []const u8, target: std.Build.ResolvedTarget) *std.Build.Step.Run {
    const exe = b.addExecutable(.{
        .name = exeName,
        .root_source_file = b.path(sourceFile),
        .target = target,
    });
    exe.root_module.addImport(NAME, uuid_module);
    b.installArtifact(exe);

    return b.addRunArtifact(exe);
}

/// Information to create and run an example.
pub const Example = struct {
    name: []const u8,
    path: []const u8,
    version: ?std.SemanticVersion = null,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode = .Debug,
    module: *std.Build.Module,
};

/// Creates an example executable, installs it, and runs it.
pub fn runExample(b: *std.Build, example: Example) void {
    // Create an example executable
    const runnable = b.addExecutable(.{
        .name = example.name,
        .target = example.target,
        .optimize = example.optimize,
        .version = example.version,
        .root_source_file = b.path(example.path),
    });

    // Add the library as an available import in the example
    runnable.root_module.addImport(NAME, example.module);
    const example_run = b.addRunArtifact(runnable);

    // Installs the example executables to the `zig-out/{EXAMPLES}` directory
    const artifact = b.addInstallArtifact(runnable, .{ .dest_dir = .{ .override = .{ .custom = EXAMPLES } } });
    b.getInstallStep().dependOn(&artifact.step);

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build examples -- arg1 arg2 etc`
    if (b.args) |args| {
        example_run.addArgs(args);
    }

    // Adds the example run step to the default step's dependencies.
    // This will run the example after the build completes.
    b.default_step.dependOn(&example_run.step);
}
