// This example is derived from the wgpu-native-zig's test repository to ensure
// that the library works with windows. This just replaces the win32 code with
// this libraries windowing logic.

const std = @import("std");
const Renderer = @import("renderer.zig");

const event = @import("storytree-core").event;

const Window = @import("storytree-core").Window;
const EventLoop = event.EventLoop;
const Event = event.Event;

pub const App = struct {
    renderer: Renderer,

    pub fn init() @This() {
        return undefined;
    }

    pub fn deinit(self: *@This()) void {
        self.renderer.release();
    }

    pub fn setup(self: *@This(), event_loop: *EventLoop(App)) !void {
        const win = try event_loop.createWindow(.{
            .title = "wgpu-native-zig windows example",
            .width = 640,
            .height = 480,
            .resizable = true,
            .icon = .{ .custom = "examples\\assets\\icon.ico" },
            // .cursor = .{ .icon = .pointer },
        });

        self.renderer = try Renderer.create(win);
    }

    pub fn handleEvent(self: *@This(), event_loop: *EventLoop(App), win: *Window, evt: Event) !bool {
        switch (evt) {
            .close => event_loop.closeWindow(win.id()),
            .resize => |size| self.renderer.resize(size.width, size.height),
            .repaint => self.renderer.render() catch {},
            else => return false,
        }
        return true;
    }
};


pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = App.init();
    defer app.deinit();

    var event_loop = try EventLoop(App).init(allocator, "storytree.core", &app);
    defer event_loop.deinit();

    while (event_loop.isActive()) {
        if (!try event_loop.poll()) {
            app.renderer.render() catch break;
        }
    }
}
