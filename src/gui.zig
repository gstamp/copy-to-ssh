// Settings dialog for sync-to-remote
// Simple Win32 dialog with text fields for host, port, username, remote_path

const std = @import("std");
const win = @import("win32.zig");
const config = @import("config.zig");

const log = std.log.scoped(.gui);

/// Layout is in **client** coordinates; the window outer size is derived with AdjustWindowRectEx.
const CLIENT_W: i32 = 460;
const CLIENT_H: i32 = 364;
const MARGIN_X: i32 = 16;
const MARGIN_Y: i32 = 12;
const TITLE_H: i32 = 28;
const LABEL_W: i32 = 118;
const GAP_LABEL_EDIT: i32 = 10;
const EDIT_H: i32 = 24;
const ROW_STEP: i32 = 36;
const BTN_W: i32 = 92;
const BTN_H: i32 = 28;
const BTN_GAP: i32 = 10;

const LABEL_X = MARGIN_X;
const EDIT_X = LABEL_X + LABEL_W + GAP_LABEL_EDIT;
const EDIT_W = CLIENT_W - EDIT_X - MARGIN_X;
const TITLE_Y = MARGIN_Y;
const START_Y = TITLE_Y + TITLE_H + 8;
const BTN_Y = CLIENT_H - MARGIN_Y - BTN_H;
const TITLE_STATIC_W = CLIENT_W - 2 * MARGIN_X;

/// State passed to the dialog procedure
const DialogState = struct {
    allocator: std.mem.Allocator,
    cfg: config.Config,
    is_saved: bool = false,
};

/// Show the settings dialog (modal)
pub fn show(hwnd_parent: win.HWND, allocator: std.mem.Allocator, cfg: config.Config) ?config.Config {
    _ = hwnd_parent; // Not used directly - created as top-level window
    const hinst = win.GetModuleHandleW(null) orelse return null;

    // Register dialog window class
    const class_name: [*:0]const u16 = &[_:0]u16{ 'S', 'y', 'n', 'c', 'T', 'o', 'R', 'e', 'm', 'o', 't', 'e', 'D', 'l', 'g' };

    const wc = win.WNDCLASSW{
        .style = win.CS_HREDRAW | win.CS_VREDRAW,
        .lpfnWndProc = dialogProc,
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .hInstance = hinst,
        .hIcon = null,
        .hCursor = win.LoadCursorW(null, win.IDC_ARROW),
        .hbrBackground = @ptrFromInt(@as(usize, @intCast(win.COLOR_WINDOW + 1))),
        .lpszMenuName = null,
        .lpszClassName = class_name,
    };

    _ = win.RegisterClassW(&wc);

    const dlg_ex: win.DWORD = win.WS_EX_DLGMODALFRAME | win.WS_EX_WINDOWEDGE;
    const dlg_style: win.DWORD = win.WS_OVERLAPPED | win.WS_CAPTION | win.WS_SYSMENU | win.WS_CLIPCHILDREN | win.WS_CLIPSIBLINGS;
    var client_rc = win.RECT{
        .left = 0,
        .top = 0,
        .right = CLIENT_W,
        .bottom = CLIENT_H,
    };
    _ = win.AdjustWindowRectEx(&client_rc, dlg_style, win.FALSE, dlg_ex);
    const outer_w = client_rc.right - client_rc.left;
    const outer_h = client_rc.bottom - client_rc.top;

    // Create the dialog window - use null parent to ensure it's top-level
    const hwnd_dlg = win.CreateWindowExW(
        dlg_ex,
        class_name,
        &[_:0]u16{ 's', 'y', 'n', 'c', '-', 't', 'o', '-', 'r', 'e', 'm', 'o', 't', 'e', ' ', 'S', 'e', 't', 't', 'i', 'n', 'g', 's' },
        dlg_style | win.WS_VISIBLE,
        0, 0, outer_w, outer_h,
        null, // No parent - top-level window
        null,
        hinst,
        null,
    ) orelse return null;

    // Center the window
    centerWindow(hwnd_dlg);

    // Store state
    const state_ptr = allocator.create(DialogState) catch return null;
    state_ptr.* = DialogState{
        .allocator = allocator,
        .cfg = cfg,
    };
    _ = win.SetWindowLongPtrW(hwnd_dlg, win.GWLP_USERDATA, @as(isize, @intCast(@intFromPtr(state_ptr))));

    // Create controls
    createControls(hwnd_dlg, &state_ptr.cfg);

    // Show and activate the window
    _ = win.ShowWindow(hwnd_dlg, win.SW_SHOWNORMAL);
    _ = win.SetForegroundWindow(hwnd_dlg);
    _ = win.UpdateWindow(hwnd_dlg);

    // Modal message loop — IsDialogMessage enables Tab / Shift+Tab between WS_TABSTOP controls.
    var msg: win.MSG = undefined;
    while (win.GetMessageW(&msg, null, 0, 0) > 0) {
        if (win.IsDialogMessageW(hwnd_dlg, &msg) == 0) {
            _ = win.TranslateMessage(&msg);
            _ = win.DispatchMessageW(&msg);
        }
        if (win.IsWindow(hwnd_dlg) == 0) break;
    }

    const result = state_ptr.cfg;
    const saved = state_ptr.is_saved;
    allocator.destroy(state_ptr);

    if (saved) return result;
    return null;
}

