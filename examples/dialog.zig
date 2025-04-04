const std = @import("std");
const core = @import("storytree-core");

pub fn main() !void {
    const result = core.dialog.message(.yes_no, .{});
    std.debug.print("{any}\n", .{ result });
}
