// Global hotkey management

const std = @import("std");
const win = @import("win32.zig");

const log = std.log.scoped(.hotkey);

pub const HOTKEY_ID = 1;

/// Register the global hotkey (Win+Alt+V)
pub fn register(hwnd: win.HWND) bool {
    const result = win.RegisterHotKey(
        hwnd,
        HOTKEY_ID,
        win.MOD_WIN | win.MOD_ALT | win.MOD_NOREPEAT,
        win.VK_V,
    );

    if (result == 0) {
        log.err("Failed to register hotkey Win+Alt+V", .{});
        return false;
    }

    log.info("Hotkey Win+Alt+V registered", .{});
    return true;
}

/// Unregister the global hotkey
pub fn unregister(hwnd: win.HWND) void {
    _ = win.UnregisterHotKey(hwnd, HOTKEY_ID);
    log.info("Hotkey unregistered", .{});
}
