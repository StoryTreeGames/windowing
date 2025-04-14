const std = @import("std");
const builtin = @import("builtin");

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

pub const Util = switch (builtin.os.tag) {
    .windows => struct {
        const MESSAGEBOX_RESULT = @import("win32").ui.windows_and_messaging.MESSAGEBOX_RESULT;

        pub fn processResult(comptime buttons: ?Buttons, result: MESSAGEBOX_RESULT) Button(buttons) {
            if (buttons) |btns| {
                switch (btns) {
                    .abort_retry_ignore => switch (result) {
                        .ABORT => return Buttons.AbortRetryIgnore.abort,
                        .RETRY => return Buttons.AbortRetryIgnore.retry,
                        .IGNORE => return Buttons.AbortRetryIgnore.retry,
                        else => return null,
                    },
                    .cancel_try_continue => switch (result) {
                        .CANCEL => return Buttons.CancelTryContinue.cancel,
                        .TRYAGAIN => return Buttons.CancelTryContinue.@"try",
                        .CONTINUE => return Buttons.CancelTryContinue.@"continue",
                        else => return null,
                    },
                    .help => switch (result) {
                        .OK => return true,
                        else => return false,
                    },
                    .ok => switch (result) {
                        .OK => return true,
                        else => return false,
                    },
                    .ok_cancel => switch (result) {
                        .OK => return Buttons.OkCancel.ok,
                        .CANCEL => return Buttons.OkCancel.cancel,
                        else => return null,
                    },
                    .retry_cancel => switch (result) {
                        .RETRY => return Buttons.RetryCancel.retry,
                        .CANCEL => return Buttons.RetryCancel.cancel,
                        else => return null,
                    },
                    .yes_no => switch (result) {
                        .YES => return Buttons.YesNo.yes,
                        else => return Buttons.YesNo.no,
                    },
                    .yes_no_cancel => switch (result) {
                        .YES => return Buttons.YesNoCancel.yes,
                        .NO => return Buttons.YesNoCancel.no,
                        .CANCEL => return Buttons.YesNoCancel.cancel,
                        else => return null,
                    },
                }
            }
            return {};
        }
    },
    else => struct {}
};

pub const MessageOptions = struct {
    title: ?[]const u8 = null,
    message: ?[]const u8 = null,
    icon: ?Icon = null,
};

