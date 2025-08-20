pub const Cursor = union(enum) {
    icon: CursorType,
    custom: struct {
        /// Path to the image file
        path: []const u8,
        /// The width of the cursor.
        width: i32 = 0,
        /// The height of the cursor.
        height: i32 = 0,
    },

    pub const Default: @This() = .{ .icon = .default };
    pub const Pointer: @This() = .{ .icon = .pointer };
    pub const Crosshair: @This() = .{ .icon = .crosshair };
    pub const Text: @This() = .{ .icon = .text };
    pub const VerticalText: @This() = .{ .icon = .vertical_text };
    pub const NotAllowed: @This() = .{ .icon = .not_allowed };
    pub const NoDrop: @This() = .{ .icon = .no_drop };
    pub const Grab: @This() = .{ .icon = .grab };
    pub const Grabbing: @This() = .{ .icon = .grabbing };
    pub const AllScroll: @This() = .{ .icon = .all_scroll };
    pub const Move: @This() = .{ .icon = .move };
    pub const EResize: @This() = .{ .icon = .e_resize };
    pub const WResize: @This() = .{ .icon = .w_resize };
    pub const EWResize: @This() = .{ .icon = .ew_resize };
    pub const ColResize: @This() = .{ .icon = .col_resize };
    pub const NResize: @This() = .{ .icon = .n_resize };
    pub const SResize: @This() = .{ .icon = .s_resize };
    pub const NSResize: @This() = .{ .icon = .ns_resize };
    pub const RowResize: @This() = .{ .icon = .row_resize };
    pub const NEResize: @This() = .{ .icon = .ne_resize };
    pub const SWResize: @This() = .{ .icon = .sw_resize };
    pub const NESWResize: @This() = .{ .icon = .nesw_resize };
    pub const NWResize: @This() = .{ .icon = .nw_resize };
    pub const SEResize: @This() = .{ .icon = .se_resize };
    pub const NWSEResize: @This() = .{ .icon = .nwse_resize };
    pub const Wait: @This() = .{ .icon = .wait };
    pub const Help: @This() = .{ .icon = .help };
    pub const Progress: @This() = .{ .icon = .progress };
    pub const ContextMenu: @This() = .{ .icon = .context_menu };
    pub const Cell: @This() = .{ .icon = .cell };
    pub const Alias: @This() = .{ .icon = .alias };
    pub const Copy: @This() = .{ .icon = .copy };
    pub const ZoomIn: @This() = .{ .icon = .zoom_in };
};

pub const CursorType = enum(u8) {
    default,
    pointer,
    crosshair,
    text,
    vertical_text,
    not_allowed,
    no_drop,
    grab,
    grabbing,
    all_scroll,
    move,
    e_resize,
    w_resize,
    ew_resize,
    col_resize,
    n_resize,
    s_resize,
    ns_resize,
    row_resize,
    ne_resize,
    sw_resize,
    nesw_resize,
    nw_resize,
    se_resize,
    nwse_resize,
    wait,
    help,
    progress,

    // all default to idc_arrow
    context_menu,
    cell,
    alias,
    copy,
    zoom_in,
};

const impl = switch(@import("builtin").os.tag) {
    .windows => @import("windows/cursor.zig"),
    else => @compileError("platform not supported"),
};

pub const showCursor = impl.showCursor;
pub const clipCursor = impl.clipCursor;
pub const getCursorPos = impl.getCursorPos;
pub const getMouseButton = impl.getKeyState;
