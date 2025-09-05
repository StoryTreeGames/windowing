const std = @import("std");

const windows = @import("windows");
const win32 = windows.win32;

const com = win32.system.com;
const ole = win32.system.ole;
const shell = win32.ui.shell;
const gdi = win32.graphics.gdi;
const windows_and_messaging = win32.ui.windows_and_messaging;
const foundation = win32.foundation;
const structured_storage = win32.storage.structured_storage;
const security = win32.security;
const data_exchange = win32.system.data_exchange;

const IUnknown = com.IUnknown;
const IID_IUnknown = com.IID_IUnknown;
const IDataObject = com.IDataObject;
const IDropTarget = ole.IDropTarget;
const IDropTargetHelper = shell.IDropTargetHelper;
const CLSID_DragDropHelper = shell.CLSID_DragDropHelper;

const HWND = foundation.HWND;
const HRESULT = foundation.HRESULT;
const Guid = windows.Guid;

const DROPEFFECT_NONE: i32 = 0x0;
const DROPEFFECT_COPY: i32 = 0x1;
const DROPEFFECT_MOVE: i32 = 0x2;
const DROPEFFECT_LINK: i32 = 0x4;
const DROPEFFECT_SCROLL: i32 = 0x8000000;

const DVASPECT_CONTENT = com.DVASPECT_CONTENT;
const TYMED_HGLOBAL = com.TYMED_HGLOBAL;
const TYMED = com.TYMED;
const CLIPBOARD_FORMATS = win32.system.system_services.CLIPBOARD_FORMATS;

const FORMATETC = com.FORMATETC;
const STGMEDIUM = com.STGMEDIUM;

const RegisterDragDrop = ole.RegisterDragDrop;
const RevokeDragDrop = ole.RevokeDragDrop;
const OleInitialize = ole.OleInitialize;
const OleUninitialize = ole.OleUninitialize;
const CoInitializeEx = com.CoInitializeEx;
const CoUninitialize = com.CoUninitialize;

const GlobalLock = win32.system.memory.GlobalLock;
const GlobalUnlock = win32.system.memory.GlobalUnlock;
const GlobalSize = win32.system.memory.GlobalSize;
const DragQueryFileW = shell.DragQueryFileW;
const DragFinish = shell.DragFinish;

const L = std.unicode.utf8ToUtf16LeStringLiteral;
const print = std.debug.print;

const DropEffect = enum { none, move, copy, link, scroll };

const DragKeyState = struct {
    left: bool = false,
    middle: bool = false,
    right: bool = false,
    x1: bool = false,
    x2: bool = false,
    control: bool = false,
    shift: bool = false,
};

pub const FormatSet = std.StringArrayHashMapUnmanaged(void);

const DragDropContext = extern struct {
    enter: ?*anyopaque = null,
    over: ?*anyopaque = null,
    drop: ?*anyopaque = null, // TODO: Add way for user to process the data
    leave: ?*anyopaque = null,

    pub fn onEnter(self: *@This(), state: ?*anyopaque, point: core.Point(u32), key_state: DragKeyState) DropEffect {
        if (self.enter) |c| {
            const callback: OnEnter = @ptrCast(@alignCast(c));
            return callback(state, point, key_state) catch .none;
        }
        return .none;
    }

    pub fn onOver(self: *@This(), state: ?*anyopaque, point: core.Point(u32), key_state: DragKeyState) DropEffect {
        if (self.over) |c| {
            const callback: OnOver = @ptrCast(@alignCast(c));
            return callback(state, point, key_state) catch .none;
        }
        return .none;
    }

    pub fn onDrop(self: *@This(), state: ?*anyopaque, point: core.Point(u32), key_state: DragKeyState, data: DropData) DropEffect {
        if (self.drop) |c| {
            const callback: OnDrop = @ptrCast(@alignCast(c));
            return callback(state, point, key_state, data) catch .none;
        }
        return .none;
    }

    pub fn onLeave(self: *@This(), state: ?*anyopaque) void {
        if (self.leave) |c| {
            const callback: OnLeave = @ptrCast(@alignCast(c));
            callback(state) catch {};
        }
    }

    pub const OnEnter = *const fn (state: ?*anyopaque, point: core.Point(u32), key_state: DragKeyState) anyerror!DropEffect;
    pub const OnOver = *const fn (state: ?*anyopaque, point: core.Point(u32), key_state: DragKeyState) anyerror!DropEffect;
    pub const OnDrop = *const fn (state: ?*anyopaque, point: core.Point(u32), key_state: DragKeyState, data: DropData) anyerror!DropEffect;
    pub const OnLeave = *const fn (state: ?*anyopaque) anyerror!void;
};

