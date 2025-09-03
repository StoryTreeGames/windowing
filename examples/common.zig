const std = @import("std");

pub fn relative_file_uri(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    const file_path = try std.fs.cwd().realpathAlloc(allocator, path);
    defer allocator.free(file_path);

    const uri = try std.fmt.allocPrint(allocator, "file:///{s}", .{ file_path });
    return uri;
}
