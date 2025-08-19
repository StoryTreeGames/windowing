const std = @import("std");
const builtin = @import("builtin");

const d = @import("../dialog.zig");
const root = @import("../root.zig");
const util = @import("util.zig");

const Color = root.Color;
const Font = root.Font;
const FileOpenDialogOptions = d.FileOpenDialogOptions;
const FileSaveDialogOptions = d.FileSaveDialogOptions;
const ColorOptions = d.ColorOptions;
const FontOptions = d.FontOptions;

const Buttons = d.Buttons;
const MessageOptions = d.MessageOptions;
const Button = d.Button;

fn configureFileDialog(allocator: std.mem.Allocator, dialog: anytype, options: anytype) !void {
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
}

fn addFileDialogFilters(allocator: std.mem.Allocator, dialog: anytype, types: []const std.meta.Tuple(&.{ []const u8, []const u8 })) !void {
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
}

pub fn processResult(comptime buttons: ?Buttons, action: i32) ?Button {
    switch (builtin.os.tag) {
        .windows => {
            const MESSAGEBOX_RESULT = @import("win32").ui.windows_and_messaging.MESSAGEBOX_RESULT;
            const result: MESSAGEBOX_RESULT = @enumFromInt(action);

            if (buttons) |btns| {
                switch (btns) {
                    .abort_retry_ignore => switch (result) {
                        .ABORT => return Button.abort,
                        .RETRY => return Button.retry,
                        .IGNORE => return Button.retry,
                        else => return null,
                    },
                    .cancel_try_continue => switch (result) {
                        .CANCEL => return Button.cancel,
                        .TRYAGAIN => return Button.@"try",
                        .CONTINUE => return Button.@"continue",
                        else => return null,
                    },
                    .help => switch (result) {
                        .OK => return .help,
                        else => return null,
                    },
                    .ok => switch (result) {
                        .OK => return .ok,
                        else => return null,
                    },
                    .ok_cancel => switch (result) {
                        .OK => return Button.ok,
                        .CANCEL => return Button.cancel,
                        else => return null,
                    },
                    .retry_cancel => switch (result) {
                        .RETRY => return Button.retry,
                        .CANCEL => return Button.cancel,
                        else => return null,
                    },
                    .yes_no => switch (result) {
                        .YES => return Button.yes,
                        else => return Button.no,
                    },
                    .yes_no_cancel => switch (result) {
                        .YES => return Button.yes,
                        .NO => return Button.no,
                        .CANCEL => return Button.cancel,
                        else => return null,
                    },
                }
            }
            return {};
        },
        else => @compileError("platform not supported")
    }
}

pub fn message(comptime buttons: ?Buttons, opts: MessageOptions) ?Button {
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

    return processResult(buttons, @intFromEnum(result));
}

pub fn open(allocator: std.mem.Allocator, opts: FileOpenDialogOptions) !?[]const []const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const allo = arena.allocator();


    if (util.CoInitializeEx(null, .{
        .APARTMENTTHREADED = 1,
        .DISABLE_OLE1DDE = 1,
    }) != util.S_OK) return error.CoInitializeFailure;
    defer util.CoUninitialize();

    var dialog: *anyopaque = undefined;
    if (util.CoCreateInstance(
        &util.CLSID_FileOpenDialog,
        null,
        util.CLSCTX_ALL,
        &util.IFileOpenDialog.UUID,
        &dialog
    ) != util.S_OK) return error.CoCreateInstanceFailure;

    var file_open_dialog: *util.IFileOpenDialog = @ptrCast(@alignCast(dialog));

    try configureFileDialog(allo, file_open_dialog, opts);

    var options = try file_open_dialog.getOptions();
    options.PICKFOLDERS = opts.directory;
    options.ALLOWMULTISELECT = opts.multiple;
    if (opts.directory)
        options.PATHMUSTEXIST = opts.exists
    else
        options.FILEMUSTEXIST = opts.exists;
    try file_open_dialog.setOptions(@bitCast(options));

    file_open_dialog.show(null) catch |e| switch (e) {
        error.UserCancelled => return null,
        else => return e
    };

    var out = std.ArrayList([]const u8).init(allocator);
    var shell_items = try file_open_dialog.getResults();
    for (0..try shell_items.getCount()) |i| {
        const item = try shell_items.getItemAt(i);
        defer _ = item.release() catch {};

        const attrs = try item.getAttributes(.{ .FILESYSTEM = true });
        if (!attrs.FILESYSTEM) {
            continue;
        }

        const name = try item.getDisplayName(.DESKTOPABSOLUTEPARSING);
        defer util.CoTaskMemFree(@ptrCast(@constCast(name)));
        const n = try std.unicode.utf16LeToUtf8Alloc(allocator, std.mem.sliceTo(name, 0));
        try out.append(n);
    }

    return try out.toOwnedSlice();
}

