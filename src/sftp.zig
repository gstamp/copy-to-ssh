// SFTP upload module - shells out to sftp.exe

const std = @import("std");
const win = @import("win32.zig");
const config = @import("config.zig");

const log = std.log.scoped(.sftp);

/// Result of an SFTP upload
pub const UploadResult = union(enum) {
    success: void,
    err: []const u8,
};

/// Upload a file to the remote host via SFTP
pub fn upload(
    allocator: std.mem.Allocator,
    host: [*:0]const u16,
    port: u16,
    username: [*:0]const u16,
    remote_path: [*:0]const u16,
    local_file: [*:0]const u16,
    remote_filename: [*:0]const u16,
) !UploadResult {
    // Build the command: echo "put <local> <remote>" | sftp -P <port> <user>@<host>
    // We use stdin pipe to send the sftp commands

    // Normalize remote directory: SFTP expects '/', not '\', and no trailing slash.
    var norm_remote: [1024]u16 = undefined;
    @memset(&norm_remote, 0);
    var ni: usize = 0;
    var ri: usize = 0;
    while (remote_path[ri] != 0 and ni < norm_remote.len - 1) : (ri += 1) {
        const c = remote_path[ri];
        norm_remote[ni] = if (c == '\\') '/' else c;
        ni += 1;
    }
    while (ni > 0 and norm_remote[ni - 1] == '/') ni -= 1;
    norm_remote[ni] = 0;
    const norm_remote_ptr: [*:0]const u16 = @ptrCast(&norm_remote);

    // First, let's build the full remote path
    // remote_path/remote_filename
    var full_remote: [1024]u16 = undefined;
    @memset(&full_remote, 0);

    var idx: usize = 0;

    // Copy normalized remote_path
    var i: usize = 0;
    while (norm_remote_ptr[i] != 0 and i < 500) : (i += 1) {
        full_remote[idx] = norm_remote_ptr[i];
        idx += 1;
        if (idx >= 1020) break;
    }
    // Ensure path ends with /
    if (idx > 0 and full_remote[idx - 1] != '/') {
        full_remote[idx] = '/';
        idx += 1;
    }
    // Append remote filename
    i = 0;
    while (remote_filename[i] != 0 and i < 500) : (i += 1) {
        full_remote[idx] = remote_filename[i];
        idx += 1;
        if (idx >= 1020) break;
    }
    full_remote[idx] = 0;

    // Build the user@host string
    var user_host: [512]u16 = undefined;
    @memset(&user_host, 0);
    idx = 0;

    i = 0;
    while (username[i] != 0 and i < 250) : (i += 1) {
        user_host[idx] = username[i];
        idx += 1;
    }
    if (idx > 0) {
        user_host[idx] = '@';
        idx += 1;
    }
    i = 0;
    while (host[i] != 0 and i < 250) : (i += 1) {
        user_host[idx] = host[i];
        idx += 1;
    }
    user_host[idx] = 0;

    // Build the port argument string
    var port_str: [16]u16 = undefined;
    @memset(&port_str, 0);
    if (port != 0 and port != 22) {
        const port_prefix = "-oPort=\x00";
        idx = 0;
        i = 0;
        while (port_prefix[i] != 0) : (i += 1) {
            port_str[idx] = port_prefix[i];
            idx += 1;
        }
        var p = port;
        var digits: [8]u16 = undefined;
        var dc: usize = 0;
        while (p > 0) {
            digits[dc] = @as(u16, @intCast('0' + (p % 10)));
            p /= 10;
            dc += 1;
        }
        var j: usize = dc;
        while (j > 0) {
            j -= 1;
            port_str[idx] = digits[j];
            idx += 1;
        }
    }

    // Build the command: sftp -b - -oPort=... user@host
    // Actually, we'll use a pipe approach
    // sftp -b - uses batch mode from stdin

    // Build full command line
    var cmdline: [2048]u16 = undefined;
    @memset(&cmdline, 0);
    idx = 0;

    // "sftp -b - " (batch commands from stdin, then target host)
    const sftp_cmd = "sftp -b - \x00";
    i = 0;
    while (sftp_cmd[i] != 0) : (i += 1) {
        cmdline[idx] = sftp_cmd[i];
        idx += 1;
    }

    // Add port option if non-standard
    if (port != 0 and port != 22) {
        i = 0;
        while (port_str[i] != 0) : (i += 1) {
            cmdline[idx] = port_str[i];
            idx += 1;
        }
        cmdline[idx] = ' ';
        idx += 1;
    }

    // Add user@host
    i = 0;
    while (user_host[i] != 0) : (i += 1) {
        cmdline[idx] = user_host[i];
        idx += 1;
    }
    cmdline[idx] = 0;

    // Build the put command to send via stdin:
    // One "-mkdir <each path prefix>" per segment, then put. The '-' prefix tells
    // sftp batch mode to continue if the directory already exists.
    var stdin_data: [8192]u8 = undefined;
    @memset(&stdin_data, 0);
    var sdx: usize = 0;

    var rp_bytes: [768]u8 = undefined;
    @memset(&rp_bytes, 0);
    const rp_len = utf16to8(norm_remote_ptr, &rp_bytes);
    appendMkdirPChain(&stdin_data, &sdx, rp_bytes[0..rp_len]) catch {
        return UploadResult{ .err = "Remote path too long for SFTP batch" };
    };

    // "put "
    const put_cmd = "put ";
    @memcpy(stdin_data[sdx..][0..put_cmd.len], put_cmd);
    sdx += put_cmd.len;

    // Convert local_file to UTF-8 and normalize Windows separators for sftp parsing.
    var lf_bytes: [1024]u8 = undefined;
    @memset(&lf_bytes, 0);
    const lf_len = utf16to8(local_file, &lf_bytes);
    for (lf_bytes[0..lf_len]) |*b| {
        if (b.* == '\\') b.* = '/';
    }
    appendQuotedPath(&stdin_data, &sdx, lf_bytes[0..lf_len]) catch {
        return UploadResult{ .err = "Local path too long for SFTP batch" };
    };

    // " "
    stdin_data[sdx] = ' ';
    sdx += 1;

    // Convert full_remote to UTF-8
    var fr_bytes: [1024]u8 = undefined;
    @memset(&fr_bytes, 0);
    const fr_len = utf16to8(@as([*:0]const u16, @ptrCast(&full_remote)), &fr_bytes);
    appendQuotedPath(&stdin_data, &sdx, fr_bytes[0..fr_len]) catch {
        return UploadResult{ .err = "Remote path too long for SFTP batch" };
    };

    // "\nbye\n"
    const bye = "\nbye\n";
    @memcpy(stdin_data[sdx..][0..bye.len], bye);
    sdx += bye.len;

    var cmdline_bytes: [2048]u8 = undefined;
    @memset(&cmdline_bytes, 0);
    const cmdline_len = utf16to8(@as([*:0]const u16, @ptrCast(&cmdline)), &cmdline_bytes);

    debugLog(allocator,
        \\--- SFTP upload start ---
        \\command: {s}
        \\batch:
        \\{s}
        \\
    , .{
        cmdline_bytes[0..cmdline_len],
        stdin_data[0..sdx],
    });

    // Now create pipes and launch sftp
    // Create stdout pipe for reading output
    var stdout_read: win.HANDLE = undefined;
    var stdout_write: win.HANDLE = undefined;

    var sa = win.SECURITY_ATTRIBUTES{
        .nLength = @sizeOf(win.SECURITY_ATTRIBUTES),
        .lpSecurityDescriptor = null,
        .bInheritHandle = win.TRUE,
    };

    // Create pipes
    if (CreatePipe(&stdout_read, &stdout_write, &sa, 0) == 0) {
        return UploadResult{ .err = "Failed to create stdout pipe" };
    }

    var stdin_read: win.HANDLE = undefined;
    var stdin_write: win.HANDLE = undefined;
    if (CreatePipe(&stdin_read, &stdin_write, &sa, 0) == 0) {
        _ = win.CloseHandle(stdout_read);
        _ = win.CloseHandle(stdout_write);
        return UploadResult{ .err = "Failed to create stdin pipe" };
    }

    // Set up startup info
    var si = std.mem.zeroes(win.STARTUPINFOW);
    si.cb = @sizeOf(win.STARTUPINFOW);
    si.dwFlags = win.STARTF_USESTDHANDLES;
    si.hStdInput = stdin_read;
    si.hStdOutput = stdout_write;
    si.hStdError = stdout_write;

    var pi: win.PROCESS_INFORMATION = undefined;

    // Launch sftp.exe
    // cmdline is already a null-terminated UTF-16 string, but CreateProcessW expects mutable
    // We need to pass it as mutable
    var cmdline_mut = cmdline;
    const result = win.CreateProcessW(
        null,
        @as([*:0]u16, @ptrCast(&cmdline_mut)),
        null,
        null,
        win.TRUE,
        win.CREATE_NO_WINDOW,
        null,
        null,
        &si,
        &pi,
    );

    if (result == 0) {
        const err = win.GetLastError();
        debugLog(allocator, "CreateProcessW failed: GetLastError={d}\r\n", .{err});
        _ = win.CloseHandle(stdout_read);
        _ = win.CloseHandle(stdout_write);
        _ = win.CloseHandle(stdin_read);
        _ = win.CloseHandle(stdin_write);
        return UploadResult{ .err = "Failed to launch sftp.exe" };
    }

    // Close the write end of stdout (we'll read from read end)
    _ = win.CloseHandle(stdout_write);
    // Close the read end of stdin (we'll write to write end)
    _ = win.CloseHandle(stdin_read);

    // Write stdin data
    var bytes_written: win.DWORD = 0;
    _ = win.WriteFile(
        stdin_write,
        @as(win.LPCVOID, @ptrCast(&stdin_data)),
        @as(win.DWORD, @intCast(sdx)),
        &bytes_written,
        null,
    );
    debugLog(allocator, "wrote {d}/{d} bytes to sftp stdin\r\n", .{ bytes_written, sdx });

    // Close stdin pipe
    _ = win.CloseHandle(stdin_write);

    // Read stdout
    var output: [4096]u8 = undefined;
    var total_read: usize = 0;

    while (true) {
        var bytes_read: win.DWORD = 0;
        const read_result = win.ReadFile(
            stdout_read,
            &output[total_read],
            @as(win.DWORD, @intCast(@min(output.len - total_read, 1024))),
            &bytes_read,
            null,
        );
        if (read_result == 0 or bytes_read == 0) break;
        total_read += bytes_read;
        if (total_read >= output.len - 1) break;
    }
    output[total_read] = 0;

    // Wait for process
    _ = win.WaitForSingleObject(pi.hProcess, win.INFINITE);
    var exit_code: win.DWORD = 0;
    _ = win.GetExitCodeProcess(pi.hProcess, &exit_code);

    // Cleanup handles
    _ = win.CloseHandle(stdout_read);
    _ = win.CloseHandle(pi.hProcess);
    _ = win.CloseHandle(pi.hThread);

    // Check for errors in output
    const output_slice = output[0..total_read];
    const output_str = std.mem.sliceTo(std.mem.sliceTo(output_slice, 0), 0);
    debugLog(allocator,
        \\sftp exit code: {d}
        \\sftp output:
        \\{s}
        \\--- SFTP upload end ---
        \\
    , .{ exit_code, output_str });

    if (exit_code != 0) {
        return UploadResult{ .err = "sftp failed; see %APPDATA%\\sync-to-remote\\debug.log" };
    }

    // Check for error messages in output
    if (std.mem.indexOf(u8, output_str, "error") != null or
        std.mem.indexOf(u8, output_str, "Couldn't") != null or
        std.mem.indexOf(u8, output_str, "failed") != null or
        std.mem.indexOf(u8, output_str, "Permission denied") != null)
    {
        return UploadResult{ .err = "sftp reported an error; see %APPDATA%\\sync-to-remote\\debug.log" };
    }

    log.info("Upload successful: {s}", .{output_str});
    return UploadResult{ .success = {} };
}

