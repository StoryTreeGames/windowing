pub const Window = @import("window.zig");
pub const cursor = @import("cursor.zig");
pub const icon = @import("icon.zig");
pub const input = @import("input.zig");
pub const event = @import("event.zig");
pub const dialog = @import("dialog.zig");

pub fn Point(By: type) type {
    return struct {
        x: By,
        y: By,
    };
}

pub fn Rect(By: type) type {
    return struct {
        x: By,
        y: By,
        width: By,
        height: By,

        pub fn right(self: @This()) By {
            return self.x +| self.width;
        }

        pub fn bottom(self: @This()) By {
            return self.y +| self.height;
        }
    };
}
