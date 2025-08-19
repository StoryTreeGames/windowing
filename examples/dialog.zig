const std = @import("std");
const core = @import("storytree-core");

pub fn main() !void {
    if (true) {
        const result = core.dialog.message(.yes_no, .{
            .icon = .@"error",
            .title = "Greeting",
            .message = "Hello, world!"
        });
        std.debug.print("{any}\n", .{ result });
    }

    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    if (true) {
        const result = try core.dialog.open(allocator, .{
            .filters = &.{
                .{ "Herb (*.hrb)", "*.hrb" },
                .{ "All types (*.*)", "*.*" },
                .{ "Text (*.txt)", "*.txt" },
            },
            .title = "Open Herb Guid",
        });

        if (result) |paths| {
            defer allocator.free(paths);
            for (paths) |path| {
                defer allocator.free(path);
                std.debug.print("{s}\n", .{ path });
            }
        }
    }

    if (true) {
        const result = try core.dialog.save(allocator, .{
            .file_name = "guide.hrb",
            .filters = &.{
                .{ "Herb (*.hrb)", "*.hrb" },
                .{ "All types (*.*)", "*.*" },
                .{ "Text (*.txt)", "*.txt" },
            },
            .title = "Save Herb Guide",
        });

        if (result) |path| {
            defer allocator.free(path);
            std.debug.print("{s}\n", .{ path });
        }
    }

    if (true) {
        const result = try core.dialog.color(.{});
        std.debug.print("{any}\n", .{ result });
    }

    if (true) {
        const result = try core.dialog.font(allocator, .{});
        if (result) |font| {
            defer allocator.free(font.name);
            std.debug.print("{{\n  Font Name: {s}\n", .{ font.name });
            std.debug.print("  Weight: {d}\n", .{ font.weight });
            std.debug.print("  Point Size: {d}\n}}\n", .{ font.point_size });
        } else {
            std.debug.print("No Font Selected\n", .{});
        }
    }
}
