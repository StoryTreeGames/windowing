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
                    else => {},
                }
            },
            else => @compileError("platform not supported"),
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
    theme: enum { light, dark }
};

pub const EventLoop = struct {
    arena: std.heap.ArenaAllocator,
    state: *anyopaque,

    identifier: if (builtin.os.tag == .windows) [:0]const u16 else void,

    handler: *const fn (*EventLoop, *anyopaque, *Window, Event) anyerror!bool,
    windows: std.AutoArrayHashMapUnmanaged(usize, *Window) = .empty,

    pub fn init(allocator: std.mem.Allocator, identifier: []const u8, State: type, state: *State) !*@This() {
        var arena = std.heap.ArenaAllocator.init(allocator);
        errdefer arena.deinit();

        const allo = arena.allocator();

        const Handler = struct {
            pub fn handleEvent(event_loop: *EventLoop, data: *anyopaque, win: *Window, event: Event) !bool {
                const s: *State = @ptrCast(@alignCast(data));
                if (@hasDecl(State, "handleEvent")) {
                    const func = @field(State, "handleEvent");
                    const F = @TypeOf(func);
                    const params = @typeInfo(F).@"fn".params;
                    const rtrn = @typeInfo(F).@"fn".return_type.?;

                    var args: std.meta.ArgsTuple(F) = undefined;
                    inline for (params, 0..) |param, i| {
                        args[i] = switch (param.type.?) {
                            *Window, *const Window => win,
                            Event => event,
                            *State, *const State => s,
                            *EventLoop, *const EventLoop => event_loop,
                            else => @compileError("invalid event loop handler argument type: " ++ @typeName(State)),
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

        const id = switch (builtin.os.tag) {
            .windows => try std.unicode.utf8ToUtf16LeAllocZ(allo, identifier),
            else => {},
        };

        switch (builtin.os.tag) {
            .windows => try @import("windows/event.zig").EventLoop.setup(id),
            else => @compileError("platform not supported"),
        }

        const el = try allo.create(@This());
        el.* = .{
            .arena = arena,
            .state = @ptrCast(@alignCast(state)),
            .identifier = id,
            // Type erased event handler that propagates the os specific event back to the event_loop and state handler
            .handler = Handler.handleEvent,
        };

        if (@hasDecl(State, "setup")) {
            const func = @field(State, "setup");
            const F = @TypeOf(func);
            const params = @typeInfo(F).@"fn".params;
            const rtrn = @typeInfo(F).@"fn".return_type.?;

            var args: std.meta.ArgsTuple(F) = undefined;
            inline for (params, 0..) |param, i| {
                args[i] = switch (param.type.?) {
                    *State, *const State => state,
                    *@This(), *const @This() => el,
                    else => @compileError("invalid event loop handler argument type: " ++ @typeName(State)),
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
        win.* = try .init(allocator, opts, self);

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
                return try @import("windows/event.zig").EventLoop.pollMessages();
            },
            else => @compileError("platform not supported"),
        }
    }

    pub fn run(self: *@This()) !void {
        switch (builtin.os.tag) {
            .windows => {
                try @import("windows/event.zig").EventLoop.messageLoop(self);
            },
            else => @compileError("platform not supported"),
        }
    }

    pub fn handleEvent(self: *@This(), args: anytype) bool {
        switch (builtin.os.tag) {
            .windows => {
                if (self.windows.get(@intFromPtr(args[0]))) |win| {
                    const event = @import("windows/event.zig").parseEvent(win, args[0], args[1], args[2], args[3]);
                    if (event) |e| {
                        return self.handler(self, self.state, win, e) catch false;
                    }
                }
                return false;
            },
            else => @compileError("platform not supported"),
        }
    }
};
