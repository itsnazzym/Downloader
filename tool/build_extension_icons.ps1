# Regenerates extension/shared/icons/icon{16,32,48,96,128}.png from the desktop
# logo (assets/brand/logo-1024.png). Real asset, high-quality downscale, transparent corners kept.
# Usage: pwsh tool/build_extension_icons.ps1   (any cwd, no arguments)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$source = Join-Path $root 'assets/brand/logo-1024.png'
$outDir = Join-Path $root 'extension/shared/icons'
New-Item -ItemType Directory -Force $outDir | Out-Null

$src = [System.Drawing.Image]::FromFile($source)
try {
    foreach ($size in 16, 32, 48, 96, 128) {
        $bmp = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $attrs = New-Object System.Drawing.Imaging.ImageAttributes
        try {
            $g.Clear([System.Drawing.Color]::Transparent)
            $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
            $attrs.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
            $dest = New-Object System.Drawing.Rectangle 0, 0, $size, $size
            $g.DrawImage($src, $dest, 0, 0, $src.Width, $src.Height, [System.Drawing.GraphicsUnit]::Pixel, $attrs)
            $file = Join-Path $outDir "icon$size.png"
            $bmp.Save($file, [System.Drawing.Imaging.ImageFormat]::Png)
            Write-Output "wrote $file"
        } finally {
            $attrs.Dispose(); $g.Dispose(); $bmp.Dispose()
        }
    }
} finally {
    $src.Dispose()
}
