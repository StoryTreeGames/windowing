const std = @import("std");
const uuid = @import("uuid");
const win32 = @import("windows").win32;
const registry = win32.system.registry;

const Color = @import("../root.zig").Color;

pub const HDC = win32.graphics.gdi.HDC;
pub const GetDC = win32.graphics.gdi.GetDC;
pub const GetDeviceCaps = win32.graphics.gdi.GetDeviceCaps;

pub const HWND = win32.foundation.HWND;
pub const HINSTANCE = win32.foundation.HINSTANCE;
pub const RECT = win32.foundation.RECT;
pub const POINT = win32.foundation.POINT;
pub const BOOL = win32.foundation.BOOL;
pub const HRESULT = win32.foundation.HRESULT;

pub const PROPERTYKEY = win32.ui.shell.properties_system.PROPERTYKEY;
pub const IPropertyStore = win32.ui.shell.properties_system.IPropertyStore;
pub const IPropertyDescriptionList = win32.ui.shell.properties_system.IPropertyDescriptionList;
pub const GETPROPERTYSTOREFLAGS = win32.ui.shell.properties_system.GETPROPERTYSTOREFLAGS;
pub const COMDLG_FILTERSPEC = win32.ui.shell.common.COMDLG_FILTERSPEC;

pub const TRUE = win32.zig.TRUE;
pub const FALSE = win32.zig.FALSE;
pub const Guid = win32.zig.Guid;

pub const CoInit = win32.system.com.COINIT;
pub const IBindCtx = win32.system.com.IBindCtx;
pub const IUnknown = win32.system.com.IUnknown;
pub const PROPVARIANT = win32.system.com.structured_storage.PROPVARIANT;
pub const CLSCTX_ALL = win32.system.com.CLSCTX_ALL;
pub const CoInitializeEx = win32.system.com.CoInitializeEx;
pub const CoUninitialize = win32.system.com.CoUninitialize;
pub const CoTaskMemFree = win32.system.com.CoTaskMemFree;
pub const CoCreateInstance = win32.system.com.CoCreateInstance;

pub const CHOOSECOLORA = win32.ui.controls.dialogs.CHOOSECOLORA;
pub const LOGFONTA = win32.graphics.gdi.LOGFONTA;
pub const CHOOSEFONTA = win32.ui.controls.dialogs.CHOOSEFONTA;
pub const CommDlgExtendedError = win32.ui.controls.dialogs.CommDlgExtendedError;
pub const ChooseFontA = win32.ui.controls.dialogs.ChooseFontA;
pub const ChooseColorA = win32.ui.controls.dialogs.ChooseColorA;

pub const Win32Error = std.os.windows.Win32Error;
pub const S_OK: HRESULT = 0;
pub const S_FALSE: HRESULT = 1;
pub const SIGDN_FILESYSPATH: i32 = -2147123200;
pub const SFGAO_FILESYSTEM: i32 = 0x40000000;

pub const CLSID_FileOpenDialog: Guid = .{ .Ints = .{
    .a = 0xdc1c5a9c,
    .b = 0xe88a,
    .c = 0x4dde, 
    .d = .{ 0xa5, 0xa1, 0x60, 0xf8, 0x2a, 0x20, 0xae, 0xf7 }
}};

pub const CLSID_FileSaveDialog: Guid = .{ .Ints = .{
    .a = 0xc0b4e2f3,
    .b = 0xba21,
    .c = 0x4773,
    .d = .{ 0x8d, 0xba, 0x33, 0x5e, 0xc9, 0x46, 0xeb, 0x8b },
}};

pub extern "shell32" fn SHCreateItemFromParsingName(pszPath: [*:0]const u16, pbc: ?*anyopaque, riid: *const Guid, ppv: **anyopaque) HRESULT;
pub extern "shell32" fn SetCurrentProcessExplicitAppUserModelID([*:0]const u16) HRESULT;

