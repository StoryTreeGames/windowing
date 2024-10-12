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
const VIRTUAL_KEY = keyboard_and_mouse.VIRTUAL_KEY;
const library_loader = win32.system.library_loader;
const gdi = win32.graphics.gdi;
const dwm = win32.graphics.dwm;
const zig = win32.zig;

const VK_CONTROL = keyboard_and_mouse.VK_CONTROL;
const VK_LCONTROL = keyboard_and_mouse.VK_LCONTROL;
const VK_RCONTROL = keyboard_and_mouse.VK_RCONTROL;
const VK_ALT = keyboard_and_mouse.VK_MENU;
const VK_LALT = keyboard_and_mouse.VK_LMENU;
const VK_RALT = keyboard_and_mouse.VK_RMENU;
const VK_SHIFT = keyboard_and_mouse.VK_SHIFT;
const VK_LSHIFT = keyboard_and_mouse.VK_LSHIFT;
const VK_RSHIFT = keyboard_and_mouse.VK_RSHIFT;

const KF_ALTDOWN = windows_and_messaging.KF_ALTDOWN;
const KF_REPEAT = windows_and_messaging.KF_REPEAT;

const root = @import("../root.zig");
const events = @import("../events.zig");
const input = @import("../input.zig");
const cursor = @import("../cursor.zig");
const icon = @import("../icon.zig");
const window = @import("../window.zig");

const Position = root.Position;
const uuid = @import("uuid");

const Event = events.Event;
const KeyEvent = events.KeyEvent;
const ButtonState = events.ButtonState;

const MouseButton = input.MouseButton;

const CursorOption = cursor.CursorOption;
const Cursor = cursor.Cursor;
const IconOption = icon.IconOption;
const Icon = icon.Icon;

const Error = window.Error;
const CreateOptions = window.CreateOptions;
const ShowState = window.ShowState;

const Window = @This();

title: [:0]const u16,
class: [:0]const u16,

icon: union(enum) {
    icon: IconOption,
    custom: [:0]const u16,
},

cursor: union(enum) {
    icon: CursorOption,
    custom: struct {
        path: [:0]const u16,
        width: i32,
        height: i32,
    },
},

handle: ?foundation.HWND,
allocator: std.mem.Allocator,

alive: bool,

pub const Target = Window;

pub fn format(value: Window, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const class = try std.unicode.utf16LeToUtf8Alloc(allocator, value.class);
    const title = try std.unicode.utf16LeToUtf8Alloc(allocator, value.title);

    return writer.print("Window {{ title: '{s}', class: '{s}' }}", .{ title, class });
}

pub fn getHCursor(self: *Window) ?windows_and_messaging.HCURSOR {
    return switch (self.cursor) {
        .icon => |i| windows_and_messaging.LoadCursorW(null, cursor.cursorToResource(i)),
        .custom => |c| @ptrCast(windows_and_messaging.LoadImageW(
            null,
            c.path.ptr,
            windows_and_messaging.IMAGE_ICON,
            c.width,
            c.height,
            windows_and_messaging.IMAGE_FLAGS{
                .DEFAULTSIZE = 1,
                .LOADFROMFILE = 1,
                .SHARED = 1,
                .LOADTRANSPARENT = 1,
            },
        )),
    };
}

