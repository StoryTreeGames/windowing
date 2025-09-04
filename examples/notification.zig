const std = @import("std");
const core = @import("storytree-core");

const Notification = core.notification.Notification;
const DismissReason = core.notification.DismissReason;
const ActivatedArgs = core.notification.ActivatedArgs;
const Action = core.notification.Action;
const relative_file_uri = @import("./common.zig").relative_file_uri;

fn dismissed(_: *const Notification, reason: DismissReason) void {
    std.debug.print("[DISMISSED] {s}\n", .{ @tagName(reason) });
}

fn activated(_: *const Notification, args: ActivatedArgs) void {
    std.debug.print("[Activated] {s}\n", .{ args.arguments });
    var it = args.inputs.iterator();
    while (it.next()) |entry| {
        std.debug.print("  - {s}: '{s}'\n", .{ entry.key_ptr.*, entry.value_ptr.* });
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const notif = try Notification.send(allocator, null, "storytree-core-example-notif", .{
        .title = "Test Notification",
        .body = "Test notification from storytree core",
        .hero = .{
            .src = "examples/assets/images/hero.png",
            .alt = "Banner",
        },
        .logo = .{
            .src = "examples/assets/images/logo.png",
            .alt = "Logo",
            .crop = true,
        },
        .progress = .{
            .value = .indeterminate,
            .status = "Loading...",
            .override = " ",
        },
        .actions = &.{
            // The actions are a 1-to-1 of the windows api
            // and will change when other platforms are implemented
            Action.Input(.{
                .id = "username",
                .title = "Username",
            }),
            Action.Button(.{
                .arguments = "submit",
                .content = "Submit",
                .hint_input_id = "username",
            }),
            Action.Button(.{
                .arguments = "https://ziglang.org/",
                .activation_type = .protocol,
                .image_uri = "examples/assets/images/button_appreciation.png",
                .hint_tool_tip = "Zig Home",
            }),
            Action.Button(.{
                .arguments = "https://ziglang.org/documentation/master/std/#",
                .activation_type = .protocol,
                .image_uri = "examples/assets/images/button_read.png",
                .hint_tool_tip = "Zig Docs",
            })
        },
        .audio = .{ .sound = .custom("examples/assets/lizard_notification.wav") },
        .onDismiss = dismissed,
        .onActivated = activated,
    });
    defer notif.deinit();

    std.Thread.sleep(std.time.ns_per_s * 1);

    for (1..11) |i| {
        const override = try std.fmt.allocPrint(allocator, "{d}/10", .{i});
        defer allocator.free(override);

        // This can fail if a button was clicked and the notification
        // is no longer in the action center on Windows
        notif.update(.{
            .progress = .{
                .value = .progress(0.1 * @as(f32, @floatFromInt(i))),
                .status = "Fetching Updates...",
                .override = override,
            },
        }) catch break;
        std.Thread.sleep(std.time.ns_per_ms * 500);
    }

    notif.update(.{ .progress = .{ .status = "Completed" } }) catch {};

    std.Thread.sleep(std.time.ns_per_s * 1);

    try notif.hide();

    std.Thread.sleep(std.time.ns_per_s * 1);
}
