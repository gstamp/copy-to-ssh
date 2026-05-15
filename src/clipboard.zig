// Clipboard handling module
// Detects clipboard content (file, image, text) and processes it for upload

const std = @import("std");
const win = @import("win32.zig");

const log = std.log.scoped(.clipboard);

pub const ClipboardType = enum {
    file,
    image,
    text,
    empty,
};

/// Detect what type of content is in the clipboard
pub fn detect() ClipboardType {
    if (win.IsClipboardFormatAvailable(win.CF_HDROP) != 0) {
        return .file;
    }
    if (win.IsClipboardFormatAvailable(win.CF_BITMAP) != 0 or
        win.IsClipboardFormatAvailable(win.CF_DIB) != 0)
    {
        return .image;
    }
    if (win.IsClipboardFormatAvailable(win.CF_UNICODETEXT) != 0 or
        win.IsClipboardFormatAvailable(win.CF_TEXT) != 0)
    {
        return .text;
    }
    return .empty;
}

/// Info about the clipboard content
pub const ClipboardInfo = struct {
    content_type: ClipboardType,
    local_path: [512]u16,       // Temp file path (for image/text, this is where we saved it)
    remote_filename: [256]u16,   // The filename to use on the remote host
    original_filename: [256]u16, // Original filename (for files)
};

/// Process clipboard content: extract to a temp file
/// Returns info about what was extracted, or null if nothing useful
pub fn extract(hwnd: win.HWND, allocator: std.mem.Allocator) !?ClipboardInfo {
    const content_type = detect();

    if (content_type == .empty) {
        return null;
    }

    // Get temp path
    var temp_path: [win.MAX_PATH]u16 = undefined;
    const temp_len = win.GetTempPathW(@as(win.DWORD, win.MAX_PATH), &temp_path);
    if (temp_len == 0 or temp_len > win.MAX_PATH) {
        return null;
    }

    // Generate timestamp for unique filenames
    const timestamp = getTimestamp();

    if (win.OpenClipboard(hwnd) == 0) {
        log.err("Failed to open clipboard", .{});
        return null;
    }
    defer _ = win.CloseClipboard();

    var info = ClipboardInfo{
        .content_type = content_type,
        .local_path = [_]u16{0} ** 512,
        .remote_filename = [_]u16{0} ** 256,
        .original_filename = [_]u16{0} ** 256,
    };

    switch (content_type) {
        .file => {
            return extractFile(&info, &temp_path);
        },
        .image => {
            return extractImage(&info, &temp_path, timestamp, allocator);
        },
        .text => {
            return extractText(&info, &temp_path, timestamp);
        },
        .empty => unreachable,
    }

    return info;
}

fn extractFile(info: *ClipboardInfo, _: []u16) !?ClipboardInfo {
    const hdrop = win.GetClipboardData(win.CF_HDROP) orelse return null;
    const hdrop_handle: win.HANDLE = @ptrCast(hdrop);

    // Get the first file
    var file_buf: [win.MAX_PATH]u16 = undefined;
    const len = win.DragQueryFileW(hdrop_handle, 0, &file_buf, win.MAX_PATH);
    if (len == 0 or len >= win.MAX_PATH) return null;

    // Find the filename part (after last backslash)
    var filename_start: usize = 0;
    for (file_buf[0..len], 0..) |c, i| {
        if (c == '\\') filename_start = i + 1;
    }

    // Copy original filename
    var i: usize = 0;
    while (filename_start + i < len and i < 255) : (i += 1) {
        info.original_filename[i] = file_buf[filename_start + i];
    }
    info.original_filename[i] = 0;

    // Remote filename (no @ prefix — that's added only to the clipboard reference)
    i = 0;
    while (filename_start + i < len and i < 255) : (i += 1) {
        info.remote_filename[i] = file_buf[filename_start + i];
    }
    info.remote_filename[i] = 0;

    // Copy local path (original file path)
    i = 0;
    while (i < len and i < 511) : (i += 1) {
        info.local_path[i] = file_buf[i];
    }
    info.local_path[i] = 0;

    win.DragFinish(hdrop_handle);
    return info.*;
}

