const std = @import("std");
const builtin = @import("builtin");
const http = std.http;
const json = std.json;

// {User}/{Repo}: Snektron/vulkan-zig
// https://raw.githubusercontent.com/
// https://api.github.com/repos/{User}/{Repo}/commits?per_page=1
fn fetch(allocator: std.mem.Allocator, url: []const u8) ![]u8 {
    var client = http.Client{ .allocator = allocator };
    defer client.deinit();

    const uri = try std.Uri.parse(url);

    var server_header_buffer: [1024 * 1024]u8 = undefined;
    const options = .{ .server_header_buffer = &server_header_buffer };
    var req = try client.open(http.Method.GET, uri, options);
    defer req.deinit();

    try req.send(.{});
    try req.wait();

    // Temp buffer to interatively fetch response body from
    var buffer = [_]u8{0} ** 1024;
    var result = std.ArrayList(u8).init(allocator);
    while (true) {
        const index = req.readAll(&buffer) catch |err| switch (err) {
            http.Client.Connection.ReadError.EndOfStream => break,
            else => return err,
        };
        if (index == 0) {
            break;
        }

        try result.appendSlice(buffer[0..index]);
    }

    return result.toOwnedSlice();
}

fn fetch_file(url: []const u8, dest: []const u8) !void {
    // Try creating the file and if it already exists don't download it again
    const file = std.fs.cwd().createFile(dest, .{}) catch unreachable;
    defer file.close();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var client = http.Client{ .allocator = allocator };
    defer client.deinit();

    const uri = try std.Uri.parse(url);

    var server_header_buffer: [1024 * 1024]u8 = undefined;
    const options = .{ .server_header_buffer = &server_header_buffer };
    var req = try client.open(http.Method.GET, uri, options);
    defer req.deinit();

    try req.send(.{});
    try req.wait();

    // Temp buffer to interatively fetch response body from
    var buffer = [_]u8{0} ** 1024;
    while (true) {
        const index = req.readAll(&buffer) catch |err| switch (err) {
            http.Client.Connection.ReadError.EndOfStream => break,
            else => return err,
        };
        if (index == 0) {
            break;
        }

        try file.writeAll(buffer[0..index]);
    }
}

const GitFile = struct { repo: struct {
    user: []const u8,
    repo: []const u8,
}, file: []const u8 };

fn ensure_file(comptime git_file: GitFile) !void {
    std.fs.cwd().makeDir(".cache") catch {};
    var hash: []const u8 = undefined;
    const cache_file = ".cache/" ++ git_file.file ++ ".hash";

    const file = std.fs.cwd().openFile(cache_file, .{ .mode = .read_write }) catch |err| switch (err) {
        error.FileNotFound => try std.fs.cwd().createFile(cache_file, .{ .read = true }),
        else => return err,
    };
    defer file.close();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var buffered = std.io.bufferedReader(file.reader());
    const reader = buffered.reader();

    var arr = std.ArrayList(u8).init(allocator);
    defer arr.deinit();

    reader.streamUntilDelimiter(arr.writer(), '\n', null) catch |err| switch (err) {
        error.EndOfStream => {},
        else => return err,
    };

    hash = try arr.toOwnedSlice();

    // Fetch latest commit from git
    const body = try fetch(
        allocator,
        "https://api.github.com/repos/" ++ git_file.repo.user ++ "/" ++ git_file.repo.repo ++ "/commits?per_page=1",
    );
    const response = try json.parseFromSliceLeaky(json.Value, allocator, body, .{});
    const value = response.array.items[0].object;

    if (value.get("sha")) |v| {
        if (std.mem.eql(u8, v.string, hash)) {
            return;
        }
        try file.writeAll(v.string);
    } else {
        std.log.warn("[build] Unable to get sha from `KhronosGroup/Vulkan-Docs`", .{});
    }

    std.log.info("[build] Missing or out of date vulkan `vk.xml`", .{});
    std.log.info("[build] Updating file `vk.xml` to latest from `KhronosGroup/Vulkan-Docs`", .{});
    fetch_file(
        "https://raw.githubusercontent.com/" ++ git_file.repo.user ++ "/" ++ git_file.repo.repo ++ "/main/xml/" ++ git_file.file,
        git_file.file,
    ) catch unreachable;
}

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // This is needed for building the vulkan-zig dependency
    // This will automatically check a cached commit hash for updates
    //  if there is an update the vk.xml file will be updated
    ensure_file(.{
        .repo = .{
            .user = "KhronosGroup",
            .repo = "Vulkan-Docs",
        },
        .file = "vk.xml",
    }) catch unreachable;

    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "native",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "src/root.zig" },
        .target = target,
        .optimize = optimize,
    });

    // This declares intent for the library to be installed into the standard
    // location when the user invokes the "install" step (the default step when
    // running `zig build`).
    b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = "native",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    switch (builtin.target.os.tag) {
        // Windows OS dependencies
        .windows => {
            exe.root_module.addImport(
                "win32",
                // zigwin32 doesn't work well with target and optimize variables passed in
                // this could change if the library updates after zig 0.12
                b.dependency("zigwin32", .{}).module("zigwin32"),
            );
        },
        else => {},
    }

    // Add vulkan-zig dependency
    exe.root_module.addImport(
        "vulkan",
        b.dependency("vulkan_zig", .{
            .registry = @as([]const u8, b.pathFromRoot("vk.xml")),
        }).module("vulkan-zig"),
    );

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const lib_unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/root.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}
