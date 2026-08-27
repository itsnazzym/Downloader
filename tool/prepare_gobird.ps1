#Requires -Version 5.1
<#
.SYNOPSIS
  Download, verify (SHA-256), and stage the pinned gobird Windows binary.

.DESCRIPTION
  Pins gobird 26.05.13 (windows amd64). Extracts only gobird.exe into the
  target bin directory and copies third-party license / risk notices.
  Does not make gobird a required startup dependency of the app.
#>
[CmdletBinding()]
param(
  [string]$OutDir = "",
  [string]$RepoRoot = "",
  [switch]$SkipDownloadIfPresent
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$PinnedVersion = '26.05.13'
$ArchiveName = "gobird_${PinnedVersion}_windows_amd64.zip"
$DownloadUrl = "https://github.com/mudrii/gobird/releases/download/${PinnedVersion}/${ArchiveName}"
$ExpectedSha256 = '7406fc3c1cf2fc70ec53c70782533f73b86ecefd08df3ea15256a90d1f20f925'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
  $RepoRoot = Split-Path -Parent $PSScriptRoot
}
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path

if ([string]::IsNullOrWhiteSpace($OutDir)) {
  $OutDir = Join-Path $RepoRoot 'bin'
}
if (-not (Test-Path -LiteralPath $OutDir)) {
  New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
}
$OutDir = (Resolve-Path -LiteralPath $OutDir).Path

$ThirdPartyDir = Join-Path $RepoRoot 'third_party\gobird'
if (-not (Test-Path -LiteralPath $ThirdPartyDir)) {
  New-Item -ItemType Directory -Force -Path $ThirdPartyDir | Out-Null
}

$ExePath = Join-Path $OutDir 'gobird.exe'
if ($SkipDownloadIfPresent -and (Test-Path -LiteralPath $ExePath)) {
  Write-Host "gobird.exe already present at $ExePath (SkipDownloadIfPresent)"
  exit 0
}

$TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("gobird-prep-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $TempRoot | Out-Null

try {
  $ZipPath = Join-Path $TempRoot $ArchiveName
  Write-Host "Downloading $DownloadUrl"
  Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath -UseBasicParsing

  $ActualHash = (Get-FileHash -LiteralPath $ZipPath -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($ActualHash -ne $ExpectedSha256.ToLowerInvariant()) {
    throw "SHA-256 mismatch for $ArchiveName. Expected $ExpectedSha256, got $ActualHash"
  }
  Write-Host "SHA-256 verified: $ActualHash"

  $ExtractDir = Join-Path $TempRoot 'extract'
  New-Item -ItemType Directory -Force -Path $ExtractDir | Out-Null
  Expand-Archive -LiteralPath $ZipPath -DestinationPath $ExtractDir -Force

  $Found = Get-ChildItem -LiteralPath $ExtractDir -Recurse -Filter 'gobird.exe' -File |
    Select-Object -First 1
  if (-not $Found) {
    throw "gobird.exe not found inside $ArchiveName"
  }

  Copy-Item -LiteralPath $Found.FullName -Destination $ExePath -Force
  Write-Host "Staged gobird.exe → $ExePath"

  # Copy third_party notices next to the staged binary (for Release artifacts).
  $NoticeOut = Join-Path $OutDir 'third_party\gobird'
  $ThirdPartyFull = (Resolve-Path -LiteralPath $ThirdPartyDir).Path
  if ((Resolve-Path -LiteralPath $OutDir).Path -ne $ThirdPartyFull -and
      -not $NoticeOut.StartsWith($ThirdPartyFull, [System.StringComparison]::OrdinalIgnoreCase)) {
    New-Item -ItemType Directory -Force -Path $NoticeOut | Out-Null
    foreach ($name in @('LICENSE', 'RISK_NOTICE.md', 'NOTICE.txt')) {
      $src = Join-Path $ThirdPartyDir $name
      if (Test-Path -LiteralPath $src) {
        Copy-Item -LiteralPath $src -Destination (Join-Path $NoticeOut $name) -Force
      }
    }
  }

  # Smoke-check version without requiring X auth.
  try {
    $ver = & $ExePath --version 2>&1 | Out-String
    Write-Host ("gobird --version: " + $ver.Trim())
  } catch {
    Write-Warning "Could not run gobird --version: $_"
  }

  Write-Host "prepare_gobird.ps1 completed successfully (v$PinnedVersion)"
}
finally {
  if (Test-Path -LiteralPath $TempRoot) {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}
