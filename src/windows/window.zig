// TODO: Do owner drawn menu bar so that the background and text colors can match the caption/title bar

const std = @import("std");

const Rect = @import("../root.zig").Rect;

const _menu = @import("../menu.zig");
const MenuInfo = _menu.Info;
const MenuItem = _menu.Item;
const MenuCheckable = _menu.Checkable;
const MenuAction = _menu.Action;

const win32 = @import("win32");
const foundation = win32.foundation;
const windows_and_messaging = win32.ui.windows_and_messaging;
const keyboard_and_mouse = win32.ui.input.keyboard_and_mouse;
const library_loader = win32.system.library_loader;
const gdi = win32.graphics.gdi;
const zig = win32.zig;
const dwm = win32.graphics.dwm;

const util = @import("util.zig");
const cursorToResource = @import("cursor.zig").cursorToResource;
const iconToResource = @import("icon.zig").iconToResource;

const ico = @import("../icon.zig");
const csr = @import("../cursor.zig");
const IconType = ico.IconType;
const CursorType = @import("../cursor.zig").CursorType;
const Win = @import("../window.zig");
const EventLoop = @import("../event.zig").EventLoop;

const HMENU = windows_and_messaging.HMENU;
const WINAPI = std.os.windows.WINAPI;

const Icon = union(enum) {
    icon: IconType,
    custom: [:0]const u16,
};

const Cursor = union(enum) {
    icon: CursorType,
    custom: struct {
        path: [:0]const u16,
        width: i32,
        height: i32,
    },
};

pub const MenuContext = struct {
    allocator: std.mem.Allocator,
    count: *usize,
    current: HMENU,
    menus: *std.ArrayListUnmanaged(HMENU),
    itemToMenu: *std.AutoArrayHashMapUnmanaged(usize, MenuInfo),

    pub fn sub(self: *@This(), inner: HMENU) @This() {
        return .{
            .allocator = self.allocator,
            .count = self.count,
            .menus = self.menus,
            .itemToMenu = self.itemToMenu,
            .current = inner,
        };
    }

    pub fn appendSeperator(self: *@This()) !void {
        if (windows_and_messaging.AppendMenuA(self.current, windows_and_messaging.MF_SEPARATOR, 0, null) == 0) {
            return error.AppendMenuSeperator;
        }
    }

    pub fn appendAction(self: *@This(), action: MenuAction) !void {
        self.count.* += 1;
        const label = try self.allocator.allocSentinel(u8, action.label.len, 0);
        @memcpy(label, action.label);
        try self.itemToMenu.put(self.allocator, self.count.*, .{
            .id = action.id,
            .menu = @ptrCast(self.current),
            .payload = .{ .action = .{ .label = label } },
        });
        if (windows_and_messaging.AppendMenuA(self.current, windows_and_messaging.MF_STRING, self.count.*, label.ptr) == 0) {
            return error.AppendMenuAction;
        }
    }

    pub fn appendToggle(self: *@This(), checkable: MenuCheckable) !void {
        self.count.* += 1;
        const label = try self.allocator.allocSentinel(u8, checkable.label.len, 0);
        @memcpy(label, checkable.label);
        try self.itemToMenu.put(self.allocator, self.count.*, .{
            .id = checkable.id,
            .menu = @ptrCast(self.current),
            .payload = .{
                .toggle = .{ .label = label },
            },
        });
        if (windows_and_messaging.AppendMenuA(
            self.current,
            if (checkable.default) windows_and_messaging.MF_CHECKED else windows_and_messaging.MF_UNCHECKED,
            self.count.*,
            label.ptr,
        ) == 0) {
            return error.AppendMenuToggle;
        }
    }

    pub fn appendRadioGroup(self: *@This(), items: []const MenuCheckable) !void {
        const start = self.count.* + 1;
        const end = start + items.len;

        for (items) |item| {
            try self.appendRadioItem(item, start, end);
        }
    }

    pub fn appendRadioItem(self: *@This(), checkable: MenuCheckable, start: usize, end: usize) !void {
        self.count.* += 1;
        const label = try self.allocator.allocSentinel(u8, checkable.label.len, 0);
        @memcpy(label, checkable.label);
        try self.itemToMenu.put(self.allocator, self.count.*, .{
            .id = checkable.id,
            .menu = @ptrCast(self.current),
            .payload = .{
                .radio = .{
                    .group = .{ start, end },
                    .label = label,
                },
            },
        });
        if (windows_and_messaging.AppendMenuA(self.current, if (checkable.default) windows_and_messaging.MF_CHECKED else windows_and_messaging.MF_UNCHECKED, self.count.*, label.ptr) == 0) {
            return error.AppendMenuRadioItem;
        }
    }

    pub fn appendMenu(self: *@This(), items: []const MenuItem) !void {
        for (items) |item| {
            switch (item) {
                .seperator_item => try self.appendSeperator(),
                .action_item => |action| try self.appendAction(action),
                .toggle_item => |toggle| try self.appendToggle(toggle),
                .radio_group_item => |group| try self.appendRadioGroup(group),
                .menu_item => |subMenu| {
                    const innerMenu = windows_and_messaging.CreatePopupMenu().?;
                    try self.menus.append(self.allocator, innerMenu);
                    if (windows_and_messaging.AppendMenuA(self.current, windows_and_messaging.MF_POPUP, @intFromPtr(innerMenu), subMenu.label.ptr) == 0) {
                        return error.AppendMenuSubmenu;
                    }

                    var inner = self.sub(innerMenu);
                    try inner.appendMenu(subMenu.items);
                },
            }
        }
    }
};

