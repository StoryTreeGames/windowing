const std = @import("std");
const builtin = @import("builtin");

const zig = @import("win32").zig;
const windows_and_messaging = @import("win32").ui.windows_and_messaging;

const Window = @import("window.zig");
const Key = @import("input.zig").Key;
const MouseButton = @import("input.zig").MouseButton;
const Position = @import("root.zig").Position;
const Target = Window.Target;

pub const KeyEvent = struct {
    /// Current button state, i.e. pressed or released
    state: ButtonState,
    /// Virtual key code
    virtual: usize = 0,
    /// Scan code
    scan: u8 = 0,
    /// Key enum representation
    key: Key,
};

pub const ButtonState = enum {
    pressed,
    released,
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

/// Event corresponding to a size
pub const SizeEvent = struct {
    width: u16,
    height: u16,
};

/// Window events that occur and are sent by the OS
pub const Event = union(enum) {
    /// Repaint request
    repaint,
    /// Close request
    close,
    /// Resize event pose
    resize: SizeEvent,
    /// Focus or Unfocus event post
    focused: bool,
    /// Key input event post
    key_input: KeyEvent,
    /// Mouse button input event post
    mouse_input: MouseEvent,
    /// Mouse move event post
    mouse_move: Position(u16),
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

    state: *anyopaque,
    handler: *const fn (self: *anyopaque, event: Event, target: *Target) void,

    /// Create a new event loop with a given event handler
    pub fn init(
        state: *anyopaque,
        handler: *const fn (self: *anyopaque, event: Event, target: *Target) void,
    ) EventLoop {
        return EventLoop{ .windowCount = 0, .state = state, .handler = handler };
    }

    pub fn handle_event(self: @This(), event: Event, target: *Target) void {
        self.handler(self.state, event, target);
    }

    pub fn deref(self: *EventLoop) void {
        self._mutex.lock();
        defer self._mutex.unlock();
        self.windowCount -= 1;
    }

    pub fn ref(self: *EventLoop) void {
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
