/// Reference Rust Winit library for handling window operations
const std = @import("std");
const AllocError = std.mem.Allocator.Error;
const unicode = std.unicode;
const assert = std.debug.assert;
const WINAPI = std.os.windows.WINAPI;

const win32 = @import("win32");
const foundation = win32.foundation;
const windows_and_messaging = win32.ui.windows_and_messaging;
const keyboard_and_mouse = win32.ui.input.keyboard_and_mouse;
const library_loader = win32.system.library_loader;
const gdi = win32.graphics.gdi;
const dwm = win32.graphics.dwm;
const zig = win32.zig;

const KF_ALTDOWN = windows_and_messaging.KF_ALTDOWN;
const KF_REPEAT = windows_and_messaging.KF_REPEAT;

const root = @import("../root.zig");

const Position = root.Position;
const UUID = root.uuid.UUID;
const Event = root.events.Event;
const EventLoop = root.events.EventLoop;
const KeyCode = root.input.KeyCode;
const MouseButton = root.input.MouseButton;
const KeyEvent = root.events.KeyEvent;
const ButtonState = root.events.ButtonState;
const CursorIcon = root.cursor.CursorIcon;
const Cursor = root.cursor.Cursor;
const cursorHandle = root.cursor.cursorHandle;

const Window = @This();

const Error = error{ InvalidUtf8, OutOfMemory, FileNotFound, SystemCreateWindow };

title: []const u8,
class: []const u8,

titleWide: [:0]const u16,
classWide: [:0]const u16,
icon: ?[:0]const u16,
cursor: union(enum) {
    icon: CursorIcon,
    custom: struct {
        path: [:0]const u16,
        width: i32,
        height: i32,
    },
},

handle: ?foundation.HWND,
allocator: std.mem.Allocator,
event_loop: *EventLoop,

pub const Target = @This();

fn keyEvent(wparam: usize, lparam: isize, state: ButtonState) KeyEvent {
    const hiword: usize = @intCast(lparam >> 16);
    const key: KeyCode = @enumFromInt(wparam);

    return .{
        .state = state,
        .virtual = wparam,
        .scan = @truncate(hiword),
        .key = key,
        .alt = if (key == .menu) false else ((lparam >> 16) & KF_ALTDOWN) == KF_ALTDOWN,
    };
}

fn keyDownEvent(wparam: usize, lparam: isize) ?Event {
    const flags: usize = @intCast(lparam);
    const repeat: bool = ((flags >> 16) & KF_REPEAT) == KF_REPEAT;

    if (!repeat) {
        return Event{ .key_input = keyEvent(wparam, lparam, .pressed) };
    }
    return null;
}

