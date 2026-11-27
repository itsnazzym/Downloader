param(
  [string]$Configuration = 'Debug'
)

$workspace = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$exe = Join-Path $workspace "build/windows/x64/runner/$Configuration/tapload.exe"
if (-not (Test-Path -LiteralPath $exe)) {
  throw "Build the Windows application first: $exe"
}

$screens = @('library', 'downloads', 'archive', 'stats', 'transfer', 'plugins')
foreach ($screen in $screens) {
  $demo = Start-Process -FilePath $exe -ArgumentList @(
    '--showcase',
    "--showcase-screen=$screen",
    '--showcase-theme=ios'
  ) -PassThru
  try {
    $ready = $false
    for ($attempt = 0; $attempt -lt 80; $attempt++) {
      Start-Sleep -Milliseconds 250
      $current = Get-Process -Id $demo.Id -ErrorAction SilentlyContinue
      if ($current -and $current.MainWindowHandle -ne 0) {
        $ready = $true
        break
      }
    }
    if (-not $ready) { throw "Showcase screen did not open: $screen" }
    Start-Sleep -Seconds 4
    $output = "site/public/media/showcase-$screen.png"
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'capture_showcase.ps1') -Output $output -ProcessId $demo.Id -ExpectedScreen $screen
    if ($LASTEXITCODE -ne 0) { throw "Capture failed: $screen" }
  } finally {
    $running = Get-CimInstance Win32_Process -Filter "ProcessId=$($demo.Id)" -ErrorAction SilentlyContinue
    if ($running -and $running.ExecutablePath -eq $exe -and $running.CommandLine -match '--showcase') {
      Stop-Process -Id $demo.Id -Force
    }
  }
}