fn getHIcon(self: *Window) ?windows_and_messaging.HICON {
    return switch (self.icon) {
        .icon => |i| windows_and_messaging.LoadIconW(null, icon.iconToResource(i)),
        .custom => |c| @ptrCast(windows_and_messaging.LoadImageW(
            null,
            c.ptr,
            windows_and_messaging.IMAGE_ICON,
            0,
            0,
            windows_and_messaging.IMAGE_FLAGS{
                .DEFAULTSIZE = 1,
                .LOADFROMFILE = 1,
                .SHARED = 1,
                .LOADTRANSPARENT = 1,
            },
        )),
    };
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
        const create_struct: *windows_and_messaging.CREATESTRUCTA = @ptrFromInt(lpptr);

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
        const win: ?*Window = @ptrFromInt(lptr);

        if (win) |target| {
            switch (uMsg) {
                windows_and_messaging.WM_DESTROY => {
                    target.alive = false;
                },
                else => {},
            }
            return windows_and_messaging.DefWindowProcW(hwnd, uMsg, wparam, lparam);
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

/// Create a new window
///
/// - @param `allocator` Allocates the tile and class for the window. Must live longer than the window
/// - @param `event_loop` Event handler and driver for the window
/// - @param `options` Options on how the window should look and behave when it is created
///
/// @returns `Window` An instance of a window. Contains methods to manipulate the window.
pub fn init(
    allocator: std.mem.Allocator,
    options: CreateOptions,
) Error!*Window {
    var win = try allocator.create(Window);
    errdefer win.deinit();

    win.* = .{
        .title = try utf8ToUtf16Alloc(allocator, options.title),
        .class = try createUIDClass(allocator),
        .icon = .{ .icon = .default },
        .cursor = .{ .icon = .default },
        .handle = null,
        .allocator = allocator,
        .alive = true,
    };

    switch (options.icon) {
        .icon => |i| win.icon = .{ .icon = i },
        .custom => |custom| {
            const temp = std.fs.cwd().realpathAlloc(allocator, custom) catch |err| switch (err) {
                error.FileNotFound => return error.FileNotFound,
                error.OutOfMemory => return error.OutOfMemory,
                else => return error.InvalidUtf8,
            };
            defer allocator.free(temp);

            // Move the cursor path into a null terminated utf16 string
            win.icon = .{
                .custom = try utf8ToUtf16Alloc(allocator, temp),
            };
        },
    }
    errdefer switch (win.icon) {
        .custom => |custom| allocator.free(custom),
        else => {},
    };

    switch (options.cursor) {
        .icon => |i| win.cursor = .{ .icon = i },
        .custom => |custom| {
            const temp = std.fs.cwd().realpathAlloc(allocator, custom.path) catch |err| switch (err) {
                error.FileNotFound => return error.FileNotFound,
                error.OutOfMemory => return error.OutOfMemory,
                else => return error.InvalidUtf8,
            };
            defer allocator.free(temp);

            // Move the cursor path into a null terminated utf16 string
            win.cursor = .{
                .custom = .{
                    .path = try utf8ToUtf16Alloc(allocator, temp),
                    .width = custom.width,
                    .height = custom.height,
                },
            };
        },
    }
    errdefer switch (win.cursor) {
        .custom => |custom| allocator.free(custom.path),
        else => {},
    };

    const instance = library_loader.GetModuleHandleW(null);
    const wnd_class = windows_and_messaging.WNDCLASSW{
        .lpszClassName = win.class.ptr,

        .style = windows_and_messaging.WNDCLASS_STYLES{ .HREDRAW = 1, .VREDRAW = 1 },
        .cbClsExtra = 0,
        .cbWndExtra = 0,

        .hIcon = win.getHIcon(),
        .hCursor = win.getHCursor(),
        .hbrBackground = gdi.GetStockObject(gdi.WHITE_BRUSH),
        .lpszMenuName = null,

        .hInstance = instance,
        .lpfnWndProc = wndProc, // wndProc,
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

    const hwnd = windows_and_messaging.CreateWindowExW(
        windows_and_messaging.WINDOW_EX_STYLE{},
        win.class.ptr,
        win.title.ptr,
        window_style, // style
        if (options.x) |x| x else windows_and_messaging.CW_USEDEFAULT,
        if (options.y) |y| y else windows_and_messaging.CW_USEDEFAULT, // initial position
        if (options.width) |width| width else windows_and_messaging.CW_USEDEFAULT,
        if (options.height) |height| height else windows_and_messaging.CW_USEDEFAULT, // initial size
        null, // Parent
        null, // Menu
        instance,
        @ptrCast(win), // WM_CREATE lpParam
    );

    if (hwnd == null) {
        return error.SystemCreateWindow;
    }

    win.handle = hwnd;

    // Set dark title bar
    var value: foundation.BOOL = undefined;
    switch (options.theme) {
        .dark => value = zig.TRUE,
        .light => value = zig.FALSE,
        .auto => value = zig.TRUE,
    }
    _ = dwm.DwmSetWindowAttribute(hwnd, dwm.DWMWA_USE_IMMERSIVE_DARK_MODE, &value, @sizeOf(foundation.BOOL));
    _ = windows_and_messaging.ShowWindow(win.handle, windows_and_messaging.SW_SHOWDEFAULT);

    return win;
}

/// Get the windows handle as an integer
pub fn id(self: Window) usize {
    return @intFromPtr(self.handle);
}

/// Close the current window
pub fn close(self: *Window) void {
    _ = windows_and_messaging.DestroyWindow(self.handle);
    self.alive = false;
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

/// Set window title
pub fn setTitle(self: *Window, title: []const u8) !void {
    self.allocator.free(self.title);
    self.title = try utf8ToUtf16Alloc(self.allocator, title);
    _ = windows_and_messaging.SetWindowTextW(self.handle, self.title);
}

/// Set window icon
pub fn setIcon(self: *Window, new_icon: Icon) !void {
    // Free old icon memory
    switch (self.icon) {
        .custom => |custom| self.allocator.free(custom),
        else => {},
    }

    // Assign new icon value/memory
    switch (new_icon) {
        .icon => |i| self.icon = .{ .icon = i },
        .custom => |c| {
            self.icon = .{ .custom = try utf8ToUtf16Alloc(self.allocator, c) };
        },
    }

    const hIcon: usize = @intFromPtr(self.getHIcon());

    // Send message to window to now render new icon
    _ = windows_and_messaging.SendMessageW(
        self.handle,
        windows_and_messaging.WM_SETICON,
        windows_and_messaging.ICON_SMALL,
        @intCast(hIcon),
    );
    _ = windows_and_messaging.SendMessageW(
        self.handle,
        windows_and_messaging.WM_SETICON,
        windows_and_messaging.ICON_BIG,
        @intCast(hIcon),
    );
}

/// Set window cursor
pub fn setCursor(self: *Window, new_cursor: Cursor) !void {
    // Free old cursor memory
    switch (self.cursor) {
        .custom => |c| self.allocator.free(c.path),
        else => {},
    }

    // Assign new cursor value/memory
    switch (new_cursor) {
        .icon => |i| self.cursor = .{ .icon = i },
        .custom => |c| {
            self.cursor = .{
                .custom = .{
                    .path = try utf8ToUtf16Alloc(self.allocator, c.path),
                    .width = c.width,
                    .height = c.height,
                },
            };
        },
    }

    // If the mouse is focused on the current window
    // update the cursor to the new value
    const currHandle = windows_and_messaging.GetForegroundWindow();
    if (currHandle) |hwnd| {
        if (hwnd == self.handle) {
            // Get HCURSOR pointer from icon
            _ = windows_and_messaging.SetCursor(self.getHCursor());
        }
    }
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

fn showWindow(hwnd: ?foundation.HWND, state: ShowState) void {
    std.log.debug("{any}", .{state});
    if (hwnd) |h| {
        _ = windows_and_messaging.ShowWindow(h, switch (state) {
            .maximize => windows_and_messaging.SW_SHOWMAXIMIZED,
            .minimize => windows_and_messaging.SW_SHOWMINIMIZED,
            .restore => windows_and_messaging.SW_RESTORE,
            else => return,
        });
        _ = gdi.UpdateWindow(h);
    }
}

/// Release window allocated memory.
///
/// Right now this includes the window classname
pub fn deinit(self: *Window) void {
    self.allocator.free(self.class);
    self.allocator.free(self.title);
    switch (self.icon) {
        .custom => |custom| self.allocator.free(custom),
        else => {},
    }
    switch (self.cursor) {
        .custom => |custom| self.allocator.free(custom.path),
        else => {},
    }
    self.allocator.destroy(self);
}

// --- Helpers and Utility ---

/// Create/Allocate a unique window class with a uuid v4 prefixed with `STC`
fn createUIDClass(allocator: std.mem.Allocator) Error![:0]u16 {
    // Size of {3}-{36}{null} == 41
    var buffer = try std.ArrayList(u8).initCapacity(allocator, 40);
    defer buffer.deinit();

    const uid = uuid.urn.serialize(uuid.v4.new());
    try std.fmt.format(buffer.writer(), "STC-{s}", .{uid});

    const temp = try buffer.toOwnedSlice();
    defer allocator.free(temp);

    return try utf8ToUtf16Alloc(allocator, temp);
}

/// Allocate a sentinal utf16 string from a utf8 string
fn utf8ToUtf16Alloc(allocator: std.mem.Allocator, data: []const u8) Error![:0]u16 {
    const len: usize = unicode.calcUtf16LeLen(data) catch unreachable;
    var utf16le: [:0]u16 = try allocator.allocSentinel(u16, len, 0);
    const utf16le_len = try unicode.utf8ToUtf16Le(utf16le[0..], data[0..]);
    assert(len == utf16le_len);
    return utf16le;
}
