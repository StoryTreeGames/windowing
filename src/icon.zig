pub const Icon = union(enum) {
    icon: IconType,
    custom: []const u8,

    pub const Default: @This() = .{ .icon = .default };
    pub const Error: @This() = .{ .icon = .@"error" };
    pub const Question: @This() = .{ .icon = .question };
    pub const Warning: @This() = .{ .icon = .warning };
    pub const Information: @This() = .{ .icon = .information };
    pub const Security: @This() = .{ .icon = .security };
};

pub const IconType = enum {
    default,
    @"error",
    question,
    warning,
    information,
    security,
};
