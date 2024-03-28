const std = @import("std");

const win32 = @import("win32");
const foundation = win32.foundation;
const windows_and_messaging = win32.ui.windows_and_messaging;
const library_loader = win32.system.library_loader;
const gdi = win32.graphics.gdi;
const dwm = win32.graphics.dwm;
const zig = win32.zig;
const builtin = @import("builtin");

const assert = std.debug.assert;
const WINAPI = std.os.windows.WINAPI;

const T = zig.L;

pub const Message = enum { Close, Repaint, Input, NoOp };

// pub const Window =
pub usingnamespace switch (builtin.target.os.tag) {
    .windows => struct {
        const Self = @This();

        title: []const u8,
        handle: foundation.HWND,

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
                    // break :blk Message.Close;
                },
                else => return windows_and_messaging.DefWindowProcW(hwnd, uMsg, wparam, lparam),
            }

            return 0;
        }

        pub fn init(comptime title: []const u8) Self {
            const window_title = T(title);
            const class_name = T("ZigNativeWindow");

            const instance = library_loader.GetModuleHandleW(null);
            const class = windows_and_messaging.WNDCLASSW{
                .lpszClassName = class_name,

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
            const result = windows_and_messaging.RegisterClassW(&class);

            // TODO: Make an error response
            assert(result != 0);

            const handle = windows_and_messaging.CreateWindowExW(
                windows_and_messaging.WINDOW_EX_STYLE{},
                class_name, // Class name
                window_title, // Window name
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

            // TODO: Make an error response
            assert(handle != null);

            // Set dark title bar
            const value: foundation.BOOL = zig.TRUE;
            _ = dwm.DwmSetWindowAttribute(handle, dwm.DWMWA_USE_IMMERSIVE_DARK_MODE, &value, @sizeOf(foundation.BOOL));

            return Self{
                .title = title,
                .handle = handle.?,
            };
        }

        pub fn show(self: *const Self, state: bool) void {
            _ = windows_and_messaging.ShowWindow(
                self.handle,
                if (state) windows_and_messaging.SW_SHOW else windows_and_messaging.SW_HIDE,
            );
            _ = gdi.UpdateWindow(self.handle);
        }
    },
    else => @compileError("znwl doesn't support the current operating system: " ++ @tagName(builtin.target.os.tag)),
};
