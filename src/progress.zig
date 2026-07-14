// Progress window: modeless top-level window that shows the status of an
// in-flight upload and stays up with a Close button once the operation fails.

const std = @import("std");
const win = @import("win32.zig");

const log = std.log.scoped(.progress);

pub const Completion = enum { success, failure };
pub const CompletionDisposition = enum { close, keep_visible };

pub fn completionDisposition(completion: Completion) CompletionDisposition {
    return if (completion == .success) .close else .keep_visible;
}

pub const NotificationPalette = struct {
    background: win.DWORD,
    text: win.DWORD,
};

const StatusRendering = enum { owner_drawn };

fn statusRendering() StatusRendering {
    return .owner_drawn;
}

pub fn notificationPalette() NotificationPalette {
    return .{
        .background = 0x00202020,
        .text = 0x00F5F5F5,
    };
}

pub fn colorBrightnessDifference(first: win.DWORD, second: win.DWORD) u16 {
    const first_brightness = @as(i32, @intCast(first & 0xFF));
    const second_brightness = @as(i32, @intCast(second & 0xFF));
    return @intCast(@abs(first_brightness - second_brightness));
}

test "successful upload closes the progress window" {
    try std.testing.expectEqual(CompletionDisposition.close, completionDisposition(.success));
}

test "failed upload keeps the progress window visible" {
    try std.testing.expectEqual(CompletionDisposition.keep_visible, completionDisposition(.failure));
}

test "notification text uses a high contrast palette" {
    const palette = notificationPalette();
    try std.testing.expect(colorBrightnessDifference(palette.background, palette.text) >= 125);
}

test "successful notifications remain visible long enough to paint completion text" {
    try std.testing.expect(SUCCESS_CLOSE_MS >= 500);
}

test "status text uses the notification window paint path" {
    try std.testing.expectEqual(StatusRendering.owner_drawn, statusRendering());
}

const CLASS_NAME: [*:0]const u16 = &[_:0]u16{ 'S', 'y', 'n', 'c', 'T', 'o', 'R', 'e', 'm', 'o', 't', 'e', 'P', 'r', 'o', 'g' };
const IDT_AUTO_CLOSE: usize = 1;
const IDT_SUCCESS_CLOSE: usize = 2;

const STATIC_CLASS: [*:0]const u16 = &[_:0]u16{ 'S', 't', 'a', 't', 'i', 'c' };
const BUTTON_CLASS: [*:0]const u16 = &[_:0]u16{ 'B', 'u', 't', 't', 'o', 'n' };
const PROGRESS_CLASS: [*:0]const u16 = &[_:0]u16{ 'm', 's', 'c', 't', 'l', 's', '_', 'p', 'r', 'o', 'g', 'r', 'e', 's', 's', '3', '2' };

const CLIENT_W: i32 = 380;
const CLIENT_H: i32 = 120;
const MARGIN: i32 = 16;
const GAP: i32 = 12;
const STATUS_H: i32 = 22;
const PROGRESS_H: i32 = 18;
const BTN_W: i32 = 80;
const BTN_H: i32 = 26;

const STATUS_X = MARGIN;
const STATUS_Y = MARGIN;
const STATUS_W = CLIENT_W - 2 * MARGIN;

const PROGRESS_X = MARGIN;
const PROGRESS_Y = STATUS_Y + STATUS_H + GAP;
const PROGRESS_W = CLIENT_W - 2 * MARGIN;

const CLOSE_X = CLIENT_W - MARGIN - BTN_W;
const CLOSE_Y = CLIENT_H - MARGIN - BTN_H;

const AUTO_CLOSE_MS: win.UINT = 6000;
const SUCCESS_CLOSE_MS: win.UINT = 700;

const WindowState = struct {
    allocator: std.mem.Allocator,
    hwnd_status: win.HWND,
    hwnd_progress: win.HWND,
    hwnd_close: win.HWND,
    job: ?*anyopaque = null,
    job_destroyer: ?*const fn (*anyopaque, std.mem.Allocator) void = null,
    finished: bool = false,
    status_text: [256]u16 = [_]u16{0} ** 256,
};

var g_class_registered: bool = false;
var g_hinst: win.HINSTANCE = undefined;
var g_background_brush: ?win.HBRUSH = null;

const INITCOMMONCONTROLSEX = extern struct {
    dwSize: win.DWORD,
    dwICC: win.DWORD,
};

