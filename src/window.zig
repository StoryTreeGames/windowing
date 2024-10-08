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
const std = @import("std");
const builtin = @import("builtin");
const Cursor = @import("cursor.zig").Cursor;
const Icon = @import("icon.zig").Icon;

const Tag = @import("std").Target.Os.Tag;

pub const Error = error{ InvalidUtf8, OutOfMemory, FileNotFound, SystemCreateWindow };

/// Cross platform window representation
pub const Window = switch (builtin.target.os.tag) {
    Tag.windows => @import("window/windows.zig"),
    Tag.linux => @import("window/linux.zig"),
    Tag.macos => @import("window/apple.zig"),
    else => @compileError("znwl doesn't support the current operating system: " ++ @tagName(builtin.target.os.tag)),
};

pub const ShowState = enum { maximize, minimize, restore, fullscreen };
pub const Theme = enum { dark, light, auto };

/// Options to apply to a window when it is created
///
/// Ref: https://docs.rs/winit/latest/winit/window/struct.Window.html#method.set_window_level
/// for ideas on what options to have
/// - [ ] Level
/// - [ ] Cursor
/// - [ ] Auto update theme
pub const CreateOptions = struct {
    /// The title of the window
    title: []const u8 = "",

    /// X position of the top left corner
    x: ?i32 = null,
    /// Y position of the top left corner
    y: ?i32 = null,
    /// Width of the window
    width: ?i32 = null,
    /// Height of the window
    height: ?i32 = null,

    /// Whether the window should be shown
    // show: bool = true,
    /// Whether the window should be maximized, minimized, fullscreen, or restored
    state: ShowState = .restore,
    /// Change whether the window can be resized
    resizable: bool = true,

    icon: Icon = .{ .icon = .default },
    cursor: Cursor = .{ .icon = .default },

    /// Set to dark or light theme. Or set to auto to match the system theme
    theme: Theme = .auto,
};