fn wndProc(
    hwnd: foundation.HWND,
    uMsg: u32,
    wparam: foundation.WPARAM,
    lparam: foundation.LPARAM,
) callconv(WINAPI) foundation.LRESULT {
    if (uMsg == windows_and_messaging.WM_CREATE) {
        // Get CREATESTRUCTW pointer from lparam
        const lpptr: usize = @intCast(lparam);
        const create_struct: *windows_and_messaging.CREATESTRUCTW = @ptrFromInt(lpptr);

        // If lpCreateParams exists then assign window data/state
        if (create_struct.lpCreateParams) |create_params| {
            // Cast from anyopaque to an expected EventLoop
            // this includes casting the pointer alignment
            const event_loop: *Window = @ptrCast(@alignCast(create_params));
            // Cast pointer to isize for setting data
            const long_ptr: usize = @intFromPtr(event_loop);
            const ptr: isize = @intCast(long_ptr);
            _ = windows_and_messaging.SetWindowLongPtrW(hwnd, windows_and_messaging.GWLP_USERDATA, ptr);
        }
    } else {
        // Get window state/data pointer
        const ptr = windows_and_messaging.GetWindowLongPtrW(hwnd, windows_and_messaging.GWLP_USERDATA);
        // Cast int to optional EventLoop pointer
        const lptr: usize = @intCast(ptr);
        const window: ?*Window = @ptrFromInt(lptr);

        if (window) |target| {
            const el = target.event_loop;

            switch (uMsg) {
                // Request to close the window
                windows_and_messaging.WM_CLOSE => {
                    el.handle_event(Event.close, target);
                },
                // Keyboard input evenets
                windows_and_messaging.WM_SYSKEYDOWN => {
                    if (keyDownEvent(wparam, lparam)) |ev| {
                        el.handle_event(
                            ev,
                            target,
                        );
                    }
                    return windows_and_messaging.DefWindowProcW(hwnd, uMsg, wparam, lparam);
                },
                windows_and_messaging.WM_SYSKEYUP => {
                    el.handle_event(
                        Event{ .key_input = keyEvent(wparam, lparam, .released) },
                        target,
                    );
                    return windows_and_messaging.DefWindowProcW(hwnd, uMsg, wparam, lparam);
                },
                windows_and_messaging.WM_KEYDOWN => if (keyDownEvent(wparam, lparam)) |ev| {
                    el.handle_event(
                        ev,
                        target,
                    );
                },
                windows_and_messaging.WM_KEYUP => el.handle_event(
                    Event{ .key_input = keyEvent(wparam, lparam, .released) },
                    target,
                ),
                // MouseMove event
                windows_and_messaging.WM_MOUSEMOVE => {
                    if (lparam >= 0) {
                        const pos: usize = @intCast(lparam);
                        const x: u16 = @truncate(pos);
                        const y: u16 = @truncate(pos >> 16);
                        el.handle_event(Event{ .mouse_move = .{ .x = x, .y = y } }, target);
                    }
                },
                // Mouse scrolling events
                windows_and_messaging.WM_MOUSEWHEEL => {
                    const params: isize = @intCast(wparam);
                    const distance: i16 = @truncate(params >> 16);

                    el.handle_event(
                        Event{ .mouse_scroll = .{
                            .direction = .vertical,
                            .delta = distance,
                        } },
                        target,
                    );
                },
                windows_and_messaging.WM_MOUSEHWHEEL => {
                    const params: isize = @intCast(wparam);
                    const distance: i16 = @truncate(params >> 16);

                    el.handle_event(
                        Event{ .mouse_scroll = .{
                            .direction = .horizontal,
                            .delta = distance,
                        } },
                        target,
                    );
                },
                // Mouse button events == MouseInput
                windows_and_messaging.WM_LBUTTONDOWN => el.handle_event(
                    Event{ .mouse_input = .{ .state = .pressed, .button = .left } },
                    target,
                ),
                windows_and_messaging.WM_LBUTTONUP => el.handle_event(
                    Event{ .mouse_input = .{ .state = .released, .button = .left } },
                    target,
                ),
                windows_and_messaging.WM_MBUTTONDOWN => el.handle_event(
                    Event{ .mouse_input = .{ .state = .pressed, .button = .middle } },
                    target,
                ),
                windows_and_messaging.WM_MBUTTONUP => el.handle_event(
                    Event{ .mouse_input = .{ .state = .released, .button = .middle } },
                    target,
                ),
                windows_and_messaging.WM_RBUTTONDOWN => el.handle_event(
                    Event{ .mouse_input = .{ .state = .pressed, .button = .right } },
                    target,
                ),
                windows_and_messaging.WM_RBUTTONUP => el.handle_event(
                    Event{ .mouse_input = .{ .state = .released, .button = .right } },
                    target,
                ),
                windows_and_messaging.WM_XBUTTONDOWN => el.handle_event(
                    Event{ .mouse_input = .{
                        .state = .pressed,
                        .button = if ((wparam >> 16) & 0x0001 == 0x0001) .x1 else .x2,
                    } },
                    target,
                ),
                windows_and_messaging.WM_XBUTTONUP => el.handle_event(
                    Event{ .mouse_input = .{
                        .state = .released,
                        .button = if ((wparam >> 16) & 0x0001 == 0x0001) .x1 else .x2,
                    } },
                    target,
                ),
                // Check for focus and unfocus
                windows_and_messaging.WM_SETFOCUS => el.handle_event(Event{ .focused = true }, target),
                windows_and_messaging.WM_KILLFOCUS => el.handle_event(Event{ .focused = false }, target),
                windows_and_messaging.WM_SIZE => {
                    const size: usize = @intCast(lparam);
                    el.handle_event(
                        Event{ .resize = .{
                            .width = @truncate(size),
                            .height = @truncate(size >> 16),
                        } },
                        target,
                    );
                },
                else => return windows_and_messaging.DefWindowProcW(hwnd, uMsg, wparam, lparam),
            }
        } else {
            switch (uMsg) {
                windows_and_messaging.WM_DESTROY => {
                    windows_and_messaging.PostQuitMessage(0);
                },
                else => return windows_and_messaging.DefWindowProcW(hwnd, uMsg, wparam, lparam),
            }
        }
    }

    return 0;
}

