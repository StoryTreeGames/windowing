// TODO: Update whole file to use windows.UI.Notification and windows.Data.Xml.Dom

const std = @import("std");
const process = std.process;

const notif = @import("../notification.zig");
const Config = notif.Config;
const Update = notif.Update;
const Action = notif.Action;
const Audio = notif.Audio;

const Dictionary = struct {
    buffer: *std.io.Writer,

    pub fn init(buffer: *std.io.Writer) !@This() {
        try buffer.writeAll("$Dictionary = [System.Collections.Generic.Dictionary[String, String]]::New();\n");
        return .{
            .buffer = buffer,
        };
    }

    pub fn add(self: *@This(), name: []const u8, value: anytype) !void {
        const fmt = switch (@TypeOf(value)) {
            f32, comptime_float => "{d}",
            else => "{s}",
        };

        try self.buffer.print("$Dictionary.Add('{s}', '" ++ fmt ++ "');\n", .{ name, value });
    }
};

const Notifier = struct {
    buffer: *std.io.Writer,

    pub fn init(buffer: *std.io.Writer, app_id: []const u8) !@This() {
        try buffer.print("$AppId = '{s}';\n", .{app_id});

        try buffer.writeAll(
            "$Notifier = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]::CreateToastNotifier($AppId);\n",
        );
        return .{
            .buffer = buffer,
        };
    }

    pub fn show(self: *@This(), dictionary: Dictionary, sequence: u8, toast_notification: ToastNotification) !void {
        _ = dictionary;
        _ = toast_notification;

        try self.buffer.writeAll("$ToastNotification.Data = [Windows.UI.Notifications.NotificationData]::New($Dictionary);\n");
        try self.buffer.print("$ToastNotification.Data.SequenceNumber = {d};\n", .{sequence});
        try self.buffer.writeAll("$Notifier.Show($ToastNotification);\n");
    }

    pub fn update(self: *@This(), dictionary: Dictionary, sequence: u8, tag: []const u8) !void {
        _ = dictionary;

        try self.buffer.writeAll("$NotificationData = [Windows.UI.Notifications.NotificationData]::New($Dictionary);\n");
        try self.buffer.print("$NotificationData.SequenceNumber = {d};\n", .{sequence});
        try self.buffer.print("$Notifier.Update($NotificationData, '{s}');\n", .{tag});
    }
};

const XmlToastTag = union(enum) {
    close: void,
    attrs: Attrs,

    pub fn open(attrs: Attrs) @This() {
        return .{ .attrs = attrs };
    }

    pub const Attrs = struct {
        duration: ?enum { long, short } = null,
        scenario: ?enum { reminder, alarm, incoming_call, urgent } = null,
        /// Arguments passed to the application when it is activated by the toast.
        launch: ?[]const u8 = null,
        /// ISO 8601 standard timestamp
        displayTimestamp: ?[]const u8 = null,
        /// Whether to use styled buttons
        useButtonStyle: ?bool = null,
    };
};

const XmlImageAttrs = struct {
    /// + http://
    /// + https://
    /// + ms-appx://
    /// + ms-appdata:///local/
    /// + file:///
    src: []const u8,
    alt: ?[]const u8 = null,
    placement: ?enum {
        /// Very top of toast spaning the full width
        hero,
        /// Replaces app logo in toast
        app_logo_override,
    } = null,
    /// Crop the image
    hint_crop: ?enum { circle } = null,
};

const XmlBindingTag = union(enum) {
    close: void,
    template: []const u8,

    pub fn open(value: []const u8) @This() {
        return .{ .template = value };
    }
};

