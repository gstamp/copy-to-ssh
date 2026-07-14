// Win32 API declarations for sync-to-remote
// We use extern function declarations to keep things minimal.

const std = @import("std");

pub const BOOL = i32;
pub const BYTE = u8;
pub const DWORD = u32;
pub const WORD = u16;
pub const WCHAR = u16;
pub const UINT = u32;
pub const LONG = i32;
pub const ULONG = u32;
pub const LPCWSTR = [*:0]const u16;
pub const LPWSTR = [*:0]u16;
pub const LPVOID = *anyopaque;
pub const HICON = *opaque {};
pub const HCURSOR = *opaque {};
pub const HINSTANCE = *opaque {};
pub const HWND = *opaque {};
pub const HMENU = *opaque {};
pub const HMODULE = HINSTANCE;
pub const HANDLE = *opaque {};
pub const HBRUSH = *opaque {};
pub const HDC = *opaque {};
pub const HBITMAP = *opaque {};
pub const HPALETTE = *opaque {};
pub const HGDIOBJ = *opaque {};
pub const HICON_PTR = *opaque {};
pub const ATOM = WORD;
pub const HRSRC = *opaque {};
pub const LRESULT = isize;
pub const WPARAM = u64;
pub const LPARAM = i64;
pub const ULONG_PTR = u64;
pub const INT_PTR = isize;
pub const UINT_PTR = u64;

pub const FALSE: BOOL = 0;
pub const TRUE: BOOL = 1;

pub const MAX_PATH = 260;

// Window messages
pub const WM_CREATE = 0x0001;
pub const WM_DESTROY = 0x0002;
pub const WM_CLOSE = 0x0010;
pub const WM_QUIT = 0x0012;
pub const WM_NCDESTROY = 0x0082;
pub const WM_PAINT = 0x000F;
pub const WM_COMMAND = 0x0111;
pub const WM_TIMER = 0x0113;
pub const WM_HOTKEY = 0x0312;
pub const WM_TRAYICON = WM_USER + 1;
pub const WM_USER = 0x0400;
pub const WM_DPICHANGED = 0x02E0;
pub const WM_CLIPBOARDUPDATE: UINT = 0x031D;

// Control colors (WM_CTLCOLOR* return value is an HBRUSH cast to LRESULT)
pub const WM_CTLCOLORSTATIC: UINT = 0x0138;
pub const WM_CTLCOLOREDIT: UINT = 0x0133;
pub const WM_CTLCOLORBTN: UINT = 0x0135;

/// System color indices (GetSysColor / GetSysColorBrush)
pub const COLOR_WINDOW: i32 = 5;
pub const COLOR_WINDOWTEXT: i32 = 8;

// Tray icon messages
pub const NIM_ADD: DWORD = 0;
pub const NIM_MODIFY: DWORD = 1;
pub const NIM_DELETE: DWORD = 2;
pub const NIF_MESSAGE: DWORD = 0x0001;
pub const NIF_ICON: DWORD = 0x0002;
pub const NIF_TIP: DWORD = 0x0004;
pub const NIF_INFO: DWORD = 0x0010;
pub const NIF_SHOWTIP: DWORD = 0x0080;
pub const NOTIFYICON_VERSION: DWORD = 4;
pub const NOTIFYICON_VERSION_4: DWORD = 4;

pub const NIS_HIDDEN: DWORD = 0x00000001;

// Notify icon info flags
pub const NIIF_NONE: DWORD = 0x00000000;
pub const NIIF_INFO: DWORD = 0x00000001;
pub const NIIF_WARNING: DWORD = 0x00000002;
pub const NIIF_ERROR: DWORD = 0x00000003;
pub const NIIF_USER: DWORD = 0x00000004;
pub const NIIF_NOSOUND: DWORD = 0x00000010;
pub const NIIF_LARGE_ICON: DWORD = 0x00000020;
pub const NIIF_RESPECT_QUIET_TIME: DWORD = 0x00000080;
pub const NIIF_ICON_MASK: DWORD = 0x0000000F;

pub const NOTIFYICONDATAW_V2_SIZE: UINT = 952; // NINFOODATAW_V2 size
pub const NOTIFYICONDATAW_V1_SIZE: UINT = 88; // NOTIFYICONDATAW_V1 size

