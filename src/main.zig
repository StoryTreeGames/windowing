const std = @import("std");

const win32 = @import("win32");
const zig = win32.zig;
const windows_and_messaging = win32.ui.windows_and_messaging;

pub const root = @import("root.zig");

const Window = root.Window;
const Event = root.events.Event;
const EventLoop = root.events.EventLoop;

fn event_handler(event: Event, target: Window.Target) void {
    switch (event) {
        .close => {
            target.exit();
        },
        .key_input => |ke| {
            switch (ke.key) {
                .escape => if (ke.state == .pressed) target.exit(), // Exit after releasing escape key
                else => {
                    std.log.debug("{s} [ {s} ]", .{
                        if (ke.state == .pressed) "PRESS" else "RELEASE",
                        @tagName(ke.key),
                    });
                },
            }
        },
        .mouse_input => |me| {
            if (me.state == .pressed and me.button == .left) {
                target.setCapture(true);
            } else if (me.state == .released and me.button == .left) {
                target.setCapture(false);
            }
            std.log.debug("Mouse Input: {any}", .{me});
        },
        .mouse_move => |me| {
            std.log.debug("Move: (x: {d}, y: {d})", .{ me.x, me.y });
        },
        .mouse_scroll => |scroll| {
            std.log.debug("Scroll: {any}", .{scroll});
        },
        .focused => |focused| {
            std.log.debug("{s}", .{if (focused) "FOCUSED" else "UNFOCUSED"});
        },
        .resize => |re| {
            std.log.debug("Resize: [width: {d}, height: {d}]", .{ re.width, re.height });
        },
        else => {},
    }
}

// TODO: How to handle persistent state through the event loop
pub fn main() !void {
    var event_loop = EventLoop.init(&event_handler);

    // Needed to allocate title and class strings
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        _ = gpa.deinit();
    }
    const allocator = gpa.allocator();

    const win = try Window.init(
        allocator,
        &event_loop,
        .{
            .title = "Zig window",
            .width = 300,
            .height = 400,
        },
    );
    defer win.deinit();

    event_loop.run();
}
