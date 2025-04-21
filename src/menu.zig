const std = @import("std");

pub const Checkable = struct {
    name: [:0]const u8,
    default: bool,
};

pub const Menu = struct {
    name: [:0]const u8,
    items: []const Item,
};

pub const Item = union(enum) {
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

pub const Info = struct {
    menu: *anyopaque,
    payload: Payload,

    pub const Payload = union(enum) {
        action,
        toggle,
        radio: std.meta.Tuple(&.{ usize, usize })
    };
};
