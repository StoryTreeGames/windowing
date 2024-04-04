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
        pub fn makeIntResourceA(comptime value: anytype) [*:0]const u8 {
            const usize_value = if (value >= 0) value else @as(usize, @bitCast(@as(isize, value)));
            const temp: [*:0]const u8 = @ptrFromInt(usize_value);
            return temp;
        }
        const ARROW = makeIntResourceA(@as(i32, 32512));
        const HAND = makeIntResourceA(@as(i32, 32649));
        const CROSS = makeIntResourceA(@as(i32, 32515));
        const BEAM = makeIntResourceA(@as(i32, 32513));
        const NO = makeIntResourceA(@as(i32, 32648));
        const SIZEALL = makeIntResourceA(@as(i32, 32646));
        const SIZEWE = makeIntResourceA(@as(i32, 32644));
        const SIZENS = makeIntResourceA(@as(i32, 32645));
        const SIZENESW = makeIntResourceA(@as(i32, 32643));
        const SIZENWSE = makeIntResourceA(@as(i32, 32642));
        const WAIT = makeIntResourceA(@as(i32, 32514));
        const HELP = makeIntResourceA(@as(i32, 32651));
        const APPSTARTING = makeIntResourceA(@as(i32, 32650));

        pub fn cursorHandle(cursor: CursorIcon) [*:0]const u8 {
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