fn createControls(hwnd_dlg: win.HWND, cfg: *const config.Config) void {
    // Title label (full client width so long text wraps)
    _ = createStatic(hwnd_dlg, &win.w("Configure your SSH connection:"), MARGIN_X, TITLE_Y, TITLE_STATIC_W, TITLE_H);

    // Host
    _ = createStatic(hwnd_dlg, &win.w("Host:"), LABEL_X, START_Y, LABEL_W, EDIT_H);
    _ = createEdit(hwnd_dlg, win.IDC_HOST, @as([*:0]const u16, @ptrCast(&cfg.host)), EDIT_X, START_Y, EDIT_W, EDIT_H);

    // Port
    var port_str: [16]u16 = undefined;
    @memset(&port_str, 0);
    var p = cfg.port;
    if (p == 0) {
        port_str[0] = '2';
        port_str[1] = '2';
    } else {
        var digits: [5]u16 = undefined;
        var dc: usize = 0;
        while (p > 0) {
            digits[dc] = @as(u16, @intCast('0' + (p % 10)));
            p /= 10;
            dc += 1;
        }
        var j: usize = 0;
        while (j < dc) : (j += 1) {
            port_str[j] = digits[dc - 1 - j];
        }
    }

    const y1 = START_Y + ROW_STEP;
    _ = createStatic(hwnd_dlg, &win.w("Port:"), LABEL_X, y1, LABEL_W, EDIT_H);
    _ = createEdit(hwnd_dlg, win.IDC_PORT, @as([*:0]const u16, @ptrCast(&port_str)), EDIT_X, y1, EDIT_W, EDIT_H);

    // Username
    const y2 = START_Y + ROW_STEP * 2;
    _ = createStatic(hwnd_dlg, &win.w("Username:"), LABEL_X, y2, LABEL_W, EDIT_H);
    _ = createEdit(hwnd_dlg, win.IDC_USERNAME, @as([*:0]const u16, @ptrCast(&cfg.username)), EDIT_X, y2, EDIT_W, EDIT_H);

    // Remote Path
    const y3 = START_Y + ROW_STEP * 3;
    _ = createStatic(hwnd_dlg, &win.w("Remote Path:"), LABEL_X, y3, LABEL_W, EDIT_H);
    _ = createEdit(hwnd_dlg, win.IDC_REMOTE_PATH, @as([*:0]const u16, @ptrCast(&cfg.remote_path)), EDIT_X, y3, EDIT_W, EDIT_H);

    // Local mode
    const y4 = START_Y + ROW_STEP * 4;
    _ = createCheckbox(hwnd_dlg, &win.w("Save locally (no SFTP)"), win.IDC_LOCAL_MODE, EDIT_X, y4, EDIT_W, EDIT_H, cfg.local_enabled);

    // Local output directory
    const y5 = START_Y + ROW_STEP * 5;
    _ = createStatic(hwnd_dlg, &win.w("Local Folder:"), LABEL_X, y5, LABEL_W, EDIT_H);
    _ = createEdit(hwnd_dlg, win.IDC_LOCAL_DIR, @as([*:0]const u16, @ptrCast(&cfg.local_dir)), EDIT_X, y5, EDIT_W, EDIT_H);

    // Buttons — anchored to bottom-right of client area
    const cancel_x = CLIENT_W - MARGIN_X - BTN_W;
    const save_x = cancel_x - BTN_GAP - BTN_W;
    _ = createButton(hwnd_dlg, &win.w("Save"), win.IDC_SAVE_BTN, save_x, BTN_Y, BTN_W, BTN_H);
    _ = createButton(hwnd_dlg, &win.w("Cancel"), win.IDC_CANCEL_BTN, cancel_x, BTN_Y, BTN_W, BTN_H);
}