title: [:0]const u16,
class: [:0]const u16,
icon: Icon,
cursor: Cursor,
theme: Win.Theme,
current_theme: Win.Theme,

handle: foundation.HWND,
instance: ?foundation.HINSTANCE,

menus: std.ArrayListUnmanaged(HMENU) = .empty,
itemToMenu: std.AutoArrayHashMapUnmanaged(usize, MenuInfo) = .empty,

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
    event_loop: *EventLoop,
) !*@This() {
    const win = try allocator.create(@This());
    errdefer allocator.destroy(win);

    const title = try util.utf8ToUtf16Alloc(allocator, options.title);
    errdefer allocator.free(title);
    const class = try util.createUIDClass(allocator);
    errdefer allocator.free(class);

    const instance = library_loader.GetModuleHandleW(null);
    const wnd_class = windows_and_messaging.WNDCLASSW{
        .lpszClassName = class.ptr,

        .style = windows_and_messaging.WNDCLASS_STYLES{ .HREDRAW = 1, .VREDRAW = 1 },
        .cbClsExtra = 0,
        .cbWndExtra = 0,

        .hIcon = null,
        .hCursor = null,
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
        @ptrCast(event_loop), // WM_CREATE lpParam
    ) orelse return error.SystemCreateWindow;

    // Set dark title bar
    var value: foundation.BOOL = undefined;
    var current_theme: Win.Theme = .dark;
    switch (options.theme) {
        .dark => value = zig.TRUE,
        .light => {
            value = zig.FALSE;
            current_theme = .light;
        },
        .system => if (util.isLightTheme() catch false) {
            current_theme = .light;
            value = zig.FALSE;
        } else {
            value = zig.TRUE;
        },
    }

    _ = dwm.DwmSetWindowAttribute(hwnd, dwm.DWMWA_USE_IMMERSIVE_DARK_MODE, &value, @sizeOf(foundation.BOOL));
    _ = windows_and_messaging.ShowWindow(hwnd, windows_and_messaging.SW_SHOWDEFAULT);

    win.* = .{
        .title = title,
        .class = class,
        .icon = .{ .icon = .default },
        .cursor = .{ .icon = .default },
        .theme = options.theme,
        .current_theme = current_theme,
        .handle = hwnd,
        .instance = instance,
    };

    try win.setCursor(allocator, options.cursor);
    try win.setIcon(allocator, options.icon);

    return win;
}

pub fn deinit(self: *@This()) void {
    windows_and_messaging.DestroyWindow(self.handle);
    for (self.menus.items) |m| _ = windows_and_messaging.DestroyMenu(m);
}

pub fn id(self: *const @This()) usize {
    return @intFromPtr(self.handle);
}

pub fn destroy(self: *const @This()) void {
    _ = windows_and_messaging.DestroyWindow(self.handle);
    _ = windows_and_messaging.UnregisterClassW(self.class, self.instance);
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
pub fn setTitle(self: *@This(), allocator: std.mem.Allocator, title: []const u8) !void {
    allocator.free(self.title);
    self.title = try util.utf8ToUtf16Alloc(allocator, title);
    _ = windows_and_messaging.SetWindowTextW(self.handle, self.title);
}

/// Set window icon
pub fn setIcon(self: *@This(), allocator: std.mem.Allocator, new_icon: ico.Icon) !void {
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

    const hIcon: usize = @intFromPtr(getHIcon(self.icon));

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
pub fn setCursor(self: *@This(), allocator: std.mem.Allocator, new_cursor: csr.Cursor) !void {
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
            _ = windows_and_messaging.SetCursor(getHCursor(self.cursor));
        }
    }
}