fn debugLog(allocator: std.mem.Allocator, comptime fmt: []const u8, args: anytype) void {
    const msg = std.fmt.allocPrint(allocator, fmt, args) catch return;
    defer allocator.free(msg);
    appendDebugLog(msg);
}

fn appendDebugLog(msg: []const u8) void {
    config.ensureConfigDir() catch return;
    var path = config.logFilePath();
    if (path[0] == 0) return;

    const file = win.CreateFileW(
        @as([*:0]const u16, @ptrCast(&path)),
        win.FILE_APPEND_DATA,
        win.FILE_SHARE_READ | win.FILE_SHARE_WRITE,
        null,
        win.OPEN_ALWAYS,
        win.FILE_ATTRIBUTE_NORMAL,
        null,
    ) orelse return;
    if (@intFromPtr(file) == std.math.maxInt(usize)) return;
    defer _ = win.CloseHandle(file);

    var written: win.DWORD = 0;
    _ = win.WriteFile(
        file,
        @as(win.LPCVOID, @ptrCast(msg.ptr)),
        @as(win.DWORD, @intCast(msg.len)),
        &written,
        null,
    );
}

fn appendQuotedPath(stdin_buf: []u8, sdx: *usize, path_utf8: []const u8) error{BufferTooSmall}!void {
    if (sdx.* + 2 > stdin_buf.len) return error.BufferTooSmall;
    stdin_buf[sdx.*] = '"';
    sdx.* += 1;

    for (path_utf8) |c| {
        if (c == '"' or c == '\\') {
            if (sdx.* + 2 > stdin_buf.len) return error.BufferTooSmall;
            stdin_buf[sdx.*] = '\\';
            stdin_buf[sdx.* + 1] = c;
            sdx.* += 2;
        } else {
            if (sdx.* + 1 > stdin_buf.len) return error.BufferTooSmall;
            stdin_buf[sdx.*] = c;
            sdx.* += 1;
        }
    }

    if (sdx.* + 1 > stdin_buf.len) return error.BufferTooSmall;
    stdin_buf[sdx.*] = '"';
    sdx.* += 1;
}

