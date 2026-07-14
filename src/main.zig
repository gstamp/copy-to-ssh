// sync-to-remote - A tiny Windows system tray app for quick clipboard-to-SSH transfers
//
// Press Win+Alt+V to grab clipboard content (file, image, or text)
// and upload it to a configured remote SSH host via SFTP.
// The clipboard is then set to @filename on the remote host.

const std = @import("std");
const win = @import("win32.zig");
const config = @import("config.zig");
const tray = @import("tray.zig");
const hotkey = @import("hotkey.zig");
const clipboard = @import("clipboard.zig");
const sftp = @import("sftp.zig");
const gui = @import("gui.zig");
const progress = @import("progress.zig");

const log = std.log.scoped(.main);
const CLASS_NAME: [*:0]const u16 = &[_:0]u16{ 'S', 'y', 'n', 'c', 'T', 'o', 'R', 'e', 'm', 'o', 't', 'e', 'W', 'n', 'd' };
const MUTEX_NAME: [*:0]const u16 = &[_:0]u16{ 'L', 'o', 'c', 'a', 'l', '\\', 'S', 'y', 'n', 'c', 'T', 'o', 'R', 'e', 'm', 'o', 't', 'e', 'M', 'u', 't', 'e', 'x' };
const APP_NAME: [*:0]const u16 = &[_:0]u16{ 's', 'y', 'n', 'c', '-', 't', 'o', '-', 'r', 'e', 'm', 'o', 't', 'e' };

var g_allocator: std.mem.Allocator = undefined;
var g_hicon: win.HICON = undefined;
var g_auto_mode: bool = false;
const WM_UPLOAD_COMPLETE = win.WM_USER + 101;

const UploadOutcome = enum { pending, success, failure };

const UploadJob = struct {
    owner: win.HWND,
    progress_window: win.HWND,
    cfg: config.Config,
    info: clipboard.ClipboardInfo,
    outcome: UploadOutcome = .pending,
    error_text: [256]u16 = [_]u16{0} ** 256,
};

extern "user32" fn PostMessageW(hWnd: win.HWND, Msg: win.UINT, wParam: win.WPARAM, lParam: win.LPARAM) callconv(.winapi) win.BOOL;

pub fn main() !void {
    // Set up allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    g_allocator = gpa.allocator();

    // Ensure single instance
    const mutex = win.CreateMutexW(null, win.FALSE, MUTEX_NAME) orelse return;
    if (win.GetLastError() == win.ERROR_ALREADY_EXISTS) {
        // Another instance is running; bring its window to front
        _ = win.SetForegroundWindow(FindWindowW(CLASS_NAME, null));
        _ = win.CloseHandle(mutex);
        return;
    }
    defer _ = win.CloseHandle(mutex);

    // Load config
    _ = config.load(g_allocator) catch config.Config.default();
    log.info("Config loaded", .{});

    // Load the icon from embedded resource first
    g_hicon = loadIcon() orelse {
        log.err("Failed to load icon", .{});
        return;
    };

    // Register window class
    const hinst = win.GetModuleHandleW(null) orelse return;
    progress.init(hinst);

    const wc = win.WNDCLASSW{
        .style = 0,
        .lpfnWndProc = wndProc,
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .hInstance = hinst,
        .hIcon = g_hicon,
        .hCursor = win.LoadCursorW(null, win.IDC_ARROW),
        .hbrBackground = null,
        .lpszMenuName = null,
        .lpszClassName = CLASS_NAME,
    };

    if (win.RegisterClassW(&wc) == 0) {
        log.err("Failed to register window class", .{});
        return;
    }

    // Create hidden window
    const hwnd = win.CreateWindowExW(
        0,
        CLASS_NAME,
        APP_NAME,
        0,
        0,
        0,
        0,
        0,
        null,
        null,
        hinst,
        null,
    ) orelse {
        log.err("Failed to create window", .{});
        return;
    };

    // Set up tray icon
    if (!tray.setup(hwnd, g_hicon)) {
        log.err("Failed to set up tray icon", .{});
        // Continue without tray icon
    }

    // Register hotkey
    if (!hotkey.register(hwnd)) {
        log.err("Failed to register hotkey", .{});
        // Continue without hotkey
    }

    // Register clipboard format listener for auto-mode
    _ = win.AddClipboardFormatListener(hwnd);

    log.info("sync-to-remote started. Press Win+Alt+V to upload clipboard.", .{});

    // Message loop
    var msg: win.MSG = undefined;
    while (win.GetMessageW(&msg, null, 0, 0) != 0) {
        _ = win.TranslateMessage(&msg);
        _ = win.DispatchMessageW(&msg);
    }

    // Cleanup
    _ = win.RemoveClipboardFormatListener(hwnd);
    hotkey.unregister(hwnd);
    tray.cleanup(hwnd, g_hicon);
    _ = win.DestroyIcon(g_hicon);
}