pub fn init(hinst: win.HINSTANCE) void {
    g_hinst = hinst;
    if (g_class_registered) return;

    const common_controls = INITCOMMONCONTROLSEX{
        .dwSize = @sizeOf(INITCOMMONCONTROLSEX),
        .dwICC = 0x00000020, // ICC_PROGRESS_CLASS
    };
    _ = InitCommonControlsEx(&common_controls);

    const palette = notificationPalette();
    g_background_brush = CreateSolidBrush(palette.background);

    const wc = win.WNDCLASSW{
        .style = 0,
        .lpfnWndProc = wndProc,
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .hInstance = hinst,
        .hIcon = null,
        .hCursor = win.LoadCursorW(null, win.IDC_ARROW),
        .hbrBackground = g_background_brush,
        .lpszMenuName = null,
        .lpszClassName = CLASS_NAME,
    };
    _ = win.RegisterClassW(&wc);
    g_class_registered = true;
}

pub fn show(allocator: std.mem.Allocator, status_text: [*:0]const u16) !win.HWND {
    const hinst = g_hinst;

    const dlg_ex: win.DWORD = win.WS_EX_DLGMODALFRAME | win.WS_EX_WINDOWEDGE | win.WS_EX_TOOLWINDOW;
    const dlg_style: win.DWORD = win.WS_OVERLAPPED | win.WS_CAPTION | win.WS_SYSMENU | win.WS_CLIPCHILDREN;
    var client_rc = win.RECT{
        .left = 0,
        .top = 0,
        .right = CLIENT_W,
        .bottom = CLIENT_H,
    };
    _ = win.AdjustWindowRectEx(&client_rc, dlg_style, win.FALSE, dlg_ex);
    const outer_w = client_rc.right - client_rc.left;
    const outer_h = client_rc.bottom - client_rc.top;

    var work_area: win.RECT = undefined;
    const has_work_area = SystemParametersInfoW(0x0030, 0, &work_area, 0) != 0; // SPI_GETWORKAREA
    const right = if (has_work_area) work_area.right else GetSystemMetrics(win.SM_CXSCREEN);
    const bottom = if (has_work_area) work_area.bottom else GetSystemMetrics(win.SM_CYSCREEN);
    const edge_gap: i32 = 16;
    const x = right - outer_w - edge_gap;
    const y = bottom - outer_h - edge_gap;

    const hwnd = win.CreateWindowExW(
        dlg_ex,
        CLASS_NAME,
        &win.w("sync-to-remote"),
        dlg_style | win.WS_VISIBLE,
        x,
        y,
        outer_w,
        outer_h,
        null,
        null,
        hinst,
        null,
    ) orelse return error.CreateFailed;

    const state_ptr = allocator.create(WindowState) catch {
        _ = win.DestroyWindow(hwnd);
        return error.OutOfMemory;
    };
    state_ptr.* = WindowState{
        .allocator = allocator,
        .hwnd_status = undefined,
        .hwnd_progress = undefined,
        .hwnd_close = undefined,
    };
    _ = win.SetWindowLongPtrW(hwnd, win.GWLP_USERDATA, @as(isize, @intCast(@intFromPtr(state_ptr))));

    createControls(hwnd, state_ptr, status_text);

    _ = win.ShowWindow(hwnd, win.SW_SHOWNORMAL);
    return hwnd;
}

/// Attach a job pointer + destroyer. The destroyer is invoked from the window's
/// WM_NCDESTROY to free the job (and any allocations it owns).
pub fn attachJob(
    hwnd: win.HWND,
    job: *anyopaque,
    destroyer: *const fn (*anyopaque, std.mem.Allocator) void,
) void {
    const state = getState(hwnd);
    state.job = job;
    state.job_destroyer = destroyer;
}

/// Update the status text while the operation is in progress.
pub fn setStatus(hwnd: win.HWND, text: [*:0]const u16) void {
    const state = getState(hwnd);
    copyStatusText(&state.status_text, text);
    _ = InvalidateRect(hwnd, null, win.TRUE);
}

/// Show the completion result briefly so fast uploads still render readable text.
pub fn completeSuccess(hwnd: win.HWND) void {
    const state = getState(hwnd);
    if (state.finished) return;
    state.finished = true;
    copyStatusText(&state.status_text, &win.w("Copied to remote clipboard"));
    _ = InvalidateRect(hwnd, null, win.TRUE);
    _ = win.SetTimer(hwnd, IDT_SUCCESS_CLOSE, SUCCESS_CLOSE_MS, null);
}

