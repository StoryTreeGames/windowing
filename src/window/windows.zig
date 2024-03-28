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

const Error = error{ InvalidUtf8, OutOfMemory, SystemCreateWindow };

const T = @import("win32").zig.L;

const UUID = @import("root").uuid.UUID;

const Event = @import("root").events.Event;

const Self = @This();

title: [:0]const u8,
class: [:0]const u8,

titleWide: [:0]const u16,
classWide: [:0]const u16,

handle: ?foundation.HWND,
allocator: std.mem.Allocator,

pub const Target = struct {
    hwnd: foundation.HWND,

    pub fn exit(self: Target) void {
        _ = windows_and_messaging.DestroyWindow(self.hwnd);
    }
    pub fn show(self: Target, state: bool) void {
        show_window(self.hwnd, state);
    }
};

fn wnd_proc(
    hwnd: foundation.HWND,
    uMsg: u32,
    wparam: foundation.WPARAM,
    lparam: foundation.LPARAM,
) callconv(WINAPI) foundation.LRESULT {
    switch (uMsg) {
        windows_and_messaging.WM_PAINT => {},
        windows_and_messaging.WM_DESTROY => {
            windows_and_messaging.PostQuitMessage(0);
            _ = Event.close;
            // _ = windows_and_messaging.DestroyWindow(hwnd);
            // if (event_handler) |handler| {
            //     event_handler(Event{.close}, Target{});
            // }
            // break :blk Message.Close;
        },
        else => return windows_and_messaging.DefWindowProcW(hwnd, uMsg, wparam, lparam),
    }

    return 0;
}

const WindowOptions = struct { title: []const u8 = "" };

/// Create a new window with the given title
pub fn init(
    allocator: std.mem.Allocator,
    options: WindowOptions,
) Error!Self {
    const title: [:0]u8 = try allocator.allocSentinel(u8, options.title.len, 0);
    @memcpy(title, options.title);
    const titleWide: [:0]const u16 = try rtUtf8ToUtf16(allocator, title);

    const class = try createUIDClass(allocator);
    const classWide = try rtUtf8ToUtf16(allocator, class[0..]);
    std.log.info("Create Window ['{s}'] {s}", .{ title, class });

    var window = Self{
        .title = title,
        .titleWide = titleWide,
        .class = class,
        .classWide = classWide,
        .handle = null,
        .allocator = allocator,
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
        .lpfnWndProc = wnd_proc,
    };
    const result = windows_and_messaging.RegisterClassW(&wnd_class);

    if (result == 0) {
        return error.SystemCreateWindow;
    }

    const handle = windows_and_messaging.CreateWindowExW(
        windows_and_messaging.WINDOW_EX_STYLE{},
        classWide.ptr, // Class name
        titleWide.ptr, // Window name
        windows_and_messaging.WS_OVERLAPPEDWINDOW, // style
        windows_and_messaging.CW_USEDEFAULT,
        windows_and_messaging.CW_USEDEFAULT, // initial position
        windows_and_messaging.CW_USEDEFAULT,
        windows_and_messaging.CW_USEDEFAULT, // initial size
        null, // Parent
        null, // Menu
        instance,
        null, // WM_CREATE lpParam
    );

    if (handle == null) {
        return error.SystemCreateWindow;
    }

    window.handle = handle;

    // Set dark title bar
    const value: foundation.BOOL = zig.TRUE;
    _ = dwm.DwmSetWindowAttribute(handle, dwm.DWMWA_USE_IMMERSIVE_DARK_MODE, &value, @sizeOf(foundation.BOOL));

    return window;
}

pub fn show(self: Self, state: bool) void {
    show_window(self.handle, state);
}

fn show_window(handle: ?foundation.HWND, state: bool) void {
    if (handle) |hwnd| {
        _ = windows_and_messaging.ShowWindow(
            hwnd,
            if (state) windows_and_messaging.SW_SHOW else windows_and_messaging.SW_HIDE,
        );
        _ = gdi.UpdateWindow(hwnd);
    }
}

/// Release window allocated memory.
///
/// Right now this includes the window classname
pub fn deinit(self: Self) void {
    self.allocator.free(self.class);
    self.allocator.free(self.classWide);
    self.allocator.free(self.title);
    self.allocator.free(self.titleWide);
}

/// Create/Allocate a unique window class with a uuid v4 prefixed with `ZNWL-`
fn createUIDClass(allocator: std.mem.Allocator) AllocError![:0]u8 {
    var class = try std.ArrayList(u8).initCapacity(allocator, 41);
    defer class.deinit();

    const uuid = UUID.init();
    try std.fmt.format(class.writer(), "ZNWL-{s}", .{uuid});

    const uid: []u8 = try class.toOwnedSlice();

    const result: [:0]u8 = try allocator.allocSentinel(u8, uid.len, 0);
    @memcpy(result, uid);
    allocator.free(uid);

    return result;
}

/// Allocate a sentinal utf16 string from a utf8 string
fn rtUtf8ToUtf16(allocator: std.mem.Allocator, data: []const u8) Error![:0]u16 {
    const len: usize = unicode.calcUtf16LeLen(data) catch unreachable;
    var utf16le: [:0]u16 = try allocator.allocSentinel(u16, len, 0);
    const utf16le_len = try unicode.utf8ToUtf16Le(utf16le[0..], data[0..]);
    assert(len == utf16le_len);
    return utf16le;
}
