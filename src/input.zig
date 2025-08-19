pub const Key = union(enum) {
    virtual: VirtualKey,
    char: [4]u8,

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
