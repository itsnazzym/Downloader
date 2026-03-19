param(
  [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

function Get-AppVersion {
  param([string]$PubspecPath)
  $match = Select-String -Path $PubspecPath -Pattern '^version:\s*([0-9]+\.[0-9]+\.[0-9]+)'
  if (-not $match) {
    throw "Unable to read the app version from $PubspecPath"
  }
  return $match.Matches[0].Groups[1].Value
}

function Write-JsonFile {
  param(
    [string]$Path,
    [Parameter(Mandatory = $true)]$Value
  )
  $Value | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 $Path
}

$pubspecPath = Join-Path $ProjectRoot "pubspec.yaml"
$manifestPath = Join-Path $ProjectRoot "extension\chrome\manifest.json"
$extensionVersionPath = Join-Path $ProjectRoot "extension_version.json"
$buildRoot = Join-Path $ProjectRoot "build\extension\chrome"
$appVersion = Get-AppVersion -PubspecPath $pubspecPath
$zipPath = Join-Path $ProjectRoot "build\extension\modern_downloader_chrome_v$appVersion.zip"

$manifest = Get-Content -Raw $manifestPath | ConvertFrom-Json
$manifest.version = $appVersion
Write-JsonFile -Path $manifestPath -Value $manifest

if (Test-Path $extensionVersionPath) {
  $extensionVersion = Get-Content -Raw $extensionVersionPath | ConvertFrom-Json
  foreach ($addon in $extensionVersion.addons.PSObject.Properties) {
    foreach ($update in $addon.Value.updates) {
      $update.version = $appVersion
    }
  }
  Write-JsonFile -Path $extensionVersionPath -Value $extensionVersion
}

if (Test-Path $buildRoot) {
  Remove-Item $buildRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $buildRoot | Out-Null
Copy-Item (Join-Path $ProjectRoot "extension\chrome\*") -Destination $buildRoot -Recurse -Force

if (Test-Path $zipPath) {
  Remove-Item $zipPath -Force
}
Compress-Archive -Path (Join-Path $buildRoot "*") -DestinationPath $zipPath -Force

Write-Host "Chrome extension packaged:"
Write-Host "  Version: $appVersion"
Write-Host "  Folder : $buildRoot"
Write-Host "  Zip    : $zipPath"