// NOTIFYICONDATAW structure (layout through dwInfoFlags; see shellapi.h)
pub const NOTIFYICONDATAW = extern struct {
    cbSize: DWORD,
    hWnd: HWND,
    uID: UINT,
    uFlags: UINT,
    uCallbackMessage: UINT,
    hIcon: HICON,
    szTip: [128]WCHAR,
    dwState: DWORD,
    dwStateMask: DWORD,
    szInfo: [256]WCHAR,
    u: extern union {
        uTimeout: UINT,
        uVersion: UINT,
    },
    szInfoTitle: [64]WCHAR,
    dwInfoFlags: DWORD,
    guidItem: Guid,
    hBalloonIcon: ?HICON,
};

// Tray menu commands
pub const IDM_SHOW = 1001;
pub const IDM_EXIT = 1002;
pub const IDM_SETTINGS = 1003;

// Window styles
pub const WS_OVERLAPPEDWINDOW: DWORD = 0x00CF0000;
pub const WS_POPUP: DWORD = 0x80000000;
pub const WS_CAPTION: DWORD = 0x00C00000;
pub const WS_SYSMENU: DWORD = 0x00080000;
pub const WS_MINIMIZEBOX: DWORD = 0x00020000;
pub const WS_VISIBLE: DWORD = 0x10000000;
pub const WS_CHILD: DWORD = 0x40000000;
pub const WS_BORDER: DWORD = 0x00800000;
pub const WS_OVERLAPPED: DWORD = 0x00000000;
pub const WS_TABSTOP: DWORD = 0x00010000;
pub const WS_DISABLED: DWORD = 0x08000000;

// Button styles (winuser.h)
pub const BS_PUSHBUTTON: DWORD = 0x00000000;
pub const WS_GROUP: DWORD = 0x00020000;
pub const WS_CLIPSIBLINGS: DWORD = 0x04000000;
pub const WS_CLIPCHILDREN: DWORD = 0x02000000;
pub const WS_EX_TOOLWINDOW: DWORD = 0x00000080;
pub const WS_EX_APPWINDOW: DWORD = 0x00040000;
pub const WS_EX_DLGMODALFRAME: DWORD = 0x00000001;
pub const WS_EX_WINDOWEDGE: DWORD = 0x00000100;
pub const WS_EX_CLIENTEDGE: DWORD = 0x00000200;

// Show window
pub const SW_HIDE: i32 = 0;
pub const SW_SHOWNORMAL: i32 = 1;
pub const SW_SHOW: i32 = 5;
pub const SW_RESTORE: i32 = 9;

// Dialog styles
pub const DS_MODALFRAME: DWORD = 0x00000080;
pub const DS_SETFONT: DWORD = 0x00000040;
pub const DS_CENTER: DWORD = 0x00000800;

// Edit control styles
pub const ES_LEFT: DWORD = 0x00000000;
pub const ES_AUTOHSCROLL: DWORD = 0x00000080;
pub const WS_THICKFRAME: DWORD = 0x00040000;

// Standard control IDs
pub const IDOK: i32 = 1;
pub const IDCANCEL: i32 = 2;

// Progress bar (msctls_progress32)
pub const PBS_MARQUEE: DWORD = 0x08;
pub const PBM_SETMARQUEE: UINT = WM_USER + 10;
pub const PBM_SETSTATE: UINT = WM_USER + 16;
pub const PBST_NORMAL: i32 = 0x0001;
pub const PBST_ERROR: i32 = 0x0002;

// Timers
pub extern "user32" fn SetTimer(
    hWnd: ?HWND,
    nIDEvent: usize,
    uElapse: UINT,
    lpTimerFunc: ?*anyopaque,
) callconv(.winapi) usize;
pub extern "user32" fn KillTimer(hWnd: ?HWND, nIDEvent: usize) callconv(.winapi) BOOL;

// System metrics
pub const SM_CXSCREEN: i32 = 0;
pub const SM_CYSCREEN: i32 = 1;
pub extern "user32" fn GetSystemMetrics(nIndex: i32) callconv(.winapi) i32;

// Static control styles
pub const SS_LEFT: DWORD = 0x00000000;
pub const SS_LEFTNOWORDWRAP: DWORD = 0x0000000C;

// Our custom control IDs for progress window
pub const IDC_PROGRESS_STATUS: i32 = 3001;
pub const IDC_PROGRESS_BAR: i32 = 3002;
pub const IDC_PROGRESS_CLOSE: i32 = 3003;

// Our custom control IDs for settings dialog
pub const IDC_HOST = 2001;
pub const IDC_PORT = 2002;
pub const IDC_USERNAME = 2003;
pub const IDC_REMOTE_PATH = 2004;
pub const IDC_SAVE_BTN = 2005;
pub const IDC_CANCEL_BTN = 2006;
pub const IDC_HOST_LABEL = 2007;
pub const IDC_PORT_LABEL = 2008;
pub const IDC_USERNAME_LABEL = 2009;
pub const IDC_REMOTE_PATH_LABEL = 2010;
pub const IDC_TITLE = 2011;
pub const IDC_LOCAL_MODE = 2012;
pub const IDC_LOCAL_DIR = 2013;
pub const IDC_LOCAL_DIR_LABEL = 2014;

