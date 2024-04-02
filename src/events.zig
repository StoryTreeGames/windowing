const std = @import("std");
const builtin = @import("builtin");
const zig = @import("win32").zig;
const windows_and_messaging = @import("win32").ui.windows_and_messaging;

const Window = @import("window.zig");
const Target = Window.Target;
const KeyCode = @import("root").root.input.KeyCode;
const MouseVirtualKey = @import("root").root.input.MouseVirtualKey;

pub const KeyEvent = struct {
    alt: bool = false,
    virtual: usize,
    scan: u8,
    key: KeyCode,
};

pub const MouseInfo = struct {
    x: u16,
    y: u16,
    buttons: ?u16,

    /// The CTRL key is down.
    pub fn isControl(self: @This()) bool {
        if (self.buttons) |buttons| {
            return buttons & @intFromEnum(MouseVirtualKey.CONTROL) == @intFromEnum(MouseVirtualKey.CONTROL);
        }
        return false;
    }
    /// The left mouse button is down.
    pub fn isLButton(self: @This()) bool {
        if (self.buttons) |buttons| {
            return buttons & @intFromEnum(MouseVirtualKey.LBUTTON) == @intFromEnum(MouseVirtualKey.LBUTTON);
        }
        return false;
    }

    /// The middle mouse button is down.
    pub fn isMButton(self: @This()) bool {
        if (self.buttons) |buttons| {
            return buttons & @intFromEnum(MouseVirtualKey.MBUTTON) == @intFromEnum(MouseVirtualKey.MBUTTON);
        }
        return false;
    }

    /// The right mouse button is down.
    pub fn isRButton(self: @This()) bool {
        if (self.buttons) |buttons| {
            return buttons & @intFromEnum(MouseVirtualKey.RBUTTON) == @intFromEnum(MouseVirtualKey.RBUTTON);
        }
        return false;
    }

    /// The SHIFT key is down.
    pub fn isShift(self: @This()) bool {
        if (self.buttons) |buttons| {
            return buttons & @intFromEnum(MouseVirtualKey.SHIFT) == @intFromEnum(MouseVirtualKey.SHIFT);
        }
        return false;
    }

    /// The first X button is down.
    pub fn isXButton1(self: @This()) bool {
        if (self.buttons) |buttons| {
            return buttons & @intFromEnum(MouseVirtualKey.XBUTTON1) == @intFromEnum(MouseVirtualKey.XBUTTON1);
        }
        return false;
    }

    /// The second X button is down.
    pub fn isXButton2(self: @This()) bool {
        if (self.buttons) |buttons| {
            return buttons & @intFromEnum(MouseVirtualKey.XBUTTON2) == @intFromEnum(MouseVirtualKey.XBUTTON2);
        }
        return false;
    }
};

pub const ScrollDirection = enum {
    vertical,
    horizontal,
};

pub const ScrollEvent = struct {
    direction: ScrollDirection,
    info: MouseInfo,
    delta: u16,
    distance: i16,
};

pub const Event = union(enum) {
    repaint,
    close,
    keydown: KeyEvent,
    keyup: KeyEvent,
    keyhold: KeyEvent,
    mousemove: MouseInfo,
    scroll: ScrollEvent,
    mouseclick,
};

pub const EventLoop = struct {
    _mutex: std.Thread.Mutex = std.Thread.Mutex{},
    windowCount: usize,
    handler: *const fn (event: Event, target: Target) void,

    pub fn init(
        handler: *const fn (event: Event, target: Target) void,
    ) EventLoop {
        return EventLoop{ .windowCount = 0, .handler = handler };
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
