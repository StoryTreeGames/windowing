const builtin = @import("builtin");
const std = @import("std");
const Window = @import("window.zig");
const input = @import("input.zig");

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

    pub usingnamespace switch (builtin.os.tag) {
        .windows => struct {
            const windows_and_messaging = @import("win32").ui.windows_and_messaging;
            const keyboard_and_mouse = @import("win32").ui.input.keyboard_and_mouse;

            const VIRTUAL_KEY = keyboard_and_mouse.VIRTUAL_KEY;
            const VK_CONTROL = keyboard_and_mouse.VK_CONTROL;
            const VK_LCONTROL = keyboard_and_mouse.VK_LCONTROL;
            const VK_RCONTROL = keyboard_and_mouse.VK_RCONTROL;
            const VK_ALT = keyboard_and_mouse.VK_MENU;
            const VK_LALT = keyboard_and_mouse.VK_LMENU;
            const VK_RALT = keyboard_and_mouse.VK_RMENU;
            const VK_SHIFT = keyboard_and_mouse.VK_SHIFT;
            const VK_LSHIFT = keyboard_and_mouse.VK_LSHIFT;
            const VK_RSHIFT = keyboard_and_mouse.VK_RSHIFT;

            const PRESSED: u8 = 0b10000000;

            fn getKeyboardState(keyboard: *[256]u8) void {
                _ = keyboard_and_mouse.GetKeyboardState(keyboard);
            }

            fn anyKeySet(keyboard: *const [256]u8, keys: []const VIRTUAL_KEY) bool {
                for (keys) |key| {
                    if (key == keyboard_and_mouse.VK_CAPITAL or key == keyboard_and_mouse.VK_NUMLOCK) {
                        if (keyboard[@intFromEnum(key)] & 1 == 1) return true;
                    } else if (keyboard[@intFromEnum(key)] & PRESSED == PRESSED) return true;
                }
                return false;
            }

            fn getModifiers(keyboard: *const [256]u8) Modifiers {
                var modifiers: Modifiers = .{};
                if (anyKeySet(keyboard, &[3]VIRTUAL_KEY{ VK_CONTROL, VK_LCONTROL, VK_RCONTROL })) {
                    modifiers.ctrl = true;
                }
                if (anyKeySet(keyboard, &[3]VIRTUAL_KEY{ VK_ALT, VK_LALT, VK_RALT })) {
                    modifiers.alt = true;
                }
                if (anyKeySet(keyboard, &[3]VIRTUAL_KEY{ VK_SHIFT, VK_LSHIFT, VK_RSHIFT })) {
                    modifiers.shift = true;
                }

                return modifiers;
            }

            pub fn from(win: *Window, message: u32, wparam: usize, lparam: isize) ?Event {
                switch (message) {
                    // Request to close the window
                    windows_and_messaging.WM_CLOSE, windows_and_messaging.WM_DESTROY => {
                        return Event.close;
                    },
                    windows_and_messaging.WM_SETCURSOR => {
                        // Set user defined cursor
                        _ = windows_and_messaging.SetCursor(Window.Inner.getHCursor(win.inner.cursor));
                        // Allow for resize cursor to be drawn if cursor is at correct position
                        // return windows_and_messaging.DefWindowProcW(hwnd, msg, wparam, lparam);
                    },
                    windows_and_messaging.WM_COMMAND => {
                        const wmId: u16 = @truncate(wparam);
                        const wmEvent: u16 = @truncate(wparam >> 16);
                        if (wmEvent == 0) {
                            const menu_info = win.inner.itemToMenu.getPtr(@intCast(wmId));
                            if (menu_info) |info| {
                                return Event{.menu = .{
                                    .id = @intCast(wmId),
                                    .item = info,
                                }};
                            }
                        }
                    },
                    // Keyboard input events
                    windows_and_messaging.WM_CHAR, windows_and_messaging.WM_SYSCHAR => {
                        const scan_code: u32 = @as(u32, @intCast(lparam >> 16)) & 0xFF;
                        const virtual_key: u32 = keyboard_and_mouse.MapVirtualKeyW(scan_code, windows_and_messaging.MAPVK_VSC_TO_VK);

                        var keyboard: [256]u8 = [_]u8{0} ** 256;
                        getKeyboardState(&keyboard);

                        const modifiers: Modifiers = getModifiers(&keyboard);

                        // Reset keyboard state for modifiers so they aren't processed with `ToUnicode`
                        keyboard[@intFromEnum(keyboard_and_mouse.VK_CONTROL)] = 0;
                        // keyboard[@intFromEnum(keyboard_and_mouse.VK_SHIFT)] = 0;
                        keyboard[@intFromEnum(keyboard_and_mouse.VK_MENU)] = 0;
                        keyboard[@intFromEnum(keyboard_and_mouse.VK_LCONTROL)] = 0;
                        // keyboard[@intFromEnum(keyboard_and_mouse.VK_LSHIFT)] = 0;
                        keyboard[@intFromEnum(keyboard_and_mouse.VK_LMENU)] = 0;
                        keyboard[@intFromEnum(keyboard_and_mouse.VK_RCONTROL)] = 0;
                        // keyboard[@intFromEnum(keyboard_and_mouse.VK_RSHIFT)] = 0;
                        keyboard[@intFromEnum(keyboard_and_mouse.VK_RMENU)] = 0;

                        var buffer: [3:0]u16 = [_:0]u16{0} ** 3;
                        const result = keyboard_and_mouse.ToUnicode(
                            virtual_key,
                            scan_code,
                            &keyboard,
                            &buffer,
                            3,
                            // Set it to not modify keyboard state. Windows 1607 and above
                            0,
                        );

                        // TODO: If dead key then store for later and combine with next char/key input
                        if (result == 0) {
                            std.log.debug("[{d}] ToUnicode failed", .{result});
                        } else if (result < 0) {
                            std.log.debug("[{d}] Dead key detected", .{result});
                        } else {
                            var data: [4]u8 = [_]u8{0} ** 4;
                            _ = std.unicode.utf16LeToUtf8(&data, buffer[0..]) catch unreachable;

                            if (data.len <= 4) {
                                return Event{
                                    .key_input = .{
                                        .key = .{ .char = data },
                                        .modifiers = modifiers,
                                        .state = .pressed,
                                        .scan = scan_code,
                                        .virtual = virtual_key,
                                    },
                                };
                            }
                        }
                    },
                    windows_and_messaging.WM_KEYDOWN => {
                        if (input.parseVirtualKey(wparam, lparam)) |key| {
                            // Keyboard state to better match keyboard input with virtual keys
                            var keyboard: [256]u8 = [_]u8{0} ** 256;
                            getKeyboardState(&keyboard);

                            const modifiers: Modifiers = getModifiers(&keyboard);

                            return Event{
                                .key_input = .{
                                    .key = .{ .virtual = key },
                                    .modifiers = modifiers,
                                    .state = .pressed,
                                },
                            };
                        }
                        // return windows_and_messaging.DefWindowProcW(hwnd, uMsg, wparam, lparam);
                    },
                    // MouseMove event
                    windows_and_messaging.WM_MOUSEMOVE => {
                        if (lparam >= 0) {
                            const pos: usize = @intCast(lparam);
                            const x: u16 = @truncate(pos);
                            const y: u16 = @truncate(pos >> 16);
                            return Event{ .mouse_move = .{ .x = x, .y = y } };
                        }
                    },
                    // Mouse scrolling events
                    windows_and_messaging.WM_MOUSEWHEEL => {
                        const params: isize = @intCast(wparam);
                        const distance: i16 = @truncate(params >> 16);

                        return Event{ .mouse_scroll = .{
                            .direction = .vertical,
                            .delta = distance,
                        } };
                    },
                    windows_and_messaging.WM_MOUSEHWHEEL => {
                        const params: isize = @intCast(wparam);
                        const distance: i16 = @truncate(params >> 16);

                        return Event{
                            .mouse_scroll = .{
                                .direction = .horizontal,
                                .delta = distance,
                            },
                        };
                    },
                    // Mouse button events == MouseInput
                    windows_and_messaging.WM_LBUTTONDOWN => return Event{ .mouse_input = .{ .state = .pressed, .button = .left } },
                    windows_and_messaging.WM_LBUTTONUP => return Event{ .mouse_input = .{ .state = .released, .button = .left } },
                    windows_and_messaging.WM_MBUTTONDOWN => return Event{ .mouse_input = .{ .state = .pressed, .button = .middle } },
                    windows_and_messaging.WM_MBUTTONUP => return Event{ .mouse_input = .{ .state = .released, .button = .middle } },
                    windows_and_messaging.WM_RBUTTONDOWN => return Event{ .mouse_input = .{ .state = .pressed, .button = .right } },
                    windows_and_messaging.WM_RBUTTONUP => return Event{ .mouse_input = .{ .state = .released, .button = .right } },
                    windows_and_messaging.WM_XBUTTONDOWN => return Event{ .mouse_input = .{
                        .state = .pressed,
                        .button = if ((wparam >> 16) & 0x0001 == 0x0001) .x1 else .x2,
                    } },
                    windows_and_messaging.WM_XBUTTONUP => return Event{ .mouse_input = .{
                        .state = .released,
                        .button = if ((wparam >> 16) & 0x0001 == 0x0001) .x1 else .x2,
                    } },
                    // Check for focus and unfocus
                    windows_and_messaging.WM_SETFOCUS => return Event{ .focused = true },
                    windows_and_messaging.WM_KILLFOCUS => return Event{ .focused = false },
                    windows_and_messaging.WM_SIZE => {
                        const size: usize = @intCast(lparam);
                        return Event{
                            .resize = .{
                                .width = @intCast(@as(u16, @truncate(size))),
                                .height = @intCast(@as(u16, @truncate(size >> 16))),
                            },
                        };
                    },
                    else => return null,
                }

                return null;
            }
        },
        else => @compileError("platform not supported")
    };
};

pub fn EventLoop(S: type) type {
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
                    .handler = (struct {
                        const HWND = @import("win32").foundation.HWND;
                        pub fn handler(s: *anyopaque, context: *anyopaque, hwnd: HWND, message: u32, wparam: usize, lparam: isize) bool {
                            const inner: *EventLoop(S) = @ptrCast(@alignCast(s));
                            const ctx: *S = @ptrCast(@alignCast(context));
                            if (inner.windows.get(@intFromPtr(hwnd))) |win| {
                                if (Event.from(win, message, wparam, lparam)) |evt| {
                                    return inner.handleEvent(ctx, win, evt) catch return false;
                                }
                            }
                            return false;
                        }
                    }).handler
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
