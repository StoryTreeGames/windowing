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
            @import("std").debug.print("{s}\n", .{ @tagName(result) });
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

pub const FileOptions = struct {
    // /// The default file extension to add to the returned file name when a file extension
    // /// is not entered. Note that if this is not set no extensions will be present on returned
    // /// filenames even when a specific file type filter is selected.
    // pub default_extension: &'a str,
    // /// The path to the default folder that the dialog will navigate to on first usage. Subsequent
    // /// usages of the dialog will remember the directory of the last selected file/folder.
    // pub default_folder: &'a str,
    // /// The filename to pre-populate in the dialog box
    // pub file_name: &'a str,
    // /// The label to display to the left of the filename input box in the dialog
    // pub file_name_label: &'a str,
    // /// Specifies the (1-based) index of the file type that is selected by default.
    // pub file_type_index: u32,
    // /// The file types that are displayed in the File Type dropdown box in the dialog. The first
    // /// element is the text description, i.e `"Text Files (*.txt)"` and the second element is the
    // /// file extension filter pattern, with multiple entries separated by a semi-colon
    // /// i.e `"*.txt;*.log"`
    // pub file_types: Vec<(&'a str, &'a str)>,
    // /// The path to the folder that is always selected when a dialog is opened, regardless of
    // /// previous user action. This is not recommended for general use, instead `default_folder`
    // /// should be used.
    // pub folder: &'a str,
    // /// The text label to replace the default "Open" or "Save" text on the "OK" button of the dialog
    // pub ok_button_label: &'a str,
    // /// A set of bit flags to apply to the dialog. Setting invalid flags will result in the dialog
    // /// failing to open. Flags should be a combination of `FOS_*` constants, the documentation for
    // /// which can be found [here](https://docs.microsoft.com/en-us/windows/win32/api/shobjidl_core/ne-shobjidl_core-_fileopendialogoptions)
    // pub options: u32,
    // /// The HWND of the window that the dialog will be owned by. If not provided the dialog will be
    // /// an independent top-level window.
    // pub owner: Option<HWND>,
    // /// The path to the existing file to use when opening a Save As dialog. Acts as a combination of
    // /// `folder` and `file_name`, displaying the file name in the edit box, and selecting the
    // /// containing folder as the initial folder in the dialog.
    // pub save_as_item: &'a str,
    // /// The text displayed in the title bar of the dialog box
    // pub title: &'a str
};

// DialogParams {
//     default_extension: "",
//     default_folder: "",
//     file_name: "",
//     file_name_label: "",
//     file_type_index: 1,
//     file_types: vec![("All types (*.*)", "*.*")],
//     folder: "",
//     ok_button_label: "",
//     options: 0,
//     owner: None,
//     save_as_item: "",
//     title: "",
// }

pub fn file(opts: FileOptions) !void {
    _ = opts;
    switch (builtin.os.tag) {
        .windows => {
            const util = @import("windows/util.zig");

            if (util.CoInitializeEx(null, .{
                .apartment_threaded = true,
                .disable_ole1dde = true,
            }) != util.S_OK) return error.CoInitializeFailure;
            defer util.CoUninitialize();

            var file_save_dialog: util.IFileSaveDialog = undefined;
            if (util.CoCreateInstance(
                &util.CLSID_FileSaveDialog(),
                null,
                util.CLSCTX_ALL,
                &util.IFileSaveDialog.uuidof(),
                &file_save_dialog.inner
            ) != util.S_OK) return error.CoCreateInstanceFailure;

            try file_save_dialog.show(null);
            // TODO: Configure the file dialog
        },
        else => @compileError("platform not supported")
    }
}
