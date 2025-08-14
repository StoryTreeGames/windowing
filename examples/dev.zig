const std = @import("std");

const event = @import("storytree-core").event;

const Window = @import("storytree-core").Window;
const EventLoop = event.EventLoop;
const Event = event.Event;

pub const App = struct {
    pub fn setup(event_loop: *EventLoop) !void {
        _ = try event_loop.createWindow(.{
            .title = "Zig window 2",
            .width = 800,
            .height = 600,
            .icon = .{ .custom = "examples\\assets\\icon.ico" },
            .cursor = .{ .icon = .pointer },
        });
    }

    pub fn handleEvent(event_loop: *EventLoop, win: *Window, evt: Event) !bool {
        std.debug.print("{any}\n", .{ evt });
        switch (evt) {
            .close => event_loop.closeWindow(win.id()),
            else => return false,
        }
        return true;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = App{};

    var event_loop = try EventLoop.init(allocator, "storytree.core.example.dev", App, &app);
    defer event_loop.deinit();

    // Custom debug output of window
    std.debug.print("Press <TAB> to toggle icon, cursor, and title at runtime\n", .{});
    std.debug.print("\x1b[1;33mWARNING\x1b[39m:\x1b[22m There are a lot of debug log statements \n\n", .{});

    while (event_loop.isActive()) {
        _ = try event_loop.poll();
    }
    // try event_loop.run();
}
