const std = @import("std");
const win32 = @import("win32");

const windows_and_messaging = win32.ui.windows_and_messaging;

const Window = @import("window.zig").Window;

pub fn main() !u8 {
    const win = Window.init("Zig window");
    win.show(true);

    var message: windows_and_messaging.MSG = undefined;
    while (windows_and_messaging.GetMessageW(&message, null, 0, 0) == win32.zig.TRUE) {
        _ = windows_and_messaging.TranslateMessage(&message);
        _ = windows_and_messaging.DispatchMessageW(&message);
    }

    return @intCast(message.wParam);
}
