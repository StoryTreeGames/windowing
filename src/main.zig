const std = @import("std");

const win32 = @import("win32");
const zig = win32.zig;
const windows_and_messaging = win32.ui.windows_and_messaging;

const Window = @import("window.zig");
pub const root = @import("root.zig");

const Event = root.events.Event;
const EventLoop = root.events.EventLoop;

const UNICODE = true;

fn handler(event: Event, target: Window.Target) void {
    switch (event) {
        .close => {
            target.exit();
        },
        .keydown => |ke| {
            switch (ke.key) {
                .ESCAPE => target.exit(), // Exit after releasing escape key
                else => {
                    std.log.debug("PRESS   [ {s} ]", .{@tagName(ke.key)});
                },
            }
        },
        .keyup => |ke| {
            std.log.debug("RELEASE [ {s} ]", .{@tagName(ke.key)});
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

    const win = try Window.init(
        allocator,
        &event_loop,
        .{
            .title = "Zig window",
            .width = 300,
            .height = 400,
            .resizable = false,
        },
    );
    defer win.deinit();

    const win2 = try Window.init(
        allocator,
        &event_loop,
        .{
            .width = 1000,
            .height = 1200,
            .theme = .light,
        },
    );
    defer win2.deinit();

    event_loop.run();
}
