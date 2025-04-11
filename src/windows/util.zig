const std = @import("std");
const uuid = @import("uuid");

pub const shobjidl = @cImport({
    @cInclude("shobjidl.h");
});
pub const combaseapi = @cImport({
    @cInclude("combaseapi.h");
});

pub const HWND = @import("win32").foundation.HWND;
pub const HRESULT = @import("win32").foundation.HRESULT;
pub const S_OK = shobjidl.S_OK;
pub const IUnknown = combaseapi.IUnknown;

pub const CLSCTX_ALL = combaseapi.CLSCTX_ALL;
pub fn CLSID_FileOpenDialog() GUID {
    return GUID.from(shobjidl.CLSID_FileOpenDialog);
}
pub fn CLSID_FileSaveDialog() GUID {
    return GUID.from(shobjidl.CLSID_FileSaveDialog);
}
pub const SIGDN_FILESYSPATH = shobjidl.SIGDN_FILESYSPATH;
pub const IShellItem = shobjidl.IShellItem;
pub const IBindCtx = shobjidl.IBindCtx;
pub const SFGAOF = shobjidl.SFGAOF;

pub const COINIT_APARTMENTTHREADED: u32 = 0x2;
pub const COINIT_DISABLE_OLE1DDE: u32 = 0x4;
pub const COINIT_MULTITHREADED: u32 = 0x0;
pub const COINIT_SPEED_OVER_MEMORY: u32 = 0x8;

pub const FOS_ALLOWMULTISELECT = shobjidl.FOS_ALLOWMULTISELECT;
pub const FOS_CREATEPROMPT = shobjidl.FOS_CREATEPROMPT;
pub const FOS_DEFAULTNOMINIMODE = shobjidl.FOS_DEFAULTNOMINIMODE;
pub const FOS_DONTADDTORECENT = shobjidl.FOS_DONTADDTORECENT;
pub const FOS_FILEMUSTEXIST = shobjidl.FOS_FILEMUSTEXIST;
pub const FOS_FORCEFILESYSTEM = shobjidl.FOS_FORCEFILESYSTEM;
pub const FOS_FORCEPREVIEWPANEON = shobjidl.FOS_FORCEPREVIEWPANEON;
pub const FOS_FORCESHOWHIDDEN = shobjidl.FOS_FORCESHOWHIDDEN;
pub const FOS_HIDEMRUPLACES = shobjidl.FOS_HIDEMRUPLACES;
pub const FOS_HIDEPINNEDPLACES = shobjidl.FOS_HIDEPINNEDPLACES;
pub const FOS_NOCHANGEDIR = shobjidl.FOS_NOCHANGEDIR;
pub const FOS_NODEREFERENCELINKS = shobjidl.FOS_NODEREFERENCELINKS;
pub const FOS_NOREADONLYRETURN = shobjidl.FOS_NOREADONLYRETURN;
pub const FOS_NOTESTFILECREATE = shobjidl.FOS_NOTESTFILECREATE;
pub const FOS_NOVALIDATE = shobjidl.FOS_NOVALIDATE;
pub const FOS_OVERWRITEPROMPT = shobjidl.FOS_OVERWRITEPROMPT;
pub const FOS_PATHMUSTEXIST = shobjidl.FOS_PATHMUSTEXIST;
pub const FOS_PICKFOLDERS = shobjidl.FOS_PICKFOLDERS;
pub const FOS_SHAREAWARE = shobjidl.FOS_SHAREAWARE;
pub const FOS_STRICTFILETYPES = shobjidl.FOS_STRICTFILETYPES;
pub const FOS_SUPPORTSTREAMABLEITEMS = shobjidl.FOS_SUPPORTSTREAMABLEITEMS;

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

pub extern "shell32" fn SHCreateItemFromParsingName(pszPath: [*]const u16, pbc: ?*opaque{}, riid: *const GUID, ppv: *anyopaque) HRESULT;
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

pub const IFileOpenDialog = struct {
    pub const Vtbl = shobjidl.struct_IFileOpenDialogVtbl;

    inner: ?*anyopaque = null,

    pub inline fn uuidof() GUID {
        return .{
            .Data1 = 0xd57c7288,
            .Data2 = 0xd4ad,
            .Data3 = 0x4768,
            .Data4 = .{ 0xbe, 0x02, 0x9d, 0x96, 0x95, 0x32, 0xd9, 0x60 },
        };
    }

    pub fn show(self: *@This(), hwnd: ?HWND) error{UserCancelled,UnknownError}!void {
        if (self.inner) |inner| {
            const i: *shobjidl.IFileOpenDialog = @ptrCast(@alignCast(inner));
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
};

pub const IFileSaveDialog = struct {
    pub const Vtbl = shobjidl.struct_IFileSaveDialogVtbl;

    inner: ?*anyopaque = null,

    pub inline fn uuidof() GUID {
        return .{
            .Data1 = 0x84bccd23,
            .Data2 = 0x5fde,
            .Data3 = 0x4cdb,
            .Data4 = .{ 0xae, 0xa4, 0xaf, 0x64, 0xb8, 0x3d, 0x78, 0xab }
        };
    }

    pub fn show(self: *@This(), hwnd: ?HWND) error{UserCancelled,UnknownError}!void {
        if (self.inner) |inner| {
            const i: *shobjidl.IFileSaveDialog = @ptrCast(@alignCast(inner));
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
};