fn dialogProc(hwnd: win.HWND, msg: win.UINT, wparam: win.WPARAM, lparam: win.LPARAM) callconv(.winapi) win.LRESULT {
    switch (msg) {
        win.WM_CTLCOLORSTATIC, win.WM_CTLCOLOREDIT, win.WM_CTLCOLORBTN => {
            const hdc: win.HDC = @as(win.HDC, @ptrFromInt(wparam));
            _ = win.SetBkColor(hdc, win.GetSysColor(win.COLOR_WINDOW));
            _ = win.SetTextColor(hdc, win.GetSysColor(win.COLOR_WINDOWTEXT));
            const brush = win.GetSysColorBrush(win.COLOR_WINDOW);
            return @as(win.LRESULT, @intCast(@intFromPtr(brush)));
        },
        win.WM_COMMAND => {
            const id = @as(i32, @intCast(wparam & 0xFFFF));
            switch (id) {
                win.IDC_SAVE_BTN => {
                    saveConfig(hwnd);
                    _ = win.DestroyWindow(hwnd);
                    return 0;
                },
                win.IDC_CANCEL_BTN => {
                    _ = win.DestroyWindow(hwnd);
                    return 0;
                },
                else => {},
            }
        },
        win.WM_CLOSE => {
            _ = win.DestroyWindow(hwnd);
            return 0;
        },
        win.WM_DESTROY => {
            // Do not call PostQuitMessage here: this dialog shares the tray app's thread.
            // PostQuitMessage would leave WM_QUIT in the queue; the modal loop exits via
            // IsWindow(hwnd_dlg)==0 before GetMessage consumes it, so the main loop would
            // quit and the entire process would exit after Save/Cancel.
            return 0;
        },
        else => {},
    }
    return win.DefWindowProcW(hwnd, msg, wparam, lparam);
}

