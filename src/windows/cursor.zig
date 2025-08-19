const wam = @import("win32").ui.windows_and_messaging;
const CursorType = @import("../cursor.zig").CursorType;

pub fn cursorToResource(cursor: CursorType) [*:0]align(1) const u16 {
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
