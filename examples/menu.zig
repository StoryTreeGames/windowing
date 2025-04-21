const std = @import("std");

const event = @import("storytree-core").event;

const Window = @import("storytree-core").Window;
const EventLoop = event.EventLoop;
const Event = event.Event;

pub const App = struct {
    pub fn setup(event_loop: *EventLoop(App)) !void {
        _ = try event_loop.createWindow(
            .{ .width = 800, .height = 600 },
            &.{
                .SubMenu("File", &.{
                    .Action("Open"),
                    .Action("Save"),
                    .Action("Save As"),
                    .Seperator,
                    .Toggle("Watch", false)
                }),
                .Action("Quit")
            }
        );
    }

    pub fn handleEvent(event_loop: *EventLoop(App), win: *Window, evt: Event) !bool {
        std.debug.print("{any}\n", .{ evt });
        switch (evt) {
            .close => event_loop.closeWindow(win.id()),
            .menu => |menu| switch (menu.id) {
                5 => event_loop.closeWindow(win.id()),
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

    var app = App{};

    var event_loop = try EventLoop(App).init(allocator, "storytree.core.window_menu", &app);
    defer event_loop.deinit();

    try event_loop.run();
}
