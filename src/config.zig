// Configuration management for sync-to-remote
// Reads/writes an INI file at %APPDATA%\sync-to-remote\config.ini

const std = @import("std");
const win = @import("win32.zig");

const app_name = "sync-to-remote";
const section_w = &win.w("connection");
const host_key = &win.w("host");
const port_key = &win.w("port");
const username_key = &win.w("username");
const remote_path_key = &win.w("remote_path");
const local_enabled_key = &win.w("local_enabled");
const local_dir_key = &win.w("local_dir");
const empty_str: [*:0]const u16 = @ptrCast(&[_:0]u16{0});
const default_port = &win.w("22");
const default_remote_path = &win.w("/tmp/sync-to-remote/");

pub const Config = struct {
    host: [256]u16 = [_]u16{0} ** 256,
    port: u16 = 22,
    username: [256]u16 = [_]u16{0} ** 256,
    remote_path: [512]u16 = undefined,
    local_enabled: bool = false,
    local_dir: [512]u16 = [_]u16{0} ** 512,

    pub fn default() Config {
        var cfg = Config{ .remote_path = undefined };
        const dp = "/tmp/sync-to-remote/";
        @memset(&cfg.remote_path, 0);
        for (dp, 0..) |c, i| {
            cfg.remote_path[i] = c;
        }
        return cfg;
    }
};

/// Returns the path to the config directory in %APPDATA%
pub fn configDir() [256]u16 {
    var appdata: [260]u16 = undefined;
    @memset(&appdata, 0);
    if (win.SHGetSpecialFolderPathW(null, &appdata, win.CSIDL_APPDATA, win.TRUE) == 0) {
        var empty: [256]u16 = undefined;
        @memset(&empty, 0);
        return empty;
    }

    var buf: [256]u16 = undefined;
    @memset(&buf, 0);

    var len: usize = 0;
    while (len < appdata.len and appdata[len] != 0) : (len += 1) {}

    if (len > 0 and len + app_name.len + 2 < buf.len) {
        @memcpy(buf[0..len], appdata[0..len]);
        if (buf[len - 1] != '\\') {
            buf[len] = '\\';
            len += 1;
        }
        for (app_name, 0..) |c, i| {
            buf[len + i] = c;
        }
        buf[len + app_name.len] = 0;
    }
    return buf;
}

/// Ensures `%APPDATA%\sync-to-remote` exists (WritePrivateProfileString does not create it).
pub fn ensureConfigDir() !void {
    var dir = configDir();
    if (dir[0] == 0) return error.NoAppDataPath;
    if (win.CreateDirectoryW(@as([*:0]const u16, @ptrCast(&dir)), null) != 0) return;
    if (win.GetLastError() == win.ERROR_ALREADY_EXISTS) return;
    return error.ConfigDirCreationFailed;
}

/// Returns the full path to config.ini
pub fn configFilePath() [512]u16 {
    var buf: [512]u16 = undefined;
    @memset(&buf, 0);

    var dir = configDir();
    var len: usize = 0;
    while (len < dir.len and dir[len] != 0) : (len += 1) {}

    if (len > 0 and len + "config.ini".len + 1 < buf.len) {
        @memcpy(buf[0..len], dir[0..len]);
        if (buf[len - 1] != '\\') {
            buf[len] = '\\';
            len += 1;
        }
        for ("config.ini", 0..) |c, i| {
            buf[len + i] = c;
        }
        buf[len + "config.ini".len] = 0;
    }
    return buf;
}

/// Returns the full path to debug.log
pub fn logFilePath() [512]u16 {
    var buf: [512]u16 = undefined;
    @memset(&buf, 0);

    var dir = configDir();
    var len: usize = 0;
    while (len < dir.len and dir[len] != 0) : (len += 1) {}

    if (len > 0 and len + "debug.log".len + 1 < buf.len) {
        @memcpy(buf[0..len], dir[0..len]);
        if (buf[len - 1] != '\\') {
            buf[len] = '\\';
            len += 1;
        }
        for ("debug.log", 0..) |c, i| {
            buf[len + i] = c;
        }
        buf[len + "debug.log".len] = 0;
    }
    return buf;
}

/// Read a string value from INI file
fn readIniString(key: [*:0]const u16, default: [*:0]const u16, buffer: []u16) void {
    const path = configFilePath();
    _ = win.GetPrivateProfileStringW(
        section_w,
        @as(?[*:0]const u16, @ptrCast(key)),
        default,
        buffer.ptr,
        @as(win.DWORD, @intCast(buffer.len)),
        @as([*:0]const u16, @ptrCast(&path)),
    );
}