/// Emit one `-mkdir <prefix>\n` per path segment (cumulative). Skips if path is empty.
/// The '-' prefix makes sftp batch mode continue when a prefix already exists.
fn appendMkdirPChain(stdin_buf: []u8, sdx: *usize, path_utf8: []const u8) error{BufferTooSmall}!void {
    const prefix = "-mkdir ";
    var end = path_utf8.len;
    while (end > 0 and path_utf8[end - 1] == '/') end -= 1;
    const trimmed = path_utf8[0..end];
    if (trimmed.len == 0) return;

    const absolute = trimmed[0] == '/';
    var accum: [768]u8 = undefined;
    var accum_len: usize = 0;

    var iter = std.mem.splitScalar(u8, trimmed, '/');
    while (iter.next()) |segment| {
        if (segment.len == 0) continue;

        if (accum_len == 0) {
            if (absolute) {
                accum[0] = '/';
                @memcpy(accum[1..][0..segment.len], segment);
                accum_len = 1 + segment.len;
            } else {
                @memcpy(accum[0..segment.len], segment);
                accum_len = segment.len;
            }
        } else {
            accum[accum_len] = '/';
            @memcpy(accum[accum_len + 1 ..][0..segment.len], segment);
            accum_len += 1 + segment.len;
        }

        const need = prefix.len + accum_len + 3;
        if (sdx.* + need > stdin_buf.len) return error.BufferTooSmall;
        @memcpy(stdin_buf[sdx.*..][0..prefix.len], prefix);
        sdx.* += prefix.len;
        try appendQuotedPath(stdin_buf, sdx, accum[0..accum_len]);
        stdin_buf[sdx.*] = '\n';
        sdx.* += 1;
    }
}

