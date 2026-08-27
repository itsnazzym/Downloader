# Signs extension/firefox with Mozilla AMO (unlisted) and writes modern_downloader_firefox.xpi.
# Requires env: AMO_JWT_ISSUER, AMO_JWT_SECRET (same names as GitHub Actions secrets).
# Usage: .\tool\sign_firefox_xpi.ps1

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

$issuer = $env:AMO_JWT_ISSUER
$secret = $env:AMO_JWT_SECRET
if (-not $issuer -or -not $secret) {
    throw "Set AMO_JWT_ISSUER and AMO_JWT_SECRET environment variables first."
}

if (-not (Test-Path "extension/firefox/manifest.json")) {
    dart run tool/build_extension.dart
}

$artifacts = "signed-xpi"
if (Test-Path $artifacts) { Remove-Item $artifacts -Recurse -Force }
New-Item -ItemType Directory -Force -Path $artifacts | Out-Null

$signed = $null
for ($attempt = 1; $attempt -le 20; $attempt++) {
    $manifest = Get-Content "extension/firefox/manifest.json" -Raw | ConvertFrom-Json
    Write-Host "Signing Firefox add-on version $($manifest.version) (attempt $attempt)"
    $signOutput = npx --yes web-ext@8 sign `
        --source-dir extension/firefox `
        --api-key $issuer `
        --api-secret $secret `
        --channel unlisted `
        --artifacts-dir $artifacts 2>&1 | Out-String
    Write-Host $signOutput
    $signed = Get-ChildItem $artifacts -Filter *.xpi -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($signed) { break }
    if ($signOutput -match 'already exists') {
        Write-Host "AMO already has version $($manifest.version) — bumping patch"
        dart run tool/build_extension.dart --bump-patch
        if ($LASTEXITCODE -ne 0) { throw "Failed to bump add-on version after AMO conflict" }
        continue
    }
    throw "web-ext sign failed without producing an XPI"
}

if (-not $signed) { throw "web-ext sign produced no XPI" }

Copy-Item $signed.FullName modern_downloader_firefox.xpi -Force
Write-Host "Signed: modern_downloader_firefox.xpi ($($signed.Length) bytes)"