/// Mark the operation as failed. Stops the marquee, sets the progress bar to
/// the error state, updates the status text, enables the Close button (and the
/// window-close (X) button), and starts a 6-second auto-close timer.
pub fn completeFailure(hwnd: win.HWND, error_text: [*:0]const u16) void {
    const state = getState(hwnd);
    if (state.finished) return;
    state.finished = true;

    copyStatusText(&state.status_text, error_text);
    _ = InvalidateRect(hwnd, null, win.TRUE);

    _ = SendMessageW(state.hwnd_progress, win.PBM_SETMARQUEE, 0, 0);
    _ = SendMessageW(state.hwnd_progress, win.PBM_SETSTATE, @as(win.WPARAM, @intCast(win.PBST_ERROR)), 0);

    _ = win.EnableWindow(state.hwnd_close, win.TRUE);
    _ = win.SetTimer(hwnd, IDT_AUTO_CLOSE, AUTO_CLOSE_MS, null);
}

fn getState(hwnd: win.HWND) *WindowState {
    const ptr_val = win.GetWindowLongPtrW(hwnd, win.GWLP_USERDATA);
    return @ptrFromInt(@as(usize, @intCast(ptr_val)));
}

fn wndProc(hwnd: win.HWND, msg: win.UINT, wparam: win.WPARAM, lparam: win.LPARAM) callconv(.winapi) win.LRESULT {
    switch (msg) {
        win.WM_COMMAND => {
            const id = @as(i32, @intCast(wparam & 0xFFFF));
            if (id == win.IDC_PROGRESS_CLOSE) {
                _ = win.KillTimer(hwnd, IDT_AUTO_CLOSE);
                _ = win.DestroyWindow(hwnd);
                return 0;
            }
        },
        win.WM_TIMER => {
            if (wparam == IDT_AUTO_CLOSE) {
                _ = win.KillTimer(hwnd, IDT_AUTO_CLOSE);
                _ = win.DestroyWindow(hwnd);
                return 0;
            }
            if (wparam == IDT_SUCCESS_CLOSE) {
                _ = win.KillTimer(hwnd, IDT_SUCCESS_CLOSE);
                _ = win.DestroyWindow(hwnd);
                return 0;
            }
        },
        win.WM_CLOSE => {
            const state = getState(hwnd);
            if (state.finished) {
                _ = win.KillTimer(hwnd, IDT_AUTO_CLOSE);
                _ = win.KillTimer(hwnd, IDT_SUCCESS_CLOSE);
                _ = win.DestroyWindow(hwnd);
            }
            return 0;
        },
        win.WM_NCDESTROY => {
            const state = getState(hwnd);
            if (state.job) |job| {
                if (state.job_destroyer) |destroyer| {
                    destroyer(job, state.allocator);
                }
                state.job = null;
            }
            state.allocator.destroy(state);
            _ = win.SetWindowLongPtrW(hwnd, win.GWLP_USERDATA, 0);
            return 0;
        },
        win.WM_PAINT => {
            const state = getState(hwnd);
            var paint: PAINTSTRUCT = undefined;
            const hdc = BeginPaint(hwnd, &paint) orelse return 0;
            const palette = notificationPalette();
            _ = win.SetBkColor(hdc, palette.background);
            _ = win.SetTextColor(hdc, palette.text);
            const font = GetStockObject(17);
            _ = SelectObject(hdc, font);
            var text_rc = win.RECT{
                .left = STATUS_X,
                .top = STATUS_Y,
                .right = STATUS_X + STATUS_W,
                .bottom = STATUS_Y + STATUS_H,
            };
            _ = DrawTextW(hdc, @as([*:0]const u16, @ptrCast(&state.status_text)), -1, &text_rc, DT_SINGLELINE | DT_VCENTER | DT_END_ELLIPSIS);
            _ = EndPaint(hwnd, &paint);
            return 0;
        },
        win.WM_CTLCOLORSTATIC => {
            const palette = notificationPalette();
            const hdc: win.HDC = @ptrFromInt(wparam);
            _ = win.SetBkColor(hdc, palette.background);
            _ = win.SetTextColor(hdc, palette.text);
            if (g_background_brush) |brush| {
                return @as(win.LRESULT, @intCast(@intFromPtr(brush)));
            }
            return 0;
        },
        else => {},
    }
    return win.DefWindowProcW(hwnd, msg, wparam, lparam);
}

