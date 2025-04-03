const std = @import("std");

const Rect = @import("../root.zig").Rect;

const win32 = @import("win32");
const foundation = win32.foundation;
const windows_and_messaging = win32.ui.windows_and_messaging;
const keyboard_and_mouse = win32.ui.input.keyboard_and_mouse;
const library_loader = win32.system.library_loader;
const gdi = win32.graphics.gdi;
const zig = win32.zig;
const dwm = win32.graphics.dwm;

const util = @import("util.zig");
const ico = @import("../icon.zig");
const csr = @import("../cursor.zig");

const Win = @import("../window.zig");
const EventHandler = @import("../event.zig").EventHandler;

const WINAPI = std.os.windows.WINAPI;

const Icon = union(enum) {
    icon: ico.IconType,
    custom: [:0]const u16,
};

const Cursor = union(enum) {
    icon: csr.CursorType,
    custom: struct {
        path: [:0]const u16,
        width: i32,
        height: i32,
    },
};

title: [:0]const u16,
class: [:0]const u16,
icon: Icon,
cursor: Cursor,

handle: foundation.HWND,
instance: ?foundation.HINSTANCE,

pub fn format(value: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
    var buf: [4]u8 = undefined;

    try writer.writeAll("Window { title: '");
    var title = std.unicode.Utf16LeIterator.init(value.title);
    while (try title.nextCodePoint()) |cp| {
        const len = try std.unicode.utf8Encode(cp, &buf);
        try writer.writeAll(buf[0..len]);
    }

    try writer.writeAll("', class: '");
    var class = std.unicode.Utf16LeIterator.init(value.class);
    while (try class.nextCodePoint()) |cp| {
        const len = try std.unicode.utf8Encode(cp, &buf);
        try writer.writeAll(buf[0..len]);
    }

    try writer.writeAll("' }");
}

/// Create a new window
///
/// - @param `allocator` Allocates the wide strings for the window. Must live longer than the window
/// - @param `event_loop` Event handler and driver for the window
/// - @param `options` Options on how the window should look and behave when it is created
///
/// @returns `Window` An instance of a window. Contains methods to manipulate the window.
pub fn init(
    allocator: std.mem.Allocator,
    options: Win.Options,
    handler: *EventHandler,
) !*@This() {
    const win = try allocator.create(@This());
    errdefer allocator.destroy(win);

    const title = try util.utf8ToUtf16Alloc(allocator, options.title);
    errdefer allocator.free(title);
    const class = try util.createUIDClass(allocator);
    errdefer allocator.free(class);

    const icon: Icon = switch (options.icon) {
        .icon => |i| .{ .icon = i },
        .custom => |custom| custom: {
            const temp = std.fs.cwd().realpathAlloc(allocator, custom) catch |err| switch (err) {
                error.FileNotFound => return error.FileNotFound,
                error.OutOfMemory => return error.OutOfMemory,
                else => return error.InvalidUtf8,
            };
            defer allocator.free(temp);

            // Move the cursor path into a null terminated utf16 string
            break :custom .{
                .custom = try util.utf8ToUtf16Alloc(allocator, temp),
            };
        },
    };
    errdefer switch (icon) {
        .custom => |custom| allocator.free(custom),
        else => {},
    };

    const cursor: Cursor = switch (options.cursor) {
        .icon => |i| .{ .icon = i },
        .custom => |custom| custom: {
            const temp = std.fs.cwd().realpathAlloc(allocator, custom.path) catch |err| switch (err) {
                error.FileNotFound => return error.FileNotFound,
                error.OutOfMemory => return error.OutOfMemory,
                else => return error.InvalidUtf8,
            };
            defer allocator.free(temp);

            // Move the cursor path into a null terminated utf16 string
            break :custom .{
                .custom = .{
                    .path = try util.utf8ToUtf16Alloc(allocator, temp),
                    .width = custom.width,
                    .height = custom.height,
                },
            };
        },
    };
    errdefer switch (cursor) {
        .custom => |custom| allocator.free(custom.path),
        else => {},
    };

    const instance = library_loader.GetModuleHandleW(null);
    const wnd_class = windows_and_messaging.WNDCLASSW{
        .lpszClassName = class.ptr,

        .style = windows_and_messaging.WNDCLASS_STYLES{ .HREDRAW = 1, .VREDRAW = 1 },
        .cbClsExtra = 0,
        .cbWndExtra = 0,

        .hIcon = getHIcon(icon),
        .hCursor = getHCursor(cursor),
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
        .MINIMIZE = @intFromBool(options.show == .minimize),
        .MAXIMIZE = @intFromBool(options.show == .maximize),
    };

    const hwnd = windows_and_messaging.CreateWindowExW(
        windows_and_messaging.WINDOW_EX_STYLE{},
        class.ptr,
        title.ptr,
        window_style, // style
        if (options.x) |x| @intCast(x) else windows_and_messaging.CW_USEDEFAULT,
        if (options.y) |y| @intCast(y) else windows_and_messaging.CW_USEDEFAULT, // initial position
        if (options.width) |width| @intCast(width) else windows_and_messaging.CW_USEDEFAULT,
        if (options.height) |height| @intCast(height) else windows_and_messaging.CW_USEDEFAULT, // initial size
        null, // Parent
        null, // Menu
        instance,
        @ptrCast(handler), // WM_CREATE lpParam
    ) orelse return error.SystemCreateWindow;

    // Set dark title bar
    var value: foundation.BOOL = undefined;
    switch (options.theme) {
        .dark => value = zig.TRUE,
        .light => value = zig.FALSE,
        .system => value = zig.TRUE,
    }
    _ = dwm.DwmSetWindowAttribute(hwnd, dwm.DWMWA_USE_IMMERSIVE_DARK_MODE, &value, @sizeOf(foundation.BOOL));
    _ = windows_and_messaging.ShowWindow(hwnd, windows_and_messaging.SW_SHOWDEFAULT);

    win.* = .{
        .title = title,
        .class = class,
        .icon = icon,
        .cursor = cursor,
        .handle = hwnd,
        .instance = instance,
    };

    return win;
}

