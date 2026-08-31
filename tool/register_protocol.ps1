$ErrorActionPreference = "Stop"

$Protocol = "moderndownloader"
$AppPath = "$PSScriptRoot\..\build\windows\x64\runner\Debug\modern_downloader.exe" 
# Note: For dev, we point to the Debug exe. In production, this would be the installed path.

# Verify exe exists
if (-not (Test-Path $AppPath)) {
    Write-Host "Executable not found at $AppPath" -ForegroundColor Yellow
    Write-Host "Please build the app first (flutter run -d windows) or update the path." -ForegroundColor Yellow
    # Fallback to trying to find it in Release if Debug is missing, or just warn.
    # We will proceed assuming the user will build it.
}

$RegistryPath = "HKCU:\Software\Classes\$Protocol"

Write-Host "Registering protocol '$Protocol'..."

# Create Key
New-Item -Path $RegistryPath -Force | Out-Null
New-ItemProperty -Path $RegistryPath -Name "(Default)" -Value "URL:Modern Downloader Protocol" -PropertyType String -Force | Out-Null
New-ItemProperty -Path $RegistryPath -Name "URL Protocol" -Value "" -PropertyType String -Force | Out-Null

# Create Default Icon
$IconPath = "$RegistryPath\DefaultIcon"
New-Item -Path $IconPath -Force | Out-Null
New-ItemProperty -Path $IconPath -Name "(Default)" -Value "$AppPath,1" -PropertyType String -Force | Out-Null

# Create Command
$CommandPath = "$RegistryPath\shell\open\command"
New-Item -Path $CommandPath -Force | Out-Null
New-ItemProperty -Path $CommandPath -Name "(Default)" -Value "`"$AppPath`" `"%1`"" -PropertyType String -Force | Out-Null

Write-Host "Protocol registered successfully!" -ForegroundColor Green
Write-Host "Test it by running: Start-Process '${Protocol}://open?url=https://youtube.com/watch?v=dQw4w9WgXcQ'" -ForegroundColor Cyan