fn extractImage(info: *ClipboardInfo, temp_path: []u16, timestamp: [32]u16, allocator: std.mem.Allocator) !?ClipboardInfo {
    _ = allocator;

    // Build filename: screenshot-{timestamp}.png (no @ prefix — added only to clipboard reference)
    const prefix = "screenshot-\x00";
    const ext = ".png\x00";

    // Build full temp path
    var path_idx: usize = 0;

    // Copy temp path
    while (temp_path[path_idx] != 0 and path_idx < 500) : (path_idx += 1) {
        info.local_path[path_idx] = temp_path[path_idx];
    }

    // Add prefix
    var pi: usize = 0;
    while (prefix[pi] != 0 and path_idx < 510) : ({
        pi += 1;
        path_idx += 1;
    }) {
        info.local_path[path_idx] = prefix[pi];
    }

    // Add timestamp
    var ti: usize = 0;
    while (timestamp[ti] != 0 and path_idx < 510) : ({
        ti += 1;
        path_idx += 1;
    }) {
        info.local_path[path_idx] = timestamp[ti];
    }

    // Add extension
    var ei: usize = 0;
    while (ext[ei] != 0 and path_idx < 510) : ({
        ei += 1;
        path_idx += 1;
    }) {
        info.local_path[path_idx] = ext[ei];
    }
    info.local_path[path_idx] = 0;

    // Set remote filename
    var ri: usize = 0;
    // Copy prefix + timestamp + ext
    pi = 0;
    while (prefix[pi] != 0 and ri < 255) : ({
        pi += 1;
        ri += 1;
    }) {
        info.remote_filename[ri] = prefix[pi];
    }
    ti = 0;
    while (timestamp[ti] != 0 and ri < 255) : ({
        ti += 1;
        ri += 1;
    }) {
        info.remote_filename[ri] = timestamp[ti];
    }
    ei = 0;
    while (ext[ei] != 0 and ri < 254) : ({
        ei += 1;
        ri += 1;
    }) {
        info.remote_filename[ri] = ext[ei];
    }
    info.remote_filename[ri] = 0;

    // Save bitmap to PNG
    if (saveBitmapToPng(info.local_path[0..])) {
        return info.*;
    }

    return null;
}

fn extractText(info: *ClipboardInfo, temp_path: []u16, timestamp: [32]u16) !?ClipboardInfo {
    // Try Unicode text first
    const htext_handle = win.GetClipboardData(win.CF_UNICODETEXT) orelse {
        // ANSI text fallback not implemented yet
        return null;
    };

    const ptr = win.GlobalLock(htext_handle) orelse return null;
    defer _ = win.GlobalUnlock(htext_handle);
    const text16: [*:0]const u16 = @ptrCast(@alignCast(ptr));

    // Build filename: clipboard-text-{timestamp}.txt (no @ prefix — added only to clipboard reference)
    const prefix = "clipboard-text-\x00";
    const ext = ".txt\x00";

    // Build local path
    var path_idx: usize = 0;
    while (temp_path[path_idx] != 0 and path_idx < 500) : (path_idx += 1) {
        info.local_path[path_idx] = temp_path[path_idx];
    }

    var pi: usize = 0;
    while (prefix[pi] != 0 and path_idx < 510) : ({
        pi += 1;
        path_idx += 1;
    }) {
        info.local_path[path_idx] = prefix[pi];
    }

    var ti: usize = 0;
    while (timestamp[ti] != 0 and path_idx < 510) : ({
        ti += 1;
        path_idx += 1;
    }) {
        info.local_path[path_idx] = timestamp[ti];
    }

    var ei: usize = 0;
    while (ext[ei] != 0 and path_idx < 510) : ({
        ei += 1;
        path_idx += 1;
    }) {
        info.local_path[path_idx] = ext[ei];
    }
    info.local_path[path_idx] = 0;

    // Set remote filename
    var ri: usize = 0;
    pi = 0;
    while (prefix[pi] != 0 and ri < 255) : ({
        pi += 1;
        ri += 1;
    }) {
        info.remote_filename[ri] = prefix[pi];
    }
    ti = 0;
    while (timestamp[ti] != 0 and ri < 255) : ({
        ti += 1;
        ri += 1;
    }) {
        info.remote_filename[ri] = timestamp[ti];
    }
    ei = 0;
    while (ext[ei] != 0 and ri < 254) : ({
        ei += 1;
        ri += 1;
    }) {
        info.remote_filename[ri] = ext[ei];
    }
    info.remote_filename[ri] = 0;

    // Convert UTF-16 to UTF-8 and save
    var utf8_buf: [65536]u8 = undefined;
    var utf8_len: usize = 0;

    var si: usize = 0;
    while (text16[si] != 0 and utf8_len < utf8_buf.len - 3) {
        const cp = text16[si];
        si += 1;
        if (cp < 0x80) {
            utf8_buf[utf8_len] = @as(u8, @intCast(cp & 0xFF));
            utf8_len += 1;
        } else if (cp < 0x800) {
            utf8_buf[utf8_len] = @as(u8, @intCast(0xC0 | (cp >> 6)));
            utf8_buf[utf8_len + 1] = @as(u8, @intCast(0x80 | (cp & 0x3F)));
            utf8_len += 2;
        } else {
            utf8_buf[utf8_len] = @as(u8, @intCast(0xE0 | (cp >> 12)));
            utf8_buf[utf8_len + 1] = @as(u8, @intCast(0x80 | ((cp >> 6) & 0x3F)));
            utf8_buf[utf8_len + 2] = @as(u8, @intCast(0x80 | (cp & 0x3F)));
            utf8_len += 3;
        }
    }

    // Write file
    const wpath: [*:0]const u16 = @ptrCast(&info.local_path);
    const hfile = win.CreateFileW(
        wpath,
        win.GENERIC_WRITE,
        0,
        null,
        win.CREATE_ALWAYS,
        win.FILE_ATTRIBUTE_NORMAL,
        null,
    ) orelse return null;

    var bytes_written: win.DWORD = 0;
    _ = win.WriteFile(
        hfile,
        @as(win.LPCVOID, @ptrCast(&utf8_buf)),
        @as(win.DWORD, @intCast(utf8_len)),
        &bytes_written,
        null,
    );
    _ = win.CloseHandle(hfile);

    return info.*;
}

