const std = @import("std");

const root = @import("../root.zig");
const events = @import("../events.zig");
const window = @import("../window.zig");

const Cursor = @import("../cursor.zig").Cursor;
const Icon = @import("../icon.zig").Icon;
const EventLoop = events.EventLoop;

// CONSTANTS

const Window = @This();
pub const Target = Window;

// ARGUMENTS

allocator: std.mem.Allocator,

// METHODS

pub fn format(value: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
    _ = value;
    return writer.print("Window {{ }}", .{});
}

pub fn init(
    allocator: std.mem.Allocator,
    event_loop: *EventLoop,
    options: window.CreateOptions,
) !*Window {
    std.debug.print("\x1b[33;1mTODO\x1b[0m: Implement linux window for x11 & wayland", .{});
    _ = event_loop;
    _ = options;

    // var env_map = std.process.getEnvMap(allocator);
    if (try std.process.hasEnvVar(allocator, "XDG_SESSION_TYPE")) {
        const session_type = try std.process.getEnvVarOwned(allocator, "XDG_SESSION_TYPE");
        std.debug.print("{s}\n", .{session_type});
        allocator.free(session_type);
    }

    var win = try allocator.create(Window);
    errdefer win.deinit();

    win.* = .{
        .allocator = allocator,
    };
    return win;
}

pub fn deinit(self: *Window) void {
    self.allocator.destroy(self);
}

pub fn minimize(self: *Window) void {
    _ = self;
}
pub fn maximize(self: *Window) void {
    _ = self;
}
pub fn restore(self: *Window) void {
    _ = self;
}

pub fn close(self: *Window) void {
    _ = self;
}

pub fn getRect(self: *Window) root.Rect(i32) {
    _ = self;

    return .{
        .left = 0,
        .right = 0,
        .top = 0,
        .bottom = 0,
    };
}

pub fn setIcon(self: *Window, icon: Icon) !void {
    _ = self;
    _ = icon;
}
pub fn setCursor(self: *Window, cursor: Cursor) !void {
    _ = self;
    _ = cursor;
}
pub fn setCursorPos(self: *Window, x: i32, y: i32) void {
    _ = self;
    _ = x;
    _ = y;
}
pub fn setTitle(self: *Window, title: []const u8) !void {
    _ = self;
    _ = title;
}
pub fn setCapture(self: *Window, state: bool) void {
    _ = self;
    _ = state;
}
