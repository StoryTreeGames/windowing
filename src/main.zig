const std = @import("std");
const win32 = @import("win32/win32.zig");

const windows_and_messaging = win32.ui.windows_and_messaging;
const foundation = win32.foundation;
const assert = std.debug.assert;
const WINAPI = std.os.windows.WINAPI;
const dwm = win32.graphics.dwm;

const W = std.unicode.utf8ToUtf16LeStringLiteral;

fn wnd_proc(
    hwnd: foundation.HWND,
    uMsg: u32,
    wparam: foundation.WPARAM,
    lparam: foundation.LPARAM,
) callconv(WINAPI) foundation.LRESULT {
    switch (uMsg) {
        windows_and_messaging.WM_DESTROY => {
            windows_and_messaging.PostQuitMessage(0);
            return 0;
        },
        else => {
            return windows_and_messaging.DefWindowProcW(hwnd, uMsg, wparam, lparam);
        },
    }
}

pub fn main() !u8 {
    const class_name = W("ZigNativeWindow");

    const instance = win32.system.library_loader.GetModuleHandleW(null);
    std.debug.print("\nINSTANCE: {?}", .{instance});
    const class = windows_and_messaging.WNDCLASSW{
        .lpszClassName = class_name,

        .style = windows_and_messaging.WNDCLASS_STYLES{ .HREDRAW = 1, .VREDRAW = 1 },
        .cbClsExtra = 0,
        .cbWndExtra = 0,

        .hIcon = windows_and_messaging.LoadIconW(null, windows_and_messaging.IDI_APPLICATION),
        .hCursor = windows_and_messaging.LoadCursorW(null, windows_and_messaging.IDC_ARROW),
        .hbrBackground = win32.graphics.gdi.GetStockObject(win32.graphics.gdi.WHITE_BRUSH),
        .lpszMenuName = null,

        .hInstance = instance,
        .lpfnWndProc = wnd_proc,
    };
    const result = windows_and_messaging.RegisterClassW(&class);

    std.debug.print("\nRESULT: {}", .{result});
    assert(result != 0);

    const title = W("Zig Window");
    const window = windows_and_messaging.CreateWindowExW(
        windows_and_messaging.WINDOW_EX_STYLE{},
        class_name, // Class name
        title, // Window name
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
    std.debug.print("\nHWND: {?}", .{window});
    if (window == null) {
        std.debug.print("{}", .{foundation.GetLastError()});
    }
    assert(window != null);

    // Set dark title bar
    const value: foundation.BOOL = win32.zig.TRUE;
    _ = dwm.DwmSetWindowAttribute(window, dwm.DWMWA_USE_IMMERSIVE_DARK_MODE, &value, @sizeOf(foundation.BOOL));

    _ = windows_and_messaging.ShowWindow(window, windows_and_messaging.SW_SHOW);
    _ = win32.graphics.gdi.UpdateWindow(window);

    var message: windows_and_messaging.MSG = undefined;
    while (windows_and_messaging.GetMessageW(&message, null, 0, 0) == win32.zig.TRUE) {
        _ = windows_and_messaging.TranslateMessage(&message);
        _ = windows_and_messaging.DispatchMessageW(&message);
    }

    return @intCast(message.wParam);
}
