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
        const makeResourceW = @import("util.zig").makeIntResourceW;
        const Application = makeResourceW(32512);
        const Error = makeResourceW(32513);
        const Question = makeResourceW(32514);
        const Warning = makeResourceW(32515);
        const Information = makeResourceW(32516);
        const Shield = makeResourceW(32518);

        pub fn iconToResource(icon: IconOption) [*:0]align(1) const u16 {
            return switch (icon) {
                .default => Application,
                .@"error" => Error,
                .question => Question,
                .warning => Warning,
                .information => Information,
                .security => Shield,
            };
        }
    },
    else => @compileError("Unsupported operating system"),
};