/// Set the cursors position relative to the window
pub fn setCursorPos(self: *@This(), x: i32, y: i32) void {
    var point = foundation.POINT{
        .x = x,
        .y = y,
    };
    _ = gdi.ClientToScreen(self.handle, &point);
    _ = windows_and_messaging.SetCursorPos(point.x, point.y);
}

/// Set the mouse to be captured by the window, or release it from the window
pub fn setCapture(self: *@This(), state: bool) void {
    if (state) {
        _ = keyboard_and_mouse.SetCapture(self.handle);
    } else {
        _ = keyboard_and_mouse.ReleaseCapture();
    }
}

pub fn setTheme(self: *@This(), theme: Win.Theme) void {
    if (theme == self.theme) return;
    self.theme = theme;

    self.setCurrentTheme(theme);
}

pub fn setCurrentTheme(self: *@This(), theme: Win.Theme) void {
    if (theme == self.current_theme) return;
    switch (theme) {
        .light => {
            self.current_theme = .light;
            _ = dwm.DwmSetWindowAttribute(self.handle, dwm.DWMWA_USE_IMMERSIVE_DARK_MODE, &zig.FALSE, @sizeOf(foundation.BOOL));
        },
        .dark => {
            self.current_theme = .dark;
            _ = dwm.DwmSetWindowAttribute(self.handle, dwm.DWMWA_USE_IMMERSIVE_DARK_MODE, &zig.TRUE, @sizeOf(foundation.BOOL));
        },
        .system => if (util.isLightTheme() catch false) {
            self.current_theme = .light;
            _ = dwm.DwmSetWindowAttribute(self.handle, dwm.DWMWA_USE_IMMERSIVE_DARK_MODE, &zig.FALSE, @sizeOf(foundation.BOOL));
        } else {
            self.current_theme = .dark;
            _ = dwm.DwmSetWindowAttribute(self.handle, dwm.DWMWA_USE_IMMERSIVE_DARK_MODE, &zig.TRUE, @sizeOf(foundation.BOOL));
        }
    }
}

pub fn getCurrentTheme(self: *@This()) Win.Theme {
    return self.current_theme;
}

pub fn getTheme(self: *@This()) Win.Theme {
    return self.theme;
}

pub fn setMenu(self: *@This(), allocator: std.mem.Allocator, new_menu: ?[]const MenuItem) !void {
    for (self.menus.items) |m| _ = windows_and_messaging.DestroyMenu(m);
    for (self.itemToMenu.values()) |v| switch (v.payload) {
        .toggle => |t| allocator.free(t.label),
        .action => |a| allocator.free(a.label),
        .radio => |r| allocator.free(r.label),
    };
    self.menus.clearAndFree(allocator);
    self.itemToMenu.clearAndFree(allocator);

    var rootMenu: ?HMENU = null;
    if (new_menu) |userMenu| {
        if (userMenu.len > 0) {
            rootMenu = windows_and_messaging.CreateMenu().?;
            try self.menus.append(allocator, rootMenu.?);

            var count: usize = 0;
            var context = MenuContext{
                .allocator = allocator,
                .current = rootMenu.?,
                .menus = &self.menus,
                .itemToMenu = &self.itemToMenu,
                .count = &count,
            };

            try context.appendMenu(userMenu);

            _ = windows_and_messaging.SetMenu(self.handle, rootMenu);
            _ = windows_and_messaging.DrawMenuBar(self.handle);
            return;
        }
    }
    _ = windows_and_messaging.SetMenu(self.handle, null);
    _ = windows_and_messaging.DrawMenuBar(self.handle);
}

const ImmersiveColorSet: [:0]const u8 = "ImmersiveColorSet\x00";
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

        if (event_loop) |loop| {
            // TODO: Return failure
            if (!loop.handleEvent(.{ hwnd, uMsg, wparam, lparam })) {
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

fn getHCursor(cursor: Cursor) ?windows_and_messaging.HCURSOR {
    return switch (cursor) {
        .icon => |i| windows_and_messaging.LoadCursorW(null, cursorToResource(i)),
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

fn getHIcon(icon: Icon) ?windows_and_messaging.HICON {
    return switch (icon) {
        .icon => |i| windows_and_messaging.LoadIconW(null, iconToResource(i)),
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