fn saveConfig(hwnd_dlg: win.HWND) void {
    const state_ptr = @as(*DialogState, @ptrFromInt(@as(usize, @intCast(win.GetWindowLongPtrW(hwnd_dlg, win.GWLP_USERDATA)))));

    // Read host
    const hwnd_host = win.GetDlgItem(hwnd_dlg, win.IDC_HOST) orelse return;
    var host_buf: [256]u16 = undefined;
    @memset(&host_buf, 0);
    _ = win.GetWindowTextW(hwnd_host, &host_buf, 256);

    // Read port
    const hwnd_port = win.GetDlgItem(hwnd_dlg, win.IDC_PORT) orelse return;
    var port_buf: [16]u16 = undefined;
    @memset(&port_buf, 0);
    _ = win.GetWindowTextW(hwnd_port, &port_buf, 16);

    var port_val: u16 = 22;
    if (port_buf[0] != 0) {
        var p: u16 = 0;
        for (port_buf) |c| {
            if (c == 0) break;
            if (c >= '0' and c <= '9') {
                p = p * 10 + @as(u16, @intCast(c - '0'));
            }
        }
        if (p > 0) port_val = p;
    }

    // Read username
    const hwnd_user = win.GetDlgItem(hwnd_dlg, win.IDC_USERNAME) orelse return;
    var user_buf: [256]u16 = undefined;
    @memset(&user_buf, 0);
    _ = win.GetWindowTextW(hwnd_user, &user_buf, 256);

    // Read remote path
    const hwnd_path = win.GetDlgItem(hwnd_dlg, win.IDC_REMOTE_PATH) orelse return;
    var path_buf: [512]u16 = undefined;
    @memset(&path_buf, 0);
    _ = win.GetWindowTextW(hwnd_path, &path_buf, 512);

    // Read local mode checkbox
    const hwnd_local = win.GetDlgItem(hwnd_dlg, win.IDC_LOCAL_MODE) orelse return;
    const checked = SendMessageW(hwnd_local, BM_GETCHECK, 0, 0);
    state_ptr.cfg.local_enabled = checked == @as(win.LRESULT, @intCast(BST_CHECKED));

    // Read local output directory
    const hwnd_local_dir = win.GetDlgItem(hwnd_dlg, win.IDC_LOCAL_DIR) orelse return;
    var local_dir_buf: [512]u16 = undefined;
    @memset(&local_dir_buf, 0);
    _ = win.GetWindowTextW(hwnd_local_dir, &local_dir_buf, 512);

    // Update config
    @memset(&state_ptr.cfg.host, 0);
    var i: usize = 0;
    while (i < 255 and host_buf[i] != 0) : (i += 1) {
        state_ptr.cfg.host[i] = host_buf[i];
    }
    state_ptr.cfg.host[i] = 0;

    state_ptr.cfg.port = port_val;

    @memset(&state_ptr.cfg.username, 0);
    i = 0;
    while (i < 255 and user_buf[i] != 0) : (i += 1) {
        state_ptr.cfg.username[i] = user_buf[i];
    }
    state_ptr.cfg.username[i] = 0;

    @memset(&state_ptr.cfg.remote_path, 0);
    i = 0;
    while (i < 511 and path_buf[i] != 0) : (i += 1) {
        state_ptr.cfg.remote_path[i] = path_buf[i];
    }
    state_ptr.cfg.remote_path[i] = 0;

    @memset(&state_ptr.cfg.local_dir, 0);
    i = 0;
    while (i < 511 and local_dir_buf[i] != 0) : (i += 1) {
        state_ptr.cfg.local_dir[i] = local_dir_buf[i];
    }
    state_ptr.cfg.local_dir[i] = 0;

    // Save to INI
    config.save(&state_ptr.cfg) catch {
        log.err("Failed to save config", .{});
        return;
    };

    state_ptr.is_saved = true;
}

fn centerWindow(hwnd: win.HWND) void {
    var rect: win.RECT = undefined;
    _ = GetWindowRect(hwnd, &rect);
    const width = rect.right - rect.left;
    const height = rect.bottom - rect.top;

    const screen_w = GetSystemMetrics(SM_CXSCREEN);
    const screen_h = GetSystemMetrics(SM_CYSCREEN);

    const x = @divTrunc(screen_w - width, 2);
    const y = @divTrunc(screen_h - height, 2);

    _ = win.SetWindowPos(hwnd, null, x, y, 0, 0, win.SWP_NOSIZE | win.SWP_NOZORDER);
}

/// Create a static text control
fn createStatic(hwnd_parent: win.HWND, text: win.LPCWSTR, x: i32, y: i32, w: i32, h: i32) win.HWND {
    const hinst = win.GetModuleHandleW(null) orelse return undefined;
    const hwnd = win.CreateWindowExW(
        0,
        @as(win.LPCWSTR, @ptrCast(&win.w("Static"))),
        text,
        win.WS_CHILD | win.WS_VISIBLE | win.WS_GROUP,
        x, y, w, h,
        hwnd_parent,
        null,
        hinst,
        null,
    ) orelse return undefined;
    _ = SendMessageW(hwnd, WM_SETFONT, @intCast(@intFromPtr(GetStockObject(DEFAULT_GUI_FONT))), 1);
    return hwnd;
}

