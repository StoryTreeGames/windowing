const std = @import("std");
const event = @import("../event.zig");

const Event = event.Event;
const EventHandler = event.EventHandler;
const util = @import("./util.zig");

pub fn EventLoop(S: type) type {
    return struct {
        const zig = @import("win32").zig;
        const windows_and_messaging = @import("win32").ui.windows_and_messaging;

        pub fn messageLoop(event_loop: *event.EventLoop(S)) !void {
            var message: windows_and_messaging.MSG = undefined;
            while (event_loop.isActive() and windows_and_messaging.GetMessageW(&message, null, 0, 0) == zig.TRUE) {
                _ = windows_and_messaging.TranslateMessage(&message);
                _ = windows_and_messaging.DispatchMessageW(&message);
            }
        }

        pub fn pollMessages() !bool {
            var message: windows_and_messaging.MSG = undefined;
            if (windows_and_messaging.PeekMessageW(&message, null, 0, 0, windows_and_messaging.PM_REMOVE) != 0) {
                _ = windows_and_messaging.TranslateMessage(&message);
                _ = windows_and_messaging.DispatchMessageW(&message);
                return true;
            }
            return false;
        }

        pub fn setup(id: [:0]const u16) !void {
            if (util.SetCurrentProcessExplicitAppUserModelID(id.ptr) != util.S_OK) return error.UnknownError;
        }
    };
}

