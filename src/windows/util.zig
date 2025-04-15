const std = @import("std");
const uuid = @import("uuid");
const Color = @import("../root.zig").Color;

pub const shobjidl = @cImport({
    @cInclude("shobjidl.h");
});
pub const combaseapi = @cImport({
    @cInclude("combaseapi.h");
});

pub const HWND = @import("win32").foundation.HWND;
pub const HDC = @import("win32").graphics.gdi.HDC;
pub const GetDeviceCaps = @import("win32").graphics.gdi.GetDeviceCaps;
pub const GetDC = @import("win32").graphics.gdi.GetDC;
pub const HINSTANCE = @import("win32").foundation.HINSTANCE;
pub const BOOL = @import("win32").foundation.BOOL;
pub const TRUE = @import("win32").zig.TRUE;
pub const FALSE = @import("win32").zig.FALSE;
pub const HRESULT = @import("win32").foundation.HRESULT;
pub const Win32Error = std.os.windows.Win32Error;
pub const S_OK = shobjidl.S_OK;
pub const S_FALSE = shobjidl.S_FALSE;
pub const IUnknown = combaseapi.IUnknown;

pub const CLSCTX_ALL = combaseapi.CLSCTX_ALL;
pub fn CLSID_FileOpenDialog() GUID {
    return GUID.from(shobjidl.CLSID_FileOpenDialog);
}
pub fn CLSID_FileSaveDialog() GUID {
    return GUID.from(shobjidl.CLSID_FileSaveDialog);
}
pub const SIGDN_FILESYSPATH = shobjidl.SIGDN_FILESYSPATH;
pub const IBindCtx = shobjidl.IBindCtx;
pub const SFGAOF = shobjidl.SFGAOF;

pub const COINIT_APARTMENTTHREADED: u32 = 0x2;
pub const COINIT_DISABLE_OLE1DDE: u32 = 0x4;
pub const COINIT_MULTITHREADED: u32 = 0x0;
pub const COINIT_SPEED_OVER_MEMORY: u32 = 0x8;

pub const SFGAO_FILESYSTEM: u32 = shobjidl.SFGAO_FILESYSTEM;

const FOS = packed struct(u32) {
    _1: u1 = 0,
    overwrite_prompt: bool = false,
    strict_file_types: bool = false, 
    no_change_dir: bool = false,
    _2: u1 = 0,
    pick_folders: bool = false,
    force_filesystem: bool = false,
    all_non_storage_items: bool = false,
    no_validate: bool = false,
    allow_multi_select: bool = false,
    _3: u1 = 0,
    path_must_exist: bool = false,
    file_must_exist: bool = false,
    create_prompt: bool = false,
    share_aware: bool = false,
    no_readonly_return: bool = false,
    no_test_file_create: bool = false,
    hide_mru_places: bool = false,
    hide_pinned_places: bool = false,
    _4: u1 = 0,
    node_reference_links: bool = false,
    ok_button_needs_interaction: bool = false,
    _5: u3 = 0,
    dont_add_to_recent: bool = false,
    _6: u2 = 0,
    force_show_hidden: bool = false,
    default_no_mini_mode: bool = false,
    force_preview_pane_on: bool = false,
    support_streamable_items: bool = false
};

pub const CoInit = packed struct(u32) {
    _1: u1 = 0,
    apartment_threaded: bool = false,
    disable_ole1dde: bool = false,
    speed_over_memory: bool = false,
    _26: u28 = 0,
};

pub const GUID = extern struct {
    Data1: u32 = std.mem.zeroes(u32),
    Data2: u16 = std.mem.zeroes(u16),
    Data3: u16 = std.mem.zeroes(u16),
    Data4: [8]u8 = std.mem.zeroes([8]u8),

    pub fn from(value: anytype) @This() {
        switch (@TypeOf(value)) {
            shobjidl.GUID => return .{
                .Data1 = value.Data1,
                .Data2 = value.Data2,
                .Data3 = value.Data3,
                .Data4 = value.Data4,
            },
            combaseapi.GUID => return .{
                .Data1 = value.Data1,
                .Data2 = value.Data2,
                .Data3 = value.Data3,
                .Data4 = value.Data4,
            },
            else => @compileError("cannot convert type to GUID")
        }
    }
};

