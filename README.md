# sync-to-remote

A small **Windows** system tray application that uploads whatever is on the **clipboard** to a remote host over **SSH (SFTP)**, then replaces the clipboard with the **remote file path** so you can paste it elsewhere.

Written in [Zig](https://ziglang.org/) with the Win32 API (no console window).

## What it does

1. You copy a **file** (Explorer copy), **image**, or **text** to the clipboard.
2. You trigger an upload (global hotkey or tray icon).
3. The app uploads the content to a directory on your configured server via `sftp`.
4. On success, your clipboard becomes the full remote path (for example `/tmp/sync-to-remote/screenshot-20250430120000.png`).

Useful for quickly moving snippets or screenshots to a Linux box and pasting the path into a terminal or chat.

## Requirements

- **Windows** x86_64 (this is the only target the build is set up for).
- **OpenSSH client** on your `PATH`, specifically **`sftp.exe`** (included with Windows 10 and later as an optional feature, or installable via *Settings → Apps → Optional features → OpenSSH Client*).

Uploads are performed by spawning `sftp -b - …` with batch commands (`mkdir -p`, `put`, `bye`). Authentication is whatever your OpenSSH client uses—typically **SSH keys** (and **ssh-agent** if your key has a passphrase). There is no separate password UI in the app.

## Build

Install a recent Zig toolchain, then from the repository root:

```sh
zig build
```

The executable is installed to `zig-out/bin/sync-to-remote.exe` (or use your Zig install layout).

Run locally:

```sh
zig build run
```

Release binary:

```sh
zig build -Doptimize=ReleaseSmall
```

## Configuration

**Tray icon → right-click → Settings** opens a dialog for:

| Field | Meaning |
|--------|--------|
| Host | SSH server hostname or IP |
| Port | SSH port (default 22) |
| Username | SSH user |
| Remote path | Directory on the server (forward slashes, e.g. `/tmp/sync-to-remote/`) |

Settings are saved to:

`%APPDATA%\sync-to-remote\config.ini`

If you previously ran the app as **copy-to-ssh**, copy `config.ini` from `%APPDATA%\copy-to-ssh\` into `%APPDATA%\sync-to-remote\` (create that folder if needed).

Example `config.ini`:

```ini
[connection]
host=example.com
port=22
username=myuser
remote_path=/tmp/sync-to-remote/
```

## Usage

| Action | Effect |
|--------|--------|
| **Ctrl+Alt+Insert** | Upload current clipboard (if it contains a supported type). |
| **Tray — left click** | Same as the hotkey. |
| **Tray — right click** | Context menu: Settings, Exit. |

**Clipboard support:**

- **Files** — copied from File Explorer (`CF_HDROP`).
- **Images** — bitmap/DIB on the clipboard.
- **Text** — uploaded as a `.txt` file with a timestamped name.

If nothing supported is in the clipboard, or the host is not configured, the app shows a tray notification.

Only **one instance** runs at a time; starting again focuses the existing hidden window.