fn getDataHGLOBAL(dobj: *IDataObject, cf: u16) ?STGMEDIUM {
    var fmt = FORMATETC{ .cfFormat = cf, .ptd = null, .dwAspect = @intFromEnum(DVASPECT_CONTENT), .lindex = -1, .tymed = @intFromEnum(TYMED.HGLOBAL) };
    var stg = std.mem.zeroes(STGMEDIUM);
    if (dobj.GetData(&fmt, &stg) != 0) return null;
    if (stg.tymed != @as(u32, @intFromEnum(TYMED.HGLOBAL))) {
        ole.ReleaseStgMedium(&stg);
        return null;
    }
    return stg; // caller must ReleaseStgMedium
}

fn hglobalToBytesOwned(allocator: std.mem.Allocator, stg: *STGMEDIUM) ?[]u8 {
    const h = stg.Anonymous.hGlobal;
    const n = GlobalSize(h);
    if (n == 0) return null;
    const p = GlobalLock(h) orelse return null;
    defer _ = GlobalUnlock(h);
    const out = if(allocator.alloc(u8, n))|o| o else |_| return null;
    @memcpy(out, @as([*]const u8, @ptrCast(p))[0..n]);
    return out; // ownership: caller frees
}

fn hglobalUtf16ToUtf8Owned(allocator: std.mem.Allocator, stg: *STGMEDIUM) ?[]const u8 {
    const h = stg.Anonymous.hGlobal;
    const total = GlobalSize(h);
    if (total < 2) return null;
    const p = GlobalLock(h) orelse return null;
    defer _ = GlobalUnlock(h);

    const u16ptr: [*:0]const u16 = @ptrCast(@alignCast(p));
    const u16slice: []const u16 = std.mem.sliceTo(u16ptr, 0);

    return std.unicode.utf16LeToUtf8Alloc(allocator, u16slice) catch null;
}

