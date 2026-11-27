# Signs extension/firefox with Mozilla AMO (unlisted) and writes tapload_firefox.xpi.
# Requires env: AMO_JWT_ISSUER, AMO_JWT_SECRET (same names as GitHub Actions secrets).
# Usage: .\tool\sign_firefox_xpi.ps1

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

function Import-DotEnv {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return }
    Get-Content $Path | ForEach-Object {
        $line = $_.Trim()
        if (-not $line -or $line.StartsWith('#')) { return }
        $eq = $line.IndexOf('=')
        if ($eq -lt 1) { return }
        $name = $line.Substring(0, $eq).Trim()
        $value = $line.Substring($eq + 1).Trim()
        if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
            $value = $value.Substring(1, $value.Length - 2)
        }
        if (-not [string]::IsNullOrWhiteSpace($name) -and -not [Environment]::GetEnvironmentVariable($name)) {
            Set-Item -Path "Env:$name" -Value $value
        }
    }
}

Import-DotEnv (Join-Path $PWD ".env")

$issuer = $env:AMO_JWT_ISSUER
$secret = $env:AMO_JWT_SECRET
if (-not $issuer -or -not $secret) {
    throw @"
AMO credentials missing. Set AMO_JWT_ISSUER and AMO_JWT_SECRET via:
  - Environment variables, or
  - A .env file at repo root (gitignored), e.g.:
      AMO_JWT_ISSUER=your_jwt_issuer
      AMO_JWT_SECRET=your_jwt_secret
Keys: https://addons.mozilla.org/developers/addon/api/key/
"@
}

dart run tool/build_extension.dart

$artifacts = "signed-xpi"
if (Test-Path $artifacts) { Remove-Item $artifacts -Recurse -Force }
New-Item -ItemType Directory -Force -Path $artifacts | Out-Null

$signed = $null
for ($attempt = 1; $attempt -le 20; $attempt++) {
    Remove-Item "extension/firefox/.amo-upload-uuid" -Force -ErrorAction SilentlyContinue
    Remove-Item "extension/firefox/.web-extension-id" -Force -ErrorAction SilentlyContinue

    $manifest = Get-Content "extension/firefox/manifest.json" -Raw | ConvertFrom-Json
    Write-Host "Signing Firefox add-on version $($manifest.version) (attempt $attempt)"
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $signOutput = & npx --yes web-ext@8 sign `
            --source-dir extension/firefox `
            --api-key $issuer `
            --api-secret $secret `
            --channel unlisted `
            --artifacts-dir $artifacts 2>&1 | Out-String
    } finally {
        $ErrorActionPreference = $prevEap
    }
    Write-Host $signOutput
    $signed = Get-ChildItem $artifacts -Filter *.xpi -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($signed) { break }
    if ($signOutput -match 'already exists' -or $signOutput -match 'already been submitted') {
        Write-Host "AMO already has version $($manifest.version) or upload was submitted - bumping patch"
        Remove-Item "extension/firefox/.amo-upload-uuid" -Force -ErrorAction SilentlyContinue
        dart run tool/build_extension.dart --bump-patch
        if ($LASTEXITCODE -ne 0) { throw "Failed to bump add-on version after AMO conflict" }
        continue
    }
    if ($signOutput -match 'throttled.*?Expected available in (\d+) seconds') {
        $waitSec = [int]$Matches[1] + 3
        Write-Host "AMO rate limited (429). Waiting $waitSec seconds before retrying..."
        Start-Sleep -Seconds $waitSec
        continue
    }
    throw "web-ext sign failed without producing an XPI"
}

if (-not $signed) { throw "web-ext sign produced no XPI" }

if (Test-Path tapload_firefox.xpi) {
    Move-Item tapload_firefox.xpi tapload_firefox.xpi.old -Force -ErrorAction SilentlyContinue
}
Copy-Item $signed.FullName tapload_firefox.xpi -Force
Remove-Item tapload_firefox.xpi.old -Force -ErrorAction SilentlyContinue
Remove-Item "extension/firefox/.amo-upload-uuid" -Force -ErrorAction SilentlyContinue
Remove-Item "extension/firefox/.web-extension-id" -Force -ErrorAction SilentlyContinue
Write-Host ("Signed: tapload_firefox.xpi ({0} bytes)" -f $signed.Length)