pub fn deinit(self: *@This()) void {
    windows_and_messaging.DestroyWindow(self.handle);
}

pub fn id(self: *const @This()) usize {
    return @intFromPtr(self.handle);
}

pub fn destroy(self: *const @This()) void {
    _ = windows_and_messaging.DestroyWindow(self.handle);
}

/// Minimize the window
pub fn minimize(self: *const @This()) void {
    show(self.handle, .minimize);
}

/// Maximize the window
pub fn maximize(self: *const @This()) void {
    show(self.handle, .maximize);
}

/// Restore the window to its default windowed state
pub fn restore(self: *const @This()) void {
    show(self.handle, .restore);
}

/// Get the windows current rect (bounding box)
pub fn getRect(self: *const @This()) Rect(u32) {
    var rect = foundation.RECT{ .left = 0, .top = 0, .right = 0, .bottom = 0 };

    _ = windows_and_messaging.GetClientRect(self.handle, &rect);
    return .{
        .x = @intCast(rect.left),
        .y = @intCast(rect.top),
        .width = @intCast(rect.right -| rect.left),
        .height = @intCast(rect.bottom -| rect.top),
    };
}

/// Set window title
pub fn setTitle(self: *const @This(), allocator: std.mem.Allocator, title: []const u8) !void {
    allocator.free(self.title);
    self.title = try util.utf8ToUtf16Alloc(allocator, title);
    _ = windows_and_messaging.SetWindowTextW(self.handle, self.title);
}

/// Set window icon
pub fn setIcon(self: *const @This(), allocator: std.mem.Allocator, new_icon: Icon) !void {
    // Free old icon memory
    switch (self.icon) {
        .custom => |custom| allocator.free(custom),
        else => {},
    }

    // Assign new icon value/memory
    switch (new_icon) {
        .icon => |i| self.icon = .{ .icon = i },
        .custom => |c| {
            self.icon = .{ .custom = try util.utf8ToUtf16Alloc(allocator, c) };
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
pub fn setCursor(self: *const @This(), allocator: std.mem.Allocator, new_cursor: Cursor) !void {
    // Free old cursor memory
    switch (self.cursor) {
        .custom => |c| allocator.free(c.path),
        else => {},
    }

    // Assign new cursor value/memory
    switch (new_cursor) {
        .icon => |i| self.cursor = .{ .icon = i },
        .custom => |c| {
            self.cursor = .{
                .custom = .{
                    .path = try util.utf8ToUtf16Alloc(allocator, c.path),
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
pub fn setCursorPos(self: *const @This(), x: i32, y: i32) void {
    var point = foundation.POINT{
        .x = x,
        .y = y,
    };
    _ = gdi.ClientToScreen(self.handle, &point);
    _ = windows_and_messaging.SetCursorPos(point.x, point.y);
}

/// Set the mouse to be captured by the window, or release it from the window
pub fn setCapture(self: *const @This(), state: bool) void {
    if (state) {
        _ = keyboard_and_mouse.SetCapture(self.handle);
    } else {
        _ = keyboard_and_mouse.ReleaseCapture();
    }
}

fn show(hwnd: ?foundation.HWND, state: Win.Show) void {
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

pub fn getHCursor(cursor: Cursor) ?windows_and_messaging.HCURSOR {
    return switch (cursor) {
        .icon => |i| windows_and_messaging.LoadCursorW(null, csr.cursorToResource(i)),
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

pub fn getHIcon(icon: Icon) ?windows_and_messaging.HICON {
    return switch (icon) {
        .icon => |i| windows_and_messaging.LoadIconW(null, ico.iconToResource(i)),
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
            const event_loop: *EventHandler = @ptrCast(@alignCast(create_params));
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
        const handler: ?*EventHandler = @ptrFromInt(lptr);

        if (handler) |target| {
            // TODO: Return failure
            if (!target.handleEvent(hwnd, uMsg, wparam, lparam)) {
                return windows_and_messaging.DefWindowProcW(hwnd, uMsg, wparam, lparam);
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
