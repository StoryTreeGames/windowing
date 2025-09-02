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
const ToastDismissedEventArgs = windows.UI.Notifications.ToastDismissedEventArgs;
const ToastActivatedEventArgs = windows.UI.Notifications.ToastActivatedEventArgs;
const ToastFailedEventArgs = windows.UI.Notifications.ToastFailedEventArgs;
const IMap = windows.Foundation.Collections.IMap;

const notif = @import("../notification.zig");
const Config = notif.Config;
const Update = notif.Update;
const Action = notif.Action;
const Audio = notif.Audio;

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

pub fn addAttribute(xmlElement: *XmlElement, key: [:0]const u16, value: [:0]const u16) !void {
    const aname = try WindowsCreateString(key);
    defer WindowsDeleteString(aname);

    const avalue = try WindowsCreateString(value);
    defer WindowsDeleteString(avalue);

    try xmlElement.SetAttribute(aname.?, avalue.?);
}

pub fn addText(allocator: std.mem.Allocator, doc: *XmlDocument, parent: *XmlElement, content: []const u8, id: usize, hint_title: bool) !void {
    const text_tag = try WindowsCreateString(L("text"));
    defer WindowsDeleteString(text_tag);

    const textElement = try doc.CreateElement(text_tag.?);
    defer _ = IUnknown.Release(@ptrCast(textElement));
    _ = try parent.AppendChild(@ptrCast(textElement));

    const id_str = try std.fmt.allocPrint(allocator, "{d}", .{ id });
    defer allocator.free(id_str);

    const wide_id = try std.unicode.utf8ToUtf16LeAllocZ(allocator, id_str);
    defer allocator.free(wide_id);

    try addAttribute(textElement, L("id"), wide_id[0..wide_id.len:0]);
    if (hint_title) {
        try addAttribute(textElement, L("hint-style"), L("title"));
    }

    const wide_content = try std.unicode.utf8ToUtf16LeAllocZ(allocator, content);
    defer allocator.free(wide_content);

    const title_text = try WindowsCreateString(wide_content[0..wide_content.len:0]);
    defer WindowsDeleteString(title_text);

    const text = try doc.CreateTextNode(title_text.?);
    defer _ = IUnknown.Release(@ptrCast(text));
    _ = try textElement.AppendChild(@ptrCast(text));
}

pub fn insertData(allocator: std.mem.Allocator, data: *IMap(HSTRING, HSTRING), key: [:0]const u16, value: []const u8) !void {
    const aname = try WindowsCreateString(key);
    defer WindowsDeleteString(aname);

    const wide_value = try std.unicode.utf8ToUtf16LeAllocZ(allocator, value);
    defer allocator.free(wide_value);

    const avalue = try WindowsCreateString(wide_value[0..wide_value.len:0]);
    defer WindowsDeleteString(avalue);

    _ = try data.Insert(aname.?, avalue.?);
}

const powershell_app_id: []const u8 = "{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\\WindowsPowerShell\\v1.0\\powershell.exe";

pub const Notification = struct {
    config: Config,
    tag: []const u8,
    app_id: []const u8,

    pub fn send(allocator: std.mem.Allocator, app_id: ?[]const u8, tag: []const u8, config: Config) !@This() {
        const aid = try std.unicode.utf8ToUtf16LeAllocZ(allocator, if (app_id)|id| id else powershell_app_id);
        defer allocator.free(aid);

        const APP_ID = try WindowsCreateString(aid[0..aid.len:0]);
        defer WindowsDeleteString(APP_ID);

        const xml_document = try XmlDocument.init();
        defer xml_document.deinit();

        var cid: usize = 0;
        {
            const toast_tag = try WindowsCreateString(L("toast"));
            defer WindowsDeleteString(toast_tag);

            const toastElement = try xml_document.CreateElement(toast_tag.?);
            defer _ = IUnknown.Release(@ptrCast(toastElement));
            _ = try xml_document.AppendChild(@ptrCast(toastElement));

            {
                const visual_tag = try WindowsCreateString(L("visual"));
                defer WindowsDeleteString(visual_tag);

                const visualElement = try xml_document.CreateElement(visual_tag.?);
                defer _ = IUnknown.Release(@ptrCast(visualElement));
                _ = try toastElement.AppendChild(@ptrCast(visualElement));

                {
                    const binding_tag = try WindowsCreateString(L("binding"));
                    defer WindowsDeleteString(binding_tag);

                    const bindingElement = try xml_document.CreateElement(binding_tag.?);
                    defer _ = IUnknown.Release(@ptrCast(bindingElement));
                    _ = try visualElement.AppendChild(@ptrCast(bindingElement));

                    try addAttribute(bindingElement, L("template"), L("ToastGeneric"));

                    try addText(allocator, xml_document, bindingElement, config.title, cid, true);
                    cid += 1;
                    if (config.body) |body| {
                        try addText(allocator, xml_document, bindingElement, body, cid, true);
                        cid += 1;
                    }

                    // TODO: Add hero and logo images
                    // TODO: Add actions
                    // TODO: Add Progress
                    // TODO: Add audio/sound
                }
            }
        }

        const notification = try ToastNotification.CreateToastNotification(xml_document);
        defer notification.deinit();

        const h_tag = try WindowsCreateString(L("toast"));
        defer WindowsDeleteString(h_tag);
        try notification.putTag(h_tag.?);

        var data = try NotificationData.init();
        defer data.deinit();
        try notification.putData(data);

        // insertData(allocator, data.getValues(), L("NotificationData"), "Zig Windows Runtime");

        // TODO: Add generic event handler
        // const dhandler = try TypedEventHandler(ToastNotification, ToastDismissedEventArgs).init(dismissNotification);
        // const dhandle = try notification.addDismissed(dhandler);
        // const ahandler = try TypedEventHandler(ToastNotification, IInspectable).init(activatedNotification);
        // const ahandle = try notification.addActivated(ahandler);
        // const fhandler = try TypedEventHandler(ToastNotification, ToastFailedEventArgs).init(failedNotification);
        // const fhandle = try notification.addFailed(fhandler);

        var notifier = try ToastNotificationManager.CreateToastNotifierWithApplicationId(APP_ID.?);
        defer _ = IUnknown.Release(@ptrCast(notifier));

        try notifier.Show(notification);

        return .{
            .config = config,
            .tag = tag,
            .app_id = if(app_id) |id| id else powershell_app_id
        };
    }

    pub fn update(self: *const @This(), alloc: std.mem.Allocator, config: Update) !void {
        _ = self;
        _ = alloc;
        _ = config;
        // TODO: Create NotificationData and send an update to the action center
    }
};
