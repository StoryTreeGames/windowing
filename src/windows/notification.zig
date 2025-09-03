// TODO: Update whole file to use windows.UI.Notification and windows.Data.Xml.Dom

const std = @import("std");
const process = std.process;

const windows = @import("windows");
const win32 = windows.win32;

const XmlDocument = windows.Data.Xml.Dom.XmlDocument;
const XmlElement = windows.Data.Xml.Dom.XmlElement;
const IXmlNode = windows.Data.Xml.Dom.IXmlNode;
const IInspectable = windows.Foundation.IInspectable;
const HSTRING = windows.HSTRING;
const IUnknown = windows.IUnknown;

const ToastNotificationManager = windows.UI.Notifications.ToastNotificationManager;
const ToastNotification = windows.UI.Notifications.ToastNotification;
const NotificationData = windows.UI.Notifications.NotificationData;

const TypedEventHandler = windows.Foundation.TypedEventHandler;
const EventRegistrationToken = windows.Foundation.EventRegistrationToken;
const ToastDismissedEventArgs = windows.UI.Notifications.ToastDismissedEventArgs;
const ToastActivatedEventArgs = windows.UI.Notifications.ToastActivatedEventArgs;
const ToastFailedEventArgs = windows.UI.Notifications.ToastFailedEventArgs;
const IMap = windows.Foundation.Collections.IMap;

const MediaPlayer = windows.Media.Playback.MediaPlayer;
const MediaSource = windows.Media.Core.MediaSource;
const MediaPlayerFailedEventArgs = windows.Media.Playback.MediaPlayerFailedEventArgs;
const MediaPlayerError = windows.Media.Playback.MediaPlayerError;
const Uri = windows.Foundation.Uri;

const notif = @import("../notification.zig");
const Config = notif.Config;
const Update = notif.Update;
const Action = notif.Action;
const Audio = notif.Audio;
const DismissReason = notif.DismissReason;

const L = std.unicode.utf8ToUtf16LeStringLiteral;

pub fn WindowsCreateString(string: [:0]const u16) !?HSTRING {
    var result: ?HSTRING = undefined;
    if (win32.system.win_rt.WindowsCreateString(string.ptr, @intCast(string.len), &result) != 0) {
        return error.E_OUTOFMEMORY;
    }
    return result;
}

pub fn WindowsDeleteString(string: ?HSTRING) void {
    _ = win32.system.win_rt.WindowsDeleteString(string);
}

pub fn WindowsGetString(string: ?HSTRING) ?[]const u16 {
    var len: u32 = 0;
    const buffer = win32.system.win_rt.WindowsGetStringRawBuffer(string, &len);
    if (buffer) |buf| {
        return buf[0..@as(usize, @intCast(len))];
    }
    return null;
}

pub fn addAttribute(xmlElement: *XmlElement, key: [:0]const u16, value: ?[:0]const u16) !void {
    const aname = try WindowsCreateString(key);
    defer WindowsDeleteString(aname);

    if (value == null or value.?.len == 0) {
        try xmlElement.SetAttribute(aname, null);
    } else {
        const avalue = try WindowsCreateString(value.?);
        defer WindowsDeleteString(avalue);
        try xmlElement.SetAttribute(aname, avalue);
    }
}

pub fn addAttributeUtf8(allocator: std.mem.Allocator, xmlElement: *XmlElement, key: [:0]const u16, value: ?[]const u8) !void {
    if (value == null or value.?.len == 0) {
        try addAttribute(xmlElement, key, null);
    } else {
        const wide_value = try std.unicode.utf8ToUtf16LeAllocZ(allocator, value.?);
        defer allocator.free(wide_value);
        try addAttribute(xmlElement, key, wide_value);
    }

}

