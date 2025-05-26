const builtin = @import("builtin");
const std = @import("std");
const input = @import("input.zig");

const Window = @import("window.zig");
const Key = input.Key;
const MouseButton = input.MouseButton;
const Point = @import("root.zig").Point;
const MenuItem = @import("menu.zig").Item;
const MenuInfo = @import("menu.zig").Info;

pub const Modifiers = packed struct(u3) {
    ctrl: bool = false,
    alt: bool = false,
    shift: bool = false,
};

pub const KeyEvent = struct {
    /// Current button state, i.e. pressed or released
    state: ButtonState,
    /// Modifiers: ctrl, alt, shift, etc as bit flags
    modifiers: Modifiers,
    /// Virtual key code
    virtual: u32 = 0,
    /// Scan code
    scan: u32 = 0,
    /// Key representation
    key: Key,

    pub fn matches(self: *const KeyEvent, key: Key, modifiers: Modifiers) bool {
        return self.modifiers.eq(modifiers) and self.key == key;
    }
};

pub const ButtonState = enum {
    pressed,
    released,
};

pub const ScrollDirection = enum {
    vertical,
    horizontal,
};

pub const ScrollEvent = struct {
    /// Whether the scrolling is horizontal or vertical
    direction: ScrollDirection,
    /// The amount of pixels scrolled.
    ///
    /// Positive scrolling is to the right and down respectively for horizontal and vertical
    delta: i16,
};

pub const MouseEvent = struct {
    /// Mouse button state, i.e. pressed or released
    state: ButtonState,
    /// What mouse button was pressed: left, right, middle, x1, or x2
    button: MouseButton,
};

/// Event corresponding to a size
pub const SizeEvent = struct {
    width: u32,
    height: u32,
};

pub const MenuEvent = struct {
    id: u32,
    item: *MenuInfo,

    pub fn toggle(self: *const @This(), state: bool) void {
        switch (builtin.os.tag) {
            .windows => {
                const wam = @import("win32").ui.windows_and_messaging;
                switch (self.item.payload) {
                    .toggle => {
                        _ = wam.CheckMenuItem(@ptrCast(@alignCast(self.item.menu)), self.id, if (state) 0x8 else 0x0);
                    },
                    .radio => |r| {
                        _ = wam.CheckMenuRadioItem(@ptrCast(@alignCast(self.item.menu)), @intCast(r.group[0]), @intCast(r.group[0]), self.id, 0x0);
                    },
                    else => {}
                }
            },
            else => @compileError("platform not supported")
        }
    }
};

pub const Event = union(enum) {
    /// Repaint request
    repaint,
    /// Close request
    close,
    /// Resize event pose
    resize: SizeEvent,
    /// Focus or Unfocus event post
    focused: bool,
    /// Key input event post
    key_input: KeyEvent,
    /// Mouse button input event post
    mouse_input: MouseEvent,
    /// Mouse move event post
    mouse_move: Point(u16),
    /// Mouse scroll event post
    mouse_scroll: ScrollEvent,
    /// Menu item event
    menu: MenuEvent,
};