const DropData = struct {
    _impl: ?*IDataObject,

    pub fn supports(self: *const @This(), format: []const u8) bool {
        if (self._impl) |o| {
            var penum: ?*com.IEnumFORMATETC = null;
            if (o.EnumFormatEtc(@intFromEnum(com.DATADIR_GET), &penum) != 0 or penum == null) return false;
            defer _ = IUnknown.Release(@ptrCast(penum.?));

            var fetched: u32 = 0;
            var arr: [1]FORMATETC = undefined;
            var buff: [128:0]u16 = undefined;

            while (penum.?.Next(1, &arr, &fetched) == 0 and fetched == 1) {
                const cf = arr[0].cfFormat;

                if (cf >= 1 and cf <= 18) {
                    switch (@as(CLIPBOARD_FORMATS, @enumFromInt(cf))) {
                        .OEMTEXT, .TEXT, .UNICODETEXT => if (std.mem.eql(u8, format, "Text")) return true,
                        .BITMAP, .DIB, .DIBV5 => if (std.mem.eql(u8, format, "Bitmap")) return true,
                        .HDROP => if (std.mem.eql(u8, format, "Files")) return true,
                        // METAFILEPICT = 3,
                        // SYLK = 4,
                        // DIF = 5,
                        // TIFF = 6,
                        // PALETTE = 9,
                        // PENDATA = 10,
                        // RIFF = 11,
                        // WAVE = 12,
                        // ENHMETAFILE = 14,
                        // LOCALE = 16,
                        // MAX = 18,
                        else => {},
                    }
                    continue;
                }

                const n = data_exchange.GetClipboardFormatNameW(@intCast(cf), &buff, buff.len);
                if (n > 0) {
                    const wide_slice = buff[0..@as(usize, @intCast(n))];
                    if (std.mem.eql(u16, wide_slice, L("HTML Format")) and std.mem.eql(u8, format, "HTML")) {
                        return true;
                    } else if (std.mem.eql(u16, wide_slice, L("UniformResourceLocatorW")) and std.mem.eql(u8, format, "URL")) {
                        return true;
                    } else {
                        var utf16It = std.unicode.Utf16LeIterator.init(wide_slice);
                        var utf8It = std.unicode.Utf8Iterator{ .bytes = format, .i = 0 };

                        var a = utf8It.nextCodepoint();
                        var b = if (utf16It.nextCodepoint()) |cp| cp else |_| null;
                        while (a != null and b != null) {
                            if (a != b) break;

                            a = utf8It.nextCodepoint();
                            b = if (utf16It.nextCodepoint()) |cp| cp else |_| null;
                        } else {
                            return true;
                        }
                    }
                }
            }
        }
        return false;
    }

    pub fn getText(self: *const @This(), allocator: std.mem.Allocator) ?[]const u8 {
        const obj = self._impl orelse return null;
        var stg = getDataHGLOBAL(obj, CF_UNICODETEXT) orelse return null;
        defer ole.ReleaseStgMedium(&stg);
        return hglobalUtf16ToUtf8Owned(allocator, &stg) orelse null;
    }

    pub fn getUrl(self: *const @This(), allocator: std.mem.Allocator) ?[]const u8 {
        const obj = self._impl orelse return null;
        var stg = getDataHGLOBAL(obj, CFSTR_INETURLW()) orelse return null;
        defer ole.ReleaseStgMedium(&stg);
        return hglobalUtf16ToUtf8Owned(allocator, &stg);
    }

    pub fn getHtml(self: *const @This(), allocator: std.mem.Allocator) ?[]const u8 {
        const obj = self._impl orelse return null;
        var stg = getDataHGLOBAL(obj, CFSTR_HTMLFORMAT()) orelse return null;
        defer ole.ReleaseStgMedium(&stg);
        const bytes = hglobalToBytesOwned(allocator, &stg) orelse return null;

        const start_tag = "<!--StartFragment-->";
        if (std.mem.indexOf(u8, bytes, start_tag)) |a| {
            if (std.mem.indexOf(u8, bytes, "<!--EndFragment-->")) |b| {
                defer allocator.free(bytes);
                return if(allocator.dupe(u8, bytes[a + start_tag.len .. b]))|o| o else |_| null; // NOTE: using same allocation; free once
            }
        }

        // Fallback: attempt header offset fields
        const hdr = bytes;
        const s_off = std.mem.indexOf(u8, hdr, "StartFragment:") orelse return bytes;
        const e_off = std.mem.indexOf(u8, hdr, "EndFragment:") orelse return bytes;
        const s_val = std.fmt.parseInt(usize, hdr[s_off + 14 .. s_off + 14 + 10], 10) catch return bytes;
        const e_val = std.fmt.parseInt(usize, hdr[e_off + 12 .. e_off + 12 + 10], 10) catch return bytes;
        if (s_val < e_val and e_val <= bytes.len) {
            defer allocator.free(bytes);
            return if(allocator.dupe(u8, bytes[s_val..e_val]))|o| o else |_| null;
        }

        // Return all bytes if parsing fails
        return bytes;
    }

    pub fn getFiles(self: *const @This(), allocator: std.mem.Allocator) ?[]const []const u8 {
        const obj = self._impl orelse return null;

        var stg = getDataHGLOBAL(obj, CF_HDROP) orelse return null;
        defer ole.ReleaseStgMedium(&stg);

        const hdrop: shell.HDROP = @ptrFromInt(@as(usize, @bitCast(stg.Anonymous.hGlobal)));
        const count = DragQueryFileW(hdrop, 0xFFFFFFFF, null, 0);
        if (count == 0) return null;

        var out: std.ArrayList([]const u8) = .empty;
        for (0..count) |i| {
            const need = DragQueryFileW(hdrop, @intCast(i), null, 0) + 1;
            const tmp = allocator.allocSentinel(u16, need, 0) catch continue;
            defer allocator.free(tmp);
            _ = DragQueryFileW(hdrop, @intCast(i), tmp.ptr, need);

            const buff = std.unicode.utf16LeToUtf8Alloc(allocator, tmp[0..tmp.len]) catch continue;
            out.append(allocator, buff) catch {
                allocator.free(buff);
                continue;
            };
        }
        return out.toOwnedSlice(allocator) catch {
            for (out.items) |item| allocator.free(item);
            out.deinit(allocator);
            return null;
        };
    }

    pub fn getBitmap(self: *@This(), allocator: std.mem.Allocator) ?[]const u8 {
        const obj = self._impl orelse return null;

        var stg = getDataHGLOBAL(obj, CF_DIBV5) orelse getDataHGLOBAL(obj, CF_DIB) orelse return null;
        defer ole.ReleaseStgMedium(&stg);
        const dib = hglobalToBytesOwned(&stg) orelse return null;

        // Wrap DIB with a BMP file header
        // DIB starts with BITMAPINFOHEADER/BITMAPV5HEADER; color table (if any) + bits follow.
        // File offset to bits is sizeof(BITMAPFILEHEADER) + the DIB header + palette.
        // For a quick/robust approach, most apps just preprend a BFH with bfOffBits = 14 + dibHeaderSize + paletteSize.
        // Here we’ll do a minimal (not palette-aware) approach that works for common 24/32bpp:

        if (dib.len < 40) return null; // need at least BITMAPINFOHEADER
        const header_size = @as(u32, @bitCast(@as([4]u8, dib[0..4].*))); // biSize
        const bfOff = 14 + header_size; // ok for BI_BITFIELDS/32bpp; palette images need more
        var out = try allocator.alloc(u8, 14 + dib.len);
        // BFH
        out[0] = 'B';
        out[1] = 'M';
        std.mem.writeInt(u32, out[2..6], @intCast(out.len), .little);
        out[6] = 0;
        out[7] = 0;
        out[8] = 0;
        out[9] = 0;
        std.mem.writeInt(u32, out[10..14], bfOff, .little);
        // DIB
        std.mem.copy(u8, out[14..], dib);
        return out; // BMP file bytes; can be written to disk as `.bmp`
    }
};