/// Load config from INI file
pub fn load(allocator: std.mem.Allocator) !Config {
    var cfg = Config.default();

    // Read host
    var buf: [256]u16 = undefined;
    @memset(&buf, 0);
    readIniString(host_key, empty_str, &buf);
    var i: usize = 0;
    while (i < 255 and buf[i] != 0) : (i += 1) {
        cfg.host[i] = buf[i];
    }
    cfg.host[i] = 0;

    // Read port
    var port_buf: [16]u16 = undefined;
    @memset(&port_buf, 0);
    readIniString(port_key, default_port, &port_buf);
    var port_val: u16 = 0;
    for (port_buf) |c| {
        if (c == 0) break;
        if (c >= '0' and c <= '9') {
            port_val = port_val * 10 + @as(u16, @intCast(c - '0'));
        }
    }
    if (port_val > 0) cfg.port = port_val;

    // Read username
    @memset(&buf, 0);
    readIniString(username_key, empty_str, &buf);
    i = 0;
    while (i < 255 and buf[i] != 0) : (i += 1) {
        cfg.username[i] = buf[i];
    }
    cfg.username[i] = 0;

    // Read remote_path
    var path_buf: [512]u16 = undefined;
    @memset(&path_buf, 0);
    readIniString(remote_path_key, default_remote_path, &path_buf);
    i = 0;
    while (i < 511 and path_buf[i] != 0) : (i += 1) {
        cfg.remote_path[i] = path_buf[i];
    }
    cfg.remote_path[i] = 0;

    // Read local_enabled
    var enabled_buf: [8]u16 = undefined;
    @memset(&enabled_buf, 0);
    readIniString(local_enabled_key, &win.w("0"), &enabled_buf);
    cfg.local_enabled = enabled_buf[0] == '1';

    // Read local_dir
    var local_buf: [512]u16 = undefined;
    @memset(&local_buf, 0);
    readIniString(local_dir_key, empty_str, &local_buf);
    i = 0;
    while (i < 511 and local_buf[i] != 0) : (i += 1) {
        cfg.local_dir[i] = local_buf[i];
    }
    cfg.local_dir[i] = 0;

    _ = allocator;
    return cfg;
}

/// Save config to INI file
pub fn save(cfg: *const Config) !void {
    try ensureConfigDir();

    const path = configFilePath();
    if (path[0] == 0) return error.NoAppDataPath;
    const path_ptr: [*:0]const u16 = @ptrCast(&path);

    // Write host
    if (win.WritePrivateProfileStringW(
        section_w,
        @as(?[*:0]const u16, @ptrCast(host_key)),
        @as(?[*:0]const u16, @ptrCast(&cfg.host)),
        path_ptr,
    ) == 0) return error.IniWriteFailed;

    // Write port as string
    var port_str: [8]u16 = undefined;
    @memset(&port_str, 0);
    var p = cfg.port;
    if (p == 0) {
        port_str[0] = '0';
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

    if (win.WritePrivateProfileStringW(
        section_w,
        @as(?[*:0]const u16, @ptrCast(port_key)),
        @as(?[*:0]const u16, @ptrCast(&port_str)),
        path_ptr,
    ) == 0) return error.IniWriteFailed;

    if (win.WritePrivateProfileStringW(
        section_w,
        @as(?[*:0]const u16, @ptrCast(username_key)),
        @as(?[*:0]const u16, @ptrCast(&cfg.username)),
        path_ptr,
    ) == 0) return error.IniWriteFailed;

    if (win.WritePrivateProfileStringW(
        section_w,
        @as(?[*:0]const u16, @ptrCast(remote_path_key)),
        @as(?[*:0]const u16, @ptrCast(&cfg.remote_path)),
        path_ptr,
    ) == 0) return error.IniWriteFailed;

    // local_enabled
    const enabled_val = if (cfg.local_enabled) &win.w("1") else &win.w("0");
    if (win.WritePrivateProfileStringW(
        section_w,
        @as(?[*:0]const u16, @ptrCast(local_enabled_key)),
        enabled_val,
        path_ptr,
    ) == 0) return error.IniWriteFailed;

    if (win.WritePrivateProfileStringW(
        section_w,
        @as(?[*:0]const u16, @ptrCast(local_dir_key)),
        @as(?[*:0]const u16, @ptrCast(&cfg.local_dir)),
        path_ptr,
    ) == 0) return error.IniWriteFailed;
}