/// Create an edit control with initial text
fn createEdit(hwnd_parent: win.HWND, id: i32, text: [*:0]const u16, x: i32, y: i32, w: i32, h: i32) win.HWND {
    const hinst = win.GetModuleHandleW(null) orelse return undefined;
    const hwnd = win.CreateWindowExW(
        win.WS_EX_CLIENTEDGE,
        @as(win.LPCWSTR, @ptrCast(&win.w("Edit"))),
        &[_:0]u16{},
        win.WS_CHILD | win.WS_VISIBLE | win.WS_TABSTOP | win.WS_BORDER | win.ES_AUTOHSCROLL,
        x, y, w, h,
        hwnd_parent,
        @ptrFromInt(@as(usize, @intCast(id))),
        hinst,
        null,
    ) orelse return undefined;
    _ = SendMessageW(hwnd, WM_SETFONT, @intCast(@intFromPtr(GetStockObject(DEFAULT_GUI_FONT))), 1);
    _ = SetWindowTextW(hwnd, text);
    return hwnd;
}

/// Create a button control
fn createButton(hwnd_parent: win.HWND, text: win.LPCWSTR, id: i32, x: i32, y: i32, w: i32, h: i32) win.HWND {
    const hinst = win.GetModuleHandleW(null) orelse return undefined;
    const hwnd = win.CreateWindowExW(
        0,
        @as(win.LPCWSTR, @ptrCast(&win.w("Button"))),
        text,
        win.WS_CHILD | win.WS_VISIBLE | win.WS_TABSTOP | win.BS_PUSHBUTTON,
        x, y, w, h,
        hwnd_parent,
        @ptrFromInt(@as(usize, @intCast(id))),
        hinst,
        null,
    ) orelse return undefined;

    // Set default font
    _ = SendMessageW(hwnd, WM_SETFONT, @intCast(@intFromPtr(GetStockObject(DEFAULT_GUI_FONT))), 1);

    return hwnd;
}

fn createCheckbox(hwnd_parent: win.HWND, text: win.LPCWSTR, id: i32, x: i32, y: i32, w: i32, h: i32, checked: bool) win.HWND {
    const hinst = win.GetModuleHandleW(null) orelse return undefined;
    const hwnd = win.CreateWindowExW(
        0,
        @as(win.LPCWSTR, @ptrCast(&win.w("Button"))),
        text,
        win.WS_CHILD | win.WS_VISIBLE | win.WS_TABSTOP | BS_AUTOCHECKBOX,
        x, y, w, h,
        hwnd_parent,
        @ptrFromInt(@as(usize, @intCast(id))),
        hinst,
        null,
    ) orelse return undefined;
    _ = SendMessageW(hwnd, WM_SETFONT, @intCast(@intFromPtr(GetStockObject(DEFAULT_GUI_FONT))), 1);
    _ = SendMessageW(hwnd, BM_SETCHECK, if (checked) BST_CHECKED else BST_UNCHECKED, 0);
    return hwnd;
}

fn isChild(hwnd_parent: win.HWND, hwnd_child: win.HWND) bool {
    _ = hwnd_parent;
    _ = hwnd_child;
    return false;
    // Simplified: just return false since we handle all messages
}

// Win32 constants
const SM_CXSCREEN: i32 = 0;
const SM_CYSCREEN: i32 = 1;
const WM_SETFONT: u32 = 0x0030;
const DEFAULT_GUI_FONT: i32 = 17;
const BS_PUSHBUTTON: u32 = 0x00000000;
const BS_AUTOCHECKBOX: u32 = 0x00000003;
const BM_GETCHECK: u32 = 0x00F0;
const BM_SETCHECK: u32 = 0x00F1;
const BST_UNCHECKED: usize = 0;
const BST_CHECKED: usize = 1;

extern "user32" fn GetWindowRect(hWnd: win.HWND, lpRect: *win.RECT) callconv(.winapi) win.BOOL;
extern "user32" fn GetSystemMetrics(nIndex: i32) callconv(.winapi) i32;
extern "user32" fn SendMessageW(hWnd: win.HWND, Msg: win.UINT, wParam: win.WPARAM, lParam: win.LPARAM) callconv(.winapi) win.LRESULT;
extern "user32" fn SetWindowTextW(hWnd: win.HWND, lpString: [*:0]const u16) callconv(.winapi) win.BOOL;
extern "gdi32" fn GetStockObject(i: i32) callconv(.winapi) win.HGDIOBJ;