const Xml = struct {
    buffer: *std.io.Writer,
    id: usize = 1,

    pub fn init(buffer: *std.io.Writer) !@This() {
        try buffer.writeAll("$xml = '\n");

        return .{
            .buffer = buffer,
        };
    }

    pub fn actions(self: *@This(), state: enum { open, close }) !void {
        switch (state) {
            .open => try self.buffer.writeAll("  <actions>\n"),
            .close => try self.buffer.writeAll("  </actions>\n"),
        }
    }

    pub fn visual(self: *@This(), state: enum { open, close }) !void {
        switch (state) {
            .open => try self.buffer.writeAll("  <visual>\n"),
            .close => try self.buffer.writeAll("  </visual>\n"),
        }
    }

    pub fn image(self: *@This(), attrs: XmlImageAttrs) !void {
        self.id += 1;

        try self.buffer.print("      <image id=\"{d}\"", .{self.id});
        try self.buffer.writeAll("\n        src=\"");
        try self.buffer.writeAll(attrs.src);
        try self.buffer.writeAll("\"");

        if (attrs.alt) |alt| {
            try self.buffer.writeAll("\n        alt=\"");
            try self.buffer.writeAll(alt);
            try self.buffer.writeAll("\"");
        }
        if (attrs.placement) |duration| {
            try self.buffer.writeAll("\n        placement=\"");
            switch (duration) {
                .hero => try self.buffer.writeAll("hero"),
                .app_logo_override => try self.buffer.writeAll("appLogoOverride"),
            }
            try self.buffer.writeAll("\"");
        }
        if (attrs.hint_crop) |crop| {
            try self.buffer.writeAll("\n        hint-crop=\"");
            switch (crop) {
                .circle => try self.buffer.writeAll("circle"),
            }
            try self.buffer.writeAll("\"");
        }
        try self.buffer.writeAll("/>\n");
    }

    pub fn action(self: *@This(), a: Action) !void {
        switch (a) {
            .input => |attrs| {
                try self.buffer.writeAll("    <input type=\"text\" id=\"");
                try self.buffer.writeAll(attrs.id);
                try self.buffer.writeByte('"');

                if (attrs.place_holder_content) |placeholder| {
                    try self.buffer.writeAll(" placeHolderContent=\"");
                    try self.buffer.writeAll(placeholder);
                    try self.buffer.writeByte('"');
                }

                if (attrs.title) |title| {
                    try self.buffer.writeAll(" title=\"");
                    try self.buffer.writeAll(title);
                    try self.buffer.writeByte('"');
                }

                try self.buffer.writeAll("/>");
            },
            .select => |config| {
                try self.buffer.writeAll("    <input type=\"selection\" id=\"");
                try self.buffer.writeAll(config.id);
                try self.buffer.writeByte('"');

                if (config.title) |title| {
                    try self.buffer.writeAll(" title=\"");
                    try self.buffer.writeAll(title);
                    try self.buffer.writeByte('"');
                }
                try self.buffer.writeAll(">\n");

                for (config.items) |item| {
                    try self.buffer.writeAll("      <selection id=\"");
                    try self.buffer.writeAll(item.id);
                    try self.buffer.writeAll("\" content=\"");
                    try self.buffer.writeAll(item.content);
                    try self.buffer.writeAll("\"/>\n");
                }
                try self.buffer.writeAll("    </input>\n");
            },
            .button => |attrs| {
                try self.buffer.writeAll(
                    \\    <action
                    \\      content="
                );
                try self.buffer.writeAll(attrs.content);
                try self.buffer.writeAll(
                    \\"
                    \\      arguments="
                );
                try self.buffer.writeAll(attrs.arguments);
                try self.buffer.writeByte('"');

                if (attrs.activation_type) |atype| {
                    switch (atype) {
                        .foreground => try self.buffer.writeAll("\n      activationType=\"foreground\""),
                        .background => try self.buffer.writeAll("\n      activationType=\"background\""),
                        .protocol => try self.buffer.writeAll("\n      activationType=\"protocol\""),
                    }
                }
                if (attrs.after_activation_behavior) |behavior| {
                    switch (behavior) {
                        .default => try self.buffer.writeAll("\n      afterActivationBehavior=\"default\""),
                        .pending_update => try self.buffer.writeAll("\n      afterActivationBehavior=\"pendingUpdate\""),
                    }
                }
                if (attrs.placement) |placement| {
                    switch (placement) {
                        .context_menu => try self.buffer.writeAll("\n      placement=\"contextMenu\""),
                    }
                }
                if (attrs.hint_button_style) |button_style| {
                    switch (button_style) {
                        .success => try self.buffer.writeAll("\n      hint-buttonStyle=\"Success\""),
                        .critical => try self.buffer.writeAll("\n      hint-buttonStyle=\"Critical\""),
                    }
                }
                if (attrs.image_uri) |uri| {
                    try self.buffer.writeAll("\n      imageUri=\"");
                    try self.buffer.writeAll(uri);
                    try self.buffer.writeByte('"');
                }
                if (attrs.hint_input_id) |id| {
                    try self.buffer.writeAll("\n      hint-inputId=\"");
                    try self.buffer.writeAll(id);
                    try self.buffer.writeByte('"');
                }
                if (attrs.hint_tool_tip) |tip| {
                    try self.buffer.writeAll("\n      hint-toolTip=\"");
                    try self.buffer.writeAll(tip);
                    try self.buffer.writeByte('"');
                }
                try self.buffer.writeAll("/>\n");
            },
        }
    }

    pub fn binding(self: *@This(), state: XmlBindingTag) !void {
        switch (state) {
            .template => |value| {
                try self.buffer.print("    <binding template=\"{s}\">\n", .{value});
            },
            .close => try self.buffer.writeAll("    </binding>\n"),
        }
    }

    pub fn toast(self: *@This(), state: XmlToastTag) !void {
        switch (state) {
            .close => try self.buffer.writeAll("      </toast>\n';\n"),
            .attrs => |attrs| {
                try self.buffer.writeAll("      <toast");
                if (attrs.scenario) |scenario| {
                    switch (scenario) {
                        .reminder => try self.buffer.writeAll(" scenario=\"reminder\""),
                        .alarm => try self.buffer.writeAll(" scenario=\"alarm\""),
                        .incoming_call,
                        => try self.buffer.writeAll(" scenario=\"incomingCall\""),
                        .urgent => try self.buffer.writeAll(" scenario=\"urgent\""),
                    }
                }
                if (attrs.duration) |duration| {
                    switch (duration) {
                        .long => try self.buffer.writeAll(" duration=\"long\""),
                        .short => try self.buffer.writeAll(" duration=\"short\""),
                    }
                }
                if (attrs.displayTimestamp) |timestamp| {
                    try self.buffer.print(" displayTimestamp=\"{s}\"", .{timestamp});
                }
                if (attrs.launch) |launch| {
                    try self.buffer.print(" launch=\"{s}\"", .{launch});
                }
                if (attrs.useButtonStyle orelse false) {
                    try self.buffer.writeAll(" useButtonStyle=\"true\"");
                } else {
                    try self.buffer.writeAll(" useButtonStyle=\"false\"");
                }
                try self.buffer.writeAll(">\n");
            },
        }
    }

    pub fn text(self: *@This(), content: []const u8, hint_style: ?[]const u8) !void {
        self.id += 1;

        try self.buffer.print("      <text id=\"{d}\"", .{self.id});

        if (hint_style) |style| {
            try self.buffer.writeAll(" hint-style=\"");
            try self.buffer.writeAll(style);
            try self.buffer.writeAll("\"");
        }

        try self.buffer.print(">{s}</text>\n", .{content});
    }

    pub fn audio(self: *@This(), sound: Audio, loop: ?bool) !void {
        try self.buffer.writeAll("      <audio");
        switch (sound) {
            .silent, .custom_uri => try self.buffer.writeAll(" silent=\"true\"/>\n"),
            else => {
                try self.buffer.writeAll(" src=\"");
                try self.buffer.writeAll(sound.source());
                try self.buffer.writeAll("\"");
                if (loop orelse false) {
                    try self.buffer.writeAll(" loop=\"true\"");
                } else {
                    try self.buffer.writeAll(" loop=\"false\"");
                }
                try self.buffer.writeAll("/>\n");
            },
        }
    }

    pub fn progress(self: *@This(), title: bool, override: bool) !void {
        try self.buffer.writeAll("      <progress\n");
        if (title) {
            try self.buffer.writeAll("        title=\"{progressTitle}\"\n");
        }
        if (override) {
            try self.buffer.writeAll("        valueStringOverride=\"{progressValueString}\"\n");
        }

        try self.buffer.writeAll(
            \\        value="{progressValue}"
            \\        status="{progressStatus}"/>
            \\
        );
    }

    pub fn close(self: *@This()) !void {
        try self.buffer.writeAll(
            \\    </binding>
            \\  </visual>
            \\</toast>
            \\';
            \\
        );
    }
};

