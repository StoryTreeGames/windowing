const std = @import("std");

const core = @import("storytree-core");
const event = core.event;

const Window = @import("storytree-core").Window;
const EventLoop = event.EventLoop;
const Event = event.Event;
const id = core.menu.id;

pub const App = struct {
    allocator: std.mem.Allocator,
    watch: bool = false,

    pub fn setup(self: *@This(), event_loop: *EventLoop(App)) !void {
        const win = try event_loop.createWindow(.{ .width = 800, .height = 600 });
        try win.setMenu(&.{
            .submenu("File", &.{
                .action("file::open", "Open"),
                .action("file::save", "Save"),
                .action("file::save-as", "Save As"),
                .seperator,
                .toggle("file::watch", "Watch", self.watch)
            }),
            .action("quit", "Quit")
        });
    }

    pub fn handleEvent(self: *@This(), event_loop: *EventLoop(App), win: *Window, evt: Event) !bool {
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();

        switch (evt) {
            .close => event_loop.closeWindow(win.id()),
            .menu => |menu| switch (menu.item.id) {
                id("quit") => event_loop.closeWindow(win.id()),
                id("file::watch") => {
                    self.watch = !self.watch;
                    menu.toggle(self.watch);
                },
                id("file::open") => {
                    _ = try core.dialog.open(arena.allocator(), .{
                        .filters = &.{
                            .{ "Herb Guide (*.hgd)", "*.hgd" },
                            .{ "All types (*.*)", "*.*" },
                        },
                        .title = "Open Herb Guide"
                    });
                },
                id("file::save-as") => {
                    _ = try core.dialog.save(arena.allocator(), .{
                        .file_name = "guide.hgd",
                        .filters = &.{
                            .{ "Herb Guide (*.hgd)", "*.hgd" },
                            .{ "All types (*.*)", "*.*" },
                        },
                        .title = "Save Herb",
                    });
                },
                else => {}
            },
            else => return false,
        }
        return true;
    }
};

const wam = @import("win32").ui.windows_and_messaging;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = App{ .allocator = allocator };

    var event_loop = try EventLoop(App).init(allocator, "storytree.core.window_menu", &app);
    defer event_loop.deinit();

    try event_loop.run();
}
