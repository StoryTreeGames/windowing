const std = @import("std");
const AllocError = std.mem.Allocator.Error;
const unicode = std.unicode;
const assert = std.debug.assert;
const WINAPI = std.os.windows.WINAPI;

const win32 = @import("win32");
const foundation = win32.foundation;
const windows_and_messaging = win32.ui.windows_and_messaging;
const library_loader = win32.system.library_loader;
const gdi = win32.graphics.gdi;
const dwm = win32.graphics.dwm;
const zig = win32.zig;

const KF_ALTDOWN = windows_and_messaging.KF_ALTDOWN;
const KF_REPEAT = windows_and_messaging.KF_REPEAT;

const Error = error{ InvalidUtf8, OutOfMemory, SystemCreateWindow };

const T = @import("win32").zig.L;

const UUID = @import("root").root.uuid.UUID;

const Event = @import("root").root.events.Event;
const EventLoop = @import("root").root.events.EventLoop;
const KeyCode = @import("root").root.input.KeyCode;
const MouseVirtualKey = @import("root").root.input.MouseVirtualKey;
const KeyEvent = @import("root").root.events.KeyEvent;

const Window = @This();

const KeyState = struct {
    ctrl: bool,
    shift: bool,
    pub fn init() KeyState {
        return .{
            .ctrl = false,
            .shift = false,
        };
    }
};
var key_state: KeyState = KeyState.init();

title: [:0]const u8,
class: [:0]const u8,

titleWide: [:0]const u16,
classWide: [:0]const u16,

handle: ?foundation.HWND,
allocator: std.mem.Allocator,
event_loop: *EventLoop,

pub const Target = struct {
    hwnd: foundation.HWND,
    event_loop: *EventLoop,

    pub fn exit(self: Target) void {
        _ = windows_and_messaging.DestroyWindow(self.hwnd);
        self.event_loop.decrement();
    }
    pub fn minimize(self: Target) void {
        showWindow(self.hwnd, .minimize);
    }
    pub fn maximize(self: Target) void {
        showWindow(self.hwnd, .maximize);
    }
    pub fn restore(self: Target) void {
        showWindow(self.hwnd, .restore);
    }
};

fn keyEvent(wparam: usize, lparam: isize) KeyEvent {
    const hiword: usize = @intCast(lparam >> 16);
    const key: KeyCode = @enumFromInt(wparam);

    return .{
        .virtual = wparam,
        .scan = @truncate(hiword),
        .key = key,
        .alt = if (key == .MENU) false else ((lparam >> 16) & KF_ALTDOWN) == KF_ALTDOWN,
    };
}