fn wndProc(hwnd: win.HWND, msg: win.UINT, wparam: win.WPARAM, lparam: win.LPARAM) callconv(.winapi) win.LRESULT {
    switch (msg) {
        win.WM_CREATE => {
            return 0;
        },
        win.WM_DESTROY => {
            win.PostQuitMessage(0);
            return 0;
        },
        win.WM_HOTKEY => {
            onHotkey(hwnd);
            return 0;
        },
        win.WM_CLIPBOARDUPDATE => {
            if (g_auto_mode) {
                // Only auto-upload images (most common case for screenshots)
                if (win.IsClipboardFormatAvailable(win.CF_BITMAP) != 0 or
                    win.IsClipboardFormatAvailable(win.CF_DIB) != 0)
                {
                    onHotkey(hwnd);
                }
            }
            return 0;
        },
        win.WM_TRAYICON => {
            const lparam_low = @as(u32, @intCast(lparam & 0xFFFF));
            switch (tray.actionForTrayMouseMessage(lparam_low)) {
                .show_menu => tray.showContextMenu(hwnd, g_auto_mode),
                .ignore => {},
            }
            return 0;
        },
        win.WM_COMMAND => {
            const id = @as(i32, @intCast(wparam & 0xFFFF));
            switch (id) {
                tray.IDM_COPY => {
                    onHotkey(hwnd);
                    return 0;
                },
                win.IDM_EXIT => {
                    _ = win.DestroyWindow(hwnd);
                    return 0;
                },
                win.IDM_SETTINGS => {
                    onSettings(hwnd);
                    return 0;
                },
                tray.IDM_AUTO_MODE => {
                    g_auto_mode = !g_auto_mode;
                    updateAutoModeTray(hwnd);
                    return 0;
                },
                else => {},
            }
            return 0;
        },
        win.WM_USER + 100 => {
            // Dummy message for tray menu cleanup
            return 0;
        },
        WM_UPLOAD_COMPLETE => {
            const job: *UploadJob = @ptrFromInt(@as(usize, @intCast(lparam)));
            finishUpload(job);
            return 0;
        },
        else => {},
    }
    return win.DefWindowProcW(hwnd, msg, wparam, lparam);
}