pub const ShowState = enum { maximize, minimize, restore, fullscreen };

/// Options to apply to a window when it is created
///
/// Ref: https://docs.rs/winit/latest/winit/window/struct.Window.html#method.set_window_level
/// for ideas on what options to have
/// - [ ] Level
/// - [ ] Cursor
/// - [ ] Auto update theme
const CreateOptions = struct {
    /// The title of the window
    title: []const u8 = "",

    /// X position of the top left corner
    x: i32 = windows_and_messaging.CW_USEDEFAULT,
    /// Y position of the top left corner
    y: i32 = windows_and_messaging.CW_USEDEFAULT,
    /// Width of the window
    width: i32 = windows_and_messaging.CW_USEDEFAULT,
    /// Height of the window
    height: i32 = windows_and_messaging.CW_USEDEFAULT,

    /// Whether the window should be shown
    // show: bool = true,
    /// Whether the window should be maximized, minimized, fullscreen, or restored
    state: ShowState = .restore,
    /// Change whether the window can be resized
    resizable: bool = true,

    icon: ?[]const u8 = null,
    cursor: Cursor = .{ .icon = .Default },

    /// Set to dark or light theme. Or set to auto to match the system theme
    theme: enum { dark, light, auto } = .auto,
};

/// Create a new window
///
/// - @param `allocator` Allocates the tile and class for the window. Must live longer than the window
/// - @param `event_loop` Event handler and driver for the window
/// - @param `options` Options on how the window should look and behave when it is created
///
/// @returns `Window` An instance of a window. Contains methods to manipulate the window.
pub fn init(
    allocator: std.mem.Allocator,
    event_loop: *EventLoop,
    options: CreateOptions,
) Error!*Window {
    const title: []u8 = try allocator.alloc(u8, options.title.len);
    errdefer allocator.free(title);
    @memcpy(title, options.title);
    const titleWide: [:0]const u16 = try utf8ToUtf16(allocator, title);
    errdefer allocator.free(titleWide);

    event_loop.increment();

    const class = try createUIDClass(allocator);
    errdefer allocator.free(class);
    const classWide = try utf8ToUtf16(allocator, class[0..]);
    errdefer allocator.free(classWide);

    var window = try allocator.create(Window);
    errdefer allocator.destroy(window);

    window.* = .{
        .title = title,
        .titleWide = titleWide,
        .class = class,
        .classWide = classWide,
        .icon = null,
        .cursor = .{ .icon = .Default },
        .handle = null,
        .allocator = allocator,
        .event_loop = event_loop,
    };

    if (options.icon) |icon| {
        const temp = std.fs.cwd().realpathAlloc(allocator, icon) catch |err| switch (err) {
            error.FileNotFound => return error.FileNotFound,
            error.OutOfMemory => return error.OutOfMemory,
            else => return error.InvalidUtf8,
        };
        errdefer allocator.free(temp);
        window.icon = try utf8ToUtf16(allocator, temp);
        allocator.free(temp);
    }
    errdefer if (window.icon) |icon| {
        allocator.free(icon);
    };

    switch (options.cursor) {
        .icon => |icon| window.cursor = .{ .icon = icon },
        .custom => |custom| {
            const temp = std.fs.cwd().realpathAlloc(allocator, custom.path) catch |err| switch (err) {
                error.FileNotFound => return error.FileNotFound,
                error.OutOfMemory => return error.OutOfMemory,
                else => return error.InvalidUtf8,
            };
            errdefer allocator.free(temp);
            window.cursor = .{
                .custom = .{
                    .path = try utf8ToUtf16(allocator, temp),
                    .width = custom.width,
                    .height = custom.height,
                },
            };
            allocator.free(temp);
        },
    }
    errdefer switch (window.cursor) {
        .custom => |custom| allocator.free(custom.path),
        else => {},
    };

    const instance = library_loader.GetModuleHandleW(null);
    const wnd_class = windows_and_messaging.WNDCLASSW{
        .lpszClassName = classWide.ptr,

        .style = windows_and_messaging.WNDCLASS_STYLES{ .HREDRAW = 1, .VREDRAW = 1 },
        .cbClsExtra = 0,
        .cbWndExtra = 0,

        .hIcon = if (window.icon) |icon| @ptrCast(windows_and_messaging.LoadImageW(
            null,
            icon.ptr,
            windows_and_messaging.IMAGE_ICON,
            0,
            0,
            windows_and_messaging.IMAGE_FLAGS{
                .DEFAULTSIZE = 1,
                .LOADFROMFILE = 1,
                .SHARED = 1,
                .LOADTRANSPARENT = 1,
            },
        )) else windows_and_messaging.LoadIconW(null, windows_and_messaging.IDI_APPLICATION),
        .hCursor = switch (window.cursor) {
            .icon => |icon| windows_and_messaging.LoadCursorA(null, cursorHandle(icon)),
            .custom => |custom| @ptrCast(windows_and_messaging.LoadImageW(
                null,
                custom.path.ptr,
                windows_and_messaging.IMAGE_CURSOR,
                custom.width,
                custom.height,
                windows_and_messaging.IMAGE_FLAGS{
                    .DEFAULTSIZE = 1,
                    .LOADFROMFILE = 1,
                    .SHARED = 1,
                    .LOADTRANSPARENT = 1,
                },
            )),
        },
        .hbrBackground = gdi.GetStockObject(gdi.WHITE_BRUSH),
        .lpszMenuName = null,

        .hInstance = instance,
        .lpfnWndProc = wndProc,
    };
    const result = windows_and_messaging.RegisterClassW(&wnd_class);

    if (result == 0) {
        return error.SystemCreateWindow;
    }

    const window_style = windows_and_messaging.WINDOW_STYLE{
        .TABSTOP = 1,
        .GROUP = 1,
        .THICKFRAME = @intFromBool(options.resizable),
        .SYSMENU = 1,
        .DLGFRAME = 1,
        .BORDER = 1,
        // Show window after it is created
        .MINIMIZE = @intFromBool(options.state == .minimize),
        .MAXIMIZE = @intFromBool(options.state == .maximize),
    };

    const handle = windows_and_messaging.CreateWindowExW(
        windows_and_messaging.WINDOW_EX_STYLE{},
        classWide.ptr, // Class name
        titleWide.ptr, // Window name
        window_style, // style
        options.x,
        options.y, // initial position
        options.width,
        options.height, // initial size
        null, // Parent
        null, // Menu
        instance,
        @ptrCast(window), // WM_CREATE lpParam
    );

    if (handle == null) {
        return error.SystemCreateWindow;
    }

    window.handle = handle;

    // Set dark title bar
    var value: foundation.BOOL = undefined;
    switch (options.theme) {
        .dark => value = zig.TRUE,
        .light => value = zig.FALSE,
        .auto => value = zig.TRUE,
    }
    _ = dwm.DwmSetWindowAttribute(handle, dwm.DWMWA_USE_IMMERSIVE_DARK_MODE, &value, @sizeOf(foundation.BOOL));
    _ = windows_and_messaging.ShowWindow(window.handle, windows_and_messaging.SW_SHOWDEFAULT);

    return window;
}

