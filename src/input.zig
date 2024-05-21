// X11 Reference: https://www.cl.cam.ac.uk/~mgk25/ucs/keysymdef.h
// Win32 Reference: https://learn.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes

// Winit Reference: https://github.com/rust-windowing/winit/blob/master/src/keyboard.rs#L1476

pub const CTRL: u4 = 0b0001;
pub const ALT: u4 = 0b0010;
pub const SHIFT: u4 = 0b0100;

pub const Key = union(enum) {
    virtual: VirtualKey,
    char: []u8,

    /// Character code points are u16 code points and there can potentially be 2
    /// unicode code points for a single character. This means there is a max
    /// size of up to around 4 bytes allocated for a single character.
    ///
    /// This method automatically converts to u8 and gives the exact length byte array
    /// that represents the given character
    pub fn getChar(self: @This()) ?[]u8 {
        for (self.char, 0..) |c, i| {
            if (c == 0) {
                return self.char[0..i];
            }
        }
        return self.char[0..];
    }
};

/// Keyboard key to keycode mapping
pub const VirtualKey = enum(u32) {
    /// backspace key
    back,
    /// tab key
    tab,
    /// clear key
    clear,
    /// enter key
    @"return",
    /// shift key
    shift,
    /// ctrl key
    control,
    /// alt key
    alt,
    /// pause key
    pause,
    /// caps lock key
    caps_lock,
    /// ime kana mode
    kana,
    /// ime hangul mode
    hangul,
    /// ime kana or hangul mode
    kana_hangul,
    /// ime on
    ime_on,
    /// ime junja mode
    junja,
    /// ime final mode
    final,
    /// ime hanja mode
    hanja,
    /// ime kanji mode
    kanji,
    /// ime hanja or kanji mode
    hanja_kanji,
    /// ime off
    ime_off,
    /// esc key
    escape,
    /// ime convert
    convert,
    /// ime nonconvert
    nonconvert,
    /// ime accept
    accept,
    /// ime mode change request
    modechange,
    /// page up key
    prior,
    /// page down key
    next,
    /// end key
    end,
    /// home key
    home,
    /// left arrow key
    left,
    /// up arrow key
    up,
    /// right arrow key
    right,
    /// down arrow key
    down,
    /// select key
    select,
    /// print key
    print,
    /// execute key
    execute,
    /// print screen key
    snapshot,
    /// ins key
    insert,
    /// del key
    delete,
    /// help key
    help,
    /// windows key
    super,
    /// applications key
    apps,
    /// computer sleep key
    sleep,
    /// numeric keypad 0 key
    numpad0,
    /// numeric keypad 1 key
    numpad1,
    /// numeric keypad 2 key
    numpad2,
    /// numeric keypad 3 key
    numpad3,
    /// numeric keypad 4 key
    numpad4,
    /// numeric keypad 5 key
    numpad5,
    /// numeric keypad 6 key
    numpad6,
    /// numeric keypad 7 key
    numpad7,
    /// numeric keypad 8 key
    numpad8,
    /// numeric keypad 9 key
    numpad9,
    /// multiply key
    multiply,
    /// add key
    add,
    /// separator key
    separator,
    /// subtract key
    subtract,
    /// decimal key
    decimal,
    /// divide key
    divide,
    /// f1 key
    f1,
    /// f2 key
    f2,
    /// f3 key
    f3,
    /// f4 key
    f4,
    /// f5 key
    f5,
    /// f6 key
    f6,
    /// f7 key
    f7,
    /// f8 key
    f8,
    /// f9 key
    f9,
    /// f10 key
    f10,
    /// f11 key
    f11,
    /// f12 key
    f12,
    /// f13 key
    f13,
    /// f14 key
    f14,
    /// f15 key
    f15,
    /// f16 key
    f16,
    /// f17 key
    f17,
    /// f18 key
    f18,
    /// f19 key
    f19,
    /// f20 key
    f20,
    /// f21 key
    f21,
    /// f22 key
    f22,
    /// f23 key
    f23,
    /// f24 key
    f24,
    /// num lock key
    num_lock,
    /// scroll lock key
    scroll,
    /// browser back key
    browser_back,
    /// browser forward key
    browser_forward,
    /// browser refresh key
    browser_refresh,
    /// browser stop key
    browser_stop,
    /// browser search key
    browser_search,
    /// browser favorites key
    browser_favorites,
    /// browser start and home key
    browser_home,
    /// volume mute key
    volume_mute,
    /// volume down key
    volume_down,
    /// volume up key
    volume_up,
    /// next track key
    media_next_track,
    /// previous track key
    media_prev_track,
    /// stop media key
    media_stop,
    /// play/pause media key
    media_play_pause,
    /// start mail key
    launch_mail,
    /// select media key
    launch_media_select,
    /// start application 1 key
    launch_app1,
    /// start application 2 key
    launch_app2,
    /// used for miscellaneous characters; it can vary by keyboard.
    oem_8,
    /// the <> keys on the us standard keyboard, or the \\| key on the non-us 102-key keyboard
    oem_102,
    /// ime process key
    processkey,
    /// used to pass unicode characters as if they were keystrokes. the packet key is the low word of a 32-bit virtual key value used for non-keyboard input methods. for more information, see remark in keybdinput, sendinput, wm_keydown, and wm_keyup
    packet,
    /// attn key
    attn,
    /// crsel key
    crsel,
    /// exsel key
    exsel,
    /// erase eof key
    ereof,
    /// play key
    play,
    /// zoom key
    zoom,
    /// reserved
    noname,
    /// pa1 key
    pa1,
    /// clear key
    oem_clear,
};

