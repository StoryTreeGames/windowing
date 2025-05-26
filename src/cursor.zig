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

    pub const default: @This() = .{ .icon = .default };
};

pub const CursorType = enum {
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