pub const CC = packed struct(u32) {
    rgb_init: bool = false,
    full_open: bool = false,
    prevent_full_open: bool = false,
    show_help: bool = false,
    enable_hook: bool = false,
    enable_template: bool = false,
    enable_template_handle: bool = false,
    solid_color: bool = false,
    any_color: bool = false,
    _m: u23 = 0,
};

pub const CHOOSECOLORA = extern struct {
    lStructSize: u32 = 0,
    hwndOwner: shobjidl.HWND = null,
    hInstance: shobjidl.HWND = null,
    rgbResult: Color = .{},
    lpCustColors: ?[*]Color = null,
    // Flags: u32 = 0,
    Flags: CC = .{},
    lCustData: isize = 0,
    lpfnHook: shobjidl.LPCCHOOKPROC = null,
    lpTemplateName: ?[*]const u8 = null,
};

pub const LOGFONTA = extern struct {
    height: i32 = @import("std").mem.zeroes(i32),
    width: i32 = @import("std").mem.zeroes(i32),
    escapement: i32 = @import("std").mem.zeroes(i32),
    orientation: i32 = @import("std").mem.zeroes(i32),
    weight: i32 = @import("std").mem.zeroes(i32),
    italic: u8 = @import("std").mem.zeroes(u8),
    underline: u8 = @import("std").mem.zeroes(u8),
    strikeout: u8 = @import("std").mem.zeroes(u8),
    charset: CharSet = @import("std").mem.zeroes(CharSet),
    out_precision: OutPrecision = @import("std").mem.zeroes(OutPrecision),
    clip_precision: Clip = @import("std").mem.zeroes(Clip),
    quality: Quality = @import("std").mem.zeroes(Quality),
    pitch_and_family: PitchAndFamily = @import("std").mem.zeroes(PitchAndFamily),
    face_name: [32:0]u8 = @import("std").mem.zeroes([32:0]u8),
};

pub const CharSet = enum(u8) {
    ansi = 0,
    default = 1,
    symbol = 2,
    shiftjis = 128,
    hangeul = 129,
    gb2312 = 134,
    chinesebig5 = 136,
    oem = 255,
    johab = 130,
    hebrew = 177,
    arabic = 178,
    greek = 161,
    turkish = 162,
    vietnamese = 163,
    thai = 222,
    easteurope = 238,
    russian = 204,
    mac = 77,
    baltic = 186,
};

pub const Quality = enum(u8) {
    default = 0,
    draft = 1,
    proof = 2,
    non_antialiased = 3,
    antialiased = 4,
    clear_type = 5,
    clear_type_natural = 6,
};

pub const Pitch = enum(u2) {
    default = 0,
    fixed = 1,
    variable = 2,
};

pub const Family = enum(u6) {
    dont_care = 0,
    roman = 1,
    swiss = 2,
    modern = 3,
    script = 4,
    decorative = 5,
};

pub const OutPrecision = enum(u8) {
    default = 0,
    string = 1,
    stroke = 3,
    tt = 4,
    device = 5,
    raster = 6,
    tt_only = 7,
    outline = 8,
    ps_only = 10,
};

pub const PitchAndFamily = packed struct(u8) {
    pitch: Pitch,
    family: Family
};

/// character  : 0000 0001
/// stroke     : 0000 0010
/// lh_angles  : 0001 0000
/// dfa_disabel: 0100 0000
/// embedded   : 1000 0000
pub const Clip = packed struct(u8) {
    character: bool = false,
    stroke: bool = false,
    _1: u2 = 0,
    lh_angles: bool = false,
    _2: u1 = 0,
    dfa_disable: bool = false,
    embedded: bool = false,
};

