// This example is derived from the wgpu-native-zig's test repository to ensure
// that the library works with windows. This just replaces the win32 code with
// this libraries windowing logic.
//
// https://github.com/bronter/wgpu-native-zig-windows-test

const std = @import("std");
const log = std.log.scoped(.app);
const Renderer = @import("renderer.zig");

const event = @import("storytree-core").event;

const Window = @import("storytree-core").Window;
const EventLoop = event.EventLoop;
const Event = event.Event;

pub const App = struct {
    renderer: Renderer,

    pub fn deinit(self: *@This()) void {
        self.renderer.release();
    }

    pub fn handleEvent(self: *@This(), event_loop: *EventLoop, win: *Window, evt: Event) !void {
        switch (evt) {
            .close => event_loop.closeWindow(win.id()),
            .resize => |size| self.renderer.resize(size.width, size.height),
            else => {},
        }
    }
};


pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    log.info("creating event loop", .{});
    var event_loop = try EventLoop.init(allocator);
    defer event_loop.deinit();

    log.info("creating window", .{});
    const win = try event_loop.createWindow(.{
        .title = "wgpu-native-zig window example",
        .width = 640,
        .height = 480,
    });

    var app = App{ .renderer = try Renderer.create(win) };
    defer app.deinit();

    while (event_loop.isActive()) {
        if (event_loop.poll()) |data| {
            try app.handleEvent(&event_loop, data.window, data.event);
        } else {
            app.renderer.render() catch break;
        }
    }
}