pub fn message(comptime buttons: ?Buttons, opts: MessageOptions) Button(buttons) {
    switch (builtin.os.tag) {
        .windows => {
            const win32 = @import("win32");
            const wam = win32.ui.windows_and_messaging;

            const button_style: u32 = @bitCast(if (buttons) |btns| switch (btns) {
                .abort_retry_ignore => wam.MB_ABORTRETRYIGNORE,
                .cancel_try_continue => wam.MB_CANCELTRYCONTINUE, // AD
                .help => wam.MB_HELP,
                .ok => wam.MB_OK,
                .ok_cancel => wam.MB_OKCANCEL, // AD
                .retry_cancel => wam.MB_RETRYCANCEL, // AD
                .yes_no => wam.MB_YESNO,
                .yes_no_cancel => wam.MB_YESNOCANCEL, // AD
            }
            else wam.MESSAGEBOX_STYLE {});

            const icon_style: u32 = @bitCast(if (opts.icon) |ico| switch (ico) {
                .warning => wam.MB_ICONWARNING,
                .information => wam.MB_ICONINFORMATION,
                .question => wam.MB_ICONQUESTION,
                .@"error" => wam.MB_ICONERROR,
            }
            else wam.MESSAGEBOX_STYLE {});

            const result = wam.MessageBoxA(
                null,
                if (opts.message) |m| @ptrCast(m.ptr) else null,
                if (opts.title) |t| @ptrCast(t.ptr) else null,
                @as(wam.MESSAGEBOX_STYLE, @bitCast(button_style | icon_style))
            );
            return Util.processResult(buttons, result);
        },
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
                var default_folder: ?*anyopaque = null;

                const result = util.SHCreateItemFromParsingName(path.ptr, null, &util.IShellItem.uuidof(), &default_folder);
                if (result != util.S_OK) return error.Win32Error;

                const folder = if (default_folder) |df| @as(*util.shobjidl.IShellItem, @ptrCast(@alignCast(df))) else null; 
                try dialog.setFolder(folder);
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
            const filters = try allocator.alloc(util.shobjidl.COMDLG_FILTERSPEC, types.len);
            for (types, 0..) |filter, i| {
                const name = try std.unicode.utf8ToUtf16LeAllocZ(allocator, filter[0]);
                const spec = try std.unicode.utf8ToUtf16LeAllocZ(allocator, filter[1]);
                filters[i] = util.shobjidl.COMDLG_FILTERSPEC {
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
    directory: bool = false,
    multiple: bool = false,
    exists: bool = true,
    show_pinned: bool = true,
    show_hidden: bool = false,
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
};

/// Caller is responsible for freeing the returned array of strings
pub fn open(allocator: std.mem.Allocator, opts: FileOpenDialogOptions) !?[]const []const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const allo = arena.allocator();

    switch (builtin.os.tag) {
        .windows => {
            const util = @import("windows/util.zig");

            if (util.CoInitializeEx(null, .{
                .apartment_threaded = true,
                .disable_ole1dde = true,
            }) != util.S_OK) return error.CoInitializeFailure;
            defer util.CoUninitialize();

            var file_open_dialog: util.IFileDialog(.open) = undefined;
            if (util.CoCreateInstance(
                &util.CLSID_FileOpenDialog(),
                null,
                util.CLSCTX_ALL,
                &util.IFileDialog(.open).uuidof(),
                &file_open_dialog.inner
            ) != util.S_OK) return error.CoCreateInstanceFailure;

            try configureFileDialog(allo, &file_open_dialog, opts);

            var options = try file_open_dialog.getOptions();
            options.pick_folders = opts.directory;
            options.allow_multi_select = opts.multiple;
            if (opts.directory)
                options.path_must_exist = opts.exists
            else
                options.file_must_exist = opts.exists;
            options.hide_pinned_places = !opts.show_pinned;
            options.force_show_hidden = opts.show_hidden;
            try file_open_dialog.setOptions(@bitCast(options));

            file_open_dialog.show(null) catch |e| switch (e) {
                error.UserCancelled => return null,
                else => return e
            };

            var out = std.ArrayList([]const u8).init(allocator);
            var shell_items = try file_open_dialog.getResults();
            for (0..try shell_items.count()) |i| {
                if (try shell_items.get(i)) |item| {
                    defer item.release() catch {};

                    const attrs = try item.getAttributes(util.SFGAO_FILESYSTEM);
                    if (attrs & util.SFGAO_FILESYSTEM == 0) {
                        continue;
                    }

                    if (try item.getDisplayName()) |name| {
                        defer util.CoTaskMemFree(@ptrCast(@constCast(name)));
                        const n = try std.unicode.utf16LeToUtf8Alloc(allocator, std.mem.sliceTo(name, 0));
                        try out.append(n);
                    }
                }
            }

            return try out.toOwnedSlice();
        },
        else => @compileError("platform not supported")
    }
}

pub const FileSaveDialogOptions = struct {
    show_pinned: bool = true,
    show_hidden: bool = false,
    prompt_on_create: bool = false,
    save_as: []const u8 = "",
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
};

pub fn save(allocator: std.mem.Allocator, opts: FileSaveDialogOptions) !?[]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const allo = arena.allocator();

    switch (builtin.os.tag) {
        .windows => {
            const util = @import("windows/util.zig");

            if (util.CoInitializeEx(null, .{
                .apartment_threaded = true,
                .disable_ole1dde = true,
            }) != util.S_OK) return error.CoInitializeFailure;
            defer util.CoUninitialize();

            var file_save_dialog: util.IFileDialog(.save) = undefined;
            if (util.CoCreateInstance(
                &util.CLSID_FileSaveDialog(),
                null,
                util.CLSCTX_ALL,
                &util.IFileDialog(.save).uuidof(),
                &file_save_dialog.inner
            ) != util.S_OK) return error.CoCreateInstanceFailure;

            if (opts.save_as.len > 0) {
                const path = try std.unicode.utf8ToUtf16LeAllocZ(allo, opts.save_as);
                var save_as_item: ?*anyopaque = null;

                const result = util.SHCreateItemFromParsingName(path.ptr, null, &util.IShellItem.uuidof(), &save_as_item);
                if (result != util.S_OK) return error.Win32Error;

                if (save_as_item) |df| {
                    try file_save_dialog.setSaveAs(@as(*util.shobjidl.IShellItem, @ptrCast(@alignCast(df))));
                }
            }

            try configureFileDialog(allo, &file_save_dialog, opts);

            var options = try file_save_dialog.getOptions();
            options.hide_pinned_places = !opts.show_pinned;
            options.force_show_hidden = opts.show_hidden;
            options.create_prompt = opts.prompt_on_create;
            try file_save_dialog.setOptions(@bitCast(options));

            file_save_dialog.show(null) catch |e| switch (e) {
                error.UserCancelled => return null,
                else => return e
            };

            const item = try file_save_dialog.getResult() orelse return null;
            defer item.release() catch {};

            if (try item.getDisplayName()) |name| {
                defer util.CoTaskMemFree(@ptrCast(@constCast(name)));
                return try std.unicode.utf16LeToUtf8Alloc(allocator, std.mem.sliceTo(name, 0));
            }
            return null;
        },
        else => @compileError("platform not supported")
    }
}
