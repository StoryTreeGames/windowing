const std = @import("std");

pub const Progress = union(enum) {
    intermediate: void,
    value: f32,
    pub fn progress(v: f32) @This() {
        return .{ .value = v };
    }
};

pub const Action = union(enum) {
    input: InputAction,
    select: SelectAction,
    button: ButtonAction,

    pub fn Input(config: InputAction) @This() {
        return .{ .input = config };
    }
    pub fn Select(config: SelectAction) @This() {
        return .{ .select = config };
    }
    pub fn Button(config: ButtonAction) @This() {
        return .{ .button = config };
    }

    pub const SelectAction = struct {
        /// The id associated with the selection
        id: []const u8,
        items: []const Selection,
        /// Text displayed as a label for the input
        title: ?[]const u8 = null,
    };

    pub const ButtonAction = struct {
        /// Content displayed on the button
        content: []const u8 = "",
        /// App-defined string of arguments that the app will later receive
        /// if the user clicks the button
        arguments: []const u8,

        /// Decides the type of activation that will be used when the user interacts
        /// with a specific action
        activation_type: ?ActiviationType = null,
        /// Specifies the behavior that the toast should use when the user takes action
        after_activation_behavior: ?ActivationBehavior = null,
        /// When set to "contextMenu" the action becomes a context menu action
        /// added to the toast notification's context menu. (right-click/more menu)
        placement: ?enum { context_menu } = null,
        /// The uri of the image source for a toast button icon. These icons are `white
        /// transparent 16x16 pixel images at 100% scaling` and should have `no padding`
        /// included in the image itself.
        ///
        /// If you choose to provide icons on a toast notification, you must provide
        /// icons for ALL of your buttons as it transforms the style of your buttons
        /// into icon buttons.
        ///
        /// Use the following formats:
        /// + http://
        /// + https://
        /// + ms-appx:///
        /// + ms-appdata:///local/
        /// + file:///
        image_uri: ?[]const u8 = null,
        /// Set to the id of an input to position the button beside the input
        hint_input_id: ?[]const u8 = null,
        /// The button style. `useButtonStyle` must be set to true on the `toast`
        ///
        /// + Success - The button is green
        /// + Critical - The button is red
        hint_button_style: ?ButtonStyle = null,
        /// The tooltip for a button, if the button has an empty content string
        hint_tool_tip: ?[]const u8 = null,
    };

    pub const InputAction = struct {
        /// The id associated with the input
        id: []const u8,
        /// The placeholder displayed for text input
        place_holder_content: ?[]const u8 = null,
        /// Text displayed as a label for the input
        title: ?[]const u8 = null,
    };

    pub const Selection = struct {
        /// Id of the selection item
        id: []const u8,
        /// Content of the selection item
        content: []const u8
    };

    pub const ButtonStyle = enum {
        /// Green
        success,
        /// Red
        critical,
    };

    pub const ActiviationType = enum {
        /// [Default] Your foreground app is launched
        foreground,
        /// Your corresponding background task is triggered
        background,
        /// Launch a different app using protocol activation
        protocol,
    };

    pub const ActivationBehavior = enum {
        /// [Default] The toast will be dismissed when the user takes action
        default,
        /// After the user clicks a button on your toast, the notification
        /// will remain present, in a "pending update" visual state.
        ///
        /// The background task should update the toast so that the user doesn't
        /// see the "pending update" state for too long.
        pending_update,
    };
};

pub const Audio = union(enum) {
    custom_uri: []const u8,

    silent: void,
    default: void,
    im: void,
    mail: void,
    reminder: void,
    sms: void,
    looping_alarm: void,
    looping_alarm2: void,
    looping_alarm3: void,
    looping_alarm4: void,
    looping_alarm5: void,
    looping_alarm6: void,
    looping_alarm7: void,
    looping_alarm8: void,
    looping_alarm9: void,
    looping_alarm10: void,
    looping_call: void,
    looping_call2: void,
    looping_call3: void,
    looping_call4: void,
    looping_call5: void,
    looping_call6: void,
    looping_call7: void,
    looping_call8: void,
    looping_call9: void,
    looping_call10: void,

    pub fn custom(uri: []const u8) @This() {
        return .{ .custom_uri = uri };
    }

    pub fn source(self: @This()) []const u8 {
        return switch (self) {
            .default => "ms-winsoundevent:Notification.Default",
            .im => "ms-winsoundevent:Notification.IM",
            .mail => "ms-winsoundevent:Notification.Mail",
            .reminder => "ms-winsoundevent:Notification.Reminder",
            .sms => "ms-winsoundevent:Notification.SMS",
            .looping_alarm => "ms-winsoundevent:Notification.Looping.Alarm",
            .looping_alarm2 => "ms-winsoundevent:Notification.Looping.Alarm2",
            .looping_alarm3 => "ms-winsoundevent:Notification.Looping.Alarm3",
            .looping_alarm4 => "ms-winsoundevent:Notification.Looping.Alarm4",
            .looping_alarm5 => "ms-winsoundevent:Notification.Looping.Alarm5",
            .looping_alarm6 => "ms-winsoundevent:Notification.Looping.Alarm6",
            .looping_alarm7 => "ms-winsoundevent:Notification.Looping.Alarm7",
            .looping_alarm8 => "ms-winsoundevent:Notification.Looping.Alarm8",
            .looping_alarm9 => "ms-winsoundevent:Notification.Looping.Alarm9",
            .looping_alarm10 => "ms-winsoundevent:Notification.Looping.Alarm10",
            .looping_call => "ms-winsoundevent:Notification.Looping.Call",
            .looping_call2 => "ms-winsoundevent:Notification.Looping.Call2",
            .looping_call3 => "ms-winsoundevent:Notification.Looping.Call3",
            .looping_call4 => "ms-winsoundevent:Notification.Looping.Call4",
            .looping_call5 => "ms-winsoundevent:Notification.Looping.Call5",
            .looping_call6 => "ms-winsoundevent:Notification.Looping.Call6",
            .looping_call7 => "ms-winsoundevent:Notification.Looping.Call7",
            .looping_call8 => "ms-winsoundevent:Notification.Looping.Call8",
            .looping_call9 => "ms-winsoundevent:Notification.Looping.Call9",
            .looping_call10 => "ms-winsoundevent:Notification.Looping.Call10",
            else => ""
        };
    }
};

pub const Config = struct {
    title: []const u8,
    body: ?[]const u8 = null,
    logo: ?struct {
        src: []const u8,
        alt: []const u8,
        crop: bool = false,
    } = null,
    hero: ?struct {
        src: []const u8,
        alt: []const u8,
    } = null,
    progress: ?struct {
        value: Progress,
        status: []const u8,
        title: ?[]const u8 = null,
        override: ?[]const u8 = null,
    } = null,
    actions: ?[]const Action = null,
    audio: ?struct {
        sound: Audio,
        loop: ?bool = null,
    } = null,
};

pub const Update = struct {
    title: ?[]const u8 = null,
    body: ?[]const u8 = null,
    progress: ?struct {
        value: ?Progress = null,
        status: ?[]const u8 = null,
        title: ?[]const u8 = null,
        override: ?[]const u8 = null,
    } = null,
};

const Impl = switch(@import("builtin").os.tag) {
    .windows => @import("windows/notification.zig").Notification,
    else => @compileError("unsupported platform")
};

pub const Notification = Impl.Notification;