/// Close the current window
pub fn close(self: Window) void {
    _ = windows_and_messaging.DestroyWindow(self.handle);
    self.event_loop.decrement();
}

/// Minimize the window
pub fn minimize(self: Window) void {
    showWindow(self.handle, .minimize);
}

/// Maximize the window
pub fn maximize(self: Window) void {
    showWindow(self.handle, .maximize);
}

/// Restore the window to its default windowed state
pub fn restore(self: Window) void {
    showWindow(self.handle, .restore);
}

/// Get the windows current rect (bounding box)
pub fn getRect(self: Window) root.Rect(i32) {
    var rect = foundation.RECT{ .left = 0, .top = 0, .right = 0, .bottom = 0 };

    _ = windows_and_messaging.GetClientRect(self.handle, &rect);
    return .{
        .left = rect.left,
        .right = rect.right,
        .top = rect.top,
        .bottom = rect.bottom,
    };
}

/// Set the cursors position relative to the window
pub fn setCursorPos(self: Window, x: i32, y: i32) void {
    var point = foundation.POINT{
        .x = x,
        .y = y,
    };
    _ = gdi.ClientToScreen(self.handle, &point);
    _ = windows_and_messaging.SetCursorPos(point.x, point.y);
}

/// Set the mouse to be captured by the window, or release it from the window
pub fn setCapture(self: Window, state: bool) void {
    if (state) {
        _ = keyboard_and_mouse.SetCapture(self.handle);
    } else {
        _ = keyboard_and_mouse.ReleaseCapture();
    }
}