pub fn EventLoop(S: type) type {
    const Handler = switch (builtin.os.tag) {
        .windows => struct {
            const HWND = @import("win32").foundation.HWND;
            pub fn handler(s: *anyopaque, context: *anyopaque, hwnd: HWND, message: u32, wparam: usize, lparam: isize) bool {
                const inner: *EventLoop(S) = @ptrCast(@alignCast(s));
                const ctx: *S = @ptrCast(@alignCast(context));
                if (inner.windows.get(@intFromPtr(hwnd))) |win| {
                    if (@import("windows/event.zig").parseEvent(win, message, wparam, lparam)) |evt| {
                        return inner.handleEvent(ctx, win, evt) catch return false;
                    }
                }
                return false;
            }
        },
        else => @compileError("platform not supported")
    };

    return struct {
        arena: std.heap.ArenaAllocator,
        state: *S,

        identifier: if (builtin.os.tag == .windows) [:0]const u16 else void,

        handler: EventHandler,
        windows: std.AutoArrayHashMapUnmanaged(usize, *Window) = .empty,

        pub fn init(allocator: std.mem.Allocator, identifier: []const u8, state: *S) !*@This() {
            var arena = std.heap.ArenaAllocator.init(allocator);
            errdefer arena.deinit();

            const allo = arena.allocator();

            const id = switch (builtin.os.tag) {
                .windows => try std.unicode.utf8ToUtf16LeAllocZ(allo, identifier),
                else => {}
            };

            switch (builtin.os.tag) {
                .windows => try @import("windows/event.zig").EventLoop(S).setup(id),
                else => @compileError("platform not supported")
            }

            // Type erased event handler that propagates the os specific event back to the event_loop
            const el = try allo.create(@This());
            el.* = .{
                .arena = arena,
                .state = state,
                .identifier = id,
                .handler = EventHandler {
                    .inner = el,
                    .state = state,
                    .handler = Handler.handler
                }
            };

            if (@hasDecl(S, "setup")) {
                const func = @field(S, "setup");
                const F = @TypeOf(func);
                const params = @typeInfo(F).@"fn".params;
                const rtrn = @typeInfo(F).@"fn".return_type.?;

                var args: std.meta.ArgsTuple(F) = undefined;
                inline for (params, 0..) |param, i| {
                    args[i] = switch (param.type.?) {
                        *S, *const S => state,
                        *@This(), *const @This() => el,
                        else => @compileError("invalid event loop handler argument type: " ++ @typeName(S))
                    };
                }

                if (@typeInfo(rtrn) == .error_union) {
                    try @call(.auto, func, args);
                } else {
                    @call(.auto, func, args);
                }
            }

            return el;
        }

        pub fn deinit(self: *@This()) void {
            self.arena.deinit();
        }

        pub fn createWindow(self: *@This(), opts: Window.Options) !*Window {
            const allocator = self.arena.allocator();

            const win = try allocator.create(Window);
            errdefer allocator.destroy(win);
            win.* = try .init(allocator, opts, &self.handler);

            try self.windows.put(allocator, win.id(), win);
            return win;
        }

        pub fn closeWindow(self: *@This(), id: usize) void {
            if (self.windows.get(id)) |win| {
                win.inner.destroy();
                win.deinit();
                self.arena.allocator().destroy(win);
                _ = self.windows.swapRemove(id);
            }
        }

        pub fn isActive(self: *const @This()) bool {
            return self.windows.count() > 0;
        }

        pub fn poll(self: *@This()) !bool {
            _ = self;

            switch (builtin.os.tag) {
                .windows => {
                    return try @import("windows/event.zig").EventLoop(S).pollMessages();
                },
                else => @compileError("platform not supported")
            }
        }

        pub fn run(self: *@This()) !void {
            switch (builtin.os.tag) {
                .windows => {
                    try @import("windows/event.zig").EventLoop(S).messageLoop(self);
                },
                else => @compileError("platform not supported")
            }
        }

        pub fn handleEvent(self: *@This(), state: *S, win: *Window, event: Event) !bool {
            if (@hasDecl(S, "handleEvent")) {
                const func = @field(S, "handleEvent");
                const F = @TypeOf(func);
                const params = @typeInfo(F).@"fn".params;
                const rtrn = @typeInfo(F).@"fn".return_type.?;

                var args: std.meta.ArgsTuple(F) = undefined;
                inline for (params, 0..) |param, i| {
                    args[i] = switch (param.type.?) {
                        *Window, *const Window => win,
                        Event => event,
                        *S, *const S => state,
                        *@This(), *const @This() => self,
                        else => @compileError("invalid event loop handler argument type: " ++ @typeName(S))
                    };
                }

                if (@typeInfo(rtrn) == .error_union) {
                    return try @call(.auto, func, args);
                } else {
                    return @call(.auto, func, args);
                }
            }
        }
    };
}

pub const EventHandler = struct {
    inner: *anyopaque,
    state: *anyopaque,
    handler: switch (builtin.os.tag) {
        .windows => h: {
            const HWND = @import("win32").foundation.HWND;
            break :h *const fn(*anyopaque, *anyopaque, hwnd: HWND, u32, usize, isize) bool;
        },
        else => @compileError("platform not supported")
    },

    pub usingnamespace switch (builtin.os.tag) {
        .windows => struct {
            const HWND = @import("win32").foundation.HWND;
            pub fn handleEvent(self: *EventHandler, hwnd: HWND, message: u32, wparam: usize, lparam: isize) bool {
                return self.handler(self.inner, self.state, hwnd, message, wparam, lparam);
            }
        },
        else => @compileError("platform not supported")
    };
};
