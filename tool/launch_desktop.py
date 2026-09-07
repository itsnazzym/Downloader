import ctypes
import ctypes.wintypes
import subprocess
import os
import sys

kernel32 = ctypes.windll.kernel32

class STARTUPINFO(ctypes.Structure):
    _fields_ = [
        ('cb', ctypes.wintypes.DWORD),
        ('lpReserved', ctypes.c_wchar_p),
        ('lpDesktop', ctypes.c_wchar_p),
        ('lpTitle', ctypes.c_wchar_p),
        ('dwX', ctypes.wintypes.DWORD),
        ('dwY', ctypes.wintypes.DWORD),
        ('dwXSize', ctypes.wintypes.DWORD),
        ('dwYSize', ctypes.wintypes.DWORD),
        ('dwXCountChars', ctypes.wintypes.DWORD),
        ('dwYCountChars', ctypes.wintypes.DWORD),
        ('dwFillAttribute', ctypes.wintypes.DWORD),
        ('dwFlags', ctypes.wintypes.DWORD),
        ('wShowWindow', ctypes.wintypes.WORD),
        ('cbReserved2', ctypes.wintypes.WORD),
        ('lpReserved2', ctypes.c_void_p),
        ('hStdInput', ctypes.wintypes.HANDLE),
        ('hStdOutput', ctypes.wintypes.HANDLE),
        ('hStdError', ctypes.wintypes.HANDLE)
    ]

class PROCESS_INFORMATION(ctypes.Structure):
    _fields_ = [
        ('hProcess', ctypes.wintypes.HANDLE),
        ('hThread', ctypes.wintypes.HANDLE),
        ('dwProcessId', ctypes.wintypes.DWORD),
        ('dwThreadId', ctypes.wintypes.DWORD)
    ]

def launch():
    # Kill any dangling background processes
    subprocess.run(["taskkill", "/F", "/IM", "modern_downloader.exe"], capture_output=True)

    si = STARTUPINFO()
    si.cb = ctypes.sizeof(STARTUPINFO)
    si.lpDesktop = "WinSta0\\Default"
    si.dwFlags = 1 # STARTF_USESHOWWINDOW
    si.wShowWindow = 1 # SW_SHOWNORMAL

    pi = PROCESS_INFORMATION()

    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    flavor = "Release" if "--release" in sys.argv else "Debug"
    app_path = os.path.join(project_root, "build", "windows", "x64", "runner", flavor, "modern_downloader.exe")

    if not os.path.exists(app_path):
        print(f"Error: binary not found at {app_path}. Please run flutter build windows first.")
        sys.exit(1)

    work_dir = os.path.dirname(app_path)
    res = kernel32.CreateProcessW(
        app_path,
        None,
        None,
        None,
        False,
        0,
        None,
        work_dir,
        ctypes.byref(si),
        ctypes.byref(pi)
    )

    if res:
        print(f"Successfully launched Modern Downloader on user desktop (WinSta0\\Default)! PID={pi.dwProcessId}")
        kernel32.CloseHandle(pi.hProcess)
        kernel32.CloseHandle(pi.hThread)
    else:
        err = kernel32.GetLastError()
        print(f"CreateProcess failed with error: {err}")
        sys.exit(1)

if __name__ == "__main__":
    launch()