const DropTarget = extern struct {
    vtable: *const IDropTarget.VTable,
    ref_count: std.atomic.Value(u32),
    hwnd: HWND,
    helper: ?*IDropTargetHelper,

    context: DragDropContext,
    state: ?*anyopaque = null,

    pub const Context = struct {
        enter: ?DragDropContext.OnEnter = null,
        over: ?DragDropContext.OnOver = null,
        drop: ?DragDropContext.OnDrop = null,
        leave: ?DragDropContext.OnLeave = null,
    };

    pub fn init(hwnd: HWND, context: Context) !*@This() {
        const self = try std.heap.c_allocator.create(@This());
        self.* = .{
            .vtable = &VTABLE,
            .ref_count = .init(1),
            .hwnd = hwnd,
            .helper = null,
            .context = .{
                .enter = @ptrCast(@constCast(context.enter)),
                .over = @ptrCast(@constCast(context.over)),
                .drop = @ptrCast(@constCast(context.drop)),
                .leave = @ptrCast(@constCast(context.leave)),
            },
        };

        var p: *IDropTargetHelper = undefined;
        const hr = com.CoCreateInstance(&CLSID_DragDropHelper, null, com.CLSCTX_INPROC_SERVER, shell.IID_IDropTargetHelper, @ptrCast(&p));
        if (hr != 0) return windows.core.hresultToError(hr).err;
        self.helper = p;
        return self;
    }

    pub fn initWithState(hwnd: HWND, context: Context, state: anytype) !*@This() {
        const self = try std.heap.c_allocator.create(@This());
        self.* = .{
            .vtable = &VTABLE,
            .ref_count = .init(1),
            .hwnd = hwnd,
            .helper = null,
            .context = .{
                .enter = @ptrCast(@constCast(context.enter)),
                .over = @ptrCast(@constCast(context.over)),
                .drop = @ptrCast(@constCast(context.drop)),
                .leave = @ptrCast(@constCast(context.leave)),
            },
            .state = @ptrCast(state),
        };

        var p: *IDropTargetHelper = undefined;
        const hr = com.CoCreateInstance(&CLSID_DragDropHelper, null, com.CLSCTX_INPROC_SERVER, shell.IID_IDropTargetHelper, @ptrCast(&p));
        if (hr != 0) return windows.core.hresultToError(hr).err;
        self.helper = p;
        return self;
    }

    /// Calls `Release` and discards ref count response
    ///
    /// This function or `Release` should be called once for every
    /// `init` or `AddRef` called.
    pub fn deinit(self: *@This()) void {
        _ = Release(@ptrCast(self));
    }

    pub fn AddRef(self: *const IUnknown) callconv(.winapi) u32 {
        const this: *@This() = @ptrCast(@constCast(self));
        return this.ref_count.fetchAdd(1, .seq_cst) + 1;
    }

    pub fn Release(self: *const IUnknown) callconv(.winapi) u32 {
        const this: *@This() = @ptrCast(@constCast(self));
        const prev = this.ref_count.fetchSub(1, .seq_cst);
        if (prev == 1) {
            if (this.helper) |h| _ = IUnknown.Release(@ptrCast(h));
            std.heap.c_allocator.destroy(this);
            return 0;
        }
        return prev -| 1;
    }

    pub fn QueryInterface(
        self: *const IUnknown,
        riid: *const Guid,
        ppv: **anyopaque,
    ) callconv(.winapi) HRESULT {
        if (std.mem.eql(u8, &riid.Bytes, &IID_IUnknown.Bytes) or
            std.mem.eql(u8, &riid.Bytes, &ole.IID_IDropTarget.Bytes))
        {
            ppv.* = @ptrCast(@constCast(self));
            _ = AddRef(self);
            return 0;
        }
        return -2147467262; // E_NOINTERFACE
    }

    /// Convert point from screen space to window space
    fn screenToWindow(self: *@This(), point: foundation.POINTL) core.Point(u32) {
        var bounds: foundation.RECT = undefined;
        _ = windows_and_messaging.GetWindowRect(self.hwnd, &bounds);
        return .{
            .y = @intCast(point.y -| bounds.top),
            .x = @intCast(point.x -| bounds.left),
        };
    }

    fn DragEnter(
        self: *const IDropTarget,
        pDataObj: ?*IDataObject,
        grfKeyState: u32,
        pt: foundation.POINTL,
        pdwEffect: ?*u32,
    ) callconv(.winapi) HRESULT {
        const this: *@This() = @ptrCast(@constCast(self));

        const effect = this.context.onEnter(
            this.state,
            this.screenToWindow(pt),
            .{
                .left = grfKeyState & windows_and_messaging.MK_LBUTTON != 0,
                .middle = grfKeyState & windows_and_messaging.MK_MBUTTON != 0,
                .right = grfKeyState & windows_and_messaging.MK_RBUTTON != 0,
                .x1 = grfKeyState & windows_and_messaging.MK_XBUTTON1 != 0,
                .x2 = grfKeyState & windows_and_messaging.MK_XBUTTON2 != 0,
                .control = grfKeyState & windows_and_messaging.MK_CONTROL != 0,
                .shift = grfKeyState & windows_and_messaging.MK_SHIFT != 0,
            },
        );
        if (pdwEffect) |e| e.* = switch (effect) {
            .none => DROPEFFECT_NONE,
            .copy => DROPEFFECT_COPY,
            .move => DROPEFFECT_MOVE,
            .link => DROPEFFECT_LINK,
            .scroll => DROPEFFECT_SCROLL,
        };

        if (this.helper) |h| {
            var p: foundation.POINT = .{ .x = pt.x, .y = pt.y };
            _ = h.DragEnter(this.hwnd, pDataObj, &p, if (pdwEffect) |e| e.* else 0);
        }
        return 0;
    }

    fn DragOver(
        self: *const IDropTarget,
        grfKeyState: u32,
        pt: foundation.POINTL,
        pdwEffect: ?*u32,
    ) callconv(.winapi) HRESULT {
        const this: *@This() = @ptrCast(@constCast(self));

        const effect = this.context.onOver(
            this.state,
            this.screenToWindow(pt),
            .{
                .left = grfKeyState & windows_and_messaging.MK_LBUTTON != 0,
                .middle = grfKeyState & windows_and_messaging.MK_MBUTTON != 0,
                .right = grfKeyState & windows_and_messaging.MK_RBUTTON != 0,
                .x1 = grfKeyState & windows_and_messaging.MK_XBUTTON1 != 0,
                .x2 = grfKeyState & windows_and_messaging.MK_XBUTTON2 != 0,
                .control = grfKeyState & windows_and_messaging.MK_CONTROL != 0,
                .shift = grfKeyState & windows_and_messaging.MK_SHIFT != 0,
            },
        );
        if (pdwEffect) |e| e.* = switch (effect) {
            .none => DROPEFFECT_NONE,
            .copy => DROPEFFECT_COPY,
            .move => DROPEFFECT_MOVE,
            .link => DROPEFFECT_LINK,
            .scroll => DROPEFFECT_SCROLL,
        };

        if (this.helper) |h| {
            var p: foundation.POINT = .{ .x = pt.x, .y = pt.y };
            _ = h.DragOver(
                &p,
                if (pdwEffect) |e| e.* else 0,
            );
        }
        return 0;
    }

    fn DragLeave(self: *const IDropTarget) callconv(.winapi) HRESULT {
        const this: *@This() = @ptrCast(@constCast(self));
        this.context.onLeave(this.state);
        if (this.helper) |h| {
            _ = h.DragLeave();
        }
        return 0;
    }

    fn Drop(
        self: *const IDropTarget,
        pDataObj: ?*IDataObject,
        grfKeyState: u32,
        pt: foundation.POINTL,
        pdwEffect: ?*u32,
    ) callconv(.winapi) HRESULT {
        const this: *@This() = @ptrCast(@constCast(self));

        var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
        defer arena.deinit();
        const data = DropData{ ._impl = pDataObj };

        const effect = this.context.onDrop(
            this.state,
            this.screenToWindow(pt),
            .{
                .left = grfKeyState & windows_and_messaging.MK_LBUTTON != 0,
                .middle = grfKeyState & windows_and_messaging.MK_MBUTTON != 0,
                .right = grfKeyState & windows_and_messaging.MK_RBUTTON != 0,
                .x1 = grfKeyState & windows_and_messaging.MK_XBUTTON1 != 0,
                .x2 = grfKeyState & windows_and_messaging.MK_XBUTTON2 != 0,
                .control = grfKeyState & windows_and_messaging.MK_CONTROL != 0,
                .shift = grfKeyState & windows_and_messaging.MK_SHIFT != 0,
            },
            data,
        );
        if (pdwEffect) |e| e.* = switch (effect) {
            .none => DROPEFFECT_NONE,
            .copy => DROPEFFECT_COPY,
            .move => DROPEFFECT_MOVE,
            .link => DROPEFFECT_LINK,
            .scroll => DROPEFFECT_SCROLL,
        };

        if (this.helper) |h| {
            var p: foundation.POINT = .{ .x = pt.x, .y = pt.y };
            _ = h.Drop(
                pDataObj,
                &p,
                if (pdwEffect) |e| e.* else 0,
            );
        }
        return 0;
    }

    const VTABLE = IDropTarget.VTable{
        .base = IUnknown.VTable{
            .QueryInterface = QueryInterface,
            .AddRef = AddRef,
            .Release = Release,
        },
        .DragEnter = DragEnter,
        .DragOver = DragOver,
        .DragLeave = DragLeave,
        .Drop = Drop,
    };
};