/// Handle the hotkey press - upload clipboard content
fn onHotkey(hwnd: win.HWND) void {
    // Open clipboard to detect content
    const content_type = clipboard.detect();

    switch (content_type) {
        .empty => {
            _ = tray.showNotification(hwnd, g_hicon, &win.w("sync-to-remote"), &win.w("No file or image in clipboard"), win.NIIF_INFO);
            return;
        },
        else => {
            // Extract clipboard content to temp file
            const info = clipboard.extract(hwnd, g_allocator) catch |err| {
                const errMsg = std.fmt.allocPrint(g_allocator, "Failed to process clipboard: {}", .{err}) catch unreachable;
                defer g_allocator.free(errMsg);
                // Convert to UTF-16 for notification
                var errWide: [256]u16 = undefined;
                @memset(&errWide, 0);
                utf8To16(errMsg, &errWide);
                _ = tray.showNotification(hwnd, g_hicon, &win.w("Error"), @as([*:0]const u16, @ptrCast(&errWide)), win.NIIF_ERROR);
                return;
            } orelse {
                _ = tray.showNotification(hwnd, g_hicon, &win.w("sync-to-remote"), &win.w("No file or image in clipboard"), win.NIIF_INFO);
                return;
            };

            // Load config (get latest)
            const cfg = config.load(g_allocator) catch {
                _ = tray.showNotification(hwnd, g_hicon, &win.w("Error"), &win.w("Failed to load config"), win.NIIF_ERROR);
                return;
            };

            // Check if host is configured
            if (cfg.host[0] == 0) {
                _ = tray.showNotification(hwnd, g_hicon, &win.w("Not Configured"), &win.w("Open Settings to configure your SSH host"), win.NIIF_WARNING);
                return;
            }

            if (cfg.local_enabled) {
                const local_res = saveLocally(hwnd, &cfg, &info) catch |err| {
                    const errMsg = std.fmt.allocPrint(g_allocator, "Local save failed: {}", .{err}) catch unreachable;
                    defer g_allocator.free(errMsg);
                    var errWide: [256]u16 = undefined;
                    @memset(&errWide, 0);
                    utf8To16(errMsg, &errWide);
                    _ = tray.showNotification(hwnd, g_hicon, &win.w("Save Failed"), @as([*:0]const u16, @ptrCast(&errWide)), win.NIIF_ERROR);
                    if (info.content_type != .file) {
                        _ = win.DeleteFileW(@as([*:0]const u16, @ptrCast(&info.local_path)));
                    }
                    return;
                };
                if (local_res) {
                    // Cleanup temp file if we created it (not for native files)
                    if (info.content_type != .file) {
                        _ = win.DeleteFileW(@as([*:0]const u16, @ptrCast(&info.local_path)));
                    }
                }
                return;
            }

            startUpload(hwnd, cfg, info);
        },
    }
}

fn startUpload(hwnd: win.HWND, cfg: config.Config, info: clipboard.ClipboardInfo) void {
    const progress_window = progress.show(g_allocator, &win.w("Uploading to server...")) catch {
        _ = tray.showNotification(hwnd, g_hicon, &win.w("Error"), &win.w("Failed to open upload progress"), win.NIIF_ERROR);
        if (info.content_type != .file) {
            _ = win.DeleteFileW(@as([*:0]const u16, @ptrCast(&info.local_path)));
        }
        return;
    };

    const job = g_allocator.create(UploadJob) catch {
        progress.completeFailure(progress_window, &win.w("Could not start upload"));
        if (info.content_type != .file) {
            _ = win.DeleteFileW(@as([*:0]const u16, @ptrCast(&info.local_path)));
        }
        return;
    };
    job.* = .{ .owner = hwnd, .progress_window = progress_window, .cfg = cfg, .info = info };
    progress.attachJob(progress_window, job, destroyUploadJob);

    const thread = std.Thread.spawn(.{}, uploadWorker, .{job}) catch {
        progress.completeFailure(progress_window, &win.w("Could not start upload"));
        return;
    };
    thread.detach();
}

fn uploadWorker(job: *UploadJob) void {
    const result = sftp.upload(
        g_allocator,
        @as([*:0]const u16, @ptrCast(&job.cfg.host)),
        job.cfg.port,
        @as([*:0]const u16, @ptrCast(&job.cfg.username)),
        @as([*:0]const u16, @ptrCast(&job.cfg.remote_path)),
        @as([*:0]const u16, @ptrCast(&job.info.local_path)),
        @as([*:0]const u16, @ptrCast(&job.info.remote_filename)),
    ) catch |err| {
        var buffer: [128]u8 = undefined;
        const message = std.fmt.bufPrint(&buffer, "Upload failed: {}", .{err}) catch "Upload failed";
        utf8To16(message, &job.error_text);
        job.outcome = .failure;
        _ = PostMessageW(job.owner, WM_UPLOAD_COMPLETE, 0, @as(win.LPARAM, @intCast(@intFromPtr(job))));
        return;
    };

    switch (result) {
        .success => job.outcome = .success,
        .err => |message| {
            utf8To16(message, &job.error_text);
            job.outcome = .failure;
        },
    }
    _ = PostMessageW(job.owner, WM_UPLOAD_COMPLETE, 0, @as(win.LPARAM, @intCast(@intFromPtr(job))));
}