fn showWindow(handle: ?foundation.HWND, state: ShowState) void {
    if (handle) |hwnd| {
        _ = windows_and_messaging.ShowWindow(hwnd, switch (state) {
            .maximize => windows_and_messaging.SW_SHOWMAXIMIZED,
            .minimize => windows_and_messaging.SW_SHOWMINIMIZED,
            .restore => windows_and_messaging.SW_RESTORE,
            else => return,
        });
        _ = gdi.UpdateWindow(hwnd);
    }
}

/// Release window allocated memory.
///
/// Right now this includes the window classname
pub fn deinit(self: *Window) void {
    self.allocator.free(self.class);
    self.allocator.free(self.classWide);
    self.allocator.free(self.title);
    self.allocator.free(self.titleWide);
    if (self.icon) |icon| {
        self.allocator.free(icon);
    }
    switch (self.cursor) {
        .custom => |custom| self.allocator.free(custom.path),
        else => {},
    }
    self.allocator.destroy(self);
}

/// Create/Allocate a unique window class with a uuid v4 prefixed with `ZNWL-`
fn createUIDClass(allocator: std.mem.Allocator) AllocError![]u8 {
    var class = try std.ArrayList(u8).initCapacity(allocator, 45);
    defer class.deinit();

    const uuid = UUID.init();
    try std.fmt.format(class.writer(), "ZNWL-FUL-{s}", .{uuid});

    return try class.toOwnedSlice();
}

/// Allocate a sentinal utf16 string from a utf8 string
fn utf8ToUtf16(allocator: std.mem.Allocator, data: []const u8) Error![:0]u16 {
    const len: usize = unicode.calcUtf16LeLen(data) catch unreachable;
    var utf16le: [:0]u16 = try allocator.allocSentinel(u16, len, 0);
    const utf16le_len = try unicode.utf8ToUtf16Le(utf16le[0..], data[0..]);
    assert(len == utf16le_len);
    return utf16le;
}