fn registerClipboardFormat(format: [:0]const u16) u16 {
    return @truncate(data_exchange.RegisterClipboardFormatW(format.ptr));
}

fn CFSTR_PNG() u16 { return registerClipboardFormat(L("PNG")); }
fn CFSTR_HTMLFORMAT() u16 { return registerClipboardFormat(L("HTML Format")); }
fn CFSTR_INETURLW() u16 { return registerClipboardFormat(L("UniformResourceLocatorW")); }
fn CFSTR_FILEDESCRIPTORW() u16 { return registerClipboardFormat(L("FileGroupDescriptorW")); }
fn CFSTR_FILECONTENTS() u16 { return registerClipboardFormat(L("FileContents")); }

fn hasFormatExact(obj: *IDataObject, cf: u16, tymed: TYMED) bool {
    var fmt = FORMATETC{
        .cfFormat = @truncate(cf),
        .ptd = null,
        .dwAspect = @intFromEnum(DVASPECT_CONTENT),
        .lindex = -1,
        .tymed = tymed,
    };

    return obj.QueryGetData(&fmt) != 0;
}

const CF_UNICODETEXT: u16 = @intFromEnum(win32.system.system_services.CF_UNICODETEXT);
const CF_HDROP: u16 = @intFromEnum(win32.system.system_services.CF_HDROP);
const CF_DIB: u16 = @intFromEnum(win32.system.system_services.CF_DIB);
const CF_DIBV5: u16 = @intFromEnum(win32.system.system_services.CF_DIBV5);