fn finishUpload(job: *UploadJob) void {
    if (job.outcome == .failure) {
        progress.completeFailure(job.progress_window, @as([*:0]const u16, @ptrCast(&job.error_text)));
        return;
    }

    var clip_ref: [1026]u16 = [_]u16{0} ** 1026;
    clip_ref[0] = '@';
    var ci: usize = 1;
    var i: usize = 0;
    while (job.cfg.remote_path[i] != 0 and ci < clip_ref.len - 1) : (i += 1) {
        clip_ref[ci] = job.cfg.remote_path[i];
        ci += 1;
    }
    if (ci > 1 and clip_ref[ci - 1] != '/') {
        clip_ref[ci] = '/';
        ci += 1;
    }
    i = 0;
    while (job.info.remote_filename[i] != 0 and ci < clip_ref.len - 1) : (i += 1) {
        clip_ref[ci] = job.info.remote_filename[i];
        ci += 1;
    }
    setClipboardText(job.owner, @as([*:0]const u16, @ptrCast(&clip_ref)));
    progress.completeSuccess(job.progress_window);
}

fn destroyUploadJob(raw_job: *anyopaque, allocator: std.mem.Allocator) void {
    const job: *UploadJob = @ptrCast(@alignCast(raw_job));
    if (job.info.content_type != .file) {
        _ = win.DeleteFileW(@as([*:0]const u16, @ptrCast(&job.info.local_path)));
    }
    allocator.destroy(job);
}

fn saveLocally(hwnd: win.HWND, cfg: *const config.Config, info: *const clipboard.ClipboardInfo) !bool {
    // Determine output directory: cfg.local_dir if set, otherwise short TEMP + "\\sync-to-remote"
    var out_dir: [512]u16 = undefined;
    @memset(&out_dir, 0);

    if (cfg.local_dir[0] != 0) {
        @memcpy(&out_dir, &cfg.local_dir);
    } else {
        var temp: [win.MAX_PATH]u16 = undefined;
        @memset(&temp, 0);
        const tlen = win.GetTempPathW(@as(win.DWORD, win.MAX_PATH), &temp);
        if (tlen == 0 or tlen > win.MAX_PATH) return error.NoTempPath;

        // Prefer a short path to avoid spaces; fall back to the long temp path.
        var temp_short: [win.MAX_PATH]u16 = undefined;
        @memset(&temp_short, 0);
        const slen = win.GetShortPathNameW(@as([*:0]const u16, @ptrCast(&temp)), &temp_short, win.MAX_PATH);
        const base = if (slen != 0 and slen < win.MAX_PATH) temp_short else temp;

        var oi: usize = 0;
        while (oi < out_dir.len - 1 and base[oi] != 0) : (oi += 1) out_dir[oi] = base[oi];
        if (oi > 0 and out_dir[oi - 1] != '\\') {
            out_dir[oi] = '\\';
            oi += 1;
        }
        for ("sync-to-remote", 0..) |c, i| {
            if (oi + i >= out_dir.len - 1) break;
            out_dir[oi + i] = c;
        }
        out_dir[@min(oi + "sync-to-remote".len, out_dir.len - 1)] = 0;
    }

    // Ensure output directory exists (single-level; user can pick an existing nested folder).
    _ = win.CreateDirectoryW(@as([*:0]const u16, @ptrCast(&out_dir)), null);

    // Build destination file path: <out_dir>\<filename>
    var dest: [1024]u16 = undefined;
    @memset(&dest, 0);
    var di: usize = 0;
    while (di < dest.len - 1 and out_dir[di] != 0) : (di += 1) dest[di] = out_dir[di];
    if (di > 0 and dest[di - 1] != '\\') {
        dest[di] = '\\';
        di += 1;
    }

    var fi: usize = 0;
    while (di < dest.len - 1 and info.remote_filename[fi] != 0) : ({
        di += 1;
        fi += 1;
    }) dest[di] = info.remote_filename[fi];
    dest[di] = 0;

    // Copy source file to destination (overwrite)
    _ = win.DeleteFileW(@as([*:0]const u16, @ptrCast(&dest)));
    if (win.CopyFileW(
        @as([*:0]const u16, @ptrCast(&info.local_path)),
        @as([*:0]const u16, @ptrCast(&dest)),
        win.FALSE,
    ) == 0) return error.CopyFailed;

    // Clipboard reference: "@<full local path>" (single leading '@')
    var clip_ref: [1026]u16 = undefined;
    @memset(&clip_ref, 0);
    clip_ref[0] = '@';
    var ci: usize = 0;
    while (ci + 1 < clip_ref.len - 1 and dest[ci] != 0) : (ci += 1) clip_ref[ci + 1] = dest[ci];
    clip_ref[ci + 1] = 0;
    setClipboardText(hwnd, @as([*:0]const u16, @ptrCast(&clip_ref)));

    _ = tray.showNotification(hwnd, g_hicon, &win.w("Saved Locally"), &win.w("Copied local reference to clipboard"), win.NIIF_INFO);
    return true;
}

