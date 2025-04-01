const std = @import("std");

pub const Window = struct {};
pub const Event = union(enum) {
    placeholder
};

pub fn EventLoop(S: type) type {
    return struct {
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) @This() {
            return .{ .allocator = allocator };
        }

        pub fn run(self: *@This(), state: *S) !void {
            var window: Window = .{};
            try self.handleEvent(state, &window, .placeholder);
        }

        fn handleEvent(self: *@This(), state: *S, window: *Window, event: Event) !void {
            if (@hasDecl(S, "handleEvent")) {
                const func = @field(S, "handleEvent");
                const F = @TypeOf(func);
                const params = @typeInfo(F).@"fn".params;
                const rtrn = @typeInfo(F).@"fn".return_type.?;

                var args: std.meta.ArgsTuple(F) = undefined;
                inline for (params, 0..) |param, i| {
                    args[i] = switch (param.type.?) {
                        *Window, *const Window => window,
                        Event => event,
                        *S, *const S => state,
                        *@This(), *const @This() => self,
                        else => @compileError("invalid event loop handler argument type: " ++ @typeName(S))
                    };
                }

                if (@typeInfo(rtrn) == .error_union) {
                    try @call(.auto, func, args);
                } else {
                    @call(.auto, func, args);
                }
            }
        }
    };
}

pub const App = struct {
    pub fn setup(event_loop: *EventLoop) !void {
        _ = event_loop;
    }

    pub fn handleEvent(self: *App, event_loop: *EventLoop(App), window: *Window, event: Event) !void {
        std.debug.print("app::handle_event", .{});
        _ = self;
        _ = event_loop;
        _ = window;
        _ = event;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = App{};
    var event_loop = EventLoop(App).init(allocator);
    try event_loop.run(&app);

    // const win1 = try event_loop.create_window(.{
    //     .title = "Zig window 1",
    //     .width = 300,
    //     .height = 400,
    //     .icon = .{ .custom = "examples\\assets\\icon.ico" },
    //     .cursor = .{ .icon = .pointer },
    // });
    //
    // const win2 = try event_loop.create_window(.{
    //     .title = "Zig window 2",
    //     .width = 800,
    //     .height = 600,
    //     .icon = .{ .custom = "examples\\assets\\icon.ico" },
    //     .cursor = .{ .icon = .pointer },
    // });
    //
    // // Custom debug output of window
    // std.debug.print("Press <TAB> to toggle icon, cursor, and title at runtime\n", .{});
    // std.debug.print("\x1b[1;33mWARNING\x1b[39m:\x1b[22m There are a lot of debug log statements \n\n", .{});
    // std.log.debug("{any}", .{win1});
    // std.log.debug("{any}", .{win2});
    //
    // event_loop.run();
}