// Hotkey modifiers
pub const MOD_ALT: UINT = 0x0001;
pub const MOD_CONTROL: UINT = 0x0002;
pub const MOD_SHIFT: UINT = 0x0004;
pub const MOD_WIN: UINT = 0x0008;
pub const MOD_NOREPEAT: UINT = 0x4000;

// Virtual key codes
pub const VK_INSERT: UINT = 0x2D;
pub const VK_RETURN: UINT = 0x0D;
pub const VK_V: UINT = 0x56;

// Window class styles
pub const CS_HREDRAW: UINT = 0x0002;
pub const CS_VREDRAW: UINT = 0x0001;
pub const CS_DBLCLKS: UINT = 0x0008;

// GDI+ status codes
pub const GdiplusOk: i32 = 0;

// GDI+ encoder CLSIDs
pub const CLSID_PNG_ENCODER: Guid = .{
    .data1 = 0x557CF406,
    .data2 = 0x1A04,
    .data3 = 0x11D3,
    .data4 = [_]u8{ 0x9A, 0x73, 0x00, 0x00, 0xF8, 0x1E, 0xF3, 0x2E },
};

pub const Guid = extern struct {
    data1: u32,
    data2: u16,
    data3: u16,
    data4: [8]u8,
};

pub const GdiplusStartupInput = extern struct {
    GdiplusVersion: UINT = 1,
    DebugEventCallback: ?*anyopaque = null,
    SuppressBackgroundThread: BOOL = FALSE,
    SuppressExternalCodecs: BOOL = FALSE,
};

pub const GdiplusStartupOutput = extern struct {
    NotificationHook: ?*anyopaque = null,
    NotificationUnhook: ?*anyopaque = null,
};

// Window class for dialog
pub const WNDCLASSW = extern struct {
    style: UINT,
    lpfnWndProc: WNDPROC,
    cbClsExtra: i32,
    cbWndExtra: i32,
    hInstance: HINSTANCE,
    hIcon: ?HICON,
    hCursor: ?HCURSOR,
    hbrBackground: ?HBRUSH,
    lpszMenuName: ?LPCWSTR,
    lpszClassName: LPCWSTR,
};

pub const WNDPROC = *const fn (HWND, UINT, WPARAM, LPARAM) callconv(.winapi) LRESULT;

pub const DLGPROC = *const fn (HWND, UINT, WPARAM, LPARAM) callconv(.winapi) INT_PTR;

pub const POINT = extern struct {
    x: LONG,
    y: LONG,
};

pub const MSG = extern struct {
    hwnd: HWND,
    message: UINT,
    wParam: WPARAM,
    lParam: LPARAM,
    time: DWORD,
    pt: POINT,
};

pub const RECT = extern struct {
    left: LONG,
    top: LONG,
    right: LONG,
    bottom: LONG,
};

pub const WINDOWPLACEMENT = extern struct {
    length: UINT,
    flags: UINT,
    showCmd: UINT,
    ptMinPosition: POINT,
    ptMaxPosition: POINT,
    rcNormalPosition: RECT,
};

pub const CREATESTRUCTW = extern struct {
    lpCreateParams: ?LPVOID,
    hInstance: HINSTANCE,
    hMenu: HMENU,
    hwndParent: HWND,
    cy: i32,
    cx: i32,
    y: i32,
    x: i32,
    style: LONG,
    lpszName: LPCWSTR,
    lpszClass: LPCWSTR,
    dwExStyle: DWORD,
};

pub const STARTUPINFOW = extern struct {
    cb: DWORD,
    lpReserved: LPWSTR,
    lpDesktop: LPWSTR,
    lpTitle: LPWSTR,
    dwX: DWORD,
    dwY: DWORD,
    dwXSize: DWORD,
    dwYSize: DWORD,
    dwXCountChars: DWORD,
    dwYCountChars: DWORD,
    dwFillAttribute: DWORD,
    dwFlags: DWORD,
    wShowWindow: WORD,
    cbReserved2: WORD,
    lpReserved2: ?*BYTE,
    hStdInput: HANDLE,
    hStdOutput: HANDLE,
    hStdError: HANDLE,
};

