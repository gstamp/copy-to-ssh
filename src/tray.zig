// System tray icon management

const std = @import("std");
const win = @import("win32.zig");

const log = std.log.scoped(.tray);

pub const TrayClickAction = enum {
    show_menu,
    ignore,
};

pub fn actionForTrayMouseMessage(message: u32) TrayClickAction {
    return switch (message) {
        0x0202, 0x0205 => .show_menu,
        else => .ignore,
    };
}

test "left mouse button release requests the tray menu" {
    try std.testing.expectEqual(TrayClickAction.show_menu, actionForTrayMouseMessage(0x0202));
}

test "right mouse button release requests the tray menu" {
    try std.testing.expectEqual(TrayClickAction.show_menu, actionForTrayMouseMessage(0x0205));
}

/// Setup the tray icon
pub fn setup(hwnd: win.HWND, hicon: win.HICON) bool {
    var nid = createNotifyIconData(hwnd, hicon, getDefaultTooltip());

    if (win.Shell_NotifyIconW(win.NIM_ADD, &nid) == 0) {
        log.err("Failed to add tray icon", .{});
        return false;
    }

    // Set version for Windows 7+ behavior
    nid.u.uVersion = win.NOTIFYICON_VERSION_4;
    _ = win.Shell_NotifyIconW(0x00000004, &nid); // NIM_SETVERSION

    log.info("Tray icon set up", .{});
    return true;
}

/// Update the tray icon tooltip
pub fn updateTooltip(hwnd: win.HWND, hicon: win.HICON, tooltip: [*:0]const u16) bool {
    var nid = createNotifyIconData(hwnd, hicon, tooltip);
    nid.uFlags = win.NIF_TIP;

    if (win.Shell_NotifyIconW(win.NIM_MODIFY, &nid) == 0) {
        log.err("Failed to update tooltip", .{});
        return false;
    }
    return true;
}

/// Show a balloon notification
pub fn showNotification(
    hwnd: win.HWND,
    hicon: win.HICON,
    title: [*:0]const u16,
    message: [*:0]const u16,
    icon_type: win.DWORD,
) bool {
    var nid = createNotifyIconData(hwnd, hicon, getDefaultTooltip());
    nid.uFlags = win.NIF_INFO;
    nid.dwState = 0;
    nid.dwStateMask = 0;

    // Copy title
    var ti: usize = 0;
    while (title[ti] != 0 and ti < 63) : (ti += 1) {
        nid.szInfoTitle[ti] = title[ti];
    }
    nid.szInfoTitle[ti] = 0;

    // Copy message
    var mi: usize = 0;
    while (message[mi] != 0 and mi < 255) : (mi += 1) {
        nid.szInfo[mi] = message[mi];
    }
    nid.szInfo[mi] = 0;

    nid.u.uTimeout = 5000; // ms (ignored on Win10+ but still set)
    nid.dwInfoFlags = icon_type;

    if (win.Shell_NotifyIconW(win.NIM_MODIFY, &nid) == 0) {
        log.err("Failed to show notification", .{});
        return false;
    }

    return true;
}

/// Remove the tray icon
pub fn cleanup(hwnd: win.HWND, hicon: win.HICON) void {
    var nid = createNotifyIconData(hwnd, hicon, getDefaultTooltip());
    _ = win.Shell_NotifyIconW(win.NIM_DELETE, &nid);
    log.info("Tray icon removed", .{});
}

pub const IDM_COPY = 1001;
pub const IDM_AUTO_MODE = 1004;

/// Show the tray context menu
pub fn showContextMenu(hwnd: win.HWND, auto_mode: bool) void {
    const hmenu = win.CreatePopupMenu() orelse return;
    defer _ = win.DestroyMenu(hmenu);

    _ = win.AppendMenuW(hmenu, win.MF_STRING, @as(win.UINT_PTR, @intCast(IDM_COPY)), &[_:0]u16{ '&', 'C', 'o', 'p', 'y', ' ', 't', 'o', ' ', 'r', 'e', 'm', 'o', 't', 'e' });
    _ = win.AppendMenuW(hmenu, win.MF_SEPARATOR, 0, null);
    const auto_flags = win.MF_STRING | if (auto_mode) win.MF_CHECKED else win.MF_UNCHECKED;
    _ = win.AppendMenuW(hmenu, auto_flags, @as(win.UINT_PTR, @intCast(IDM_AUTO_MODE)), &[_:0]u16{ 'A', 'u', 't', 'o', ' ', 'M', 'o', 'd', 'e' });
    _ = win.AppendMenuW(hmenu, win.MF_SEPARATOR, 0, null);
    _ = win.AppendMenuW(hmenu, win.MF_STRING, @as(win.UINT_PTR, @intCast(win.IDM_SETTINGS)), &[_:0]u16{ '&', 'S', 'e', 't', 't', 'i', 'n', 'g', 's' });
    _ = win.AppendMenuW(hmenu, win.MF_SEPARATOR, 0, null);
    _ = win.AppendMenuW(hmenu, win.MF_STRING, @as(win.UINT_PTR, @intCast(win.IDM_EXIT)), &[_:0]u16{ 'E', '&', 'x', 'i', 't' });

    // Get cursor position
    var pt: win.POINT = undefined;
    _ = GetCursorPos(&pt);

    // Set foreground window for menu to work correctly
    _ = SetForegroundWindow(hwnd);

    _ = win.TrackPopupMenu(
        hmenu,
        win.TPM_RIGHTBUTTON | win.TPM_LEFTALIGN,
        pt.x,
        pt.y,
        0,
        hwnd,
        null,
    );

    // Post a message to make the taskbar icon work correctly after menu
    _ = PostMessageW(hwnd, win.WM_USER + 100, 0, 0);
}

fn createNotifyIconData(hwnd: win.HWND, hicon: win.HICON, tooltip: [*:0]const u16) win.NOTIFYICONDATAW {
    var nid = std.mem.zeroes(win.NOTIFYICONDATAW);
    nid.cbSize = @sizeOf(win.NOTIFYICONDATAW);
    nid.hWnd = hwnd;
    nid.uID = 1;
    nid.uFlags = win.NIF_MESSAGE | win.NIF_ICON | win.NIF_TIP;
    nid.uCallbackMessage = win.WM_TRAYICON;
    nid.hIcon = hicon;

    // Copy tooltip
    var i: usize = 0;
    while (tooltip[i] != 0 and i < 127) : (i += 1) {
        nid.szTip[i] = tooltip[i];
    }
    nid.szTip[i] = 0;

    return nid;
}

fn getDefaultTooltip() [*:0]const u16 {
    return &[_:0]u16{ 's', 'y', 'n', 'c', '-', 't', 'o', '-', 'r', 'e', 'm', 'o', 't', 'e' };
}

extern "user32" fn GetCursorPos(lpPoint: *win.POINT) callconv(.winapi) win.BOOL;
extern "user32" fn SetForegroundWindow(hWnd: win.HWND) callconv(.winapi) win.BOOL;
extern "user32" fn PostMessageW(hWnd: win.HWND, Msg: win.UINT, wParam: win.WPARAM, lParam: win.LPARAM) callconv(.winapi) win.BOOL;