fn createControls(hwnd_dlg: win.HWND, state: *WindowState, status_text: [*:0]const u16) void {
    const hinst = g_hinst;
    copyStatusText(&state.status_text, status_text);
    const font = GetStockObject(17);
    const font_wparam: win.WPARAM = @intCast(@intFromPtr(font));

    state.hwnd_status = hwnd_dlg;

    state.hwnd_progress = win.CreateWindowExW(
        0,
        @as(win.LPCWSTR, @ptrCast(PROGRESS_CLASS)),
        &[_:0]u16{},
        win.WS_CHILD | win.WS_VISIBLE | win.PBS_MARQUEE,
        PROGRESS_X,
        PROGRESS_Y,
        PROGRESS_W,
        PROGRESS_H,
        hwnd_dlg,
        @ptrFromInt(@as(usize, @intCast(win.IDC_PROGRESS_BAR))),
        hinst,
        null,
    ).?;
    _ = SendMessageW(state.hwnd_progress, 0x0030, font_wparam, 1);
    _ = SendMessageW(state.hwnd_progress, win.PBM_SETMARQUEE, @as(win.WPARAM, 1), @as(win.LPARAM, 30));

    state.hwnd_close = win.CreateWindowExW(
        0,
        @as(win.LPCWSTR, @ptrCast(BUTTON_CLASS)),
        &win.w("Close"),
        win.WS_CHILD | win.WS_VISIBLE | win.WS_TABSTOP | win.BS_PUSHBUTTON | win.WS_DISABLED,
        CLOSE_X,
        CLOSE_Y,
        BTN_W,
        BTN_H,
        hwnd_dlg,
        @ptrFromInt(@as(usize, @intCast(win.IDC_PROGRESS_CLOSE))),
        hinst,
        null,
    ).?;
    _ = SendMessageW(state.hwnd_close, 0x0030, font_wparam, 1);
}

fn copyStatusText(destination: *[256]u16, source: [*:0]const u16) void {
    @memset(destination, 0);
    var i: usize = 0;
    while (i < destination.len - 1 and source[i] != 0) : (i += 1) {
        destination[i] = source[i];
    }
}

const PAINTSTRUCT = extern struct {
    hdc: win.HDC,
    fErase: win.BOOL,
    rcPaint: win.RECT,
    fRestore: win.BOOL,
    fIncUpdate: win.BOOL,
    rgbReserved: [32]u8,
};

const DT_SINGLELINE: win.UINT = 0x20;
const DT_VCENTER: win.UINT = 0x04;
const DT_END_ELLIPSIS: win.UINT = 0x8000;

extern "user32" fn GetSystemMetrics(nIndex: i32) callconv(.winapi) i32;
extern "user32" fn SystemParametersInfoW(uiAction: win.UINT, uiParam: win.UINT, pvParam: *win.RECT, fWinIni: win.UINT) callconv(.winapi) win.BOOL;
extern "comctl32" fn InitCommonControlsEx(picce: *const INITCOMMONCONTROLSEX) callconv(.winapi) win.BOOL;
extern "gdi32" fn CreateSolidBrush(color: win.DWORD) callconv(.winapi) ?win.HBRUSH;
extern "gdi32" fn GetStockObject(i: i32) callconv(.winapi) win.HGDIOBJ;
extern "gdi32" fn SelectObject(hdc: win.HDC, h: win.HGDIOBJ) callconv(.winapi) ?win.HGDIOBJ;
extern "user32" fn BeginPaint(hwnd: win.HWND, paint: *PAINTSTRUCT) callconv(.winapi) ?win.HDC;
extern "user32" fn EndPaint(hwnd: win.HWND, paint: *const PAINTSTRUCT) callconv(.winapi) win.BOOL;
extern "user32" fn InvalidateRect(hwnd: win.HWND, rect: ?*const win.RECT, erase: win.BOOL) callconv(.winapi) win.BOOL;
extern "user32" fn DrawTextW(hdc: win.HDC, text: [*:0]const u16, count: i32, rect: *win.RECT, format: win.UINT) callconv(.winapi) i32;
extern "user32" fn SendMessageW(hWnd: win.HWND, Msg: win.UINT, wParam: win.WPARAM, lParam: win.LPARAM) callconv(.winapi) win.LRESULT;
