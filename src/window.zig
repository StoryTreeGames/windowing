/// A platform specific window implementation.
///
/// This contains methods for creating and manipulating windows, but stops
/// short of the full features that allow for full UI creation. The idea is that
/// other libraries can be used with this one, like Vulkan, to render UI onto
/// the window seperatly.
///
/// ## Features
/// - size
/// - title
/// - placement
/// - show/hide
/// - icon
/// - background
/// - theme (dark/light)
/// - minimize
/// - maximize
/// - fullscreen
/// - menu
const builtin = @import("builtin");

/// Cross platform window representation
pub usingnamespace switch (builtin.target.os.tag) {
    .windows => @import("window/windows.zig"),
    .linux => @import("window/linux.zig"),
    .macos => @import("window/apple.zig"),
    else => @compileError("znwl doesn't support the current operating system: " ++ @tagName(builtin.target.os.tag)),
};
