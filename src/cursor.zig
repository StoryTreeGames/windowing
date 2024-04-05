const util = @import("util.zig");

pub const Cursor = union(enum) {
    icon: CursorIcon,
    custom: struct {
        /// Path to the image file
        path: []const u8,
        /// The width of the cursor.
        width: i32 = 0,
        /// The height of the cursor.
        height: i32 = 0,
    },
};

/// A cross-platform way of specifying a cursor icon. When a platform specific
/// window loads a certain value of this enum it will translate it to a usable
/// type.
///
/// Referenced from rust's cursor-icon crate.
/// - https://github.com/rust-windowing/cursor-icon
pub const CursorIcon = enum {
    Default,
    Pointer,
    Crosshair,
    Text,
    VerticalText,
    NotAllowed,
    NoDrop,
    Grab,
    Grabbing,
    AllScroll,
    Move,
    EResize,
    WResize,
    EwResize,
    ColResize,
    NResize,
    SResize,
    NsResize,
    RowResize,
    NeResize,
    SwResize,
    NeswResize,
    NwResize,
    SeResize,
    NwseResize,
    Wait,
    Help,
    Progress,

    // All default to IDC_ARROW
    ContextMenu,
    Cell,
    Alias,
    Copy,
    ZoomIn,
};

pub usingnamespace switch (@import("builtin").target.os.tag) {
    .windows => struct {
        const ARROW = util.makeIntResourceA(32512);
        const HAND = util.makeIntResourceA(32649);
        const CROSS = util.makeIntResourceA(32515);
        const BEAM = util.makeIntResourceA(32513);
        const NO = util.makeIntResourceA(32648);
        const SIZEALL = util.makeIntResourceA(32646);
        const SIZEWE = util.makeIntResourceA(32644);
        const SIZENS = util.makeIntResourceA(32645);
        const SIZENESW = util.makeIntResourceA(32643);
        const SIZENWSE = util.makeIntResourceA(32642);
        const WAIT = util.makeIntResourceA(32514);
        const HELP = util.makeIntResourceA(32651);
        const APPSTARTING = util.makeIntResourceA(32650);

        pub fn resource(cursor: CursorIcon) [*:0]const u8 {
            return switch (cursor) {
                .Default => ARROW,
                .Pointer => HAND,
                .Crosshair => CROSS,
                .Text => BEAM,
                .VerticalText => BEAM,
                .NotAllowed => NO,
                .NoDrop => NO,
                .Grab => SIZEALL,
                .Grabbing => SIZEALL,
                .AllScroll => SIZEALL,
                .Move => SIZEALL,
                .EResize => SIZEWE,
                .WResize => SIZEWE,
                .EwResize => SIZEWE,
                .ColResize => SIZEWE,
                .NResize => SIZENS,
                .SResize => SIZENS,
                .NsResize => SIZENS,
                .RowResize => SIZENS,
                .NeResize => SIZENESW,
                .SwResize => SIZENESW,
                .NeswResize => SIZENESW,
                .NwResize => SIZENWSE,
                .SeResize => SIZENWSE,
                .NwseResize => SIZENWSE,
                .Wait => WAIT,
                .Help => HELP,
                .Progress => APPSTARTING,

                // All default to IDC_ARROW
                .ContextMenu => ARROW,
                .Cell => ARROW,
                .Alias => ARROW,
                .Copy => ARROW,
                .ZoomIn => ARROW,
            };
        }
    },
    else => @compileError("Unkown os"),
};