pub const PROCESS_INFORMATION = extern struct {
    hProcess: HANDLE,
    hThread: HANDLE,
    dwProcessId: DWORD,
    dwThreadId: DWORD,
};

pub const SECURITY_ATTRIBUTES = extern struct {
    nLength: DWORD,
    lpSecurityDescriptor: ?LPVOID,
    bInheritHandle: BOOL,
};

// STARTF flags
pub const STARTF_USESTDHANDLES: DWORD = 0x00000100;

// STD handles
pub const STD_INPUT_HANDLE: DWORD = 0xFFFFFFF6 & 0xFFFFFFFF;
pub const STD_OUTPUT_HANDLE: DWORD = 0xFFFFFFF5 & 0xFFFFFFFF;
pub const STD_ERROR_HANDLE: DWORD = 0xFFFFFFF4 & 0xFFFFFFFF;

// File creation
pub const CREATE_ALWAYS: DWORD = 2;
pub const OPEN_EXISTING: DWORD = 3;
pub const OPEN_ALWAYS: DWORD = 4;
pub const GENERIC_READ: DWORD = 0x80000000;
pub const GENERIC_WRITE: DWORD = 0x40000000;
pub const FILE_APPEND_DATA: DWORD = 0x00000004;
pub const FILE_SHARE_READ: DWORD = 0x00000001;
pub const FILE_SHARE_WRITE: DWORD = 0x00000002;
pub const FILE_ATTRIBUTE_NORMAL: DWORD = 0x00000080;

// Process creation flags
pub const CREATE_NO_WINDOW: DWORD = 0x08000000;
pub const NORMAL_PRIORITY_CLASS: DWORD = 0x00000020;

// Error codes
pub const ERROR_SUCCESS: DWORD = 0;
pub const ERROR_ALREADY_EXISTS: DWORD = 183;
pub const ERROR_FILE_NOT_FOUND: DWORD = 2;
pub const ERROR_MORE_DATA: DWORD = 234;

// Clipboard formats
pub const CF_TEXT: UINT = 1;
pub const CF_BITMAP: UINT = 2;
pub const CF_UNICODETEXT: UINT = 13;
pub const CF_HDROP: UINT = 15;
pub const CF_DIB: UINT = 8;

// GetLastError
pub extern "kernel32" fn GetLastError() callconv(.winapi) DWORD;

// Memory
pub extern "kernel32" fn GlobalAlloc(uFlags: UINT, dwBytes: usize) callconv(.winapi) ?HANDLE;
pub extern "kernel32" fn GlobalFree(hMem: HANDLE) callconv(.winapi) ?HANDLE;
pub extern "kernel32" fn GlobalLock(hMem: HANDLE) callconv(.winapi) ?LPVOID;
pub extern "kernel32" fn GlobalUnlock(hMem: HANDLE) callconv(.winapi) BOOL;
pub extern "kernel32" fn HeapAlloc(hHeap: HANDLE, dwFlags: DWORD, dwBytes: usize) callconv(.winapi) ?LPVOID;
pub extern "kernel32" fn HeapFree(hHeap: HANDLE, dwFlags: DWORD, lpMem: LPVOID) callconv(.winapi) BOOL;
pub extern "kernel32" fn GetProcessHeap() callconv(.winapi) HANDLE;

// Mutex (single instance)
pub extern "kernel32" fn CreateMutexW(
    lpMutexAttributes: ?*SECURITY_ATTRIBUTES,
    bInitialOwner: BOOL,
    lpName: LPCWSTR,
) callconv(.winapi) ?HANDLE;

pub extern "kernel32" fn ReleaseMutex(hMutex: HANDLE) callconv(.winapi) BOOL;

// File I/O
pub extern "kernel32" fn CreateFileW(
    lpFileName: LPCWSTR,
    dwDesiredAccess: DWORD,
    dwShareMode: DWORD,
    lpSecurityAttributes: ?*SECURITY_ATTRIBUTES,
    dwCreationDisposition: DWORD,
    dwFlagsAndAttributes: DWORD,
    hTemplateFile: ?HANDLE,
) callconv(.winapi) ?HANDLE;

pub extern "kernel32" fn WriteFile(
    hFile: HANDLE,
    lpBuffer: LPCVOID,
    nNumberOfBytesToWrite: DWORD,
    lpNumberOfBytesWritten: ?*DWORD,
    lpOverlapped: ?*anyopaque,
) callconv(.winapi) BOOL;

pub extern "kernel32" fn ReadFile(
    hFile: HANDLE,
    lpBuffer: LPVOID,
    nNumberOfBytesToRead: DWORD,
    lpNumberOfBytesRead: ?*DWORD,
    lpOverlapped: ?*anyopaque,
) callconv(.winapi) BOOL;

