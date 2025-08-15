const std = @import("std");

const core = @import("storytree-core");
const event = core.event;

const Window = @import("storytree-core").Window;
const EventLoop = event.EventLoop;
const Event = event.Event;

pub const App = struct {
    allocator: std.mem.Allocator,
    cursor: core.cursor.Cursor = .Default,
    pos: enum { tl, tr, bl, br } = .tl,

    pub fn setup(self: *const @This(), event_loop: *EventLoop) !void {
        const title = try std.fmt.allocPrint(self.allocator, "Cursor ({s})", .{ @tagName(self.cursor.icon) });
        defer self.allocator.free(title);

        _ = try event_loop.createWindow(.{
            .title = title,
            .width = 800,
            .height = 600,
            .icon = .{ .custom = "examples\\assets\\icon.ico" }
        });
    }

    pub fn handleEvent(self: *@This(), event_loop: *EventLoop, win: *Window, evt: Event) !bool {
        switch (evt) {
            .close => {
                if (core.dialog.message(.yes_no, .{
                    .icon = .warning,
                    .title = "Exit",
                    .message = "Are you sure you want to exit the application?"
                }) == .yes) {
                    event_loop.closeWindow(win.id());
                }
            },
            .key_input => |key_event| {
                if (key_event.matches(.tab, .{ .shift = false })) {
                    self.cursor = .{ .icon = @enumFromInt(@as(u8, (@intFromEnum(self.cursor.icon)) +| 1) % 33) };

                    const title = try std.fmt.allocPrint(self.allocator, "Cursor ({s})", .{ @tagName(self.cursor.icon) });
                    defer self.allocator.free(title);
                    try win.setTitle(title);

                    try win.setCursor(self.cursor);
                }

                if (key_event.matches(.tab, .{ .shift = true })) {
                    var new_cursor = @as(i8, @bitCast(@as(u8, (@intFromEnum(self.cursor.icon))))) - 1;
                    if (new_cursor < 0) {
                        new_cursor = @as(i8, @bitCast(@as(u8, (@intFromEnum(core.cursor.CursorType.zoom_in))))) + new_cursor + 1;
                    }
                    self.cursor = .{ .icon = @enumFromInt(new_cursor) };

                    const title = try std.fmt.allocPrint(self.allocator, "Cursor ({s})", .{ @tagName(self.cursor.icon) });
                    defer self.allocator.free(title);
                    try win.setTitle(title);

                    try win.setCursor(self.cursor);
                }

                if (key_event.matches(.right, .{})) {
                    const client = win.getRect();
                    switch (self.pos) {
                        .tl, .tr => {
                            win.setCursorPos(client.width -| 1, 0);
                            self.pos = .tr;
                        },
                        .bl, .br => {
                            win.setCursorPos(client.width -| 1, client.height -| 1);
                            self.pos = .br;
                        },
                    }
                }

                if (key_event.matches(.left, .{})) {
                    const client = win.getRect();
                    switch (self.pos) {
                        .tl, .tr => {
                            win.setCursorPos(0, 0);
                            self.pos = .tl;
                        },
                        .bl, .br => {
                            win.setCursorPos(0, client.height -| 1);
                            self.pos = .bl;
                        },
                    }
                }

                if (key_event.matches(.up, .{})) {
                    const client = win.getRect();
                    switch (self.pos) {
                        .br, .tr => {
                            win.setCursorPos(client.width -| 1, 0);
                            self.pos = .tr;
                        },
                        .bl, .tl => {
                            win.setCursorPos(0, 0);
                            self.pos = .tl;
                        },
                    }
                }

                if (key_event.matches(.down, .{})) {
                    const client = win.getRect();
                    switch (self.pos) {
                        .br, .tr => {
                            win.setCursorPos(client.width -| 1, client.height -| 1);
                            self.pos = .br;
                        },
                        .bl, .tl => {
                            win.setCursorPos(0, client.height -| 1);
                            self.pos = .bl;
                        },
                    }
                }
            },
            else => return false,
        }
        return true;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = App{ .allocator = allocator };

    var event_loop = try EventLoop.init(allocator, "storytree.core.example.dev", App, &app);
    defer event_loop.deinit();

    // Custom debug output of window
    std.debug.print(
        \\Controls:
        \\  <tab>: Toggle forwards through cursor icons
        \\  <shift+tab>: Toggle backwards through cursor icons
        \\  <left>: Cursor to left corner
        \\  <right>: Cursor to right corner
        \\  <up>: Cursor to top corner
        \\  <down>: Cursor to bottom corner
        \\
    , .{});

    while (event_loop.isActive()) {
        _ = try event_loop.poll();
    }
    // try event_loop.run();
}