pub const MouseButton = enum(u32) {
    /// The left mouse button.
    left = 0x0001,
    /// The middle mouse button.
    middle = 0x0010,
    /// The right mouse button.
    right = 0x0002,
    /// The first X button.
    x1 = 0x0020,
    /// The second X button.
    x2 = 0x0040,
};

pub usingnamespace switch (@import("builtin").target.os.tag) {
    .windows => struct {
        pub fn parseVirtualKey(wparam: usize, lparam: isize) ?VirtualKey {
            _ = lparam;
            return switch (wparam) {
                0x08 => .back,
                0x09 => .tab,
                0x0c => .clear,
                0x0d => .@"return",
                0x10, 0xa0, 0xa1 => .shift,
                0x11, 0xa2, 0xa3 => .control,
                0x12, 0xa4, 0xa5 => .alt,
                0x13 => .pause,
                0x14 => .caps_lock,
                0x15 => .kana_hangul,
                0x16 => .ime_on,
                0x17 => .junja,
                0x18 => .final,
                0x19 => .hanja_kanji,
                0x1a => .ime_off,
                0x1b => .escape,
                0x1c => .convert,
                0x1d => .nonconvert,
                0x1e => .accept,
                0x1f => .modechange,
                0x21 => .prior,
                0x22 => .next,
                0x23 => .end,
                0x24 => .home,
                0x25 => .left,
                0x26 => .up,
                0x27 => .right,
                0x28 => .down,
                0x29 => .select,
                0x2a => .print,
                0x2b => .execute,
                0x2c => .snapshot,
                0x2d => .insert,
                0x2e => .delete,
                0x2f => .help,
                0x5b, 0x5c => .super,
                0x5d => .apps,
                0x5f => .sleep,
                0x60 => .numpad0,
                0x61 => .numpad1,
                0x62 => .numpad2,
                0x63 => .numpad3,
                0x64 => .numpad4,
                0x65 => .numpad5,
                0x66 => .numpad6,
                0x67 => .numpad7,
                0x68 => .numpad8,
                0x69 => .numpad9,
                0x6a => .multiply,
                0x6b => .add,
                0x6c => .separator,
                0x6d => .subtract,
                0x6e => .decimal,
                0x6f => .divide,
                0x70 => .f1,
                0x71 => .f2,
                0x72 => .f3,
                0x73 => .f4,
                0x74 => .f5,
                0x75 => .f6,
                0x76 => .f7,
                0x77 => .f8,
                0x78 => .f9,
                0x79 => .f10,
                0x7a => .f11,
                0x7b => .f12,
                0x7c => .f13,
                0x7d => .f14,
                0x7e => .f15,
                0x7f => .f16,
                0x80 => .f17,
                0x81 => .f18,
                0x82 => .f19,
                0x83 => .f20,
                0x84 => .f21,
                0x85 => .f22,
                0x86 => .f23,
                0x87 => .f24,
                0x90 => .num_lock,
                0x91 => .scroll,
                0xa6 => .browser_back,
                0xa7 => .browser_forward,
                0xa8 => .browser_refresh,
                0xa9 => .browser_stop,
                0xaa => .browser_search,
                0xab => .browser_favorites,
                0xac => .browser_home,
                0xad => .volume_mute,
                0xae => .volume_down,
                0xaf => .volume_up,
                0xb0 => .media_next_track,
                0xb1 => .media_prev_track,
                0xb2 => .media_stop,
                0xb3 => .media_play_pause,
                0xb4 => .launch_mail,
                0xb5 => .launch_media_select,
                0xb6 => .launch_app1,
                0xb7 => .launch_app2,
                0xdf => .oem_8,
                0xe2 => .oem_102,
                0xe5 => .processkey,
                0xe7 => .packet,
                0xf6 => .attn,
                0xf7 => .crsel,
                0xf8 => .exsel,
                0xf9 => .ereof,
                0xfa => .play,
                0xfb => .zoom,
                0xfc => .noname,
                0xfd => .pa1,
                0xFE => .oem_clear,
                else => null,
            };
        }
    },
    .linux => struct {
        pub fn parseVirtualKey(wparam: usize, lparam: isize) ?VirtualKey {
            _ = wparam;
            _ = lparam;
            @import("std").debug.print("\x1b[33;1mTODO\x1b[0m: Implement linux parseVirtualKey", .{});
            return null;
        }
    },
    else => |tag| @compileError("Unsupported operating system: " ++ @tagName(tag)),
};