pub extern "kernel32" fn CloseHandle(hObject: HANDLE) callconv(.winapi) BOOL;
pub extern "kernel32" fn DeleteFileW(lpFileName: LPCWSTR) callconv(.winapi) BOOL;

pub extern "kernel32" fn CreateDirectoryW(
    lpPathName: LPCWSTR,
    lpSecurityAttributes: ?*SECURITY_ATTRIBUTES,
) callconv(.winapi) BOOL;

pub extern "kernel32" fn CopyFileW(
    lpExistingFileName: LPCWSTR,
    lpNewFileName: LPCWSTR,
    bFailIfExists: BOOL,
) callconv(.winapi) BOOL;

pub extern "kernel32" fn GetShortPathNameW(
    lpszLongPath: LPCWSTR,
    lpszShortPath: [*]WCHAR,
    cchBuffer: DWORD,
) callconv(.winapi) DWORD;

pub const LPCVOID = *const anyopaque;

// Process creation
pub extern "kernel32" fn CreateProcessW(
    lpApplicationName: ?LPCWSTR,
    lpCommandLine: LPWSTR,
    lpProcessAttributes: ?*SECURITY_ATTRIBUTES,
    lpThreadAttributes: ?*SECURITY_ATTRIBUTES,
    bInheritHandles: BOOL,
    dwCreationFlags: DWORD,
    lpEnvironment: ?LPVOID,
    lpCurrentDirectory: ?LPCWSTR,
    lpStartupInfo: *STARTUPINFOW,
    lpProcessInformation: *PROCESS_INFORMATION,
) callconv(.winapi) BOOL;

// Wait for process
pub extern "kernel32" fn WaitForSingleObject(
    hHandle: HANDLE,
    dwMilliseconds: DWORD,
) callconv(.winapi) DWORD;
pub const WAIT_OBJECT_0: DWORD = 0;
pub const WAIT_TIMEOUT: DWORD = 0x00000102;
pub const WAIT_FAILED: DWORD = 0xFFFFFFFF;
pub const INFINITE: DWORD = 0xFFFFFFFF;

// Get exit code
pub extern "kernel32" fn GetExitCodeProcess(
    hProcess: HANDLE,
    lpExitCode: *DWORD,
) callconv(.winapi) BOOL;

// Temp path
pub extern "kernel32" fn GetTempPathW(
    nBufferLength: DWORD,
    lpBuffer: [*]WCHAR,
) callconv(.winapi) DWORD;

// Windows/System directory
pub extern "kernel32" fn GetWindowsDirectoryW(
    lpBuffer: [*]WCHAR,
    uSize: UINT,
) callconv(.winapi) UINT;

// Ini file functions
pub extern "kernel32" fn GetPrivateProfileStringW(
    lpAppName: LPCWSTR,
    lpKeyName: ?LPCWSTR,
    lpDefault: LPCWSTR,
    lpReturnedString: [*]WCHAR,
    nSize: DWORD,
    lpFileName: LPCWSTR,
) callconv(.winapi) DWORD;

pub extern "kernel32" fn WritePrivateProfileStringW(
    lpAppName: LPCWSTR,
    lpKeyName: ?LPCWSTR,
    lpString: ?LPCWSTR,
    lpFileName: LPCWSTR,
) callconv(.winapi) BOOL;

// Module
pub extern "kernel32" fn GetModuleHandleW(lpModuleName: ?LPCWSTR) callconv(.winapi) ?HINSTANCE;

// Environment
pub extern "kernel32" fn GetEnvironmentVariableW(
    lpName: LPCWSTR,
    lpBuffer: [*]WCHAR,
    nSize: DWORD,
) callconv(.winapi) DWORD;

// User32 - Window creation
pub extern "user32" fn RegisterClassW(
    lpWndClass: *const WNDCLASSW,
) callconv(.winapi) ATOM;

/// Expand a client-area RECT (0,0,cw,ch) to outer window pixels for the given styles.
pub extern "user32" fn AdjustWindowRectEx(
    lpRect: *RECT,
    dwStyle: DWORD,
    bMenu: BOOL,
    dwExStyle: DWORD,
) callconv(.winapi) BOOL;

pub extern "user32" fn CreateWindowExW(
    dwExStyle: DWORD,
    lpClassName: LPCWSTR,
    lpWindowName: LPCWSTR,
    dwStyle: DWORD,
    X: i32,
    Y: i32,
    nWidth: i32,
    nHeight: i32,
    hWndParent: ?HWND,
    hMenu: ?HMENU,
    hInstance: ?HINSTANCE,
    lpParam: ?LPVOID,
) callconv(.winapi) ?HWND;