/// Open settings dialog
fn onSettings(hwnd: win.HWND) void {
    const cfg = config.load(g_allocator) catch config.Config.default();
    if (gui.show(hwnd, g_allocator, cfg)) |new_cfg| {
        var to_save = new_cfg;
        config.save(&to_save) catch {
            _ = tray.showNotification(hwnd, g_hicon, &win.w("Error"), &win.w("Failed to save settings"), win.NIIF_ERROR);
        };
    }
}

fn updateAutoModeTray(hwnd: win.HWND) void {
    if (g_auto_mode) {
        _ = tray.updateTooltip(hwnd, g_hicon, &[_:0]u16{ 's', 'y', 'n', 'c', '-', 't', 'o', '-', 'r', 'e', 'm', 'o', 't', 'e', ' ', '[', 'A', 'u', 't', 'o', ' ', 'M', 'o', 'd', 'e', ']' });
    } else {
        _ = tray.updateTooltip(hwnd, g_hicon, &[_:0]u16{ 's', 'y', 'n', 'c', '-', 't', 'o', '-', 'r', 'e', 'm', 'o', 't', 'e' });
    }
}

/// Set clipboard text to a UTF-16 string
fn setClipboardText(hwnd: win.HWND, text: [*:0]const u16) void {
    if (win.OpenClipboard(hwnd) == 0) return;
    defer _ = win.CloseClipboard();

    _ = win.EmptyClipboard();

    // Calculate string length
    var len: usize = 0;
    while (text[len] != 0) : (len += 1) {}

    // Allocate global memory
    const hmem = win.GlobalAlloc(0x0042, (len + 1) * 2) orelse return; // GHND = GMEM_MOVEABLE | GMEM_ZEROINIT
    const ptr = win.GlobalLock(hmem) orelse {
        _ = win.GlobalFree(hmem);
        return;
    };

    // Copy string
    @memcpy(@as([*]u16, @ptrCast(@alignCast(ptr)))[0 .. len + 1], text[0 .. len + 1]);

    _ = win.GlobalUnlock(hmem);
    _ = win.SetClipboardData(win.CF_UNICODETEXT, hmem);
}

