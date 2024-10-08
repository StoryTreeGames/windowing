const std = @import("std");
const Tag = std.Target.Os.Tag;
const builtin = @import("builtin");

const Window = switch (builtin.target.os.tag) {
    .windows => @import("window/windows.zig"),
    .linux => @import("window/linux.zig"),
    // .macos => @import("window/macos.zig"),
    else => @compileError("Invalid os support"),
};

const CreateOptions = @import("window.zig").CreateOptions;
const Key = @import("input.zig").Key;
const Modifiers = @import("input.zig").Modifiers;
const CTRL = @import("input.zig").CTRL;
const ALT = @import("input.zig").ALT;
const SHIFT = @import("input.zig").SHIFT;
const MouseButton = @import("input.zig").MouseButton;
const Position = @import("root.zig").Position;
const Target = Window.Target;

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
    width: u16,
    height: u16,
};

/// Window events that occur and are sent by the OS
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
    mouse_move: Position(u16),
    /// Mouse scroll event post
    mouse_scroll: ScrollEvent,
};

const Converter = switch (builtin.target.os.tag) {
    Tag.windows => struct {
        const input = @import("input.zig");

        const win32 = @import("win32");
        const foundation = win32.foundation;
        const windows_and_messaging = win32.ui.windows_and_messaging;
        const keyboard_and_mouse = win32.ui.input.keyboard_and_mouse;

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
            if (anyKeySet(keyboard, &[3]VIRTUAL_KEY{
                VK_CONTROL,
                VK_LCONTROL,
                VK_RCONTROL,
            })) {
                modifiers.ctrl = true;
            }
            if (anyKeySet(keyboard, &[3]VIRTUAL_KEY{
                VK_ALT,
                VK_LALT,
                VK_RALT,
            })) {
                modifiers.alt = true;
            }
            if (anyKeySet(keyboard, &[3]VIRTUAL_KEY{
                VK_SHIFT,
                VK_LSHIFT,
                VK_RSHIFT,
            })) {
                modifiers.shift = true;
            }

            return modifiers;
        }

        pub fn toEvent(window: *Window, msg: u32, wparam: foundation.WPARAM, lparam: foundation.LPARAM) ?Event {
            switch (msg) {
                // Request to close the window
                windows_and_messaging.WM_CLOSE => return Event.close,
                windows_and_messaging.WM_SETCURSOR => {
                    // Set user defined cursor
                    _ = windows_and_messaging.SetCursor(window.getHCursor());
                    // Allow for resize cursor to be drawn if cursor is at correct position
                    // return windows_and_messaging.DefWindowProcW(hwnd, msg, wparam, lparam);
                },
                // Keyboard input evenets
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
                        const data = std.unicode.utf16LeToUtf8Alloc(window.allocator, buffer[0..]) catch unreachable;
                        defer window.allocator.free(data);
                        if (data.len <= 4) {
                            return Event{
                                .key_input = .{
                                    .key = .{ .char = data[0..] },
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
                            .width = @truncate(size),
                            .height = @truncate(size >> 16),
                        },
                    };
                },
                else => return null,
            }
            return null;
        }
    },
    else => |tag| {
        @compileError("\x1b[31;1mERROR:\x1b[0m Event are not supported for the current os <{s}>\n" ++ @tagName(tag));
    },
};

/// A event context manager
///
/// Handles events by translating them and exposing a cross platform api
/// to use with the event handler.
pub fn EventLoop(State: type) type {
    return struct {
        allocator: std.mem.Allocator,
        windows: std.AutoHashMap(usize, *Window),
        state: *State,

        /// Create a new event loop with a given event handler
        pub fn init(
            allocator: std.mem.Allocator,
            state: *State,
        ) @This() {
            return .{
                .state = state,
                .windows = std.AutoHashMap(usize, *Window).init(allocator),
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *@This()) void {
            _ = self;
        }

        pub fn create_window(self: *@This(), options: CreateOptions) !*const Window {
            const window = try Window.init(self.allocator, options);
            std.debug.print("{any}", .{window.*});
            try self.windows.put(window.id(), window);
            return self.windows.get(window.id()).?;
        }

        /// Run the event/message loop which allows windows to recieve events
        pub fn run(self: *@This()) void {
            switch (builtin.target.os.tag) {
                Tag.windows => {
                    const zig = @import("win32").zig;
                    const windows_and_messaging = @import("win32").ui.windows_and_messaging;

                    var message: windows_and_messaging.MSG = undefined;
                    while (self.windows.count() > 0 and windows_and_messaging.GetMessageW(&message, null, 0, 0) == zig.TRUE) {
                        _ = windows_and_messaging.TranslateMessage(&message);

                        const id = @intFromPtr(message.hwnd);

                        if (self.windows.get(id)) |window| {
                            if (Converter.toEvent(window, message.message, message.wParam, message.lParam)) |event| {
                                self.state.onEvent(window, event);
                                if (!window.alive) {
                                    if (self.windows.get(id)) |w| {
                                        w.deinit();
                                    }
                                    _ = self.windows.remove(id);
                                }
                            } else {
                                _ = windows_and_messaging.DispatchMessageW(&message);
                            }
                        } else {
                            _ = windows_and_messaging.DispatchMessageW(&message);
                        }
                    }
                },
                // TODO: Add run impls for other systems
                else => |tag| {
                    std.debug.print("\x1b[33;1mWARNING:\x1b[0m Event loop run is not implemented for the current os <{s}>\n", .{@tagName(tag)});
                },
            }
        }
    };
}