fn hasFormat_(obj: *IDataObject, cf: u16) bool {
    if (cf == CFSTR_FILECONTENTS()) {
        if (hasFormatExact(obj, cf, TYMED.ISTREAM)) return true;
        if (hasFormatExact(obj, cf, TYMED.ISTORAGE)) return true;
    }

    return hasFormatExact(obj, cf, TYMED.HGLOBAL);
}

const core = @import("storytree-core");
const event = core.event;
const input = core.input;

const Window = @import("storytree-core").Window;
const EventLoop = event.EventLoop;
const Event = event.Event;

const State = struct {
    allocator: std.mem.Allocator,

    pub fn handleEvent(self: *@This(), event_loop: *EventLoop, window: *Window, evt: Event) !void {
        _ = self;
        switch (evt) {
            .close => event_loop.closeWindow(window.id()),
            .key_input => |key_event| {
                std.debug.print("{any}\n", .{key_event.key});
            },
            else => {},
        }
    }
};

fn onDrag(state: ?*anyopaque, point: core.Point(u32), key_state: DragKeyState) !DropEffect {
    _ = state;
    _ = point;

    if (key_state.control and key_state.shift) return .link;
    if (key_state.shift) return .move;
    return .copy;
}

fn onDrop(state: ?*anyopaque, point: core.Point(u32), key_state: DragKeyState, data: DropData) !DropEffect {
    _ = point;

    var gpa: *std.heap.GeneralPurposeAllocator(.{}) = @ptrCast(@alignCast(state.?));
    const allocator = gpa.allocator();

    if (data.supports("URL")) {
        if (data.getUrl(allocator)) |text| {
            defer allocator.free(text);
            std.debug.print("[URL] {s}\n", .{text});
        }
    } else if (data.supports("HTML")) {
        if (data.getHtml(allocator)) |text| {
            defer allocator.free(text);
            std.debug.print("[HTML] {s}\n", .{text});
        }
    } else if (data.supports("Text")) {
        if (data.getText(allocator)) |text| {
            defer allocator.free(text);
            std.debug.print("[TEXT] {s}\n", .{text});
        }
    } else if (data.supports("Files")) {
        if (data.getFiles(allocator)) |files| {
            defer {
                for (files) |file| allocator.free(file);
                allocator.free(files);
            }

            std.debug.print("[FILES]\n", .{});
            for (files) |file| {
                std.debug.print("  - {s}\n", .{file});
            }
        }
    }

    if (key_state.control and key_state.shift) return .link;
    if (key_state.shift) return .move;
    return .copy;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    _ = OleInitialize(null);
    defer OleUninitialize();

    var event_loop = try EventLoop.init(allocator);
    defer event_loop.deinit();

    var state: State = .{ .allocator = allocator };

    const window = try event_loop.createWindow(.{
        .title = "Drag & Drop",
        .width = 800,
        .height = 600,
    });

    const hwnd = window.impl.handle;

    const drop_target = try DropTarget.initWithState(hwnd, .{
        .enter = onDrag,
        .over = onDrag,
        .drop = onDrop,
    }, &gpa);
    defer drop_target.deinit();

    const hr = RegisterDragDrop(hwnd, @ptrCast(drop_target));
    defer _ = RevokeDragDrop(hwnd);
    if (hr != 0) return windows.core.hresultToError(hr).err;

    while (event_loop.isActive()) {
        if (event_loop.poll()) |data| {
            try state.handleEvent(&event_loop, data.window, data.event);
        }
    }
}