pub fn save(allocator: std.mem.Allocator, opts: FileSaveDialogOptions) !?[]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const allo = arena.allocator();

    if (util.CoInitializeEx(null, .{
        .APARTMENTTHREADED = 1,
        .DISABLE_OLE1DDE = 1,
    }) != util.S_OK) return error.CoInitializeFailure;
    defer util.CoUninitialize();

    var dialog: *anyopaque = undefined;
    if (util.CoCreateInstance(
        &util.CLSID_FileSaveDialog,
        null,
        util.CLSCTX_ALL,
        &util.IFileSaveDialog.UUID,
        &dialog
    ) != util.S_OK) return error.CoCreateInstanceFailure;

    var file_save_dialog: *util.IFileSaveDialog = @ptrCast(@alignCast(dialog));

    try configureFileDialog(allo, file_save_dialog, opts);

    var options = try file_save_dialog.getOptions();
    options.CREATEPROMPT = opts.prompt_on_create;
    try file_save_dialog.setOptions(@bitCast(options));

    file_save_dialog.show(null) catch |e| switch (e) {
        error.UserCancelled => return null,
        else => return e
    };

    const item = try file_save_dialog.getResult();
    defer _ = item.release() catch {};

    const name = try item.getDisplayName(.DESKTOPABSOLUTEPARSING);
    defer util.CoTaskMemFree(@ptrCast(@constCast(name)));
    return try std.unicode.utf16LeToUtf8Alloc(allocator, std.mem.sliceTo(name, 0));
}

pub fn color(options: ColorOptions) !?Color {
    var custom_colors: [16]u32 = [_]u32{ 0x00FFFFFF } ** 16;
    if (options.custom) |custom| {
        for (custom, 0..) |c, i| {
            custom_colors[i] = @bitCast(c);
        }
    }

    var cc: util.CHOOSECOLORA = std.mem.zeroes(util.CHOOSECOLORA);
    cc.lStructSize = @sizeOf(util.CHOOSECOLORA);
    cc.hwndOwner = @ptrCast(@alignCast(options.owner));
    cc.lpCustColors = @ptrCast(@alignCast(custom_colors[0..].ptr));
    cc.rgbResult = @bitCast(options.initial);
    cc.Flags = @bitCast(util.CC{ .rgb_init = true, .full_open = true });

    if (util.ChooseColorA(&cc) != util.TRUE) {
        switch (util.CommDlgExtendedError()) {
            .CDERR_GENERALCODES => return null,
            else => return error.UnknownError,
        }
    }

    if (options.custom) |custom| {
        for (custom_colors, 0..) |c, i| {
            custom[i] = @bitCast(c);
        }
    }

    return @bitCast(cc.rgbResult);
}

/// Caller is responsible for freeing the returned `Font.name`
pub fn font(allocator: std.mem.Allocator, options: FontOptions) !?Font {
    const style = try allocator.allocSentinel(u8, options.style.len, 0);
    @memcpy(style, options.style);
    defer allocator.free(style);

    var face_name: [32:0]u8 = std.mem.zeroes([32:0]u8);
    for (options.face[0..@min(options.face.len, 32)], 0..) |f, i| {
        face_name[i] = f;
    }

    var lf: util.LOGFONTA = std.mem.zeroes(util.LOGFONTA);
    const caps = util.GetDeviceCaps(util.GetDC(null), .LOGPIXELSY);
    lf.lfHeight = @intFromFloat(@round(@as(f32, @floatFromInt(options.point_size)) * @as(f32, @floatFromInt(caps)) / 72.0));
    lf.lfFaceName = face_name;

    var cf: util.CHOOSEFONTA = std.mem.zeroes(util.CHOOSEFONTA);
    cf.lStructSize = @sizeOf(util.CHOOSEFONTA);
    cf.lpLogFont = &lf;
    cf.hwndOwner = @ptrCast(@alignCast(options.owner));
    cf.lpszStyle = style.ptr;
    cf.rgbColors = @bitCast(options.color);
    cf.iPointSize = options.point_size;
    cf.Flags = .{ .SCREENFONTS = 1, .EFFECTS = 1, .INITTOLOGFONTSTRUCT = 1, .USESTYLE = 1 };

    if (util.ChooseFontA(&cf) == util.FALSE) {
        switch (util.CommDlgExtendedError()) {
            .CDERR_GENERALCODES => return null,
            else => return error.UnknownError,
        }
    }

    const name_slice: []const u8 = std.mem.sliceTo(lf.lfFaceName[0..], 0);
    const name = try allocator.alloc(u8, name_slice.len);
    @memcpy(name, name_slice);

    return .{
        .height = @intCast(@abs(lf.lfHeight)),
        .width = @intCast(@abs(lf.lfWidth)),
        .point_size = @intFromFloat(@round(@as(f32, @floatFromInt(@abs(lf.lfHeight))) * 72.0 / @as(f32, @floatFromInt(caps)))),
        .color = @bitCast(cf.rgbColors),
        .weight = @intCast(lf.lfWeight),
        .italic = lf.lfItalic == 1,
        .underline = lf.lfUnderline == 1,
        .strikeout = lf.lfStrikeOut == 1,
        .name = name,
    };
}