pub fn isLightTheme() error{ RegRead, RegNotFound, SystemError }!bool {
    var data_type: u32 = 0;
    var data: [4:0]u8 = [_:0]u8{0} ** 4;
    var length: u32 = 4;

    const code = registry.RegGetValueA(
        registry.HKEY_CURRENT_USER,
        "Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
        "AppsUseLightTheme",
        registry.RRF_RT_REG_DWORD,
        &data_type,
        @ptrCast(@alignCast(&data)),
        &length,
    );

    switch (code) {
        .NO_ERROR => return data[0] == 1,
        .ERROR_MORE_DATA => return error.RegRead,
        .ERROR_FILE_NOT_FOUND => return error.RegNotFound,
        else => return error.SystemError,
    }
}

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
    const uid = uuid.urn.serialize(uuid.v4.new());
    const temp = try std.fmt.allocPrint(allocator, "STC-{s}", .{uid});
    defer allocator.free(temp);

    return try utf8ToUtf16Alloc(allocator, temp);
}

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

pub const FDE_RESPONSE = enum(u16) {
  DEFAULT = 0,
  ACCEPT = 1,
  REFUSE = 2
};

pub const FDAP = enum(u16) {
  BOTTOM = 0,
  TOP = 1
};

pub const SHCONTF = enum(u32) {
  CHECKING_FOR_CHILDREN = 0x10,
  FOLDERS = 0x20,
  NONFOLDERS = 0x40,
  INCLUDEHIDDEN = 0x80,
  INIT_ON_FIRST_NEXT = 0x100,
  NETPRINTERSRCH = 0x200,
  SHAREABLE = 0x400,
  STORAGE = 0x800,
  NAVIGATION_ENUM = 0x1000,
  FASTITEMS = 0x2000,
  FLATLIST = 0x4000,
  ENABLE_ASYNC = 0x8000,
  INCLUDESUPERHIDDEN = 0x10000
};

pub const SIGDN = enum(i32) {
    NORMALDISPLAY = 0,
    PARENTRELATIVEPARSING = -2147385343,
    DESKTOPABSOLUTEPARSING = -2147319808,
    PARENTRELATIVEEDITING = -2147282943,
    DESKTOPABSOLUTEEDITING = -2147172352,
    FILESYSPATH = -2147123200,
    URL = -2147057664,
    PARENTRELATIVEFORADDRESSBAR = -2146975743,
    PARENTRELATIVE = -2146959359,
    PARENTRELATIVEFORUI = -2146877439,
};

pub const SICHINTF = enum(u32) {
  DISPLAY = 0,
  ALLFIELDS = 1,
  CANONICAL = 0x10000000,
  TEST_FILESYSPATH_IF_NOT_EQUAL = 0x20000000
};

pub const SIATTRIBFLAGS = enum(u16) {
    AND = 1,
    OR = 2,
    MASK = 3,
    ALLITEMS = 16384,
};


pub const SFGAO = packed struct(u32) {
    pub const CAPABILITYMASK: @This() = .{
        .CANCOPY = true,
        .CANMOVE = true,
        .CANLINK = true,
        .CANRENAME = true,
        .CANDELETE = true,
        .HASPROPSHEET = true,
        .DROPTARGET = true
    };
    pub const CONTENTSMASK: @This() = .{ .HASSUBFOLDER = true };
    pub const STORAGECAPMASK: @This() =  .{
        .STORAGE = true,
        .LINK = true,
        .READONLY = true,
        .STREAM = true,
        .STORAGEANCESTOR = true,
        .FILESYSANCESTOR = true,
        .FOLDER = true,
        .FILESYSTEM = true
    };
    pub const PKEYSFGAOMASK: @This() = .{
        .ISSLOW = true,
        .READONLY = true,
        .HASSUBFOLDER = true,
        .VALIDATE = true,
    };

    CANCOPY: bool = false,
    CANMOVE: bool = false,
    CANLINK: bool = false,
    STORAGE: bool = false,
    CANRENAME: bool = false,
    CANDELETE: bool = false,
    HASPROPSHEET: bool = false,
    _1: u1 = 0,
    DROPTARGET: bool = false,
    _2: u3 = 0,
    SYSTEM: bool = false,
    ENCRYPTED: bool = false,
    ISSLOW: bool = false,
    GHOSTED: bool = false,
    LINK: bool = false,
    SHARE: bool = false,
    READONLY: bool = false,
    HIDDEN: bool = false,
    NONENUMERATED: bool = false,
    NEWCONTENT: bool = false,
    STREAM: bool = false,
    STORAGEANCESTOR: bool = false,
    VALIDATE: bool = false,
    REMOVABLE: bool = false,
    COMPRESSED: bool = false,
    BROWSABLE: bool = false,
    FILESYSANCESTOR: bool = false,
    FOLDER: bool = false,
    FILESYSTEM: bool = false,
    HASSUBFOLDER: bool = false,
};

