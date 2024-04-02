const std = @import("std");
const builtin = @import("builtin");
const zig = @import("win32").zig;
const windows_and_messaging = @import("win32").ui.windows_and_messaging;

const Window = @import("window.zig");
const Target = Window.Target;
const KeyCode = @import("root").root.input.KeyCode;
const MouseVirtualKey = @import("root").root.input.MouseVirtualKey;
const MouseButton = @import("root").root.input.MouseButton;

pub const KeyEvent = struct {
    /// Current button state, i.e. pressed or released
    state: ButtonState,
    /// Whether the alt key is pressed
    alt: bool = false,
    /// Virtual key code
    virtual: usize,
    /// Scan code
    scan: u8,
    /// Key enum representation
    key: KeyCode,
};

pub const ButtonState = enum {
    pressed,
    released,
};

pub const Position = struct {
    x: u16,
    y: u16,
};

pub const ScrollDirection = enum {
    vertical,
    horizontal,
};

pub const ScrollEvent = struct {
    /// Whether the scrolling is horizontal or vertical
    direction: ScrollDirection,
    /// The amount of pixels scrolled.
    ///
    /// Positive scrolling is to the right and down respectively for horizontal and vertical
    delta: i16,
};

pub const MouseEvent = struct {
    /// Mouse button state, i.e. pressed or released
    state: ButtonState,
    /// What mouse button was pressed: left, right, middle, x1, or x2
    button: MouseButton,
};

/// Window events that occur and are sent by the OS
pub const Event = union(enum) {
    /// Repaint request
    repaint,
    /// Close request
    close,
    /// Key input event post
    key_input: KeyEvent,
    /// Mouse button input event post
    mouse_input: MouseEvent,
    /// Mouse move event post
    mouse_move: Position,
    /// Mouse scroll event post
    mouse_scroll: ScrollEvent,
};

/// A event context manager
///
/// Handles events by translating them and exposing a cross platform api
/// to use with the event handler.
pub const EventLoop = struct {
    _mutex: std.Thread.Mutex = std.Thread.Mutex{},
    windowCount: usize,
    handler: *const fn (event: Event, target: Target) void,

    /// Create a new event loop with a given event handler
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

    /// Run the event/message loop which allows windows to recieve events
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
