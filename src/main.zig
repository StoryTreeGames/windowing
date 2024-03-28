const std = @import("std");

const win32 = @import("win32");
const zig = win32.zig;
const windows_and_messaging = win32.ui.windows_and_messaging;

const Window = @import("window.zig");
pub const events = @import("events.zig");
const Event = events.Event;
pub const uuid = @import("uuid.zig");

const UNICODE = true;

fn handler(event: Event, target: Window.Target) void {
    switch (event) {
        .close => target.exit(),
        else => {},
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        _ = gpa.deinit();
    }
    const allocator = gpa.allocator();

    const win = try Window.init(allocator, .{ .title = "Zig window" });
    defer win.deinit();
    const win2 = try Window.init(allocator, .{});
    defer win2.deinit();

    win.show(true);
    win2.show(true);
    events.event_loop(null);
}
