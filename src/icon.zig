pub const Icon = union(enum) {
    icon: IconOption,
    custom: []const u8,
};

pub const IconOption = enum {
    default,
    @"error",
    question,
    warning,
    information,
    security,
};

pub usingnamespace switch (@import("builtin").target.os.tag) {
    .windows => struct {
        const wam = @import("win32").ui.windows_and_messaging;
        const makeResourceW = @import("util.zig").makeIntResourceW;

        const IDI_ERROR = makeResourceW(32513);
        const IDI_WARNING = makeResourceW(32515);
        const IDI_INFORMATION = makeResourceW(32516);

        pub fn iconToResource(icon: IconOption) [*:0]align(1) const u16 {
            @import("std").debug.print("{any}", .{wam.IDI_APPLICATION});
            return switch (icon) {
                .default => wam.IDI_APPLICATION,
                .@"error" => IDI_ERROR,
                .question => wam.IDI_QUESTION,
                .warning => IDI_WARNING,
                .information => IDI_INFORMATION,
                .security => wam.IDI_SHIELD,
            };
        }
    },
    else => @compileError("Unsupported operating system"),
};
