const std = @import("std");
const uuid = @import("uuid");

/// Allocate a sentinal utf16 string from a utf8 string
pub fn utf8ToUtf16Alloc(allocator: std.mem.Allocator, data: []const u8) ![:0]u16 {
    const len: usize = std.unicode.calcUtf16LeLen(data) catch unreachable;
    var utf16le: [:0]u16 = try allocator.allocSentinel(u16, len, 0);
    const utf16le_len = try std.unicode.utf8ToUtf16Le(utf16le[0..], data[0..]);
    std.debug.assert(len == utf16le_len);
    return utf16le;
}

/// Create/Allocate a unique window class with a uuid v4 prefixed with `STC`
pub fn createUIDClass(allocator: std.mem.Allocator) ![:0]u16 {
    // Size of {3}-{36}{null} == 41
    var buffer = try std.ArrayList(u8).initCapacity(allocator, 40);
    defer buffer.deinit();

    const uid = uuid.urn.serialize(uuid.v4.new());
    try std.fmt.format(buffer.writer(), "STC-{s}", .{uid});

    const temp = try buffer.toOwnedSlice();
    defer allocator.free(temp);

    return try utf8ToUtf16Alloc(allocator, temp);
}
