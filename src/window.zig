const std = @import("std");
const Rect = @import("root.zig").Rect;

const Icon = @import("icon.zig").Icon;
const Cursor = @import("cursor.zig").Cursor;
const EventHandler = @import("event.zig").EventHandler;

pub const Inner = switch (@import("builtin").os.tag) {
    .windows => @import("windows/window.zig"),
    else => @compileError("platform not supported")
};

pub const Theme = enum {
    light,
    dark,
    system,
};

pub const Show = enum { maximize, minimize, restore, fullscreen };

pub const Options = struct {
    title: []const u8 = "",
    x: ?u32 = null,
    y: ?u32 = null,
    width: ?u32 = null,
    height: ?u32 = null,
    icon: Icon = .default,
    cursor: Cursor = .default,
    resizable: bool = true,
    theme: Theme = .system,
    show: Show = .restore,
};

arena: std.heap.ArenaAllocator,

inner: *Inner,
alive: bool,

pub fn init(allocator: std.mem.Allocator, options: Options, handler: *EventHandler) !@This() {
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();

    return .{
        .inner = try Inner.init(arena.allocator(), options, handler),
        .alive = true,
        .arena = arena,
    };
}

pub fn deinit(self: *@This()) void {
    self.arena.deinit();
}

pub fn id(self: *const @This()) usize {
    return self.inner.id();
}

/// Minimize the window
pub fn minimize(self: *const @This()) void {
    self.inner.minimize();
}

/// Maximize the window
pub fn maximize(self: *const @This()) void {
    self.inner.maximize();
}

/// Restore the window to its default windowed state
pub fn restore(self: *const @This()) void {
    self.inner.restore();
}

/// Get the windows current rect (bounding box)
pub fn getRect(self: *const @This()) Rect(u32) {
    return self.inner.getRect();
}

/// Set window title
pub fn setTitle(self: *const @This(), title: []const u8) !void {
    try self.inner.setTitle(title);
}

/// Set window icon
pub fn setIcon(self: *const @This(), new_icon: Icon) !void {
    try self.inner.setIcon(new_icon);
}

/// Set window cursor
pub fn setCursor(self: *const @This(), new_cursor: Cursor) !void {
    try self.inner.setCursor(new_cursor);
}

/// Set the cursors position relative to the window
pub fn setCursorPos(self: *const @This(), x: u32, y: u32) void {
    self.inner.setCursorPos(@intCast(x), @intCast(y));
}

/// Set the mouse to be captured by the window, or release it from the window
pub fn setCapture(self: *const @This(), state: bool) void {
    self.inner.setCapture(state);
}
