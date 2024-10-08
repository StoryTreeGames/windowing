const std = @import("std");
const Tag = std.Target.Os.Tag;
const builtin = @import("builtin");

const NAME = "znwl";
const EXAMPLES = "examples";

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const list_examples = b.option(bool, "list-examples", "List all available examples") orelse false;
    const example_name = b.option([]const u8, "example", "Run a specific example after building");

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const VERSION = std.SemanticVersion{ .major = 0, .minor = 0, .patch = 0 };
    const LIB_PATH = b.path("src/root.zig");

    // ========================================================================
    //                             module
    // ========================================================================

    const module = b.addModule(NAME, .{ .root_source_file = LIB_PATH });

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

    // Dynamically resolve the examples

    if (list_examples) {
        // If the `EXAMPLES` directory exists, list all the examples in that directory in that directory.
        if (std.fs.cwd().access(EXAMPLES, .{})) {
            const dir = std.fs.cwd().openDir(EXAMPLES, .{ .iterate = true }) catch unreachable;
            var walker = dir.iterate();
            var count: usize = 1;

            // Iterate children of the `EXAMPLES` directory
            while (walker.next() catch unreachable) |entry| {
                if (entry.kind == std.fs.File.Kind.directory) {
                    // If the entry is a directory and has a `main.zig`
                    // treat that as an example entry point where the example can be multiple files.

                    const path = b.allocator.alloc(u8, entry.name.len + 18) catch unreachable;
                    defer b.allocator.free(path);
                    @memcpy(path[0..8], EXAMPLES);
                    path[8] = '/';
                    @memcpy(path[9 .. 9 + entry.name.len], entry.name);
                    @memcpy(path[9 + entry.name.len ..], "/main.zig");

                    if (std.fs.cwd().access(path, .{})) {
                        std.debug.print("{d}. {s}\n", .{ count, entry.name });
                        count += 1;
                    } else |_| {}
                } else {
                    // Else the entry is a file and it is treated as an example entry point
                    // where the example is a single file.

                    const ext = std.fs.path.extension(entry.name);
                    if (std.mem.eql(u8, ext, ".zig")) {
                        std.debug.print("{d}. {s}\n", .{ count, entry.name[0 .. entry.name.len - 4] });
                        count += 1;
                    }
                }
            }
        } else |_| {}
    }

    // Allow the user to define a specificly defined example to run
    if (example_name) |name| {
        const example_file_path = b.allocator.alloc(u8, 13 + name.len) catch unreachable;
        defer b.allocator.free(example_file_path);
        @memcpy(example_file_path[0..8], EXAMPLES);
        example_file_path[8] = '/';
        @memcpy(example_file_path[9 .. 9 + name.len], name);
        @memcpy(example_file_path[9 + name.len ..], ".zig");

        const example_dir_path = b.allocator.alloc(u8, 18 + name.len) catch unreachable;
        defer b.allocator.free(example_dir_path);
        @memcpy(example_dir_path[0..8], EXAMPLES);
        example_dir_path[8] = '/';
        @memcpy(example_dir_path[9 .. 9 + name.len], name);
        @memcpy(example_dir_path[9 + name.len ..], "/main.zig");

        if (std.fs.cwd().access(example_file_path, .{})) {
            runExample(b, .{
                .name = name,
                .path = example_file_path,
                .version = VERSION,
                .target = target,
                .optimize = optimize,
                .module = module,
            });
        } else |_| {
            if (std.fs.cwd().access(example_dir_path, .{})) {
                runExample(b, .{
                    .name = name,
                    .path = example_dir_path,
                    .version = VERSION,
                    .target = target,
                    .optimize = optimize,
                    .module = module,
                });
            } else |_| {
                std.debug.print("Example '{s}' not found\n", .{name});
            }
        }
    }
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
