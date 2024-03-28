const builtin = @import("builtin");

pub usingnamespace switch (builtin.target.os.tag) {
    .windows => @import("window/windows.zig"),
    .linux => @import("window/linux.zig"),
    .macos => @import("window/apple.zig"),
    else => @compileError("znwl doesn't support the current operating system: " ++ @tagName(builtin.target.os.tag)),
};
