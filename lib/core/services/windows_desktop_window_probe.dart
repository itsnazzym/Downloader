import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import '../logger/logger_service.dart';

/// Detects Flutter windows on the *current* Win32 desktop only.
///
/// [EnumWindows] does not see HWNDs on another desktop in the same session
/// (e.g. an agent sandbox desktop). That lets a user-facing launch reclaim
/// a zombie that still holds the single-instance port.
class WindowsDesktopWindowProbe {
  static const flutterWindowClass = 'FLUTTER_RUNNER_WIN32_WINDOW';

  static final DynamicLibrary _user32 = DynamicLibrary.open('user32.dll');

  static final int Function(
    Pointer<NativeFunction<_EnumWindowsProc>>,
    int,
  )
  _enumWindows = _user32
      .lookupFunction<
        Int32 Function(Pointer<NativeFunction<_EnumWindowsProc>>, IntPtr),
        int Function(Pointer<NativeFunction<_EnumWindowsProc>>, int)
      >('EnumWindows');

  static final int Function(int, Pointer<Uint32>) _getWindowThreadProcessId =
      _user32
          .lookupFunction<
            Uint32 Function(IntPtr, Pointer<Uint32>),
            int Function(int, Pointer<Uint32>)
          >('GetWindowThreadProcessId');

  static final int Function(int, Pointer<Utf16>, int) _getClassNameW = _user32
      .lookupFunction<
        Int32 Function(IntPtr, Pointer<Utf16>, Int32),
        int Function(int, Pointer<Utf16>, int)
      >('GetClassNameW');

  static int _excludePid = 0;
  static bool _foundOther = false;

  static bool hasOtherAppWindow({required int currentPid}) {
    if (!Platform.isWindows) return false;
    try {
      _excludePid = currentPid;
      _foundOther = false;
      final cb = Pointer.fromFunction<_EnumWindowsProc>(_enumCallback, 0);
      _enumWindows(cb, 0);
      return _foundOther;
    } catch (e) {
      LoggerService.w('Desktop window probe failed: $e');
      return false;
    }
  }

  static int _enumCallback(int hwnd, int lParam) {
    if (hwnd == 0) return 1;
    final pidPtr = calloc<Uint32>();
    try {
      _getWindowThreadProcessId(hwnd, pidPtr);
      final ownerPid = pidPtr.value;
      if (ownerPid == 0 || ownerPid == _excludePid) return 1;
    } finally {
      calloc.free(pidPtr);
    }

    final name = calloc<Uint16>(256);
    try {
      final written = _getClassNameW(hwnd, name.cast<Utf16>(), 256);
      if (written > 0 && name.cast<Utf16>().toDartString() == flutterWindowClass) {
        _foundOther = true;
        return 0;
      }
    } finally {
      calloc.free(name);
    }
    return 1;
  }

  static Future<int?> listenerPidOnPort(int port) async {
    if (!Platform.isWindows) return null;
    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        'Get-NetTCPConnection -LocalPort $port -State Listen '
            '-ErrorAction SilentlyContinue | '
            'Select-Object -ExpandProperty OwningProcess -First 1',
      ]);
      final text = (result.stdout as String).trim();
      if (text.isEmpty) return null;
      return int.tryParse(RegExp(r'\d+').firstMatch(text)?.group(0) ?? '');
    } catch (e) {
      LoggerService.w('Failed to resolve listener PID on port $port: $e');
      return null;
    }
  }

  static bool terminatePid(int processId) {
    if (processId <= 0) return false;
    try {
      return Process.killPid(processId);
    } catch (e) {
      LoggerService.w('Failed to terminate stale PID $processId: $e');
      return false;
    }
  }
}

typedef _EnumWindowsProc = Int32 Function(IntPtr hwnd, IntPtr lParam);
