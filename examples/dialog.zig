const std = @import("std");
const core = @import("storytree-core");

pub fn main() !void {
    // const result = core.dialog.message(.yes_no, .{
    //     .icon = .@"error",
    //     .title = "Greeting",
    //     .message = "Hello, world!"
    // });
    // std.debug.print("{any}\n", .{ result });
    try core.dialog.file(.{});
}
