const std = @import("std");
const core = @import("storytree-core");

pub fn main() !void {
    // const result = core.dialog.message(.yes_no, .{
    //     .icon = .@"error",
    //     .title = "Greeting",
    //     .message = "Hello, world!"
    // });
    // std.debug.print("{any}\n", .{ result });

    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    {
        const result = try core.dialog.open(allocator, .{
            .folder = "C:\\Users\\zboehm",
            .filters = &.{
                .{ "All types (*.*)", "*.*" },
                .{ "Text (*.txt)", "*.txt" },
            },
            .title = "save herb"
        });

        if (result) |paths| {
            defer allocator.free(paths);
            for (paths) |path| {
                defer allocator.free(path);
                std.debug.print("{s}\n", .{ path });
            }
        }
    }

    {
        const result = try core.dialog.save(allocator, .{
            .folder = "C:\\Users\\zboehm",
            .file_name = "sample.txt",
            .filters = &.{
                .{ "All types (*.*)", "*.*" },
                .{ "Text (*.txt)", "*.txt" },
            },
            .title = "Save Herb",
        });

        if (result) |path| {
            defer allocator.free(path);
            std.debug.print("{s}\n", .{ path });
        }
    }
}