/// Convert UTF-16 null-terminated string to UTF-8
fn utf16to8(src16: [*:0]const u16, dest8: []u8) usize {
    var di: usize = 0;
    var si: usize = 0;
    while (src16[si] != 0 and di < dest8.len) {
        const cp = src16[si];
        si += 1;
        if (cp < 0x80) {
            dest8[di] = @as(u8, @intCast(cp & 0xFF));
            di += 1;
        } else if (cp < 0x800) {
            if (di + 1 >= dest8.len) break;
            dest8[di] = @as(u8, @intCast(0xC0 | (cp >> 6)));
            dest8[di + 1] = @as(u8, @intCast(0x80 | (cp & 0x3F)));
            di += 2;
        } else {
            if (di + 2 >= dest8.len) break;
            dest8[di] = @as(u8, @intCast(0xE0 | (cp >> 12)));
            dest8[di + 1] = @as(u8, @intCast(0x80 | ((cp >> 6) & 0x3F)));
            dest8[di + 2] = @as(u8, @intCast(0x80 | (cp & 0x3F)));
            di += 3;
        }
    }
    return di;
}

extern "kernel32" fn CreatePipe(
    hReadPipe: *win.HANDLE,
    hWritePipe: *win.HANDLE,
    lpPipeAttributes: *win.SECURITY_ATTRIBUTES,
    nSize: win.DWORD,
) callconv(.winapi) win.BOOL;