pub fn addText(allocator: std.mem.Allocator, doc: *XmlDocument, parent: *XmlElement, content: []const u8, id: usize, hint_title: bool) !void {
    const text_tag = try WindowsCreateString(L("text"));
    defer WindowsDeleteString(text_tag);

    const textElement = try doc.CreateElement(text_tag);
    defer _ = IUnknown.Release(@ptrCast(textElement));
    _ = try parent.AppendChild(@ptrCast(textElement));

    const id_str = try std.fmt.allocPrint(allocator, "{d}", .{id});
    defer allocator.free(id_str);

    const wide_id = try std.unicode.utf8ToUtf16LeAllocZ(allocator, id_str);
    defer allocator.free(wide_id);

    try addAttribute(textElement, L("id"), wide_id);
    if (hint_title) {
        try addAttribute(textElement, L("hint-style"), L("title"));
    }

    const wide_content = try std.unicode.utf8ToUtf16LeAllocZ(allocator, content);
    defer allocator.free(wide_content);

    const title_text = try WindowsCreateString(wide_content);
    defer WindowsDeleteString(title_text);

    const text = try doc.CreateTextNode(title_text);
    defer _ = IUnknown.Release(@ptrCast(text));
    _ = try textElement.AppendChild(@ptrCast(text));
}

fn isLink(src: []const u8) bool {
    if (src.len >= 8 and
        (std.mem.eql(u8, src[0..8], "http://") or
            std.mem.eql(u8, src[0..9], "https://") or
            std.mem.eql(u8, src[0..9], "file:///")))
    {
        return true;
    }

    if (src.len >= 11 and std.mem.eql(u8, src[0..12], "ms-appx:///")) return true;
    if (src.len >= 20 and std.mem.eql(u8, src[0..12], "ms-appdata:///local/")) return true;
    if (src.len >= 20 and std.mem.eql(u8, src[0..12], "ms-appdata:///local/")) return true;
    return false;
}

fn addImage(
    allocator: std.mem.Allocator,
    doc: *XmlDocument,
    parent: *XmlElement,
    id: usize,
    src: []const u8,
    alt: []const u8,
    placement: ?[]const u8,
    crop: bool,
) !void {
    const image_tag = try WindowsCreateString(L("image"));
    defer WindowsDeleteString(image_tag);

    const image_element = try doc.CreateElement(image_tag);
    defer _ = IUnknown.Release(@ptrCast(image_element));
    _ = try parent.AppendChild(@ptrCast(image_element));

    const id_str = try std.fmt.allocPrint(allocator, "{d}", .{id});
    defer allocator.free(id_str);

    try addAttributeUtf8(allocator, image_element, L("id"), id_str);
    if (isLink(src)) {
        try addAttributeUtf8(allocator, image_element, L("src"), src);
    } else {
        // Assume the src is a file path and resolve the full path
        // in case it is relative and add the `file:///` prefix
        const realpath = try std.fs.realpathAlloc(allocator, src);
        defer allocator.free(realpath);
        const file_uri = try std.fmt.allocPrint(allocator, "file:///{s}", .{realpath});
        defer allocator.free(file_uri);
        try addAttributeUtf8(allocator, image_element, L("src"), file_uri);
    }
    try addAttributeUtf8(allocator, image_element, L("alt"), alt);
    if (placement) |p| {
        try addAttributeUtf8(allocator, image_element, L("placement"), p);
    }
    if (crop) {
        try addAttributeUtf8(allocator, image_element, L("hint-crop"), "circle");
    }
}

fn addProgress(
    allocator: std.mem.Allocator,
    doc: *XmlDocument,
    parent: *XmlElement,
    id: usize,
    title: bool,
    override: bool,
) !void {
    const progress_tag = try WindowsCreateString(L("progress"));
    defer WindowsDeleteString(progress_tag);

    const progress_element = try doc.CreateElement(progress_tag);
    defer _ = IUnknown.Release(@ptrCast(progress_element));
    _ = try parent.AppendChild(@ptrCast(progress_element));

    const id_str = try std.fmt.allocPrint(allocator, "{d}", .{id});
    defer allocator.free(id_str);

    try addAttributeUtf8(allocator, progress_element, L("id"), id_str);
    try addAttribute(progress_element, L("value"), L("{progressValue}"));
    try addAttribute(progress_element, L("status"), L("{progressStatus}"));

    if (title) {
        try addAttribute(progress_element, L("title"), L("{progressTitle}"));
    }
    if (override) {
        try addAttribute(progress_element, L("valueStringOverride"), L("{progressValueString}"));
    }
}