pub extern "user32" fn DestroyWindow(hWnd: HWND) callconv(.winapi) BOOL;
pub extern "user32" fn IsWindow(hWnd: HWND) callconv(.winapi) BOOL;

pub extern "user32" fn ShowWindow(hWnd: HWND, nCmdShow: i32) callconv(.winapi) BOOL;

pub extern "user32" fn UpdateWindow(hWnd: HWND) callconv(.winapi) BOOL;

pub extern "user32" fn SetWindowTextW(hWnd: HWND, lpString: LPCWSTR) callconv(.winapi) BOOL;

pub extern "user32" fn GetWindowTextW(hWnd: HWND, lpString: [*]WCHAR, nMaxCount: i32) callconv(.winapi) i32;

pub extern "user32" fn GetWindowTextLengthW(hWnd: HWND) callconv(.winapi) i32;

// Message handling
pub extern "user32" fn GetMessageW(
    lpMsg: *MSG,
    hWnd: ?HWND,
    wMsgFilterMin: UINT,
    wMsgFilterMax: UINT,
) callconv(.winapi) BOOL;

pub extern "user32" fn DispatchMessageW(
    lpMsg: *const MSG,
) callconv(.winapi) LRESULT;

pub extern "user32" fn TranslateMessage(
    lpMsg: *const MSG,
) callconv(.winapi) BOOL;

/// When non-zero, Tab / arrow keys for child controls were handled; skip Translate/Dispatch.
pub extern "user32" fn IsDialogMessageW(
    hDlg: HWND,
    lpMsg: *MSG,
) callconv(.winapi) BOOL;

pub extern "user32" fn PostQuitMessage(nExitCode: i32) callconv(.winapi) void;

pub extern "user32" fn DefWindowProcW(
    hWnd: HWND,
    msg: UINT,
    wParam: WPARAM,
    lParam: LPARAM,
) callconv(.winapi) LRESULT;

// Hotkey
pub extern "user32" fn RegisterHotKey(
    hWnd: ?HWND,
    id: i32,
    fsModifiers: UINT,
    vk: UINT,
) callconv(.winapi) BOOL;

pub extern "user32" fn UnregisterHotKey(
    hWnd: ?HWND,
    id: i32,
) callconv(.winapi) BOOL;

// Menu
pub extern "user32" fn CreatePopupMenu() callconv(.winapi) ?HMENU;

pub extern "user32" fn TrackPopupMenu(
    hMenu: HMENU,
    uFlags: UINT,
    x: i32,
    y: i32,
    nReserved: i32,
    hWnd: HWND,
    prcRect: ?*RECT,
) callconv(.winapi) BOOL;

pub extern "user32" fn DestroyMenu(hMenu: HMENU) callconv(.winapi) BOOL;

pub extern "user32" fn AppendMenuW(
    hMenu: HMENU,
    uFlags: UINT,
    uIDNewItem: UINT_PTR,
    lpNewItem: ?LPCWSTR,
) callconv(.winapi) BOOL;

pub const MF_STRING: UINT = 0x00000000;
pub const MF_SEPARATOR: UINT = 0x00000800;
pub const MF_POPUP: UINT = 0x00000010;
pub const MF_CHECKED: UINT = 0x00000008;
pub const MF_UNCHECKED: UINT = 0x00000000;
pub const TPM_RIGHTBUTTON: UINT = 0x0002;
pub const TPM_LEFTALIGN: UINT = 0x0000;

pub extern "user32" fn SetForegroundWindow(hWnd: HWND) callconv(.winapi) BOOL;

pub extern "user32" fn AddClipboardFormatListener(hwnd: HWND) callconv(.winapi) BOOL;
pub extern "user32" fn RemoveClipboardFormatListener(hwnd: HWND) callconv(.winapi) BOOL;

pub extern "user32" fn LoadCursorW(hInstance: ?HINSTANCE, lpCursorName: LPCWSTR) callconv(.winapi) HCURSOR;
pub const IDC_ARROW: [*:0]const u16 = @ptrCast(&[_:0]u16{0x7F00}); // IDC_ARROW = MAKEINTRESOURCE(32512) = (HCURSOR)32512

// Icon
pub extern "user32" fn CreateIconFromResourceEx(
    presbits: [*]u8,
    dwResSize: DWORD,
    fIcon: BOOL,
    dwVer: DWORD,
    cxDesired: i32,
    cyDesired: i32,
    Flags: UINT,
) callconv(.winapi) ?HICON;

