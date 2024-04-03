const std = @import("std");

const win32 = @import("win32");
const zig = win32.zig;
const windows_and_messaging = win32.ui.windows_and_messaging;

pub const root = @import("root.zig");

const Window = root.Window;
const Target = Window.Target;
const Event = root.events.Event;
const EventLoop = root.events.EventLoop;

const State = struct {
    ctrl: bool = false,
    alt: bool = false,
    shift: bool = false,

    captured: bool = false,
    focused: bool = false,

    pub fn handler(self: *anyopaque, event: Event, target: *Target) void {
        var state: *State = @ptrCast(@alignCast(self));

        switch (event) {
            .close => {
                target.close();
            },
            .key_input => |ke| {
                switch (ke.key) {
                    .shift => state.shift = (ke.state == .pressed),
                    .control => state.ctrl = (ke.state == .pressed),
                    .menu => state.alt = (ke.state == .pressed),
                    // Exit after pressing the escape key
                    .escape => if (ke.state == .pressed) target.close(),
                    else => {
                        std.log.debug("[ {s} ] {s}{s}{s}{s}", .{
                            if (ke.state == .pressed) "PRESSED" else "RELEASED",
                            if (state.ctrl) "ctrl+" else "",
                            if (state.alt) "alt+" else "",
                            if (state.shift) "shift+" else "",
                            @tagName(ke.key),
                        });
                    },
                }
            },
            .mouse_input => |me| {
                if (me.state == .pressed and me.button == .left) {
                    target.setCapture(true);
                    state.captured = true;
                } else if (me.state == .released and me.button == .left) {
                    target.setCapture(false);
                    state.captured = false;
                }
                std.log.debug("Mouse Input: {any}", .{me});
            },
            .mouse_move => |me| {
                if (state.captured) {
                    // Lock the cursor to the center of the screen
                    // this is useful for situations like games where
                    // you capture the mouse and only want the delta of how
                    // much the mouse moved
                    const rect = target.getRect();
                    const x = @divTrunc(rect.width(), 2);
                    const y = @divTrunc(rect.height(), 2);

                    std.log.debug("Delta: (dx: {d}, dy: {d})", .{ me.x - x, me.y - y });
                    target.setCursorPos(x, y);
                } else if (state.focused) {
                    std.log.debug("Position: (x: {d}, y: {d})", .{ me.x, me.y });
                }
            },
            .mouse_scroll => |scroll| {
                std.log.debug("Scroll: {any}", .{scroll});
            },
            .focused => |focused| {
                state.focused = focused;
            },
            .resize => |re| {
                if (state.focused) {
                    std.log.debug("Resize: [width: {d}, height: {d}]", .{ re.width, re.height });
                }
            },
            else => {},
        }
    }
};

// TODO: How to make state optional?
pub fn main() !void {
    var state = State{};
    var event_loop = EventLoop.init(&state, &State.handler);

    // Needed to allocate title and class strings
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        _ = gpa.deinit();
    }
    const allocator = gpa.allocator();

    const win = try Window.init(
        allocator,
        &event_loop,
        .{
            .title = "Zig window",
            .width = 300,
            .height = 400,
        },
    );
    defer win.deinit();

    event_loop.run();
}