pub fn insertData(allocator: std.mem.Allocator, data: *IMap(?HSTRING, ?HSTRING), key: [:0]const u16, value: []const u8) !void {
    const aname = try WindowsCreateString(key);
    defer WindowsDeleteString(aname);

    const wide_value = try std.unicode.utf8ToUtf16LeAllocZ(allocator, value);
    defer allocator.free(wide_value);

    const avalue = try WindowsCreateString(wide_value);
    defer WindowsDeleteString(avalue);

    _ = try data.Insert(aname, avalue);
}

const powershell_app_id: []const u8 = "{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\\WindowsPowerShell\\v1.0\\powershell.exe";

pub const Notification = struct {
    config: Config,
    tag: []const u8,
    app_id: [:0]const u16,

    inner: *ToastNotification,

    dismiss: ?EventRegistrationToken = null,
    activate: ?EventRegistrationToken = null,
    fail: ?EventRegistrationToken = null,

    /// Caller must call deinit to free all allocated resourced
    pub fn send(allocator: std.mem.Allocator, app_id: ?[]const u8, tag: []const u8, config: Config) !*@This() {
        @setEvalBranchQuota(10_000);
        const aid = try std.unicode.utf8ToUtf16LeAllocZ(allocator, if (app_id) |id| id else powershell_app_id);

        const APP_ID = try WindowsCreateString(aid);
        defer WindowsDeleteString(APP_ID);

        const xml_document = try XmlDocument.init();
        defer xml_document.deinit();

        var cid: usize = 0;
        {
            const toast_tag = try WindowsCreateString(L("toast"));
            defer WindowsDeleteString(toast_tag);

            const toastElement = try xml_document.CreateElement(toast_tag);
            defer _ = IUnknown.Release(@ptrCast(toastElement));
            _ = try xml_document.AppendChild(@ptrCast(toastElement));

            {
                const visual_tag = try WindowsCreateString(L("visual"));
                defer WindowsDeleteString(visual_tag);

                const visualElement = try xml_document.CreateElement(visual_tag);
                defer _ = IUnknown.Release(@ptrCast(visualElement));
                _ = try toastElement.AppendChild(@ptrCast(visualElement));

                {
                    const binding_tag = try WindowsCreateString(L("binding"));
                    defer WindowsDeleteString(binding_tag);

                    const bindingElement = try xml_document.CreateElement(binding_tag);
                    defer _ = IUnknown.Release(@ptrCast(bindingElement));
                    _ = try visualElement.AppendChild(@ptrCast(bindingElement));

                    try addAttribute(bindingElement, L("template"), L("ToastGeneric"));

                    try addText(allocator, xml_document, bindingElement, config.title, cid, true);
                    cid += 1;
                    if (config.body) |body| {
                        try addText(allocator, xml_document, bindingElement, body, cid, true);
                        cid += 1;
                    }

                    if (config.hero) |hero| {
                        try addImage(
                            allocator,
                            xml_document,
                            bindingElement,
                            cid,
                            hero.src,
                            hero.alt,
                            "hero",
                            false,
                        );
                        cid += 1;
                    }

                    if (config.logo) |logo| {
                        try addImage(
                            allocator,
                            xml_document,
                            bindingElement,
                            cid,
                            logo.src,
                            logo.alt,
                            "appLogoOverride",
                            logo.crop,
                        );
                        cid += 1;
                    }

                    if (config.progress) |progress| {
                        try addProgress(
                            allocator,
                            xml_document,
                            bindingElement,
                            cid,
                            progress.title != null,
                            progress.override != null,
                        );
                        cid += 1;
                    }
                }
            }

            if (config.actions) |actions| {
                const actions_tag = try WindowsCreateString(L("actions"));
                defer WindowsDeleteString(actions_tag);

                const actions_element = try xml_document.CreateElement(actions_tag);
                defer _ = IUnknown.Release(@ptrCast(actions_element));
                _ = try toastElement.AppendChild(@ptrCast(actions_element));

                for (actions) |action| {
                    switch (action) {
                        .input => |input| {
                            const input_tag = try WindowsCreateString(L("input"));
                            defer WindowsDeleteString(input_tag);

                            const input_element = try xml_document.CreateElement(input_tag);
                            defer _ = IUnknown.Release(@ptrCast(input_element));
                            _ = try actions_element.AppendChild(@ptrCast(input_element));

                            try addAttributeUtf8(allocator, input_element, L("id"), input.id);
                            try addAttribute(input_element, L("type"), L("text"));

                            if (input.place_holder_content) |placeholder| {
                                try addAttributeUtf8(allocator, input_element, L("placeHolderContent"), placeholder);
                            }

                            if (input.title) |title| {
                                try addAttributeUtf8(allocator, input_element, L("title"), title);
                            }
                        },
                        // SelectAction,
                        .select => |select| {
                            const input_tag = try WindowsCreateString(L("input"));
                            defer WindowsDeleteString(input_tag);

                            const input_element = try xml_document.CreateElement(input_tag);
                            defer _ = IUnknown.Release(@ptrCast(input_element));
                            _ = try actions_element.AppendChild(@ptrCast(input_element));

                            try addAttributeUtf8(allocator, input_element, L("id"), select.id);
                            try addAttribute(input_element, L("type"), L("selection"));

                            if (select.title) |title| {
                                try addAttributeUtf8(allocator, input_element, L("title"), title);
                            }

                            const selection_tag = try WindowsCreateString(L("selection"));
                            defer WindowsDeleteString(selection_tag);
                            for (select.items) |item| {
                                const selection_element = try xml_document.CreateElement(selection_tag);
                                defer _ = IUnknown.Release(@ptrCast(selection_element));
                                _ = try input_element.AppendChild(@ptrCast(selection_element));

                                try addAttributeUtf8(allocator, input_element, L("id"), item.id);
                                try addAttributeUtf8(allocator, input_element, L("content"), item.content);
                            }
                        },
                        .button => |button| {
                            defer cid += 1;

                            const action_tag = try WindowsCreateString(L("action"));
                            defer WindowsDeleteString(action_tag);

                            const action_element = try xml_document.CreateElement(action_tag);
                            defer _ = IUnknown.Release(@ptrCast(action_element));
                            _ = try actions_element.AppendChild(@ptrCast(action_element));

                            try addAttributeUtf8(allocator, action_element, L("arguments"), button.arguments);
                            try addAttributeUtf8(allocator, action_element, L("content"), button.content);

                            if (button.activation_type) |atype| {
                                try addAttribute(action_element, L("activationType"), switch (atype) {
                                    .foreground => L("foreground"),
                                    .background => L("background"),
                                    .protocol => L("protocol"),
                                });
                            }
                            if (button.after_activation_behavior) |behavior| {
                                try addAttribute(action_element, L("afterActivationBehavior"), switch (behavior) {
                                    .default => L("default"),
                                    .pending_update => L("pendingUpdate"),
                                });
                            }
                            if (button.placement) |placement| {
                                try addAttribute(action_element, L("placement"), switch (placement) {
                                    .context_menu => L("contextMenu"),
                                });
                            }
                            if (button.hint_button_style) |button_style| {
                                try addAttribute(action_element, L("hint-buttonStyle"), switch (button_style) {
                                    .success => L("Success"),
                                    .critical => L("Critical"),
                                });
                            }
                            if (button.image_uri) |uri| {
                                if (isLink(uri)) {
                                    try addAttributeUtf8(allocator, action_element, L("imageUri"), uri);
                                } else {
                                    // Assume the src is a file path and resolve the full path
                                    // in case it is relative and add the `file:///` prefix
                                    const realpath = try std.fs.realpathAlloc(allocator, uri);
                                    defer allocator.free(realpath);
                                    const file_uri = try std.fmt.allocPrint(allocator, "file:///{s}", .{realpath});
                                    defer allocator.free(file_uri);
                                    try addAttributeUtf8(allocator, action_element, L("imageUri"), file_uri);
                                }
                            }
                            if (button.hint_input_id) |id| {
                                try addAttributeUtf8(allocator, action_element, L("hint-inputid"), id);
                            }
                            if (button.hint_tool_tip) |tip| {
                                try addAttributeUtf8(allocator, action_element, L("hint-toolTip"), tip);
                            }
                        },
                    }
                }
            }

            if (config.audio) |audio| {
                const audio_tag = try WindowsCreateString(L("action"));
                defer WindowsDeleteString(audio_tag);

                const audio_element = try xml_document.CreateElement(audio_tag);
                defer _ = IUnknown.Release(@ptrCast(audio_element));
                _ = try toastElement.AppendChild(@ptrCast(audio_element));

                switch (audio.sound) {
                    .silent, .custom_uri => try addAttribute(audio_element, L("silent"), L("true")),
                    else => {
                        try addAttributeUtf8(allocator, audio_element, L("src"), audio.sound.source());
                        try addAttribute(audio_element, L("loop"), if (audio.loop orelse false) L("true") else L("false"));
                    },
                }
            }
        }

        const notification = try ToastNotification.CreateToastNotification(xml_document);
        errdefer notification.deinit();

        const h_tag = try WindowsCreateString(L("toast"));
        defer WindowsDeleteString(h_tag);
        try notification.putTag(h_tag);

        var data = try NotificationData.init();
        defer data.deinit();
        try notification.putData(data);

        try data.putSequenceNumber(1);

        if (config.progress) |progress| {
            const values = try data.getValues();

            switch (progress.value) {
                .indeterminate => try insertData(allocator, values, L("progressValue"), "indeterminate"),
                .value => |value| {
                    const v = try std.fmt.allocPrint(allocator, "{d}", .{value});
                    defer allocator.free(v);
                    try insertData(allocator, values, L("progressValue"), v);
                },
            }

            try insertData(allocator, values, L("progressStatus"), progress.status);

            if (progress.title) |title| {
                try insertData(allocator, values, L("progressTitle"), title);
            }
            if (progress.override) |override| {
                try insertData(allocator, values, L("progressValueString"), override);
            }
        }

        const instance = try allocator.create(@This());
        instance.* = .{
            .config = config,
            .tag = tag,
            .app_id = aid,
            .inner = notification,
        };
        errdefer instance.deinit(allocator);

        const dhandler = try TypedEventHandler(ToastNotification, ToastDismissedEventArgs).initWithState(ToastHandlers.dismiss, instance);
        instance.dismiss = try notification.addDismissed(dhandler);

        const ahandler = try TypedEventHandler(ToastNotification, IInspectable).initWithState(ToastHandlers.activate, instance);
        instance.activate = try notification.addActivated(ahandler);

        const fhandler = try TypedEventHandler(ToastNotification, ToastFailedEventArgs).initWithState(ToastHandlers.fail, instance);
        instance.fail = try notification.addFailed(fhandler);

        var notifier = try ToastNotificationManager.CreateToastNotifierWithApplicationId(APP_ID);
        defer _ = IUnknown.Release(@ptrCast(notifier));

        if (config.audio) |audio| {
            if (audio.sound == .custom_uri) try oneshotSound(allocator, audio.sound.custom_uri);
        }

        try notifier.Show(notification);

        return instance;
    }

    pub fn deinit(self: *const @This(), allocator: std.mem.Allocator) void {
        if (self.dismiss) |dismiss| self.inner.removeDismissed(dismiss) catch {};
        if (self.activate) |activate| self.inner.removeActivated(activate) catch {};
        if (self.fail) |fail| self.inner.removeFailed(fail) catch {};
        self.inner.deinit();

        allocator.free(self.app_id);
        allocator.destroy(self);
    }

    pub fn hide(self: *const @This()) !void {
        const APP_ID = try WindowsCreateString(self.app_id);
        defer WindowsDeleteString(APP_ID);

        var notifier = try ToastNotificationManager.CreateToastNotifierWithApplicationId(APP_ID);
        defer _ = IUnknown.Release(@ptrCast(notifier));

        try notifier.Hide(self.inner);
    }

    pub fn update(self: *const @This(), allocator: std.mem.Allocator, config: Update) !void {
        const APP_ID = try WindowsCreateString(self.app_id);
        defer WindowsDeleteString(APP_ID);

        var data = try NotificationData.init();
        defer data.deinit();

        try data.putSequenceNumber(2);

        if (config.progress) |progress| {
            const values = try data.getValues();

            if (progress.value) |value| {
                switch (value) {
                    .indeterminate => try insertData(allocator, values, L("progressValue"), "indeterminate"),
                    .value => |float| {
                        const v = try std.fmt.allocPrint(allocator, "{d}", .{float});
                        defer allocator.free(v);
                        try insertData(allocator, values, L("progressValue"), v);
                    },
                }
            }

            if (progress.status) |status| {
                try insertData(allocator, values, L("progressStatus"), status);
            }

            if (progress.title) |title| {
                if (self.config.progress.?.title == null) return error.NotificationProgressTitleNotConfigured;
                try insertData(allocator, values, L("progressTitle"), title);
            }
            if (progress.override) |override| {
                if (self.config.progress.?.override == null) return error.NotificationProgressValueStringNotConfigured;
                try insertData(allocator, values, L("progressValueString"), override);
            }
        }

        var notifier = try ToastNotificationManager.CreateToastNotifierWithApplicationId(APP_ID);
        defer _ = IUnknown.Release(@ptrCast(notifier));

        const h_tag = try WindowsCreateString(L("toast"));
        defer WindowsDeleteString(h_tag);

        switch (try notifier.Update(data, h_tag)) {
            .Failed => return error.Failed,
            .NotificationNotFound => return error.NotificationNotFound,
            else => {},
        }
    }
};

