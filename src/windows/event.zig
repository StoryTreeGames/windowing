const std = @import("std");

const windows_and_messaging = @import("win32").ui.windows_and_messaging;
const keyboard_and_mouse = @import("win32").ui.input.keyboard_and_mouse;
const zig = @import("win32").zig;

const event = @import("../event.zig");
const input = @import("input.zig");
const util = @import("./util.zig");

const Window = @import("../window.zig");
const Modifiers = event.Modifiers;
const Event = event.Event;
const EventHandler = event.EventHandler;


const VIRTUAL_KEY = keyboard_and_mouse.VIRTUAL_KEY;
const VK_CONTROL = keyboard_and_mouse.VK_CONTROL;
const VK_LCONTROL = keyboard_and_mouse.VK_LCONTROL;
const VK_RCONTROL = keyboard_and_mouse.VK_RCONTROL;
const VK_ALT = keyboard_and_mouse.VK_MENU;
const VK_LALT = keyboard_and_mouse.VK_LMENU;
const VK_RALT = keyboard_and_mouse.VK_RMENU;
const VK_SHIFT = keyboard_and_mouse.VK_SHIFT;
const VK_LSHIFT = keyboard_and_mouse.VK_LSHIFT;
const VK_RSHIFT = keyboard_and_mouse.VK_RSHIFT;

const PRESSED: u8 = 0b10000000;

pub fn EventLoop(S: type) type {
    return struct {
        pub fn messageLoop(event_loop: *event.EventLoop(S)) !void {
            var message: windows_and_messaging.MSG = undefined;
            while (event_loop.isActive() and windows_and_messaging.GetMessageW(&message, null, 0, 0) == zig.TRUE) {
                _ = windows_and_messaging.TranslateMessage(&message);
                _ = windows_and_messaging.DispatchMessageW(&message);
            }
        }

        pub fn pollMessages() !bool {
            var message: windows_and_messaging.MSG = undefined;
            if (windows_and_messaging.PeekMessageW(&message, null, 0, 0, windows_and_messaging.PM_REMOVE) != 0) {
                _ = windows_and_messaging.TranslateMessage(&message);
                _ = windows_and_messaging.DispatchMessageW(&message);
                return true;
            }
            return false;
        }

        pub fn setup(id: [:0]const u16) !void {
            if (util.SetCurrentProcessExplicitAppUserModelID(id.ptr) != util.S_OK) return error.UnknownError;
        }
    };
}

fn getKeyboardState(keyboard: *[256]u8) void {
    _ = keyboard_and_mouse.GetKeyboardState(keyboard);
}

fn anyKeySet(keyboard: *const [256]u8, keys: []const VIRTUAL_KEY) bool {
    for (keys) |key| {
        if (key == keyboard_and_mouse.VK_CAPITAL or key == keyboard_and_mouse.VK_NUMLOCK) {
            if (keyboard[@intFromEnum(key)] & 1 == 1) return true;
        } else if (keyboard[@intFromEnum(key)] & PRESSED == PRESSED) return true;
    }
    return false;
}

fn getModifiers(keyboard: *const [256]u8) Modifiers {
    var modifiers: Modifiers = .{};
    if (anyKeySet(keyboard, &[3]VIRTUAL_KEY{ VK_CONTROL, VK_LCONTROL, VK_RCONTROL })) {
        modifiers.ctrl = true;
    }
    if (anyKeySet(keyboard, &[3]VIRTUAL_KEY{ VK_ALT, VK_LALT, VK_RALT })) {
        modifiers.alt = true;
    }
    if (anyKeySet(keyboard, &[3]VIRTUAL_KEY{ VK_SHIFT, VK_LSHIFT, VK_RSHIFT })) {
        modifiers.shift = true;
    }

    return modifiers;
}

