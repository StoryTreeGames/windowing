const util = @import("util.zig");

pub const Cursor = union(enum) {
    icon: CursorOption,
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
pub const CursorOption = enum {
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

pub usingnamespace switch (@import("builtin").target.os.tag) {
    .windows => struct {
        const ARROW = util.makeIntResourceW(32512);
        pub const IDI_HAND = @import("win32").zig.typedConst([*:0]align(1) const u16, @as(u32, 32649));
        const HAND = util.makeIntResourceW(32649);
        const CROSS = util.makeIntResourceW(32515);
        const BEAM = util.makeIntResourceW(32513);
        const NO = util.makeIntResourceW(32648);
        const SIZEALL = util.makeIntResourceW(32646);
        const SIZEWE = util.makeIntResourceW(32644);
        const SIZENS = util.makeIntResourceW(32645);
        const SIZENESW = util.makeIntResourceW(32643);
        const SIZENWSE = util.makeIntResourceW(32642);
        const WAIT = util.makeIntResourceW(32514);
        const HELP = util.makeIntResourceW(32651);
        const APPSTARTING = util.makeIntResourceW(32650);

        pub fn cursorToResource(cursor: CursorOption) [*:0]align(1) const u16 {
            return switch (cursor) {
                .default => ARROW,
                .pointer => HAND,
                .crosshair => CROSS,
                .text => BEAM,
                .vertical_text => BEAM,
                .not_allowed => NO,
                .no_drop => NO,
                .grab => SIZEALL,
                .grabbing => SIZEALL,
                .all_scroll => SIZEALL,
                .move => SIZEALL,
                .e_resize => SIZEWE,
                .w_resize => SIZEWE,
                .ew_resize => SIZEWE,
                .col_resize => SIZEWE,
                .n_resize => SIZENS,
                .s_resize => SIZENS,
                .ns_resize => SIZENS,
                .row_resize => SIZENS,
                .ne_resize => SIZENESW,
                .sw_resize => SIZENESW,
                .nesw_resize => SIZENESW,
                .nw_resize => SIZENWSE,
                .se_resize => SIZENWSE,
                .nwse_resize => SIZENWSE,
                .wait => WAIT,
                .help => HELP,
                .progress => APPSTARTING,

                // All default to IDC_ARROW
                .context_menu => ARROW,
                .cell => ARROW,
                .alias => ARROW,
                .copy => ARROW,
                .zoom_in => ARROW,
            };
        }
    },
    else => @compileError("Unkown os"),
};