pub const CHOOSEFONTA = extern struct {
    lStructSize: u32 = 0,
    hwndOwner: shobjidl.HWND = null,
    hDC: shobjidl.HDC = null,
    lpLogFont: ?*LOGFONTA = null,
    iPointSize: i16 = 0,
    Flags: CF = .{},
    rgbColors: Color = .{},
    lCustData: isize = 0,
    lpfnHook: shobjidl.LPCFHOOKPROC = null,
    lpTemplateName: ?[*:0]const u8 = null,
    hInstance: shobjidl.HINSTANCE = null,
    lpszStyle: ?[*:0]const u8 = null,
    nFontType: u16 = 0,
    ___MISSING_ALIGNMENT__: u16 = 0, 
    nSizeMin: i16 = 0,
    nSizeMax: i16 = 0,
};

pub const FontType = packed struct(u16) {
    _1: u8 = 0,
    bold: bool = false,
    italic: bool = false,
    regular: bool = false,
    _2: u2 = 0,
    screen: bool = false,
    printer: bool = false,
    simulated: bool = false,
};

pub const CF = packed struct(u32) {
    pub const both: @This() = .{ .screen_fonts = true,  .printer_fonts = true };
    pub const scripts_only: @This() = .{ .ansi_only = true };
    pub const no_oemfonts = .{ .no_vector_fonts };

    screen_fonts: bool = false,
    printer_fonts: bool = false,
    show_help: bool = false,
    enable_hook: bool = false,
    enable_template: bool = false,
    enable_template_handle: bool = false,
    init_to_log_font_struct: bool = false,
    use_style: bool = false,
    effects: bool = false,
    apply: bool = false,
    ansi_only: bool = false,
    no_vector_fonts: bool = false,
    no_simulations: bool = false,
    limit_size: bool = false,
    fixed_pitch_only: bool = false,
    wysiwyg: bool = false,
    force_font_exist: bool = false,
    scalable_only: bool = false,
    tt_only: bool = false,
    no_face_sel: bool = false,
    no_style_sel: bool = false,
    no_size_sel: bool = false,
    select_script: bool = false,
    no_script_sel: bool = false,
    no_vert_fonts: bool = false,
    inactive_fonts: bool = false,

    _m: u6 = 0,
};

pub const CDERR = enum(u32) {
    CDERR_DIALOGFAILURE = 0xFFFF,
    CDERR_FINDRESFAILURE = 0x0006,
    CDERR_INITIALIZATION = 0x0002,
    CDERR_LOADRESFAILURE = 0x0007,
    CDERR_LOADSTRFAILURE = 0x0005,
    CDERR_LOCKRESFAILURE = 0x0008,
    CDERR_MEMALLOCFAILURE = 0x0009,
    CDERR_MEMLOCKFAILURE = 0x000A,
    CDERR_NOHINSTANCE = 0x0004,
    CDERR_NOHOOK = 0x000B,
    CDERR_NOTEMPLATE = 0x0003,
    CDERR_REGISTERMSGFAIL = 0x000C,
    CDERR_STRUCTSIZE = 0x0001,
};

pub extern "comdlg32" fn ChooseColorA(*CHOOSECOLORA) BOOL;
pub extern "comdlg32" fn ChooseFontA(*CHOOSEFONTA) BOOL;
pub extern "comdlg32" fn CommDlgExtendedError() u32;
pub extern "shell32" fn SHCreateItemFromParsingName(pszPath: [*]const u16, pbc: ?*opaque{}, riid: *const GUID, ppv: *?*anyopaque) HRESULT;
pub extern "ole32" fn CoCreateInstance(rclsid: *const GUID, pUnkOuter: ?*IUnknown, dwClsContext: u32, riid: *const GUID, ppv: *?*anyopaque) HRESULT;
pub extern "ole32" fn CoInitializeEx(pvReserved: ?*anyopaque, dwCoInit: CoInit) HRESULT;
pub extern "ole32" fn CoTaskMemFree(pv: ?*anyopaque) void;
pub extern "ole32" fn CoUninitialize() void;

