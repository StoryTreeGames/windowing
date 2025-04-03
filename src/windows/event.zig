const std = @import("std");
const event = @import("../event.zig");

const Event = event.Event;
const EventHandler = event.EventHandler;

pub fn EventLoop(S: type) type {
    return struct {
        pub fn messageLoop(event_loop: *event.EventLoop(S)) !void {
            for (event_loop.windows.keys()) |key| {
                std.debug.print("{d}\n", .{ key });
            }

            const zig = @import("win32").zig;
            const windows_and_messaging = @import("win32").ui.windows_and_messaging;

            var message: windows_and_messaging.MSG = undefined;
            while (event_loop.windows.count() > 0 and windows_and_messaging.GetMessageW(&message, null, 0, 0) == zig.TRUE) {
                _ = windows_and_messaging.TranslateMessage(&message);
                _ = windows_and_messaging.DispatchMessageW(&message);
            }
        }
    };
}

