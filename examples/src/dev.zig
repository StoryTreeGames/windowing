const std = @import("std");

pub const znwl = @import("znwl");

const Window = znwl.Window;
const Target = Window.Target;
const Event = znwl.events.Event;
const icon = znwl.icon;
const cursor = znwl.cursor;
const EventLoop = znwl.events.EventLoop;

const State = struct {
    captured: bool = false,
    focused: bool = false,

    cursor: enum { pointer, default } = .default,
    icon: enum { default, security } = .default,
    title: enum { first, second } = .first,

    pub fn toggleCursor(self: *State) cursor.Cursor {
        switch (self.cursor) {
            .pointer => {
                self.cursor = .default;
                return .{ .icon = .default };
            },
            .default => {
                self.cursor = .pointer;
                return .{ .icon = .pointer };
            },
        }
    }

    pub fn toggleIcon(self: *State) icon.Icon {
        switch (self.icon) {
            .security => {
                self.icon = .default;
                return .{ .icon = .default };
            },
            .default => {
                self.icon = .security;
                return .{ .icon = .security };
            },
        }
    }

    pub fn toggleTitle(self: *State) []const u8 {
        switch (self.title) {
            .first => {
                self.title = .second;
                return "second";
            },
            .second => {
                self.title = .first;
                return "first";
            },
        }
    }

    pub fn handler(self: *anyopaque, event: Event, target: *Target) void {
        var state: *State = @ptrCast(@alignCast(self));

        switch (event) {
            .close => {
                target.close();
            },
            .key_input => |ke| {
                switch (ke.key) {
                    .virtual => |virtual| switch (virtual) {
                        .escape => if (ke.state == .pressed) target.close(),
                        .tab => {
                            target.setIcon(state.toggleIcon()) catch unreachable;
                            target.setCursor(state.toggleCursor()) catch unreachable;
                            target.setTitle(state.toggleTitle()) catch unreachable;
                        },
                        .down => target.minimize(),
                        .up => target.restore(),
                        .right => target.maximize(),
                        .f1 => std.log.debug("F1", .{}),
                        else => {},
                    },
                    // Exit after pressing the escape key
                    .char => |char| {
                        if (ke.state == .pressed) {
                            std.log.debug("DEV [ {s} ] {s}{s}{s}{s}", .{
                                if (ke.state == .pressed) "PRESSED" else "RELEASED",
                                if (ke.isCtrl()) "ctrl+" else "",
                                if (ke.isAlt()) "alt+" else "",
                                if (ke.isShift()) "shift+" else "",
                                char,
                            });
                        }
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
            .icon = .{ .custom = "assets\\icon.ico" },
            .cursor = .{ .icon = .pointer },
        },
    );
    defer win.deinit();

    // Custom debug output of window
    std.debug.print("Press <TAB> to toggle icon, cursor, and title at runtime\n", .{});
    std.debug.print("\x1b[1;33mWARNING\x1b[39m:\x1b[22m There are a lot of debug log statements \n\n", .{});
    std.log.debug("{any}", .{win});

    event_loop.run();
}