/// Allocate a sentinal utf16 string from a utf8 string
pub fn utf8ToUtf16Alloc(allocator: std.mem.Allocator, data: []const u8) ![:0]u16 {
    const len: usize = std.unicode.calcUtf16LeLen(data) catch unreachable;
    var utf16le: [:0]u16 = try allocator.allocSentinel(u16, len, 0);
    const utf16le_len = try std.unicode.utf8ToUtf16Le(utf16le[0..], data[0..]);
    std.debug.assert(len == utf16le_len);
    return utf16le;
}

/// Create/Allocate a unique window class with a uuid v4 prefixed with `STC`
pub fn createUIDClass(allocator: std.mem.Allocator) ![:0]u16 {
    // Size of {3}-{36}{null} == 41
    var buffer = try std.ArrayList(u8).initCapacity(allocator, 40);
    defer buffer.deinit();

    const uid = uuid.urn.serialize(uuid.v4.new());
    try std.fmt.format(buffer.writer(), "STC-{s}", .{uid});

    const temp = try buffer.toOwnedSlice();
    defer allocator.free(temp);

    return try utf8ToUtf16Alloc(allocator, temp);
}

pub fn IFileDialog(D: enum { save, open }) type {
    const T = if (D == .save) shobjidl.IFileSaveDialog else shobjidl.IFileOpenDialog;
    const guid: GUID = if (D == .save) .{
        .Data1 = 0x84bccd23,
        .Data2 = 0x5fde,
        .Data3 = 0x4cdb,
        .Data4 = .{ 0xae, 0xa4, 0xaf, 0x64, 0xb8, 0x3d, 0x78, 0xab }
    }
    else .{
        .Data1 = 0xd57c7288,
        .Data2 = 0xd4ad,
        .Data3 = 0x4768,
        .Data4 = .{ 0xbe, 0x02, 0x9d, 0x96, 0x95, 0x32, 0xd9, 0x60 },
    };

    return struct {
        const Self = @This();

        pub const Vtbl = if (D == .save) 
            shobjidl.struct_IFileSaveDialogVtbl
        else
            shobjidl.struct_IFileOpenDialogVtbl;

        inner: ?*anyopaque = null,

        pub inline fn uuidof() GUID {
            return guid;
        }

        pub fn show(self: *@This(), hwnd: ?HWND) error{UserCancelled,UnknownError}!void {
            if (self.inner) |inner| {
                const i: *T = @ptrCast(@alignCast(inner));
                if (i.lpVtbl.*.Show) |Show| {
                    const result = Show(i, if (hwnd) |h| @ptrCast(@alignCast(h)) else null);
                    if (result == S_OK) return;

                    switch (std.os.windows.HRESULT_CODE(result)) {
                        .CANCELLED => return error.UserCancelled,
                        else => return error.UnknownError,
                    }
                }
            }

            return error.UnknownError;
        }

        pub fn setDefaultExtension(self: *@This(), extension: [*:0]const u16) !void {
            if (self.inner) |inner| {
                const i: *T = @ptrCast(@alignCast(inner));
                if (i.lpVtbl.*.SetDefaultExtension) |SetDefaultExtension| {
                    const result = SetDefaultExtension(i, extension);
                    if (result == S_OK) return;
                    return error.Win32Error;
                    // return std.os.windows.HRESULT_CODE(result);
                }
            }
        }

        pub fn setDefaultFolder(self: *@This(), item: ?*shobjidl.IShellItem) !void {
            if (self.inner) |inner| {
                const i: *T = @ptrCast(@alignCast(inner));
                if (i.lpVtbl.*.SetDefaultFolder) |SetDefaultFolder| {
                    const result = SetDefaultFolder(i, item);
                    if (result == S_OK) return;
                    return error.Win32Error;
                }
            }
        }

        pub fn setFolder(self: *@This(), item: ?*shobjidl.IShellItem) !void {
            if (self.inner) |inner| {
                const i: *T = @ptrCast(@alignCast(inner));
                if (i.lpVtbl.*.SetFolder) |SetFolder| {
                    const result = SetFolder(i, item);
                    if (result == S_OK) return;
                    return error.Win32Error;
                }
            }
        }

        pub fn setFileName(self: *@This(), file_name: [*:0]const u16) !void {
            if (self.inner) |inner| {
                const i: *T = @ptrCast(@alignCast(inner));
                if (i.lpVtbl.*.SetFileName) |SetFileName| {
                    const result = SetFileName(i, file_name);
                    if (result == S_OK) return;
                    return error.Win32Error;
                }
            }
        }

        pub fn setFileNameLabel(self: *@This(), file_name_label: [*:0]const u16) !void {
            if (self.inner) |inner| {
                const i: *T = @ptrCast(@alignCast(inner));
                if (i.lpVtbl.*.SetFileNameLabel) |SetFileNameLabel| {
                    const result = SetFileNameLabel(i, file_name_label);
                    if (result == S_OK) return;
                    return error.Win32Error;
                }
            }
        }

        pub fn setFileTypes(self: *@This(), specs: []const shobjidl.COMDLG_FILTERSPEC) !void {
            if (self.inner) |inner| {
                const i: *T = @ptrCast(@alignCast(inner));
                if (i.lpVtbl.*.SetFileTypes) |SetFileTypes| {
                    const result = SetFileTypes(i, @intCast(specs.len), specs.ptr);
                    if (result == S_OK) return;
                    return error.Win32Error;
                }
            }
        }

        pub fn setFileTypeIndex(self: *@This(), idx: u32) !void {
            if (self.inner) |inner| {
                const i: *T = @ptrCast(@alignCast(inner));
                if (i.lpVtbl.*.SetFileTypeIndex) |SetFileTypeIndex| {
                    const result = SetFileTypeIndex(i, idx);
                    if (result == S_OK) return;
                    return error.Win32Error;
                }
            }
        }

        pub fn setOkButtonLabel(self: *@This(), label: [*:0]const u16) !void {
            if (self.inner) |inner| {
                const i: *T = @ptrCast(@alignCast(inner));
                if (i.lpVtbl.*.SetOkButtonLabel) |SetOkButtonLabel| {
                    const result = SetOkButtonLabel(i, label);
                    if (result == S_OK) return;
                    return error.Win32Error;
                }
            }
        }

        pub fn setTitle(self: *@This(), title: [*:0]const u16) !void {
            if (self.inner) |inner| {
                const i: *T = @ptrCast(@alignCast(inner));
                if (i.lpVtbl.*.SetTitle) |SetTitle| {
                    const result = SetTitle(i, title);
                    if (result == S_OK) return;
                    return error.Win32Error;
                }
            }
        }

        pub fn getOptions(self: *@This()) !FOS {
            if (self.inner) |inner| {
                const i: *T = @ptrCast(@alignCast(inner));
                if (i.lpVtbl.*.GetOptions) |GetOptions| {
                    var options: u32 = 0;
                    const result = GetOptions(i, &options);
                    if (result == S_OK) {
                        return @bitCast(options);
                    }
                    return error.Win32Error;
                }
            }
            return error.NoDialog;
        }

        pub fn setOptions(self: *@This(), options: FOS) !void {
            if (self.inner) |inner| {
                const i: *T = @ptrCast(@alignCast(inner));
                if (i.lpVtbl.*.SetOptions) |SetOptions| {
                    const result = SetOptions(i, @bitCast(options));
                    if (result == S_OK) return;
                    return error.Win32Error;
                }
            }
        }

        pub usingnamespace switch (D) {
            .open => struct {
                pub fn getResults(self: *Self) !IShellItemArray {
                    if (self.inner) |inner| {
                        const i: *shobjidl.IFileOpenDialog = @ptrCast(@alignCast(inner));
                        if (i.lpVtbl.*.GetResults) |GetResults| {
                            var data: ?*shobjidl.IShellItemArray = null;
                            const result = GetResults(i, &data);
                            if (result == S_OK) return IShellItemArray { .inner = data };
                            return error.Win32Error;
                        }
                    }
                    return error.NoDialogFound;
                }
            },
            .save => struct {
                pub fn setSaveAs(self: *Self, path: *shobjidl.IShellItem) !void {
                    if (self.inner) |inner| {
                        const i: *shobjidl.IFileSaveDialog = @ptrCast(@alignCast(inner));
                        if (i.lpVtbl.*.SetSaveAsItem) |SetSaveAsItem| {
                            const result = SetSaveAsItem(i, path);
                            if (result == S_OK) return;
                            return error.Win32Error;
                        }
                    }
                    return error.NoDialogFound;
                }

                pub fn getResult(self: *Self) !?IShellItem {
                    if (self.inner) |inner| {
                        const i: *shobjidl.IFileSaveDialog = @ptrCast(@alignCast(inner));
                        if (i.lpVtbl.*.GetResult) |GetResult| {
                            var item: ?*shobjidl.IShellItem = null;
                            const result = GetResult(i, &item);
                            if (result == S_OK) return IShellItem { .inner = item };
                            return error.Win32Error;
                        }
                    }
                    return error.NoDialogFound;
                }
            }
        };
    };
}

