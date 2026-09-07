$ErrorActionPreference = 'Stop'
$repoRoot = (Get-Location).Path
$release = Join-Path $repoRoot 'build\windows\x64\runner\Release'

Write-Host "Embedding extensions..."
$extDest = Join-Path $release 'extension'
New-Item -ItemType Directory -Force -Path $extDest | Out-Null
Copy-Item -Recurse -Force (Join-Path $repoRoot 'extension\chrome') (Join-Path $extDest 'chrome')
Copy-Item -Recurse -Force (Join-Path $repoRoot 'extension\firefox') (Join-Path $extDest 'firefox')

Write-Host "Preparing binaries in Release\bin..."
$releaseBin = Join-Path $release 'bin'
New-Item -ItemType Directory -Force -Path $releaseBin | Out-Null
if (Test-Path ".\tool\prepare_gobird.ps1") {
    try {
        & ".\tool\prepare_gobird.ps1" -OutDir $releaseBin -RepoRoot $repoRoot -SkipDownloadIfPresent
    } catch {
        Write-Warning "Gobird staging skipped: $_"
    }
}
if (Test-Path "third_party\gobird") {
    Copy-Item -Recurse -Force "third_party\gobird" (Join-Path $releaseBin 'third_party\gobird')
}

if (Test-Path "bin") {
    Get-ChildItem -Path "bin\*.exe" -ErrorAction SilentlyContinue | ForEach-Object {
        Copy-Item -Force $_.FullName (Join-Path $releaseBin $_.Name)
    }
}

Write-Host "Creating Portable ZIP..."
$zipPath = Join-Path $repoRoot 'ModernDownloader-Windows-Portable.zip'
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path "$release\*" -DestinationPath $zipPath -CompressionLevel Optimal
Write-Host "Portable ZIP created at: $zipPath"

Write-Host "Building Setup Installer with Inno Setup..."
$iscc = "C:\Users\entre\AppData\Local\Programs\Inno Setup 6\ISCC.exe"
if (-not (Test-Path $iscc)) {
    $iscc = "C:\Users\entre\AppData\Local\Programs\Antigravity IDE\resources\app\node_modules\innosetup\bin\ISCC.exe"
}
& $iscc /DAppVersion="1.0.8" "installer\setup.iss"
$setupExe = Join-Path $repoRoot 'ModernDownloader-Setup-1.0.8.exe'
Write-Host "Setup Installer created at: $setupExe"
