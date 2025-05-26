const std = @import("std");
const builtin = @import("builtin");

const windows_impl = @import("windows/dialog.zig");

const Color = @import("./root.zig").Color;
const Font = @import("./root.zig").Font;

pub const Icon = enum {
    warning,
    information,
    question,
    @"error",
};

pub const Buttons = enum {
    abort_retry_ignore,
    cancel_try_continue,
    help,
    ok,
    ok_cancel,
    retry_cancel,
    yes_no,
    yes_no_cancel,

    pub const AbortRetryIgnore = enum {
        abort,
        retry,
        ignore
    };

    pub const CancelTryContinue = enum {
        cancel,
        @"try",
        @"continue"
    };

    pub const OkCancel = enum {
        ok,
        cancel,
    };

    pub const RetryCancel = enum {
        retry,
        cancel,
    };

    pub const YesNo = enum {
        yes,
        no,
    };

    pub const YesNoCancel = enum {
        yes,
        no,
        cancel,
    };
};

fn Button(comptime buttons: ?Buttons) type {
    if (buttons) |btns| {
        return switch (btns) {
            .abort_retry_ignore => ?Buttons.AbortRetryIgnore,
            .cancel_try_continue => ?Buttons.CancelTryContinue,
            .help, .ok => bool,
            .ok_cancel => ?Buttons.OkCancel,
            .retry_cancel => ?Buttons.RetryCancel,
            .yes_no => Buttons.YesNo,
            .yes_no_cancel => ?Buttons.YesNoCancel,
        };
    }
    return void;
}

pub const MessageOptions = struct {
    title: ?[]const u8 = null,
    message: ?[]const u8 = null,
    icon: ?Icon = null,
};

pub fn message(comptime buttons: ?Buttons, opts: MessageOptions) Button(buttons) {
    switch (builtin.os.tag) {
        .windows => return windows_impl.message(buttons, opts),
        else => @compileError("platform not supported"),
    }
    return null;
}

fn configureFileDialog(allocator: std.mem.Allocator, dialog: anytype, options: anytype) !void {
    switch (builtin.os.tag) {
        .windows => {
            const util = @import("windows/util.zig");

            if (options.folder.len > 0) {
                const path = try std.unicode.utf8ToUtf16LeAllocZ(allocator, options.folder);
                var default_folder: *anyopaque = undefined;

                const result = util.SHCreateItemFromParsingName(path.ptr, null, &util.IShellItem.UUID, &default_folder);
                if (result != util.S_OK) return error.Win32Error;
                try dialog.setFolder(@ptrCast(@alignCast(default_folder)));
            }

            if (options.file_name.len > 0) {
                const path = try std.unicode.utf8ToUtf16LeAllocZ(allocator, options.file_name);
                try dialog.setFileName(path.ptr);
            }

            if (options.filters.len > 0) {
                try addFileDialogFilters(allocator, dialog, options.filters);
            }

            if (options.title.len > 0) {
                const title = try std.unicode.utf8ToUtf16LeAllocZ(allocator, options.title);
                try dialog.setTitle(title.ptr);
            }
        },
        else => @compileError("platform not supported")
    }
}

fn addFileDialogFilters(allocator: std.mem.Allocator, dialog: anytype, types: []const std.meta.Tuple(&.{ []const u8, []const u8 })) !void {
    switch(builtin.os.tag) {
        .windows => {
            const util = @import("windows/util.zig");
            const filters = try allocator.alloc(util.COMDLG_FILTERSPEC, types.len);
            for (types, 0..) |filter, i| {
                const name = try std.unicode.utf8ToUtf16LeAllocZ(allocator, filter[0]);
                const spec = try std.unicode.utf8ToUtf16LeAllocZ(allocator, filter[1]);
                filters[i] = util.COMDLG_FILTERSPEC {
                    .pszName = name.ptr,
                    .pszSpec = spec.ptr,
                };
            }
            try dialog.setFileTypes(filters);
        },
        else => @compileError("platform not supported")
    }
}

pub const FileOpenDialogOptions = struct {
    /// The HWND of the window that the dialog will be owned by. If not provided the dialog will be
    /// an independent top-level window.
    owner: ?*anyopaque = null,
    /// The text displayed in the title bar of the dialog box
    title: []const u8 = "",
    /// The path to the folder that is always selected when a dialog is opened, regardless of
    /// previous user action. This is not recommended for general use, instead `default_folder`
    /// should be used.
    folder: []const u8 = "",
    /// The file types that are displayed in the File Type dropdown box in the dialog. The first
    /// element is the text description, i.e `"Text Files (*.txt)"` and the second element is the
    /// file extension filter pattern, with multiple entries separated by a semi-colon
    /// i.e `"*.txt;*.log"`
    filters: []const std.meta.Tuple(&.{ []const u8, []const u8 }) = &.{ .{ "All types (*.*)", "*.*" } },
    /// The filename to pre-populate in the dialog box
    file_name: []const u8 = "",
    /// Pick folders/directories instead of files
    directory: bool = false,
    /// Allow the user to select more than one item
    multiple: bool = false,
    /// Ensure that the selected item(s) exist
    exists: bool = true,
};

/// Caller is responsible for freeing the returned array of strings
pub fn open(allocator: std.mem.Allocator, opts: FileOpenDialogOptions) !?[]const []const u8 {
    switch (builtin.os.tag) {
        .windows => return try windows_impl.open(allocator, opts),
        else => @compileError("platform not supported")
    }
}

pub const FileSaveDialogOptions = struct {
    /// The HWND of the window that the dialog will be owned by. If not provided the dialog will be
    /// an independent top-level window.
    owner: ?*anyopaque = null,
    /// The text displayed in the title bar of the dialog box
    title: []const u8 = "",
    /// The path to the folder that is always selected when a dialog is opened, regardless of
    /// previous user action. This is not recommended for general use, instead `default_folder`
    /// should be used.
    folder: []const u8 = "",
    /// The file types that are displayed in the File Type dropdown box in the dialog. The first
    /// element is the text description, i.e `"Text Files (*.txt)"` and the second element is the
    /// file extension filter pattern, with multiple entries separated by a semi-colon
    /// i.e `"*.txt;*.log"`
    filters: []const std.meta.Tuple(&.{ []const u8, []const u8 }) = &.{ .{ "All types (*.*)", "*.*" } },
    /// The filename to pre-populate in the dialog box
    file_name: []const u8 = "",
    /// Whether the user should be prompted when creating or overwritting a file
    prompt_on_create: bool = false,
};

pub fn save(allocator: std.mem.Allocator, opts: FileSaveDialogOptions) !?[]const u8 {
    switch (builtin.os.tag) {
        .windows => return try windows_impl.save(allocator, opts),
        else => @compileError("platform not supported")
    }
}

pub const ColorOptions = struct {
    owner: ?*anyopaque = null,
    initial: Color = .{ .red = 200, .green = 100, .blue = 100 },
    custom: ?*[16]Color = null,
};

pub fn color(options: ColorOptions) !?Color {
    switch (builtin.os.tag) {
        .windows => return try windows_impl.color(options),
        else => @compileError("platform not supported")
    }
}

pub const FontOptions = struct {
    owner: ?*anyopaque = null,
    color: Color = .{},
    face: []const u8 = "Arial",
    style: []const u8 = "Regular",
    point_size: i16 = 12,
};

/// Caller is responsible for freeing the returned `Font.name`
pub fn font(allocator: std.mem.Allocator, options: FontOptions) !?Font {
    switch (builtin.os.tag) {
        .windows => return try windows_impl.font(allocator, options),
        else => @compileError("platform not supported")
    }
}
