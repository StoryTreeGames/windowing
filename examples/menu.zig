const std = @import("std");

const event = @import("storytree-core").event;

const Window = @import("storytree-core").Window;
const EventLoop = event.EventLoop;
const Event = event.Event;

pub const App = struct {
    pub fn setup(event_loop: *EventLoop(App)) !void {
        _ = try event_loop.createWindow(.{ .width = 800, .height = 600 });
    }

    pub fn handleEvent(event_loop: *EventLoop(App), win: *Window, evt: Event) !bool {
        std.debug.print("{any}\n", .{ evt });
        switch (evt) {
            .close => event_loop.closeWindow(win.id()),
            .menu => |menu| switch (menu.id) {
                999 => event_loop.closeWindow(win.id()),
                else => {}
            },
            else => return false,
        }
        return true;
    }
};

const wam = @import("win32").ui.windows_and_messaging;

const Checkable = struct {
    name: [:0]const u8,
    default: bool,
};

const Menu = struct {
    name: [:0]const u8,
    items: []const Item,
};

const Item = union(enum) {
    seperator: void,
    action: [:0]const u8,
    toggle: Checkable,
    menu: Menu,
    radio_group: []const Checkable,

    pub const Seperator: @This() = .seperator;

    pub fn Action(label: [:0]const u8) @This() {
        return .{ .action = label };
    }

    pub fn Toggle(label: [:0]const u8, default: bool) @This() {
        return .{ .toggle = .{ .name = label, .default = default }};
    }

    pub fn SubMenu(name: [:0]const u8, items: []const Item) @This() {
        return .{ .menu = .{ .name = name, .items = items }};
    }

    pub fn Group(radio_group: []const Checkable) @This() {
        return .{ .radio_group = radio_group };
    }
};

fn MenuBar(menu_bar: []const Item) void {
    _ = menu_bar;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = App{};

    var event_loop = try EventLoop(App).init(allocator, "storytree.core.window_menu", &app);
    defer event_loop.deinit();

    const win = event_loop.windows.get(event_loop.windows.keys()[0]).?;
    const menu_handle = wam.CreateMenu();

    _ = wam.SetMenu(win.inner.handle, menu_handle);

    const file_submenu = wam.CreatePopupMenu().?;
    _ = wam.AppendMenuA(menu_handle, wam.MF_POPUP, @intFromPtr(file_submenu), "File".ptr);
    _ = wam.AppendMenuA(file_submenu, wam.MF_STRING, 1, "Open".ptr);
    _ = wam.AppendMenuA(file_submenu, wam.MF_STRING, 2, "Save".ptr);
    _ = wam.AppendMenuA(file_submenu, wam.MF_STRING, 3, "Save As".ptr);
    _ = wam.AppendMenuA(file_submenu, wam.MF_SEPARATOR, 0, null);
    _ = wam.AppendMenuA(file_submenu, wam.MF_UNCHECKED, 4, "Watch".ptr);

    _ = wam.AppendMenuA(menu_handle, wam.MF_STRING, 999, "Quit".ptr);

    _ = wam.DrawMenuBar(win.inner.handle);
    defer _ = wam.DestroyMenu(menu_handle);

    while (event_loop.isActive()) {
        _ = try event_loop.poll();
    }
    // try event_loop.run();

    MenuBar(&.{
        .SubMenu("File", &.{
            .Action("Open"),
            .Action("Save"),
            .Action("Save As"),
            .Seperator,
            .Toggle("Watch", false)
        }),
        .Action("Quit")
    });
}