pub extern "user32" fn DestroyIcon(hIcon: HICON) callconv(.winapi) BOOL;
pub extern "user32" fn LoadImageW(
    hInst: ?HINSTANCE,
    name: LPCWSTR,
    type: UINT,
    cx: i32,
    cy: i32,
    fuLoad: UINT,
) callconv(.winapi) ?HANDLE;

pub const IMAGE_ICON: UINT = 1;
pub const LR_LOADFROMFILE: UINT = 0x00000010;
pub const LR_DEFAULTSIZE: UINT = 0x00000040;

// Dialog
pub extern "user32" fn DialogBoxParamW(
    hInstance: ?HINSTANCE,
    lpTemplateName: LPCWSTR,
    hWndParent: ?HWND,
    lpDialogFunc: ?DLGPROC,
    dwInitParam: LPARAM,
) callconv(.winapi) INT_PTR;

pub extern "user32" fn EndDialog(hDlg: HWND, nResult: INT_PTR) callconv(.winapi) BOOL;

pub extern "user32" fn CreateDialogParamW(
    hInstance: ?HINSTANCE,
    lpTemplateName: LPCWSTR,
    hWndParent: ?HWND,
    lpDialogFunc: ?DLGPROC,
    dwInitParam: LPARAM,
) callconv(.winapi) ?HWND;

// Controls
pub extern "user32" fn CreateWindowExW_ctl(
    dwExStyle: DWORD,
    lpClassName: LPCWSTR,
    lpWindowName: LPCWSTR,
    dwStyle: DWORD,
    X: i32,
    Y: i32,
    nWidth: i32,
    nHeight: i32,
    hWndParent: HWND,
    hMenu: ?HMENU,
    hInstance: ?HINSTANCE,
    lpParam: ?LPVOID,
) callconv(.winapi) ?HWND;

// GetDlgItem
pub extern "user32" fn GetDlgItem(hDlg: HWND, nIDDlgItem: i32) callconv(.winapi) ?HWND;

// EnableWindow
pub extern "user32" fn EnableWindow(hWnd: HWND, bEnable: BOOL) callconv(.winapi) BOOL;

// SetFocus
pub extern "user32" fn SetFocus(hWnd: HWND) callconv(.winapi) ?HWND;

// Get/Set window long
pub extern "user32" fn SetWindowLongPtrW(
    hWnd: HWND,
    nIndex: i32,
    dwNewLong: isize,
) callconv(.winapi) isize;

pub extern "user32" fn GetWindowLongPtrW(
    hWnd: HWND,
    nIndex: i32,
) callconv(.winapi) isize;

pub const GWLP_USERDATA: i32 = -21;

// SetWindowPos
pub extern "user32" fn SetWindowPos(
    hWnd: HWND,
    hWndInsertAfter: ?HWND,
    X: i32,
    Y: i32,
    cx: i32,
    cy: i32,
    uFlags: UINT,
) callconv(.winapi) BOOL;

pub const SWP_NOSIZE: UINT = 0x0001;
pub const SWP_NOMOVE: UINT = 0x0002;
pub const SWP_NOZORDER: UINT = 0x0004;
pub const SWP_SHOWWINDOW: UINT = 0x0040;
pub const SWP_HIDEWINDOW: UINT = 0x0080;

// Clipboard
pub extern "user32" fn OpenClipboard(hWndNewOwner: ?HWND) callconv(.winapi) BOOL;
pub extern "user32" fn CloseClipboard() callconv(.winapi) BOOL;
pub extern "user32" fn GetClipboardData(uFormat: UINT) callconv(.winapi) ?HANDLE;
pub extern "user32" fn SetClipboardData(uFormat: UINT, hMem: ?HANDLE) callconv(.winapi) ?HANDLE;
pub extern "user32" fn EmptyClipboard() callconv(.winapi) BOOL;
pub extern "user32" fn IsClipboardFormatAvailable(uFormat: UINT) callconv(.winapi) BOOL;
pub extern "user32" fn CountClipboardFormats() callconv(.winapi) i32;