const FOS = packed struct(u32) {
    _1: u1 = 0,
    OVERWRITEPROMPT: bool = false,
    STRICTFILETYPES: bool = false, 
    NOCHANGEDIR: bool = false,
    _2: u1 = 0,
    PICKFOLDERS: bool = false,
    FORCEFILESYSTEM: bool = false,
    ALLNONSTORAGEITEMS: bool = false,
    NOVALIDATE: bool = false,
    ALLOWMULTISELECT: bool = false,
    _3: u1 = 0,
    PATHMUSTEXIST: bool = false,
    FILEMUSTEXIST: bool = false,
    CREATEPROMPT: bool = false,
    SHAREAWARE: bool = false,
    NOREADONLYRETURN: bool = false,
    NOTESTFILECREATE: bool = false,
    HIDEMRUPLACES: bool = false,
    HIDEPINNEDPLACES: bool = false,
    _4: u1 = 0,
    NODEREFERENCELINKS: bool = false,
    OKBUTTONNEEDSINTERACTION: bool = false,
    _5: u3 = 0,
    DONTADDTORECENT: bool = false,
    _6: u2 = 0,
    FORCESHOWHIDDEN: bool = false,
    DEFAULTNOMINIMODE: bool = false,
    FORCEPREVIEWPANEON: bool = false,
    SUPPORTSTREAMABLEITEMS: bool = false
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

pub const IFileDialogEvents = extern struct {
    pub const VTable = extern struct {
        QueryInterface: *const fn (*IFileDialogEvents, *const Guid, *?*anyopaque) callconv(.c) HRESULT,
        AddRef: *const fn (*IFileDialogEvents) callconv(.c) u32,
        Release: *const fn (*IFileDialogEvents) callconv(.c) u32,
        OnFileOk: *const fn (*IFileDialogEvents, *IFileDialog) callconv(.c) HRESULT,
        OnFolderChanging: *const fn (*IFileDialogEvents, *IFileDialog, *IShellItem) callconv(.c) HRESULT,
        OnFolderChange: *const fn (*IFileDialogEvents, *IFileDialog) callconv(.c) HRESULT,
        OnSelectionChange: *const fn (*IFileDialogEvents, *IFileDialog) callconv(.c) HRESULT,
        OnShareViolation: *const fn (*IFileDialogEvents, *IFileDialog, *IShellItem, *FDE_RESPONSE) callconv(.c) HRESULT,
        OnTypeChange: *const fn (*IFileDialogEvents, *IFileDialog) callconv(.c) HRESULT,
        OnOverwrite: *const fn (*IFileDialogEvents, *IFileDialog, *IShellItem, *FDE_RESPONSE) callconv(.c) HRESULT,
    };

    vtable: *const VTable,
};

pub const IFileOperationProgressSink = extern struct {
    pub const VTable = extern struct {
        base: IUnknown.VTable,
        StartOperations: *const fn (*IFileOperationProgressSink) callconv(.c) HRESULT,
        FinishOperations: *const fn (*IFileOperationProgressSink, HRESULT) callconv(.c) HRESULT,
        PreRenameItem: *const fn (*IFileOperationProgressSink, u32, *IShellItem, [*:0]const u16) callconv(.c) HRESULT,
        PostRenameItem: *const fn (*IFileOperationProgressSink, u32, *IShellItem, [*:0]const u16, HRESULT, *IShellItem) callconv(.c) HRESULT,
        PreMoveItem: *const fn (*IFileOperationProgressSink, u32, *IShellItem, *IShellItem, [*:0]const u16) callconv(.c) HRESULT,
        PostMoveItem: *const fn (*IFileOperationProgressSink, u32, *IShellItem, *IShellItem, [*:0]const u16, HRESULT, *IShellItem) callconv(.c) HRESULT,
        PreCopyItem: *const fn (*IFileOperationProgressSink, u32, *IShellItem, *IShellItem, [*:0]const u16) callconv(.c) HRESULT,
        PostCopyItem: *const fn (*IFileOperationProgressSink, u32, *IShellItem, *IShellItem, [*:0]const u16, HRESULT, *IShellItem) callconv(.c) HRESULT,
        PreDeleteItem: *const fn (*IFileOperationProgressSink, u32, *IShellItem) callconv(.c) HRESULT,
        PostDeleteItem: *const fn (*IFileOperationProgressSink, u32, *IShellItem, HRESULT, *IShellItem) callconv(.c) HRESULT,
        PreNewItem: *const fn (*IFileOperationProgressSink, u32, *IShellItem, [*:0]const u16) callconv(.c) HRESULT,
        PostNewItem: *const fn (*IFileOperationProgressSink, u32, *IShellItem, [*:0]const u16, [*:0]const u16, u32, HRESULT, *IShellItem) callconv(.c) HRESULT,
        UpdateProgress: *const fn (*IFileOperationProgressSink, u16, u16) callconv(.c) HRESULT,
        ResetTimer: *const fn (*IFileOperationProgressSink) callconv(.c) HRESULT,
        PauseTimer: *const fn (*IFileOperationProgressSink) callconv(.c) HRESULT,
        ResumeTimer: *const fn (*IFileOperationProgressSink) callconv(.c) HRESULT,
    };
    vtable: *const VTable,
};

pub const IModalWindow = extern struct {
    pub const VTable = extern struct {
        base: IUnknown.VTable,
        Show: *const fn (*IModalWindow, ?HWND) callconv(.c) HRESULT,
    };
    vtable: *const VTable,

    pub fn show(self: *@This(), hwnd: ?HWND) !void {
        const result = self.vtable.Show(self, hwnd);
        if (result == S_OK) return;

        switch (std.os.windows.HRESULT_CODE(result)) {
            .CANCELLED => return error.UserCancelled,
            else => return error.UnknownError,
        }
    }
};

pub const IFileDialog = extern struct {
    pub const VTable = extern struct {
        base: IModalWindow.VTable,
        SetFileTypes: *const fn (*IFileDialog, u16, [*]const COMDLG_FILTERSPEC) callconv(.c) HRESULT,
        SetFileTypeIndex: *const fn (*IFileDialog, u16) callconv(.c) HRESULT,
        GetFileTypeIndex: *const fn (*IFileDialog, *u16) callconv(.c) HRESULT,
        Advise: *const fn (*IFileDialog, *IFileDialogEvents, *u32) callconv(.c) HRESULT,
        Unadvise: *const fn (*IFileDialog, u32) callconv(.c) HRESULT,
        SetOptions: *const fn (*IFileDialog, FOS) callconv(.c) HRESULT,
        GetOptions: *const fn (*IFileDialog, *FOS) callconv(.c) HRESULT,
        SetDefaultFolder: *const fn (*IFileDialog, *IShellItem) callconv(.c) HRESULT,
        SetFolder: *const fn (*IFileDialog, *IShellItem) callconv(.c) HRESULT,
        GetFolder: *const fn (*IFileDialog, **IShellItem) callconv(.c) HRESULT,
        GetCurrentSelection: *const fn (*IFileDialog, **IShellItem) callconv(.c) HRESULT,
        SetFileName: *const fn (*IFileDialog, [*:0]const u16) callconv(.c) HRESULT,
        GetFileName: *const fn (*IFileDialog, *[*:0]const u16) callconv(.c) HRESULT,
        SetTitle: *const fn (*IFileDialog, [*:0]const u16) callconv(.c) HRESULT,
        SetOkButtonLabel: *const fn (*IFileDialog, [*:0]const u16) callconv(.c) HRESULT,
        SetFileNameLabel: *const fn (*IFileDialog, [*:0]const u16) callconv(.c) HRESULT,
        GetResult: *const fn (*IFileDialog, **IShellItem) callconv(.c) HRESULT,
        AddPlace: *const fn (*IFileDialog, *IShellItem, FDAP) callconv(.c) HRESULT,
        SetDefaultExtension: *const fn (*IFileDialog, [*:0]const u16) callconv(.c) HRESULT,
        Close: *const fn (*IFileDialog, HRESULT) callconv(.c) HRESULT,
        SetClientGuid: *const fn (*IFileDialog, *const Guid) callconv(.c) HRESULT,
        ClearClientData: *const fn (*IFileDialog) callconv(.c) HRESULT,
        SetFilter: *const fn (*IFileDialog, *IShellItemFilter) callconv(.c) HRESULT,
    };
    vtable: *const VTable,
    IModalWindow: IModalWindow,

    pub fn setFolder(self: *@This(), item: *IShellItem) !void {
        const result = self.vtable.SetFolder(self, item);
        if (result != S_OK) return error.UknownError;
    }

    pub fn setFileName(self: *@This(), path: [*:0]const u16) !void {
        const result = self.vtable.SetFileName(self, path);
        if (result != S_OK) return error.UknownError;
    }

    pub fn setFileTypes(self: *@This(), filters: []const COMDLG_FILTERSPEC) !void {
        const result = self.vtable.SetFileTypes(self, @intCast(filters.len), filters.ptr);
        if (result != S_OK) return error.UknownError;
    }

    pub fn setTitle(self: *@This(), title: [*:0]const u16) !void {
        const result = self.vtable.SetTitle(self, title);
        if (result != S_OK) return error.UknownError;
    }

    pub fn getOptions(self: *@This()) !FOS {
        var options: FOS = .{};
        const result = self.vtable.GetOptions(self, &options);
        if (result != S_OK) return error.UknownError;
        return options;
    }

    pub fn setOptions(self: *@This(), options: FOS) !void {
        const result = self.vtable.SetOptions(self, options);
        if (result != S_OK) return error.UnknownError;
    }

    pub fn getResult(self: *@This()) !*IShellItem {
        var item: *IShellItem = undefined;
        const result = self.vtable.GetResult(self, &item);
        if (result != S_OK) return error.UnknownError;
        return item;
    }

    pub fn getSelectedItem(self: *@This()) !*IShellItem {
        var item: *IShellItem = undefined;
        const result = self.vtable.GetCurrentSelection(self, &item);
        if (result != S_OK) return error.UnknownError;
        return item;
    }
};

pub const IFileOpenDialog = extern struct {
    pub const VTable = extern struct {
        base: IFileDialog.VTable,
        GetResults: *const fn (*IFileOpenDialog, **IShellItemArray) callconv(.c) HRESULT,
        GetSelectedItems: *const fn (*IFileOpenDialog, **IShellItemArray) callconv(.c) HRESULT,
    };

    pub const UUID: Guid = .{ .Ints = .{
        .a = 0xd57c7288,
        .b = 0xd4ad,
        .c = 0x4768,
        .d = .{ 0xbe, 0x02, 0x9d, 0x96, 0x95, 0x32, 0xd9, 0x60 },
    }};

    vtable: *const VTable,

    pub fn setFolder(self: *@This(), item: *IShellItem) !void {
        const this: *IFileDialog = @ptrCast(@alignCast(self));
        try this.setFolder(item);
    }

    pub fn setFileName(self: *@This(), path: [*:0]const u16) !void {
        const this: *IFileDialog = @ptrCast(@alignCast(self));
        try this.setFileName(path);
    }

    pub fn setFileTypes(self: *@This(), filters: []const COMDLG_FILTERSPEC) !void {
        const this: *IFileDialog = @ptrCast(@alignCast(self));
        try this.setFileTypes(filters);
    }

    pub fn setTitle(self: *@This(), title: [*:0]const u16) !void {
        const this: *IFileDialog = @ptrCast(@alignCast(self));
        try this.setTitle(title);
    }

    pub fn getOptions(self: *@This()) !FOS {
        const this: *IFileDialog = @ptrCast(@alignCast(self));
        return try this.getOptions();
    }

    pub fn setOptions(self: *@This(), options: FOS) !void {
        const this: *IFileDialog = @ptrCast(@alignCast(self));
        try this.setOptions(options);
    }

    pub fn show(self: *@This(), hwnd: ?HWND) !void {
        const this: *IModalWindow = @ptrCast(@alignCast(self));
        try this.show(hwnd);
    }

    pub fn getResults(self: *@This()) !*IShellItemArray {
        var items: *IShellItemArray = undefined;
        const result = self.vtable.GetResults(self, &items);
        if (result != S_OK) return error.UnknownError;
        return items;
    }

    pub fn getSelectedItems(self: *@This()) !*IShellItemArray {
        var items: *IShellItemArray = undefined;
        const result = self.vtable.GetSelectedItems(self, &items);
        if (result != S_OK) return error.UnknownError;
        return items;
    }
};

pub const IFileSaveDialog = extern struct {
    const VTable = extern struct {
        base: IFileDialog.VTable,
        SetSaveAsItem: *const fn (*IFileSaveDialog, *IShellItem) callconv(.c) HRESULT,
        SetProperties: *const fn (*IFileSaveDialog, *IPropertyStore) callconv(.c) HRESULT,
        SetCollectedProperties: *const fn (*IFileSaveDialog, *IPropertyDescriptionList, i16) callconv(.c) HRESULT,
        GetProperties: *const fn (*IFileSaveDialog, **IPropertyStore) callconv(.c) HRESULT,
        ApplyProperties: *const fn (*IFileSaveDialog, *IShellItem, *IPropertyStore, ?HWND, *IFileOperationProgressSink) callconv(.c) HRESULT,
    };

    pub const UUID: Guid = .{ .Ints = .{
        .a = 0x84bccd23,
        .b = 0x5fde,
        .c = 0x4cdb,
        .d = .{ 0xae, 0xa4, 0xaf, 0x64, 0xb8, 0x3d, 0x78, 0xab }
    }};

    vtable: *const VTable,

    pub fn setFolder(self: *@This(), item: *IShellItem) !void {
        const this: *IFileDialog = @ptrCast(@alignCast(self));
        try this.setFolder(item);
    }

    pub fn setFileName(self: *@This(), path: [*:0]const u16) !void {
        const this: *IFileDialog = @ptrCast(@alignCast(self));
        try this.setFileName(path);
    }

    pub fn setFileTypes(self: *@This(), filters: []const COMDLG_FILTERSPEC) !void {
        const this: *IFileDialog = @ptrCast(@alignCast(self));
        try this.setFileTypes(filters);
    }

    pub fn setTitle(self: *@This(), title: [*:0]const u16) !void {
        const this: *IFileDialog = @ptrCast(@alignCast(self));
        try this.setTitle(title);
    }

    pub fn getOptions(self: *@This()) !FOS {
        const this: *IFileDialog = @ptrCast(@alignCast(self));
        return try this.getOptions();
    }

    pub fn setOptions(self: *@This(), options: FOS) !void {
        const this: *IFileDialog = @ptrCast(@alignCast(self));
        try this.setOptions(options);
    }

    pub fn show(self: *@This(), hwnd: ?HWND) !void {
        const this: *IModalWindow = @ptrCast(@alignCast(self));
        try this.show(hwnd);
    }

    pub fn getResult(self: *@This()) !*IShellItem {
        const this: *IFileDialog = @ptrCast(@alignCast(self));
        return try this.getResult();
    }

    pub fn getSelectedItem(self: *@This()) !*IShellItem {
        const this: *IFileDialog = @ptrCast(@alignCast(self));
        return try this.getSelectedItem();
    }
};

pub const IShellItem = extern struct {
    pub const VTable = extern struct {
        base: IUnknown.VTable,
        BindToHandler: *const fn (*IShellItem, *IBindCtx, *const Guid, *const Guid, *?*anyopaque) callconv(.c) HRESULT,
        GetParent: *const fn (*IShellItem, **IShellItem) callconv(.c) HRESULT,
        GetDisplayName: *const fn (*IShellItem, SIGDN, *[*:0]const u16) callconv(.c) HRESULT,
        GetAttributes: *const fn (*IShellItem, SFGAO, *SFGAO) callconv(.c) HRESULT,
        Compare: *const fn (*IShellItem, *IShellItem, SICHINTF, *c_int) callconv(.c) HRESULT,
    };

    pub const UUID: Guid = .{ .Ints = .{
        .a = 0x43826d1e,
        .b = 0xe718,
        .c = 0x42ee,
        .d = .{ 0xbc, 0x55, 0xa1, 0xe2, 0x61, 0xc3, 0x7b, 0xfe },
    }};

    vtable: *const VTable,

    pub fn getParent(self: *@This()) !?*IShellItem {
        var parent: *IShellItem = undefined;
        const result = self.vtable.GetParent(self, &parent);
        if (result != S_OK) return null;
        return parent;
    }

    pub fn getDisplayName(self: *@This(), sig: SIGDN) ![*:0]const u16 {
        var display_name: [*:0]const u16 = undefined;
        const result = self.vtable.GetDisplayName(self, sig, &display_name);
        if (result != S_OK) return error.UnknownError;
        return display_name;
    }

    pub fn getAttributes(self: *@This(), in: SFGAO) !SFGAO {
        var attrs: SFGAO = .{};
        const result = self.vtable.GetAttributes(self, in, &attrs);
        if (result != S_OK) return error.UnknownError;
        return attrs;
    }

    pub fn release(self: *@This()) u32 {
        var this: *IUnknown = @ptrCast(@alignCast(self));
        return this.Release();
    }
};

pub const IShellItemFilter = extern struct {
    pub const VTable = extern struct {
        base: IUnknown.VTable,
        IncludeItem: *const fn (*IShellItemFilter, *IShellItem) callconv(.c) HRESULT,
        GetEnumFlagsForItem: *const fn (*IShellItemFilter, *IShellItem, *SHCONTF) callconv(.c) HRESULT,
    };
    vtable: *const VTable,
};

pub const IEnumShellItems = extern struct {
    pub const VTable = extern struct {
        base: IUnknown.VTable,
        Next: *const fn (*IEnumShellItems, u32, **IShellItem, *u32) callconv(.c) HRESULT,
        Skip: *const fn (*IEnumShellItems, u32) callconv(.c) HRESULT,
        Reset: *const fn (*IEnumShellItems) callconv(.c) HRESULT,
        Clone: *const fn (*IEnumShellItems, **IEnumShellItems) callconv(.c) HRESULT,
    };

    vtable: *const VTable,
};

pub const IShellItemArray = extern struct {
    pub const VTable = extern struct {
        base: IUnknown.VTable,
        BindToHandler: *const fn (*IShellItemArray, *IBindCtx, *const Guid, *const Guid, *?*anyopaque) callconv(.c) HRESULT,
        GetPropertyStore: *const fn (*IShellItemArray, GETPROPERTYSTOREFLAGS, *const Guid, *?*anyopaque) callconv(.c) HRESULT,
        GetPropertyDescriptionList: *const fn (*IShellItemArray, *const PROPERTYKEY, *const Guid, *?*anyopaque) callconv(.c) HRESULT,
        GetAttributes: *const fn (*IShellItemArray, SIATTRIBFLAGS, SFGAO, *SFGAO) callconv(.c) HRESULT,
        GetCount: *const fn (*IShellItemArray, *u32) callconv(.c) HRESULT,
        GetItemAt: *const fn (*IShellItemArray, u32, **IShellItem) callconv(.c) HRESULT,
        EnumItems: *const fn (*IShellItemArray, **IEnumShellItems) callconv(.c) HRESULT,
    };

    vtable: *const VTable,

    pub fn getItemAt(self: *@This(), index: usize) !*IShellItem {
        var item: *IShellItem = undefined;
        const result = self.vtable.GetItemAt(self, @intCast(index), &item);
        if (result != S_OK) {
            return error.UnknownError;
        }
        return item;
    }

    pub fn getCount(self: *@This()) !usize {
        var count: u32 = 0;
        const result = self.vtable.GetCount(self, &count);
        if (result != S_OK) return error.UnknownError;
        return @intCast(count);
    }
};