pub fn parseEvent(win: *Window, message: u32, wparam: usize, lparam: isize) ?Event {
    switch (message) {
        // Request to close the window
        windows_and_messaging.WM_CLOSE, windows_and_messaging.WM_DESTROY => {
            return Event.close;
        },
        windows_and_messaging.WM_SETCURSOR => {
            // Set user defined cursor
            _ = windows_and_messaging.SetCursor(Window.Inner.getHCursor(win.inner.cursor));
            // Allow for resize cursor to be drawn if cursor is at correct position
            // return windows_and_messaging.DefWindowProcW(hwnd, msg, wparam, lparam);
        },
        windows_and_messaging.WM_COMMAND => {
            const wmId: u16 = @truncate(wparam);
            const wmEvent: u16 = @truncate(wparam >> 16);
            if (wmEvent == 0) {
                const menu_info = win.inner.itemToMenu.getPtr(@intCast(wmId));
                if (menu_info) |info| {
                    return Event{.menu = .{
                        .id = @intCast(wmId),
                        .item = info,
                    }};
                }
            }
        },
        // Keyboard input events
        windows_and_messaging.WM_CHAR, windows_and_messaging.WM_SYSCHAR => {
            const scan_code: u32 = @as(u32, @intCast(lparam >> 16)) & 0xFF;
            const virtual_key: u32 = keyboard_and_mouse.MapVirtualKeyW(scan_code, windows_and_messaging.MAPVK_VSC_TO_VK);

            var keyboard: [256]u8 = [_]u8{0} ** 256;
            getKeyboardState(&keyboard);

            const modifiers: Modifiers = getModifiers(&keyboard);

            // Reset keyboard state for modifiers so they aren't processed with `ToUnicode`
            keyboard[@intFromEnum(keyboard_and_mouse.VK_CONTROL)] = 0;
            // keyboard[@intFromEnum(keyboard_and_mouse.VK_SHIFT)] = 0;
            keyboard[@intFromEnum(keyboard_and_mouse.VK_MENU)] = 0;
            keyboard[@intFromEnum(keyboard_and_mouse.VK_LCONTROL)] = 0;
            // keyboard[@intFromEnum(keyboard_and_mouse.VK_LSHIFT)] = 0;
            keyboard[@intFromEnum(keyboard_and_mouse.VK_LMENU)] = 0;
            keyboard[@intFromEnum(keyboard_and_mouse.VK_RCONTROL)] = 0;
            // keyboard[@intFromEnum(keyboard_and_mouse.VK_RSHIFT)] = 0;
            keyboard[@intFromEnum(keyboard_and_mouse.VK_RMENU)] = 0;

            var buffer: [3:0]u16 = [_:0]u16{0} ** 3;
            const result = keyboard_and_mouse.ToUnicode(
                virtual_key,
                scan_code,
                &keyboard,
                &buffer,
                3,
                // Set it to not modify keyboard state. Windows 1607 and above
                0,
            );

            // TODO: If dead key then store for later and combine with next char/key input
            if (result == 0) {
                std.log.debug("[{d}] ToUnicode failed", .{result});
            } else if (result < 0) {
                std.log.debug("[{d}] Dead key detected", .{result});
            } else {
                var data: [4]u8 = [_]u8{0} ** 4;
                _ = std.unicode.utf16LeToUtf8(&data, buffer[0..]) catch unreachable;

                if (data.len <= 4) {
                    return Event{
                        .key_input = .{
                            .key = .{ .char = data },
                            .modifiers = modifiers,
                            .state = .pressed,
                            .scan = scan_code,
                            .virtual = virtual_key,
                        },
                    };
                }
            }
        },
        windows_and_messaging.WM_KEYDOWN => {
            if (input.parseVirtualKey(wparam, lparam)) |key| {
                // Keyboard state to better match keyboard input with virtual keys
                var keyboard: [256]u8 = [_]u8{0} ** 256;
                getKeyboardState(&keyboard);

                const modifiers: Modifiers = getModifiers(&keyboard);

                return Event{
                    .key_input = .{
                        .key = .{ .virtual = key },
                        .modifiers = modifiers,
                        .state = .pressed,
                    },
                };
            }
            // return windows_and_messaging.DefWindowProcW(hwnd, uMsg, wparam, lparam);
        },
        // MouseMove event
        windows_and_messaging.WM_MOUSEMOVE => {
            if (lparam >= 0) {
                const pos: usize = @intCast(lparam);
                const x: u16 = @truncate(pos);
                const y: u16 = @truncate(pos >> 16);
                return Event{ .mouse_move = .{ .x = x, .y = y } };
            }
        },
        // Mouse scrolling events
        windows_and_messaging.WM_MOUSEWHEEL => {
            const params: isize = @intCast(wparam);
            const distance: i16 = @truncate(params >> 16);

            return Event{ .mouse_scroll = .{
                .direction = .vertical,
                .delta = distance,
            } };
        },
        windows_and_messaging.WM_MOUSEHWHEEL => {
            const params: isize = @intCast(wparam);
            const distance: i16 = @truncate(params >> 16);

            return Event{
                .mouse_scroll = .{
                    .direction = .horizontal,
                    .delta = distance,
                },
            };
        },
        // Mouse button events == MouseInput
        windows_and_messaging.WM_LBUTTONDOWN => return Event{ .mouse_input = .{ .state = .pressed, .button = .left } },
        windows_and_messaging.WM_LBUTTONUP => return Event{ .mouse_input = .{ .state = .released, .button = .left } },
        windows_and_messaging.WM_MBUTTONDOWN => return Event{ .mouse_input = .{ .state = .pressed, .button = .middle } },
        windows_and_messaging.WM_MBUTTONUP => return Event{ .mouse_input = .{ .state = .released, .button = .middle } },
        windows_and_messaging.WM_RBUTTONDOWN => return Event{ .mouse_input = .{ .state = .pressed, .button = .right } },
        windows_and_messaging.WM_RBUTTONUP => return Event{ .mouse_input = .{ .state = .released, .button = .right } },
        windows_and_messaging.WM_XBUTTONDOWN => return Event{ .mouse_input = .{
            .state = .pressed,
            .button = if ((wparam >> 16) & 0x0001 == 0x0001) .x1 else .x2,
        } },
        windows_and_messaging.WM_XBUTTONUP => return Event{ .mouse_input = .{
            .state = .released,
            .button = if ((wparam >> 16) & 0x0001 == 0x0001) .x1 else .x2,
        } },
        // Check for focus and unfocus
        windows_and_messaging.WM_SETFOCUS => return Event{ .focused = true },
        windows_and_messaging.WM_KILLFOCUS => return Event{ .focused = false },
        windows_and_messaging.WM_SIZE => {
            const size: usize = @intCast(lparam);
            return Event{
                .resize = .{
                    .width = @intCast(@as(u16, @truncate(size))),
                    .height = @intCast(@as(u16, @truncate(size >> 16))),
                },
            };
        },
        else => return null,
    }

    return null;
}