fn oneshotSound(allocator: std.mem.Allocator, audio_uri: []const u8) !void {
    const player = try MediaPlayer.init();
    defer player.deinit();

    var w_uri: [:0]const u16 = undefined;
    if (isLink(audio_uri)) {
        w_uri = try std.unicode.utf8ToUtf16LeAllocZ(allocator, audio_uri);
    } else {
        const realpath = try std.fs.realpathAlloc(allocator, audio_uri);
        defer allocator.free(realpath);
        const custom = try std.fmt.allocPrint(allocator, "file:///{s}", .{ realpath });
        defer allocator.free(custom);
        w_uri = try std.unicode.utf8ToUtf16LeAllocZ(allocator, custom);
    }
    defer allocator.free(w_uri);

    const h_uri = try WindowsCreateString(w_uri);
    defer WindowsDeleteString(h_uri);

    const uri = try Uri.CreateUri(h_uri);
    defer uri.deinit();

    const source = try MediaSource.CreateFromUri(uri);
    defer source.deinit();

    var context: MediaContext = .{};

    const h_opened_handler = try TypedEventHandler(MediaPlayer, IInspectable).initWithState(MediaHandlers.onOpened, &context);
    defer h_opened_handler.deinit();

    const h_failed_handler = try TypedEventHandler(MediaPlayer, MediaPlayerFailedEventArgs).initWithState(MediaHandlers.onFail, &context);
    defer h_failed_handler.deinit();

    const h_media_opened = try player.addMediaOpened(h_opened_handler);
    const h_media_failed = try player.addMediaFailed(h_failed_handler);

    try player.putSource(@ptrCast(source));
    context.channel.wait();

    // TODO: Playing a custom sound can fail. Is there a good way to bubble up the error or store it
    // so the user can check why the audio didn't play.
    // if (context.failed) |err| std.debug.print("[CUSTOM SOUND FAIL] {s}\n", .{ @tagName(err) });

    try player.removeMediaOpened(h_media_opened);
    try player.removeMediaFailed(h_media_failed);

    try player.Play();
}