const MediaPlayer = struct {
    buffer: *std.io.Writer,

    pub fn init(buffer: *std.io.Writer) !@This() {
        try buffer.writeAll(
            \\$PLAYSOUND = @'
            \\$MediaPlayer = [Windows.Media.Playback.MediaPlayer, Windows.Media, ContentType = WindowsRuntime]::New();
            \\
        );

        return .{
            .buffer = buffer,
        };
    }

    pub fn createFromUri(self: *@This(), uri: []const u8) !void {
        try self.buffer.writeAll("$MediaSource = [Windows.Media.Core.MediaSource]::CreateFromUri(\\\"");
        try self.buffer.writeAll(uri);
        try self.buffer.writeAll(
            \\\");
            \\$MediaSource.OpenAsync() | Out-Null
            \\while ($MediaSource.State -eq \"Opening\" -or $MediaSource.State -eq \"Initial\") { Start-Sleep -Milliseconds 50 }
            \\$MediaPlayer.Source = $MediaSource
            \\
        );
    }

    pub fn play(self: *@This()) !void {
        try self.buffer.writeAll(
            \\$MediaPlayer.Play();
            \\Start-Sleep -Seconds $MediaPlayer.NaturalDuration.TotalSeconds
            \\'@;
            \\Start-Process -WindowStyle Hidden -FilePath powershell.exe -ArgumentList "-NoProfile", "-Command", $PLAYSOUND
            \\
        );
    }
};

const XmlDocument = struct {
    buffer: *std.io.Writer,

    pub fn init(buffer: *std.io.Writer) !@This() {
        try buffer.writeAll("$XmlDocument = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]::New();\n");
        return .{
            .buffer = buffer,
        };
    }

    pub fn loadXml(self: *@This(), xml: Xml) !void {
        _ = xml;
        try self.buffer.writeAll("$XmlDocument.loadXml($xml);\n");
    }
};

const ToastNotification = struct {
    pub fn init(buffer: *std.io.Writer, xml_document: XmlDocument, tag: []const u8) !@This() {
        _ = xml_document;

        try buffer.writeAll(
            \\$ToastNotification = [Windows.UI.Notifications.ToastNotification, Windows.UI.Notifications, ContentType = WindowsRuntime]::New($XmlDocument);
            \\
        );

        try buffer.print("$ToastNotification.Tag = '{s}';\n", .{tag});
        return .{};
    }
};

const Script = struct {
    allocator: std.mem.Allocator,
    buffer: std.io.Writer.Allocating,

    pub fn init(allocator: std.mem.Allocator) @This() {
        return .{
            .allocator = allocator,
            .buffer = .init(allocator),
        };
    }

    pub fn deinit(self: *@This()) void {
        self.buffer.deinit();
    }

    pub fn execute(self: *@This()) !void {
        const data = try self.buffer.toOwnedSlice();
        defer self.allocator.free(data);

        const result = try process.Child.run(.{
            .allocator = self.allocator,
            .argv = &.{
                "powershell",
                "-c",
                data,
            },
        });
        self.allocator.free(result.stdout);
        self.allocator.free(result.stderr);
    }

    pub fn startCommand(self: *@This()) !void {
        try self.buffer.writer.writeAll("Invoke-Command -ScriptBlock {\n");
    }

    pub fn endCommand(self: *@This()) !void {
        try self.buffer.writer.writeByte('}');
    }

    pub fn xml(self: *@This()) !Xml {
        return try Xml.init(&self.buffer.writer);
    }

    pub fn dictionary(self: *@This()) !Dictionary {
        return try Dictionary.init(&self.buffer.writer);
    }

    pub fn xml_document(self: *@This()) !XmlDocument {
        return try XmlDocument.init(&self.buffer.writer);
    }

    pub fn toast_notification(self: *@This(), document: XmlDocument, tag: []const u8) !ToastNotification {
        return try ToastNotification.init(&self.buffer.writer, document, tag);
    }

    pub fn notifier(self: *@This(), app_id: []const u8) !Notifier {
        return try Notifier.init(&self.buffer.writer, app_id);
    }

    pub fn media_player(self: *@This()) !MediaPlayer {
        return try MediaPlayer.init(&self.buffer.writer);
    }
};

pub const Notification = struct {
    config: Config,
    tag: []const u8,
    app_id: []const u8,

    pub fn send(alloc: std.mem.Allocator, app_id: ?[]const u8, tag: []const u8, config: Config) !@This() {
        var script = Script.init(alloc);
        defer script.deinit();

        try script.startCommand();

        var xml = try script.xml();
        try xml.toast(.open(.{ .scenario = .reminder }));
        try xml.visual(.open);
        try xml.binding(.open("ToastGeneric"));

        try xml.text("{notificationTitle}", "title");

        if (config.body != null) {
            try xml.text("{notificationBody}", null);
        }

        if (config.progress) |progress| {
            try xml.progress(progress.title != null, progress.override != null);
        }

        if (config.hero) |hero| {
            try xml.image(.{
                .src = hero.src,
                .alt = hero.alt,
                .placement = .hero,
            });
        }

        if (config.logo) |logo| {
            try xml.image(.{
                .src = logo.src,
                .alt = logo.alt,
                .placement = .app_logo_override,
                .hint_crop = if (logo.crop) .circle else null,
            });
        }

        try xml.binding(.close);
        try xml.visual(.close);

        try xml.actions(.open);
        if (config.actions) |actions| {
            for (actions) |action| {
                try xml.action(action);
            }
        }
        try xml.actions(.close);

        if (config.audio) |audio| {
            try xml.audio(audio.sound, audio.loop);
        }

        try xml.toast(.close);

        var dictionary = try script.dictionary();
        try dictionary.add("notificationTitle", config.title);

        if (config.body) |body| try dictionary.add("notificationBody", body);

        if (config.progress) |progress| {
            switch (progress.value) {
                .intermediate => try dictionary.add("progressValue", "intermediate"),
                .value => |v| try dictionary.add("progressValue", v),
            }
            try dictionary.add("progressStatus", progress.status);
            if (progress.title) |title| try dictionary.add("progressTitle", title);
            if (progress.override) |override| try dictionary.add("progressValueString", override);
        }

        var xml_document = try script.xml_document();
        try xml_document.loadXml(xml);

        const toast_notification = try script.toast_notification(xml_document, tag);

        if (config.audio) |audio| {
            if (audio.sound == .custom_uri) {
                var media_player = try script.media_player();
                try media_player.createFromUri(audio.sound.custom_uri);
                try media_player.play();
            }
        }

        var notifier = try script.notifier(app_id orelse "{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\\WindowsPowerShell\\v1.0\\powershell.exe");
        try notifier.show(dictionary, 1, toast_notification);

        try script.endCommand();
        try script.execute();

        return .{
            .tag = tag,
            .app_id = app_id orelse "{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\\WindowsPowerShell\\v1.0\\powershell.exe",
            .config = config,
        };
    }

    pub fn update(self: *const @This(), alloc: std.mem.Allocator, config: Update) !void {
        var script = Script.init(alloc);
        defer script.deinit();

        try script.startCommand();

        var dictionary = try script.dictionary();
        if (config.title) |title| {
            try dictionary.add("notificationTitle", title);
        }

        if (config.body) |body| {
            if (self.config.body == null) return error.NotificationBodyNotConfigured;
            try dictionary.add("notificationBody", body);
        }

        if (config.progress) |progress| {
            if (self.config.progress == null) return error.NotificationProgressNotConfigured;
            if (progress.title) |title| {
                if (self.config.progress.?.title == null) return error.NotificationProgressTitleNotConfigured;
                try dictionary.add("progressTitle", title);
            }

            if (progress.value) |value| {
                switch (value) {
                    .intermediate => try dictionary.add("progressValue", "intermediate"),
                    .value => |v| try dictionary.add("progressValue", v),
                }
            }

            if (progress.status) |status| {
                try dictionary.add("progressStatus", status);
            }

            if (progress.override) |override| {
                if (self.config.progress.?.override == null) return error.NotificationProgressValueStringNotConfigured;
                try dictionary.add("progressValueString", override);
            }
        }

        var notifier = try script.notifier(self.app_id);
        try notifier.update(dictionary, 2, self.tag);

        try script.endCommand();
        try script.execute();
    }
};
