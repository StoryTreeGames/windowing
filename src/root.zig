pub const uuid = @import("uuid");
pub const Window = @import("window.zig").Window;
pub const event = @import("events.zig");
pub const input = @import("input.zig");
pub const icon = @import("icon.zig");
pub const cursor = @import("cursor.zig");

pub fn Position(By: type) type {
    return struct {
        x: By,
        y: By,
    };
}

pub fn Rect(By: type) type {
    return struct {
        left: By,
        top: By,
        right: By,
        bottom: By,

        pub fn width(self: @This()) By {
            return self.right - self.left;
        }

        pub fn height(self: @This()) By {
            return self.bottom - self.top;
        }
    };
}
