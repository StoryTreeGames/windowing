pub const Icon = union(enum) {
    icon: IconType,
    custom: []const u8,

    pub const default: @This() = .{ .icon = .default };
};

pub const IconType = enum {
    default,
    @"error",
    question,
    warning,
    information,
    security,
};