const MediaContext = struct {
    failed: ?MediaPlayerError = null,
    channel: std.Thread.Semaphore = .{}
};

const MediaHandlers = struct{
    pub fn onOpened(state: ?*anyopaque, sender: *MediaPlayer, args: *IInspectable) void {
        _ = sender;
        _ = args;

        const ctx: *MediaContext = @ptrCast(@alignCast(state.?));
        ctx.channel.post();
    }

    pub fn onFail(state: ?*anyopaque, sender: *MediaPlayer, args: *MediaPlayerFailedEventArgs) void {
        _ = sender;

        const ctx: *MediaContext = @ptrCast(@alignCast(state.?));
        ctx.failed = if (args.getError()) |e| e else |_| .Unknown;
        ctx.channel.post();
    }
};

const ToastHandlers = struct {
    pub fn dismiss(state: ?*anyopaque, _: *ToastNotification, args: *ToastDismissedEventArgs) void {
        const instance: *Notification = @ptrCast(@alignCast(state.?));

        if (instance.config.onDismiss) |onDismiss| {
            const reason = if (args.getReason()) |r| r else |_| return;
            onDismiss(instance, switch (reason) {
                .UserCanceled => .cancel,
                .ApplicationHidden => .hidden,
                .TimedOut => .timeout,
            });
        }
    }

    pub fn activate(state: ?*anyopaque, _: *ToastNotification, args: *IInspectable) void {
        const input: *ToastActivatedEventArgs = @ptrCast(args);
        const instance: *Notification = @ptrCast(@alignCast(state.?));

        if (instance.config.onActivated) |onActivated| {
            const h_args = if (input.getArguments()) |h_args| h_args else |_| return;
            const w_args = WindowsGetString(h_args).?;
            const arguments = std.unicode.utf16LeToUtf8Alloc(std.heap.c_allocator, w_args) catch return;
            defer std.heap.c_allocator.free(arguments);

            // TODO: Get user input so that the input can be queried

            onActivated(instance, arguments);
        }
    }

    pub fn fail(state: ?*anyopaque, _: *ToastNotification, args: *ToastFailedEventArgs) void {
        _ = args;
        const instance: *Notification = @ptrCast(@alignCast(state.?));
        if (instance.config.onFail) |onFail| {
            // TODO: find a way to pass the error code
            onFail(instance);
        }
    }
};

fn formatWinError(error_code: u32, writer: *std.io.Writer) !void {
    try writer.print("{} (", .{error_code});
    var buf: [300]u8 = undefined;
    const len = win32.system.diagnostics.debug.FormatMessageA(
        .{ .FROM_SYSTEM = 1, .IGNORE_INSERTS = 1 },
        null,
        error_code,
        0,
        @ptrCast(&buf),
        buf.len,
        null,
    );
    if (len == 0) {
        try writer.writeAll("unknown error");
    }
    const msg = std.mem.trimRight(u8, buf[0..len], "\r\n");
    try writer.writeAll(msg);
    if (len + 1 >= buf.len) {
        try writer.writeAll("...");
    }
    try writer.writeAll(")");
}
