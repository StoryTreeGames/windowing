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

        pub const shobjidl = @cImport({
            @cInclude("shobjidl.h");
        });

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

};

pub fn file(opts: FileOptions) void {
    @import("std").debug.print("{s}\n", .{ @typeName(Util.shobjidl.IFileDialog) });
    _ = opts;
}