fn keyDownEvent(wparam: usize, lparam: isize) Event {
    const flags: usize = @intCast(lparam);
    const repeat: bool = ((flags >> 16) & KF_REPEAT) == KF_REPEAT;

    if (repeat) {
        return Event{ .keyhold = keyEvent(wparam, lparam) };
    } else {
        return Event{ .keydown = keyEvent(wparam, lparam) };
    }
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
            const event_loop: *EventLoop = @ptrCast(@alignCast(create_params));
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
        const event_loop: ?*EventLoop = @ptrFromInt(lptr);

        if (event_loop) |el| {
            const target = Target{ .hwnd = hwnd, .event_loop = el };
            switch (uMsg) {
                windows_and_messaging.WM_CLOSE => {
                    el.handler(Event.close, target);
                },
                windows_and_messaging.WM_SYSKEYDOWN => {
                    el.handler(
                        keyDownEvent(wparam, lparam),
                        target,
                    );
                    return windows_and_messaging.DefWindowProcW(hwnd, uMsg, wparam, lparam);
                },
                windows_and_messaging.WM_SYSKEYUP => {
                    el.handler(
                        Event{ .keyup = keyEvent(wparam, lparam) },
                        target,
                    );
                    return windows_and_messaging.DefWindowProcW(hwnd, uMsg, wparam, lparam);
                },
                windows_and_messaging.WM_KEYDOWN => {
                    el.handler(
                        keyDownEvent(wparam, lparam),
                        target,
                    );
                },
                windows_and_messaging.WM_KEYUP => {
                    el.handler(
                        Event{ .keyup = keyEvent(wparam, lparam) },
                        target,
                    );
                },
                windows_and_messaging.WM_MOUSEMOVE => {
                    const buttons: ?u16 = if (wparam == 0) null else @truncate(wparam);
                    const pos: usize = @intCast(lparam);
                    const x: u16 = @truncate(pos);
                    const y: u16 = @truncate(pos >> 16);
                    el.handler(Event{ .mousemove = .{ .x = x, .y = y, .buttons = buttons } }, target);
                },
                windows_and_messaging.WM_MOUSEWHEEL => {
                    const params: isize = @intCast(wparam);
                    const pos: usize = @intCast(lparam);
                    const distance: i16 = @truncate(params >> 16);

                    el.handler(
                        Event{ .scroll = .{
                            .direction = .vertical,
                            .info = .{
                                .x = @truncate(pos),
                                .y = @truncate(pos >> 16),
                                .buttons = @truncate(wparam),
                            },
                            .delta = 120,
                            .distance = @divTrunc(distance, 120),
                        } },
                        target,
                    );
                },
                windows_and_messaging.WM_MOUSEHWHEEL => {
                    const params: isize = @intCast(wparam);
                    const pos: usize = @intCast(lparam);
                    const distance: i16 = @truncate(params >> 16);

                    el.handler(
                        Event{ .scroll = .{
                            .direction = .horizontal,
                            .info = .{
                                .x = @truncate(pos),
                                .y = @truncate(pos >> 16),
                                .buttons = @truncate(wparam),
                            },
                            .delta = 120,
                            .distance = @divTrunc(distance, 120),
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
) Error!Window {
    const title: [:0]u8 = try allocator.allocSentinel(u8, options.title.len, 0);
    @memcpy(title, options.title);
    const titleWide: [:0]const u16 = try utf8ToUtf16(allocator, title);

    event_loop.increment();

    const class = try createUIDClass(allocator);
    const classWide = try utf8ToUtf16(allocator, class[0..]);

    var window = Window{
        .title = title,
        .titleWide = titleWide,
        .class = class,
        .classWide = classWide,
        .handle = null,
        .allocator = allocator,
        .event_loop = event_loop,
    };

    const instance = library_loader.GetModuleHandleW(null);

    const wnd_class = windows_and_messaging.WNDCLASSW{
        .lpszClassName = classWide.ptr,

        .style = windows_and_messaging.WNDCLASS_STYLES{ .HREDRAW = 1, .VREDRAW = 1 },
        .cbClsExtra = 0,
        .cbWndExtra = 0,

        .hIcon = windows_and_messaging.LoadIconW(null, windows_and_messaging.IDI_APPLICATION),
        .hCursor = windows_and_messaging.LoadCursorW(null, windows_and_messaging.IDC_ARROW),
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
        .VISIBLE = 1, // @intFromBool(options.show),
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
        @ptrCast(event_loop), // WM_CREATE lpParam
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

    return window;
}

pub fn minimize(self: Window) void {
    showWindow(self.handle, .minimize);
}
pub fn maximize(self: Window) void {
    showWindow(self.handle, .maximize);
}
pub fn restore(self: Window) void {
    showWindow(self.handle, .restore);
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
pub fn deinit(self: Window) void {
    self.allocator.free(self.class);
    self.allocator.free(self.classWide);
    self.allocator.free(self.title);
    self.allocator.free(self.titleWide);
}

/// Create/Allocate a unique window class with a uuid v4 prefixed with `ZNWL-`
fn createUIDClass(allocator: std.mem.Allocator) AllocError![:0]u8 {
    var class = try std.ArrayList(u8).initCapacity(allocator, 45);
    defer class.deinit();

    const uuid = UUID.init();
    try std.fmt.format(class.writer(), "ZNWL-FUL-{s}", .{uuid});

    const uid: []u8 = try class.toOwnedSlice();

    const result: [:0]u8 = try allocator.allocSentinel(u8, uid.len, 0);
    @memcpy(result, uid);
    allocator.free(uid);

    return result;
}

/// Allocate a sentinal utf16 string from a utf8 string
fn utf8ToUtf16(allocator: std.mem.Allocator, data: []const u8) Error![:0]u16 {
    const len: usize = unicode.calcUtf16LeLen(data) catch unreachable;
    var utf16le: [:0]u16 = try allocator.allocSentinel(u16, len, 0);
    const utf16le_len = try unicode.utf8ToUtf16Le(utf16le[0..], data[0..]);
    assert(len == utf16le_len);
    return utf16le;
}
