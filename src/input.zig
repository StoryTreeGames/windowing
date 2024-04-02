/// Keyboard key to keycode mapping
pub const KeyCode = enum(u32) {
    /// backspace key
    back = 0x08,
    /// tab key
    tab = 0x09,
    /// clear key
    clear = 0x0c,
    /// enter key
    @"return" = 0x0d,
    /// shift key
    shift = 0x10,
    /// ctrl key
    control = 0x11,
    /// alt key
    menu = 0x12,
    /// pause key
    pause = 0x13,
    /// caps lock key
    capital = 0x14,
    /// ime kana mode
    // kana = 0x15,
    /// ime hangul mode
    hangul = 0x15,
    /// ime on
    ime_on = 0x16,
    /// ime junja mode
    junja = 0x17,
    /// ime final mode
    final = 0x18,
    /// ime hanja mode
    // hanja = 0x19,
    /// ime kanji mode
    kanji = 0x19,
    /// ime off
    ime_off = 0x1a,
    /// esc key
    escape = 0x1b,
    /// ime convert
    convert = 0x1c,
    /// ime nonconvert
    nonconvert = 0x1d,
    /// ime accept
    accept = 0x1e,
    /// ime mode change request
    modechange = 0x1f,
    /// spacebar
    space = 0x20,
    /// page up key
    prior = 0x21,
    /// page down key
    next = 0x22,
    /// end key
    end = 0x23,
    /// home key
    home = 0x24,
    /// left arrow key
    left = 0x25,
    /// up arrow key
    up = 0x26,
    /// right arrow key
    right = 0x27,
    /// down arrow key
    down = 0x28,
    /// select key
    select = 0x29,
    /// print key
    print = 0x2a,
    /// execute key
    execute = 0x2b,
    /// print screen key
    snapshot = 0x2c,
    /// ins key
    insert = 0x2d,
    /// del key
    delete = 0x2e,
    /// help key
    help = 0x2f,
    /// 0 key
    @"0" = 0x30,
    /// 1 key
    @"1" = 0x31,
    /// 2 key
    @"2" = 0x32,
    /// 3 key
    @"3" = 0x33,
    /// 4 key
    @"4" = 0x34,
    /// 5 key
    @"5" = 0x35,
    /// 6 key
    @"6" = 0x36,
    /// 7 key
    @"7" = 0x37,
    /// 8 key
    @"8" = 0x38,
    /// 9 key
    @"9" = 0x39,
    /// a key
    a = 0x41,
    /// b key
    b = 0x42,
    /// c key
    c = 0x43,
    /// d key
    d = 0x44,
    /// e key
    e = 0x45,
    /// f key
    f = 0x46,
    /// g key
    g = 0x47,
    /// h key
    h = 0x48,
    /// i key
    i = 0x49,
    /// j key
    j = 0x4a,
    /// k key
    k = 0x4b,
    /// l key
    l = 0x4c,
    /// m key
    m = 0x4d,
    /// n key
    n = 0x4e,
    /// o key
    o = 0x4f,
    /// p key
    p = 0x50,
    /// q key
    q = 0x51,
    /// r key
    r = 0x52,
    /// s key
    s = 0x53,
    /// t key
    t = 0x54,
    /// u key
    u = 0x55,
    /// v key
    v = 0x56,
    /// w key
    w = 0x57,
    /// x key
    x = 0x58,
    /// y key
    y = 0x59,
    /// z key
    z = 0x5a,
    /// left windows key
    lsuper = 0x5b,
    /// right windows key
    rsuper = 0x5c,
    /// applications key
    apps = 0x5d,
    /// computer sleep key
    sleep = 0x5f,
    /// numeric keypad 0 key
    numpad0 = 0x60,
    /// numeric keypad 1 key
    numpad1 = 0x61,
    /// numeric keypad 2 key
    numpad2 = 0x62,
    /// numeric keypad 3 key
    numpad3 = 0x63,
    /// numeric keypad 4 key
    numpad4 = 0x64,
    /// numeric keypad 5 key
    numpad5 = 0x65,
    /// numeric keypad 6 key
    numpad6 = 0x66,
    /// numeric keypad 7 key
    numpad7 = 0x67,
    /// numeric keypad 8 key
    numpad8 = 0x68,
    /// numeric keypad 9 key
    numpad9 = 0x69,
    /// multiply key
    multiply = 0x6a,
    /// add key
    add = 0x6b,
    /// separator key
    separator = 0x6c,
    /// subtract key
    subtract = 0x6d,
    /// decimal key
    decimal = 0x6e,
    /// divide key
    divide = 0x6f,
    /// f1 key
    f1 = 0x70,
    /// f2 key
    f2 = 0x71,
    /// f3 key
    f3 = 0x72,
    /// f4 key
    f4 = 0x73,
    /// f5 key
    f5 = 0x74,
    /// f6 key
    f6 = 0x75,
    /// f7 key
    f7 = 0x76,
    /// f8 key
    f8 = 0x77,
    /// f9 key
    f9 = 0x78,
    /// f10 key
    f10 = 0x79,
    /// f11 key
    f11 = 0x7a,
    /// f12 key
    f12 = 0x7b,
    /// f13 key
    f13 = 0x7c,
    /// f14 key
    f14 = 0x7d,
    /// f15 key
    f15 = 0x7e,
    /// f16 key
    f16 = 0x7f,
    /// f17 key
    f17 = 0x80,
    /// f18 key
    f18 = 0x81,
    /// f19 key
    f19 = 0x82,
    /// f20 key
    f20 = 0x83,
    /// f21 key
    f21 = 0x84,
    /// f22 key
    f22 = 0x85,
    /// f23 key
    f23 = 0x86,
    /// f24 key
    f24 = 0x87,
    /// num lock key
    numlock = 0x90,
    /// scroll lock key
    scroll = 0x91,
    /// left shift key
    lshift = 0xa0,
    /// right shift key
    rshift = 0xa1,
    /// left control key
    lcontrol = 0xa2,
    /// right control key
    rcontrol = 0xa3,
    /// left alt key
    lmenu = 0xa4,
    /// right alt key
    rmenu = 0xa5,
    /// browser back key
    browser_back = 0xa6,
    /// browser forward key
    browser_forward = 0xa7,
    /// browser refresh key
    browser_refresh = 0xa8,
    /// browser stop key
    browser_stop = 0xa9,
    /// browser search key
    browser_search = 0xaa,
    /// browser favorites key
    browser_favorites = 0xab,
    /// browser start and home key
    browser_home = 0xac,
    /// volume mute key
    volume_mute = 0xad,
    /// volume down key
    volume_down = 0xae,
    /// volume up key
    volume_up = 0xaf,
    /// next track key
    media_next_track = 0xb0,
    /// previous track key
    media_prev_track = 0xb1,
    /// stop media key
    media_stop = 0xb2,
    /// play/pause media key
    media_play_pause = 0xb3,
    /// start mail key
    launch_mail = 0xb4,
    /// select media key
    launch_media_select = 0xb5,
    /// start application 1 key
    launch_app1 = 0xb6,
    /// start application 2 key
    launch_app2 = 0xb7,
    /// used for miscellaneous characters; it can vary by keyboard. for the us standard keyboard, the ;: key
    colon = 0xba,
    /// for any country/region, the + key
    plus = 0xbb,
    /// for any country/region, the , key
    comma = 0xbc,
    /// for any country/region, the - key
    minus = 0xbd,
    /// for any country/region, the . key
    period = 0xbe,
    /// used for miscellaneous characters; it can vary by keyboard. for the us standard keyboard, the /? key
    slash = 0xbf,
    /// used for miscellaneous characters; it can vary by keyboard. for the us standard keyboard, the `~ key
    tilde = 0xc0,
    /// used for miscellaneous characters; it can vary by keyboard. for the us standard keyboard, the [{ key
    lbracket = 0xdb,
    /// used for miscellaneous characters; it can vary by keyboard. for the us standard keyboard, the \\| key
    backslash = 0xdc,
    /// used for miscellaneous characters; it can vary by keyboard. for the us standard keyboard, the ]} key
    rbracket = 0xdd,
    /// used for miscellaneous characters; it can vary by keyboard. for the us standard keyboard, the '" key
    quote = 0xde,
    /// used for miscellaneous characters; it can vary by keyboard.
    oem_8 = 0xdf,
    /// the <> keys on the us standard keyboard, or the \\| key on the non-us 102-key keyboard
    oem_102 = 0xe2,
    /// ime process key
    processkey = 0xe5,
    /// used to pass unicode characters as if they were keystrokes. the packet key is the low word of a 32-bit virtual key value used for non-keyboard input methods. for more information, see remark in keybdinput, sendinput, wm_keydown, and wm_keyup
    packet = 0xe7,
    /// attn key
    attn = 0xf6,
    /// crsel key
    crsel = 0xf7,
    /// exsel key
    exsel = 0xf8,
    /// erase eof key
    ereof = 0xf9,
    /// play key
    play = 0xfa,
    /// zoom key
    zoom = 0xfb,
    /// reserved
    noname = 0xfc,
    /// pa1 key
    pa1 = 0xfd,
    /// clear key
    oem_clear = 0xFE,
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
