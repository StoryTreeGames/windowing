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
        const wam = @import("win32").ui.windows_and_messaging;

        pub fn cursorToResource(cursor: CursorOption) [*:0]align(1) const u16 {
            return switch (cursor) {
                .default => wam.IDC_ARROW,
                .pointer => wam.IDC_HAND,
                .crosshair => wam.IDC_CROSS,
                .text => wam.IDC_IBEAM,
                .vertical_text => wam.IDC_IBEAM,
                .not_allowed => wam.IDC_NO,
                .no_drop => wam.IDC_NO,
                .grab => wam.IDC_SIZEALL,
                .grabbing => wam.IDC_SIZEALL,
                .all_scroll => wam.IDC_SIZEALL,
                .move => wam.IDC_SIZEALL,
                .e_resize => wam.IDC_SIZEWE,
                .w_resize => wam.IDC_SIZEWE,
                .ew_resize => wam.IDC_SIZEWE,
                .col_resize => wam.IDC_SIZEWE,
                .n_resize => wam.IDC_SIZENS,
                .s_resize => wam.IDC_SIZENS,
                .ns_resize => wam.IDC_SIZENS,
                .row_resize => wam.IDC_SIZENS,
                .ne_resize => wam.IDC_SIZENESW,
                .sw_resize => wam.IDC_SIZENESW,
                .nesw_resize => wam.IDC_SIZENESW,
                .nw_resize => wam.IDC_SIZENWSE,
                .se_resize => wam.IDC_SIZENWSE,
                .nwse_resize => wam.IDC_SIZENWSE,
                .wait => wam.IDC_WAIT,
                .help => wam.IDC_HELP,
                .progress => wam.IDC_APPSTARTING,

                // All default to IDC_ARROW
                .context_menu => wam.IDC_ARROW,
                .cell => wam.IDC_ARROW,
                .alias => wam.IDC_ARROW,
                .copy => wam.IDC_ARROW,
                .zoom_in => wam.IDC_ARROW,
            };
        }
    },
    .linux => struct {
        pub fn cursorToResource(cursor: CursorOption) void {
            _ = cursor;
            @import("std").debug.print("\x1b[33;1mTODO\x1b[0m: Implement linux cursorToResource", .{});
        }
    },
    else => |tag| @compileError("Unkown os " ++ @tagName(tag) ++ "; cursor not implemented"),
};
