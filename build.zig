const std = @import("std");
const builtin = @import("builtin");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Main root module import of the library
    const znwl = b.addModule("znwl", .{
        .root_source_file = .{ .path = "src/root.zig" },
    });

    // Add dependencies

    // Add platform specific dependencies
    switch (builtin.target.os.tag) {
        .windows => {
            // Note: To build exe so a console window doesn't appear
            // Add this to any exe build: `exe.subsystem = .Windows;`
            znwl.addImport(
                "win32",
                // zigwin32 doesn't work well with target and optimize variables passed in
                // this could change if the library updates after zig 0.12
                b.dependency("zigwin32", .{}).module("zigwin32"),
            );
        },
        else => {},
    }

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const lib_unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/root.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
