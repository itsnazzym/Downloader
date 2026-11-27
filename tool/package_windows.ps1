[CmdletBinding()]
param(
    [switch]$PortableOnly
)
$ErrorActionPreference = 'Stop'
$repoRoot = (Get-Location).Path
$release = Join-Path $repoRoot 'build\windows\x64\runner\Release'
$pubspec = Get-Content (Join-Path $repoRoot 'pubspec.yaml') -Raw
$versionMatch = [regex]::Match($pubspec, '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)')
if (-not $versionMatch.Success) {
    throw 'Unable to read application version from pubspec.yaml'
}
$appVersion = $versionMatch.Groups[1].Value

Write-Host "Building browser extensions..."
& dart run tool/build_extension.dart

Write-Host "Building a clean Windows release..."
& flutter clean
& flutter build windows --release

Write-Host "Embedding extensions..."
$extDest = Join-Path $release 'extension'
if (Test-Path $extDest) {
    Remove-Item $extDest -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $extDest | Out-Null
Copy-Item -Recurse -Force (Join-Path $repoRoot 'extension\chrome') (Join-Path $extDest 'chrome')
Copy-Item -Recurse -Force (Join-Path $repoRoot 'extension\firefox') (Join-Path $extDest 'firefox')

Write-Host "Preparing binaries in Release\bin..."
$releaseBin = Join-Path $release 'bin'
New-Item -ItemType Directory -Force -Path $releaseBin | Out-Null
& (Join-Path $repoRoot 'tool\prepare_tor_bundle.ps1') -OutDir $releaseBin -RepoRoot $repoRoot
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
$releaseDir = Join-Path $repoRoot 'release'
if (-not (Test-Path $releaseDir)) {
    New-Item -ItemType Directory -Force -Path $releaseDir | Out-Null
}
$zipPath = Join-Path $releaseDir "TapLoad-Windows-Portable-$appVersion.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path "$release\*" -DestinationPath $zipPath -CompressionLevel Optimal
Write-Host "Portable ZIP created at: $zipPath"

if ($PortableOnly) {
    Write-Host "Portable build completed! Skipping Setup Installer as requested."
    return
}

Write-Host "Building Setup Installer with Inno Setup..."
$iscc = "C:\Users\entre\AppData\Local\Programs\Inno Setup 6\ISCC.exe"
if (-not (Test-Path $iscc)) {
    $iscc = "C:\Users\entre\AppData\Local\Programs\Antigravity IDE\resources\app\node_modules\innosetup\bin\ISCC.exe"
}
& $iscc /DAppVersion="$appVersion" "installer\setup.iss"
$setupExe = Join-Path $releaseDir "TapLoad-Setup-$appVersion.exe"
Write-Host "Setup Installer created at: $setupExe"