// GDI
pub extern "gdi32" fn CreateCompatibleDC(hdc: ?HDC) callconv(.winapi) ?HDC;
pub extern "gdi32" fn DeleteDC(hdc: HDC) callconv(.winapi) BOOL;
pub extern "gdi32" fn SelectObject(hdc: HDC, h: HGDIOBJ) callconv(.winapi) ?HGDIOBJ;
pub extern "gdi32" fn DeleteObject(ho: HGDIOBJ) callconv(.winapi) BOOL;
pub extern "gdi32" fn GetSysColorBrush(nIndex: i32) callconv(.winapi) HBRUSH;
pub extern "user32" fn GetSysColor(nIndex: i32) callconv(.winapi) DWORD;
pub extern "gdi32" fn SetBkColor(hdc: HDC, color: DWORD) callconv(.winapi) DWORD;
pub extern "gdi32" fn SetTextColor(hdc: HDC, color: DWORD) callconv(.winapi) DWORD;
pub extern "gdi32" fn CreateDIBSection(
    hdc: ?HDC,
    pbmi: *const BITMAPINFO,
    usage: UINT,
    ppvBits: ?*?*anyopaque,
    hSection: ?HANDLE,
    offset: DWORD,
) callconv(.winapi) ?HBITMAP;

pub const BITMAPINFOHEADER = extern struct {
    biSize: DWORD,
    biWidth: LONG,
    biHeight: LONG,
    biPlanes: WORD,
    biBitCount: WORD,
    biCompression: DWORD,
    biSizeImage: DWORD,
    biXPelsPerMeter: LONG,
    biYPelsPerMeter: LONG,
    biClrUsed: DWORD,
    biClrImportant: DWORD,
};

pub const BITMAPINFO = extern struct {
    bmiHeader: BITMAPINFOHEADER,
    bmiColors: [1]u32 align(4),
};

pub const DIB_RGB_COLORS: UINT = 0;

pub const BI_RGB: DWORD = 0;

// GDI+ (single named opaque so callers and declarations share one type)
pub const GpImage = opaque {};

// GDI+
pub extern "gdiplus" fn GdiplusStartup(
    token: *ULONG_PTR,
    input: *const GdiplusStartupInput,
    output: ?*GdiplusStartupOutput,
) callconv(.winapi) i32;

pub extern "gdiplus" fn GdiplusShutdown(token: ULONG_PTR) callconv(.winapi) void;

pub extern "gdiplus" fn GdipCreateBitmapFromHBITMAP(
    hbm: HBITMAP,
    hpal: ?HPALETTE,
    bitmap: *?*GpImage,
) callconv(.winapi) i32;

pub extern "gdiplus" fn GdipSaveImageToFile(
    image: *GpImage,
    filename: LPCWSTR,
    clsidEncoder: *const Guid,
    encoderParams: ?*anyopaque,
) callconv(.winapi) i32;

pub extern "gdiplus" fn GdipDisposeImage(image: *GpImage) callconv(.winapi) i32;

pub extern "gdiplus" fn GdipGetImageEncodersSize(
    numEncoders: *u32,
    size: *u32,
) callconv(.winapi) i32;

pub extern "gdiplus" fn GdipGetImageEncoders(
    numEncoders: u32,
    size: u32,
    encoders: *u8,
) callconv(.winapi) i32;

// Shell32
pub extern "shell32" fn Shell_NotifyIconW(
    dwMessage: DWORD,
    lpData: *NOTIFYICONDATAW,
) callconv(.winapi) BOOL;

pub extern "shell32" fn DragQueryFileW(
    hDrop: HANDLE,
    iFile: UINT,
    lpszFile: [*]WCHAR,
    cch: UINT,
) callconv(.winapi) UINT;

pub extern "shell32" fn DragFinish(hDrop: HANDLE) callconv(.winapi) void;

pub extern "shell32" fn SHGetSpecialFolderPathW(
    hwndOwner: ?HWND,
    lpszPath: [*]WCHAR,
    nFolder: i32,
    fCreate: BOOL,
) callconv(.winapi) BOOL;

pub const CSIDL_APPDATA: i32 = 0x001a;
pub const CSIDL_LOCAL_APPDATA: i32 = 0x001c;

// ShellExecute for opening urls or explorer
pub extern "shell32" fn ShellExecuteW(
    hwnd: ?HWND,
    lpOperation: LPCWSTR,
    lpFile: LPCWSTR,
    lpParameters: ?LPCWSTR,
    lpDirectory: ?LPCWSTR,
    nShowCmd: i32,
) callconv(.winapi) HINSTANCE;

/// ASCII string literal to UTF-16 null-terminated wide string (LPCWSTR). Non-ASCII is not mapped.
pub fn w(comptime s: []const u8) [(s.len + 1):0]u16 {
    var buf: [(s.len + 1):0]u16 = undefined;
    for (s, 0..) |c, i| {
        buf[i] = @as(u16, c);
    }
    buf[s.len] = 0;
    return buf;
}

// Convert UTF-8 to UTF-16 (allocating with the given allocator)
