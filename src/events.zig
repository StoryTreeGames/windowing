const std = @import("std");
const builtin = @import("builtin");
const zig = @import("win32").zig;
const windows_and_messaging = @import("win32").ui.windows_and_messaging;

const Window = @import("window.zig");
const Target = Window.Target;

pub const Event = union(enum) {
    repaint,
    close,
    input: union(enum) { keyboard: struct {}, mouse: struct {} },
};

pub const EventLoop = struct {
    _mutex: std.Thread.Mutex = std.Thread.Mutex{},
    windowCount: usize,
    handler: ?*const fn (event: Event, target: Target) void,

    pub fn init(handler: ?*const fn (event: Event, target: Target) void) EventLoop {
        return EventLoop{
            .windowCount = 0,
            .handler = handler,
        };
    }

    pub fn decrement(self: *EventLoop) void {
        self._mutex.lock();
        defer self._mutex.unlock();
        self.windowCount -= 1;
    }

    pub fn increment(self: *EventLoop) void {
        self._mutex.lock();
        defer self._mutex.unlock();
        self.windowCount += 1;
    }

    pub fn run(self: *EventLoop) void {
        switch (builtin.target.os.tag) {
            .windows => {
                var message: windows_and_messaging.MSG = undefined;
                while (self.windowCount > 0 and windows_and_messaging.GetMessageW(&message, null, 0, 0) == zig.TRUE) {
                    _ = windows_and_messaging.TranslateMessage(&message);
                    _ = windows_and_messaging.DispatchMessageW(&message);
                }
            },
            else => {},
        }
    }
};
