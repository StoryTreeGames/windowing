const builtin = @import("builtin");
const zig = @import("win32").zig;
const windows_and_messaging = @import("win32").ui.windows_and_messaging;

const Target = @import("window.zig").Target;

pub const Event = union(enum) {
    repaint,
    close,
    input: union(enum) { keyboard: struct {}, mouse: struct {} },
};

pub fn eventLoop(comptime handler: ?*const fn (event: Event, target: Target) void) void {
    switch (builtin.target.os.tag) {
        .windows => {
            var message: windows_and_messaging.MSG = undefined;
            while (windows_and_messaging.GetMessageW(&message, null, 0, 0) == zig.TRUE) {
                _ = windows_and_messaging.TranslateMessage(&message);
                _ = windows_and_messaging.DispatchMessageW(&message);
                if (handler) |hndlr| {
                    switch (message.message) {
                        windows_and_messaging.WM_DESTROY => {
                            hndlr(Event.close, Target{ .hwnd = message.hwnd });
                        },
                    }
                }
            }
        },
        else => {},
    }
}
