const std = @import("std");
pub const Window = @import("window.zig");
pub const cursor = @import("cursor.zig");
pub const icon = @import("icon.zig");
pub const input = @import("input.zig");
pub const event = @import("event.zig");
pub const dialog = @import("dialog.zig");
pub const menu = @import("menu.zig");

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

pub const Color = packed struct(u32) {
    red: u8 = 0,
    green: u8 = 0,
    blue: u8 = 0,
    _alpha: u8 = 0,

    pub const white: @This() = .{ .red = 255, .green = 255, .blue = 255 };
};

pub const Font = struct {
    height: u16,
    width: u16,
    point_size: u16,
    color: Color,
    weight: u32,
    italic: bool,
    underline: bool,
    strikeout: bool,
    // TODO: allocate or have better representation
    name: []const u8,
    // TODO: precisions, charset, quality, pitch and family, orientation, escapement
};
