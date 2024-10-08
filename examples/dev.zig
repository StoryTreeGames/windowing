const std = @import("std");

pub const core = @import("storytree-core");

const Window = core.Window;
const Event = core.event.Event;
const Icon = core.icon.Icon;
const Cursor = core.cursor.Cursor;
const EventLoop = core.event.EventLoop;

const State = struct {
    captured: bool = false,
    focused: bool = false,

    cursor: enum { pointer, default } = .default,
    icon: enum { default, security } = .default,
    title: enum { first, second } = .first,

    pub fn toggleCursor(self: *State) Cursor {
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

    pub fn toggleIcon(self: *State) Icon {
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

    pub fn onEvent(self: *@This(), window: *Window, event: Event) void {
        switch (event) {
            .close => {
                window.close();
            },
            .key_input => |ke| {
                switch (ke.key) {
                    .virtual => |virtual| switch (virtual) {
                        .escape => if (ke.state == .pressed) window.close(),
                        .tab => {
                            window.setIcon(self.toggleIcon()) catch unreachable;
                            window.setCursor(self.toggleCursor()) catch unreachable;
                            window.setTitle(self.toggleTitle()) catch unreachable;
                        },
                        .down => window.minimize(),
                        .up => window.restore(),
                        .right => window.maximize(),
                        .f1 => std.log.debug("F1", .{}),
                        else => {},
                    },
                    // Exit after pressing the escape key
                    .char => |char| {
                        if (ke.state == .pressed) {
                            std.log.debug("DEV [ {s} ] {s}{s}{s}{s}", .{
                                if (ke.state == .pressed) "PRESSED" else "RELEASED",
                                if (ke.modifiers.ctrl) "ctrl+" else "",
                                if (ke.modifiers.alt) "alt+" else "",
                                if (ke.modifiers.shift) "shift+" else "",
                                char,
                            });
                        }
                    },
                }
            },
            .mouse_input => |me| {
                if (me.state == .pressed and me.button == .left) {
                    window.setCapture(true);
                    self.captured = true;
                } else if (me.state == .released and me.button == .left) {
                    window.setCapture(false);
                    self.captured = false;
                }
                std.log.debug("Mouse Input: {any}", .{me});
            },
            .mouse_move => |me| {
                if (self.captured) {
                    // Lock the cursor to the center of the screen
                    // this is useful for situations like games where
                    // you capture the mouse and only want the delta of how
                    // much the mouse moved
                    const rect = window.getRect();
                    const x = @divTrunc(rect.width(), 2);
                    const y = @divTrunc(rect.height(), 2);

                    std.log.debug("Delta: (dx: {d}, dy: {d})", .{ me.x - x, me.y - y });
                    window.setCursorPos(x, y);
                } else if (self.focused) {
                    std.log.debug("Position: (x: {d}, y: {d})", .{ me.x, me.y });
                }
            },
            .mouse_scroll => |scroll| {
                std.log.debug("Scroll: {any}", .{scroll});
            },
            .focused => |focused| {
                self.focused = focused;
            },
            .resize => |re| {
                if (self.focused) {
                    std.log.debug("Resize: [width: {d}, height: {d}]", .{ re.width, re.height });
                }
            },
            else => {},
        }
    }
};

// TODO: How to make state optional?
pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var state = State{};
    var event_loop = EventLoop(State).init(allocator, &state);
    defer event_loop.deinit();

    const win = try event_loop.create_window(.{
        .title = "Zig window",
        .width = 300,
        .height = 400,
        .icon = .{ .custom = "examples\\assets\\icon.ico" },
        .cursor = .{ .icon = .pointer },
    });

    // Custom debug output of window
    std.debug.print("Press <TAB> to toggle icon, cursor, and title at runtime\n", .{});
    std.debug.print("\x1b[1;33mWARNING\x1b[39m:\x1b[22m There are a lot of debug log statements \n\n", .{});
    std.log.debug("{any}", .{win});

    event_loop.run();
}