/// Load the icon from embedded resource data
fn loadIcon() ?win.HICON {
    const icon_data = @embedFile("icon.ico");

    // Get temp path
    var temp_path: [260]u16 = undefined;
    if (win.GetTempPathW(260, &temp_path) == 0) return null;

    // Create temp file name
    var temp_file: [260]u16 = undefined;
    @memset(&temp_file, 0);
    var i: usize = 0;
    while (temp_path[i] != 0 and i < 260) : (i += 1) {
        temp_file[i] = temp_path[i];
    }
    var j: usize = 0;
    const prefix = "sync-to-remote-icon.ico";
    while (prefix[j] != 0 and i + j < 259) : (j += 1) {
        temp_file[i + j] = prefix[j];
    }
    temp_file[i + j] = 0;

    // Write to temp file
    var wszTempFile: [260]u16 = undefined;
    @memset(&wszTempFile, 0);
    @memcpy(&wszTempFile, &temp_file);

    // Create file
    const hFile = win.CreateFileW(
        @as([*:0]const u16, @ptrCast(&wszTempFile)),
        win.GENERIC_WRITE,
        win.FILE_SHARE_READ,
        null,
        win.CREATE_ALWAYS,
        win.FILE_ATTRIBUTE_NORMAL,
        null,
    );
    if (hFile) |hf| {
        defer _ = win.CloseHandle(hf);
        var written: win.DWORD = 0;
        _ = win.WriteFile(hf, icon_data.ptr, @as(win.DWORD, @intCast(icon_data.len)), &written, null);
    } else {
        return null;
    }

    // Load the icon from temp file
    const hicon = win.LoadImageW(
        null,
        @as([*:0]const u16, @ptrCast(&wszTempFile)),
        win.IMAGE_ICON,
        32,
        32,
        win.LR_LOADFROMFILE,
    );

    // Delete temp file
    _ = win.DeleteFileW(@as([*:0]const u16, @ptrCast(&wszTempFile)));

    return @as(?win.HICON, @ptrCast(hicon));
}

/// Convert a UTF-8 string to a UTF-16 buffer (null-terminated)
fn utf8To16(src: []const u8, dest: []u16) void {
    var di: usize = 0;
    var si: usize = 0;
    while (si < src.len and di < dest.len - 1) {
        const cp: u21 = blk: {
            const b0 = src[si];
            if (b0 < 0x80) {
                si += 1;
                break :blk b0;
            } else if (b0 < 0xE0) {
                const b1 = src[si + 1];
                si += 2;
                break :blk @as(u21, b0 & 0x1F) << 6 | @as(u21, b1 & 0x3F);
            } else if (b0 < 0xF0) {
                const b1 = src[si + 1];
                const b2 = src[si + 2];
                si += 3;
                break :blk @as(u21, b0 & 0x0F) << 12 | @as(u21, b1 & 0x3F) << 6 | @as(u21, b2 & 0x3F);
            } else {
                const b1 = src[si + 1];
                const b2 = src[si + 2];
                const b3 = src[si + 3];
                si += 4;
                break :blk @as(u21, b0 & 0x07) << 18 | @as(u21, b1 & 0x3F) << 12 | @as(u21, b2 & 0x3F) << 6 | @as(u21, b3 & 0x3F);
            }
        };
        if (cp <= 0xFFFF) {
            dest[di] = @as(u16, @intCast(cp));
            di += 1;
        } else {
            // Surrogate pair (unlikely for our use case)
            const cp2 = cp - 0x10000;
            if (di + 1 < dest.len - 1) {
                dest[di] = @as(u16, @intCast(0xD800 | (cp2 >> 10)));
                dest[di + 1] = @as(u16, @intCast(0xDC00 | (cp2 & 0x3FF)));
                di += 2;
            }
        }
    }
    dest[di] = 0;
}

// External functions
extern "user32" fn FindWindowW(lpClassName: ?[*:0]const u16, lpWindowName: ?[*:0]const u16) callconv(.winapi) win.HWND;
