const std = @import("std");

const win32 = @import("win32");
const zig = win32.zig;
const windows_and_messaging = win32.ui.windows_and_messaging;

const Window = @import("window.zig");
pub const events = @import("events.zig");
const Event = events.Event;
const EventLoop = events.EventLoop;
pub const uuid = @import("uuid.zig");

const UNICODE = true;

fn handler(event: Event, target: Window.Target) void {
    switch (event) {
        .close => {
            target.exit();
            std.log.debug("Closing From Handler: {any}", .{target.hwnd});
        },
        else => {},
    }
}

pub fn main() !void {
    var event_loop = EventLoop.init(&handler);

    // Needed to allocate title and class strings
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        _ = gpa.deinit();
    }
    const allocator = gpa.allocator();

    const win = try Window.init(allocator, &event_loop, .{ .title = "Zig window" });
    defer win.deinit();

    const win2 = try Window.init(allocator, &event_loop, .{});
    defer win2.deinit();

    win.show(true);
    win2.show(true);
    event_loop.run();
}
