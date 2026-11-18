param(
  [string]$Output = 'site/public/media/showcase-library.png',
  [int]$ProcessId = 0,
  [string]$ExpectedScreen = ''
)

$source = @'
using System;
using System.Runtime.InteropServices;
public static class ShowcaseWindowCapture {
  [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd, out Rect rect);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hwnd, IntPtr hdc, uint flags);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hwnd, int command);
}
'@

Add-Type -TypeDefinition $source
Add-Type -AssemblyName System.Drawing
$process = if ($ProcessId -gt 0) {
  Get-Process -Id $ProcessId -ErrorAction Stop
} else {
  Get-Process modern_downloader -ErrorAction Stop |
    Where-Object { $_.Path -like '*Downloader-main*' } |
    Select-Object -First 1
}
if (-not $process -or $process.MainWindowHandle -eq 0) {
  throw 'The local showcase window was not found.'
}
if ($process.Path -notlike '*Downloader-main*') {
  throw 'Refusing to capture a window outside this checkout.'
}
$commandLine = (Get-CimInstance Win32_Process -Filter "ProcessId=$($process.Id)").CommandLine
if ($commandLine -notmatch '(?:^|\s)--showcase(?:\s|$)') {
  throw 'Refusing to capture a window that was not started in showcase mode.'
}
if ($ExpectedScreen -and $commandLine -notmatch "--showcase-screen=$([regex]::Escape($ExpectedScreen))(?:\s|$)") {
  throw "Refusing to capture a different showcase screen: $ExpectedScreen"
}

[ShowcaseWindowCapture]::ShowWindow($process.MainWindowHandle, 9) | Out-Null
Start-Sleep -Milliseconds 300
$bounds = New-Object ShowcaseWindowCapture+Rect
[ShowcaseWindowCapture]::GetWindowRect($process.MainWindowHandle, [ref]$bounds) | Out-Null
$width = $bounds.Right - $bounds.Left
$height = $bounds.Bottom - $bounds.Top
if ($width -lt 800 -or $height -lt 600) {
  throw "Unexpected capture size: $width x $height"
}

$bitmap = New-Object System.Drawing.Bitmap($width, $height)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$device = $graphics.GetHdc()
$ok = [ShowcaseWindowCapture]::PrintWindow($process.MainWindowHandle, $device, 2)
$graphics.ReleaseHdc($device)
$graphics.Dispose()
if (-not $ok) {
  $bitmap.Dispose()
  throw 'Capturing the showcase window failed.'
}

$destination = Join-Path (Split-Path $PSScriptRoot -Parent) $Output
New-Item -ItemType Directory -Force -Path (Split-Path $destination) | Out-Null
$bitmap.Save($destination, [System.Drawing.Imaging.ImageFormat]::Png)
$bitmap.Dispose()
Write-Output $destination