pub const IShellItem = struct {
    inner: ?*shobjidl.IShellItem = null,

    pub inline fn uuidof() GUID { 
        return .{
            .Data1 = 0x43826d1e,
            .Data2 = 0xe718,
            .Data3 = 0x42ee,
            .Data4 = .{ 0xbc, 0x55, 0xa1, 0xe2, 0x61, 0xc3, 0x7b, 0xfe },
        };
    }

    pub fn getAttributes(self: @This(), in: u32) !u32 {
        if (self.inner) |inner| {
            if (inner.lpVtbl.*.GetAttributes) |GetAttributes| {
                var out: u32 = 0;
                const result = GetAttributes(inner, in, &out);
                if (result == S_OK or result == S_FALSE) return out;
                return error.Win32Error;
            }
        }
        return error.NoInnerValue;
    }

    pub fn getDisplayName(self: @This()) !?[*:0]const u16 {
        if (self.inner) |inner| {
            if (inner.lpVtbl.*.GetDisplayName) |GetDisplayName| {
                const gdn: *const fn (?*shobjidl.IShellItem, shobjidl.SIGDN, *?[*:0]const u16) callconv(.c) HRESULT = @ptrCast(GetDisplayName);
                var out: ?[*:0]const u16 = null;

                const result = gdn(inner, shobjidl.SIGDN_FILESYSPATH, &out);
                if (result != S_OK) return error.Win32Error;
                return out;
            }
        }
        return error.NoInnerValue;
    }

    pub fn release(self: @This()) !void {
        if (self.inner) |inner| {
            if (inner.lpVtbl.*.Release) |Release| {
                if (Release(inner) != S_OK) return error.ReleaseShellItem;
            }
        }
    }
};

pub const IShellItemArray = struct {
    inner: ?*shobjidl.IShellItemArray = null,

    pub fn count(self: *const @This()) !usize {
        if (self.inner) |inner| {
            if (inner.lpVtbl.*.GetCount) |GetCount| {
                var c: u32 = 0;
                const response = GetCount(inner, &c);
                if (response == S_OK) return @intCast(c);
                return error.Win32Error;
            }
        }
        return error.NoInnerValue;
    }

    pub fn get(self: *@This(), at: usize) !?IShellItem {
        if (self.inner) |inner| {
            if (inner.lpVtbl.*.GetItemAt) |GetItemAt| {
                var result: ?*shobjidl.IShellItem = null;
                const response = GetItemAt(inner, @intCast(at), &result);
                if (response == S_OK) return if (result) |r| IShellItem { .inner = r } else null;
                return error.Win32Error;
            }
        }
        return error.NoInnerValue;
    }
};