/// Save a clipboard bitmap to a PNG file using GDI+
fn saveBitmapToPng(path16: []u16) bool {
    // Make sure path is null-terminated
    var null_path: [win.MAX_PATH + 1]u16 = undefined;
    @memset(&null_path, 0);
    var i: usize = 0;
    while (i < path16.len and path16[i] != 0) : (i += 1) {
        null_path[i] = path16[i];
    }

    // Get the bitmap from clipboard
    var hbitmap: win.HBITMAP = undefined;

    // Try CF_BITMAP first
    const hbm = win.GetClipboardData(win.CF_BITMAP);
    if (hbm) |h| {
        hbitmap = @ptrCast(h);
    } else {
        // Try CF_DIB - need to convert to HBITMAP
        const hdib = win.GetClipboardData(win.CF_DIB) orelse return false;
        // Convert DIB to HBITMAP using CreateDIBSection + SetDIBits
        // For now, fall back
        _ = hdib;
        return false;
    }

    // Initialize GDI+
    var gdip_token: win.ULONG_PTR = 0;
    var startup_input = win.GdiplusStartupInput{};
    if (win.GdiplusStartup(&gdip_token, &startup_input, null) != win.GdiplusOk) {
        return false;
    }
    defer win.GdiplusShutdown(gdip_token);

    // Create GDI+ bitmap from HBITMAP
    var gdip_bitmap_ptr: ?*win.GpImage = null;
    if (win.GdipCreateBitmapFromHBITMAP(hbitmap, null, &gdip_bitmap_ptr) != win.GdiplusOk) {
        return false;
    }
    defer {
        if (gdip_bitmap_ptr) |p| {
            _ = win.GdipDisposeImage(p);
        }
    }
    const gdip_bitmap = gdip_bitmap_ptr.?;

    // Save as PNG
    const path_ptr: [*:0]const u16 = @ptrCast(&null_path);
    if (win.GdipSaveImageToFile(gdip_bitmap, path_ptr, &win.CLSID_PNG_ENCODER, null) != win.GdiplusOk) {
        return false;
    }

    return true;
}

/// Get a timestamp string for unique filenames
fn getTimestamp() [32]u16 {
    var buf: [32]u16 = undefined;
    @memset(&buf, 0);

    // Get system time
    var st: SYSTEMTIME = undefined;
    GetLocalTime(&st);

    // Format: YYYY-MM-DD_HHMMSS
    const parts = [6]u16{ st.wYear, st.wMonth, st.wDay, st.wHour, st.wMinute, st.wSecond };

    var idx: usize = 0;
    for (parts, 0..) |val, pi| {
        // Two digits (or four for year)
        const digits: u16 = if (pi == 0) 4 else 2;
        var v = val;
        var d: [4]u16 = undefined;
        var di: usize = 0;
        while (di < digits) : (di += 1) {
            d[di] = @as(u16, @intCast('0' + (v % 10)));
            v /= 10;
        }
        var j: usize = digits;
        while (j > 0) {
            j -= 1;
            buf[idx] = d[j];
            idx += 1;
        }
        // Separator
        if (pi == 2) {
            buf[idx] = '_';
            idx += 1;
        } else if (pi < 5) {
            buf[idx] = '-';
            idx += 1;
        }
    }
    buf[idx] = 0;
    return buf;
}

const SYSTEMTIME = extern struct {
    wYear: u16,
    wMonth: u16,
    wDayOfWeek: u16,
    wDay: u16,
    wHour: u16,
    wMinute: u16,
    wSecond: u16,
    wMilliseconds: u16,
};

extern "kernel32" fn GetLocalTime(lpSystemTime: *SYSTEMTIME) callconv(.winapi) void;
