[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$OutDir,
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$version = '15.0.23'
$archiveName = "tor-expert-bundle-windows-x86_64-$version.tar.gz"
$archiveUrl = "https://dist.torproject.org/torbrowser/$version/$archiveName"
$expectedSha256 = '231dad6b9cb401a54c260db7046965ef04e4f72ff071b140d423fb5da281ab1e'

$repoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
if (Test-Path -LiteralPath $OutDir) {
    $outputDirectory = (Resolve-Path -LiteralPath $OutDir).Path
} else {
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
    $outputDirectory = (Resolve-Path -LiteralPath $OutDir).Path
}

$localBundle = Join-Path $repoRoot 'tor-bundle-expert'
$localTorExe = Join-Path $localBundle 'tor\tor.exe'
$useLocalBundle = (
    (Test-Path -LiteralPath $localTorExe) -and
    (Test-Path -LiteralPath (Join-Path $localBundle 'data\geoip')) -and
    (Test-Path -LiteralPath (Join-Path $localBundle 'data\geoip6'))
)

$destination = Join-Path $outputDirectory 'tor-bundle-expert'
$fullDestination = [System.IO.Path]::GetFullPath($destination)
$fullOutputDirectory = [System.IO.Path]::GetFullPath($outputDirectory).TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
)
$destinationParent = [System.IO.Path]::GetFullPath((Split-Path -Parent $fullDestination)).TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
)
if (-not $destinationParent.Equals($fullOutputDirectory, [System.StringComparison]::OrdinalIgnoreCase) -or
    (Split-Path -Leaf $fullDestination) -ne 'tor-bundle-expert') {
    throw "Refusing to replace an unexpected Tor destination: $fullDestination"
}

$sourceRoot = $localBundle
$temporaryRoot = $null
try {
    if (-not $useLocalBundle) {
        $tempBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd(
            [System.IO.Path]::DirectorySeparatorChar,
            [System.IO.Path]::AltDirectorySeparatorChar
        )
        $temporaryRoot = Join-Path $tempBase ("moderndownloader-tor-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Force -Path $temporaryRoot | Out-Null
        $archivePath = Join-Path $temporaryRoot $archiveName
        Invoke-WebRequest -Uri $archiveUrl -OutFile $archivePath

        $actualSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $archivePath).Hash.ToLowerInvariant()
        if ($actualSha256 -ne $expectedSha256) {
            throw "Tor bundle checksum mismatch. Expected $expectedSha256, received $actualSha256."
        }

        $sourceRoot = Join-Path $temporaryRoot 'extracted'
        New-Item -ItemType Directory -Force -Path $sourceRoot | Out-Null
        & tar -xzf $archivePath -C $sourceRoot
        if ($LASTEXITCODE -ne 0) {
            throw "Could not extract the Tor bundle (tar exit code $LASTEXITCODE)."
        }
    }

    $requiredFiles = @(
        'tor\tor.exe',
        'data\geoip',
        'data\geoip6',
        'docs\tor.txt'
    )
    foreach ($relativePath in $requiredFiles) {
        if (-not (Test-Path -LiteralPath (Join-Path $sourceRoot $relativePath))) {
            throw "Tor bundle is missing required file: $relativePath"
        }
    }

    if (Test-Path -LiteralPath $destination) {
        Remove-Item -LiteralPath $destination -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $destination | Out-Null
    Get-ChildItem -LiteralPath $sourceRoot | Copy-Item -Destination $destination -Recurse -Force

    $torVersion = (& (Join-Path $destination 'tor\tor.exe') --version | Select-Object -First 1)
    Write-Host "Prepared $torVersion at $destination"
} finally {
    if ($null -ne $temporaryRoot -and (Test-Path -LiteralPath $temporaryRoot)) {
        $fullTemporaryRoot = [System.IO.Path]::GetFullPath($temporaryRoot).TrimEnd(
            [System.IO.Path]::DirectorySeparatorChar,
            [System.IO.Path]::AltDirectorySeparatorChar
        )
        $fullTempBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd(
            [System.IO.Path]::DirectorySeparatorChar,
            [System.IO.Path]::AltDirectorySeparatorChar
        )
        if (-not $fullTemporaryRoot.StartsWith(
            "$fullTempBase$([System.IO.Path]::DirectorySeparatorChar)",
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
            throw "Refusing to remove a Tor download outside the temporary directory: $fullTemporaryRoot"
        }
        Remove-Item -LiteralPath $fullTemporaryRoot -Recurse -Force
    }
}
