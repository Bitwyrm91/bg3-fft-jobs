# Builds the icon textures for the package from art\icons\<key>.jpg (or .png) and the atlas layout written by tools\build.py
# (Mod\Public\FFTJobs\GUI\Icons_FFTJobs.lsx), into the stage folder. Called by tools\package.ps1. Same files as vanilla
# ships for a spell icon (checked in Icons.pak / Game.pak, 2026-10-12):
#   Public\FFTJobs\Assets\Textures\Icons\Icons_FFTJobs.dds                 hotbar atlas, 64 px cells, DXT5 + mipmaps
#                                                                         (vanilla Icons_Items_Dev.dds is the same)
#   Public\Game\GUI\Assets\Tooltips\Icons\<icon>.DDS                       380 px tooltip picture
#   Public\Game\GUI\AssetsLowRes\Tooltips\Icons\<icon>.DDS                 192 px
#   Public\Game\GUI\Assets\ControllerUIIcons\skills_png\<icon>.DDS         144 px, controller UI
#   Public\Game\GUI\AssetsLowRes\ControllerUIIcons\skills_png\<icon>.DDS   72 px
# The single pictures are BC3 under a DX10 header (vanilla's are BC7, which nvdxt cannot write); the extension must
# be upper-case .DDS (the game's lookup is case-sensitive).
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_icons.ps1 -Stage build\stage [-Nvdxt <path>]
param(
    [Parameter(Mandatory = $true)][string]$Stage,
    [string]$Nvdxt = "C:\Program Files (x86)\Steam\steamapps\common\The Divinity Engine 2\DefEd\nvdxt.exe"
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$Stage = (Resolve-Path $Stage).Path
$lsx = Join-Path $root "Mod\Public\FFTJobs\GUI\Icons_FFTJobs.lsx"
if (-not (Test-Path $lsx)) {
    Write-Host "no icon atlas (no pictures in art\icons): icons skipped"
    return
}
if (-not (Test-Path $Nvdxt)) { throw "nvdxt.exe not found at $Nvdxt" }
Add-Type -AssemblyName System.Drawing
$prefix = "FFTJ_Icon_"
[xml]$doc = Get-Content $lsx -Raw
$size = [int]$doc.SelectSingleNode("//node[@id='TextureAtlasTextureSize']/attribute[@id='Width']").value
$cell = [int]$doc.SelectSingleNode("//node[@id='TextureAtlasIconSize']/attribute[@id='Width']").value
$atlasPath = $doc.SelectSingleNode("//node[@id='TextureAtlasPath']/attribute[@id='Path']").value
$icons = foreach ($n in $doc.SelectNodes("//node[@id='IconUV']")) {
    $name = $n.SelectSingleNode("attribute[@id='MapKey']").value
    [pscustomobject]@{
        Name = $name
        Key  = $name.Substring($prefix.Length)
        X    = [int][math]::Floor([double]$n.SelectSingleNode("attribute[@id='U1']").value * $size)
        Y    = [int][math]::Floor([double]$n.SelectSingleNode("attribute[@id='V1']").value * $size)
    }
}
$tmp = Join-Path $root "build\icons_tmp"
if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
New-Item -ItemType Directory -Force $tmp | Out-Null

function Resize([System.Drawing.Image]$img, [int]$px) {
    $bmp = New-Object System.Drawing.Bitmap $px, $px, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $g.DrawImage($img, 0, 0, $px, $px)
    $g.Dispose()
    return $bmp
}

function Invoke-Nvdxt([string]$png, [string]$dds, [switch]$Mips) {
    $nvArgs = @("-file", $png, "-output", $dds, "-dxt5", "-quality_production")
    if (-not $Mips) { $nvArgs += "-nomipmap" }
    & $Nvdxt @nvArgs 2>&1 | Out-Null
    if (-not (Test-Path $dds)) { throw "nvdxt failed for $png" }
}

# nvdxt's DXT5 file (128-byte legacy header) -> the same BC3 blocks under a DX10 header (DXGI_FORMAT_BC3_UNORM = 77),
# laid out like vanilla's tooltip pictures: flags 0xA1007, one mip level, caps TEXTURE, 2D texture, array size 1.
function Convert-ToDx10([string]$src, [string]$dst) {
    $b = [IO.File]::ReadAllBytes($src)
    $h = [BitConverter]::ToUInt32($b, 12)
    $w = [BitConverter]::ToUInt32($b, 16)
    $data = $b.Length - 128
    $ms = New-Object IO.MemoryStream
    $bw = New-Object IO.BinaryWriter $ms
    $bw.Write([byte[]][char[]]"DDS ")
    foreach ($v in @(124, 0xA1007, $h, $w, $data, 0, 1)) { $bw.Write([uint32]$v) }
    for ($i = 0; $i -lt 11; $i++) { $bw.Write([uint32]0) }          # reserved
    $bw.Write([uint32]32); $bw.Write([uint32]4); $bw.Write([byte[]][char[]]"DX10")
    for ($i = 0; $i -lt 5; $i++) { $bw.Write([uint32]0) }           # bit count and masks
    foreach ($v in @(0x1000, 0, 0, 0, 0)) { $bw.Write([uint32]$v) }  # caps, caps2-4, reserved
    foreach ($v in @(77, 3, 0, 1, 0)) { $bw.Write([uint32]$v) }      # DX10: format, 2D, misc, array size, misc2
    $bw.Write($b, 128, $data)
    $bw.Flush()
    [IO.File]::WriteAllBytes($dst, $ms.ToArray())
    $bw.Dispose()
}

$sizes = @(
    @("Public\Game\GUI\Assets\Tooltips\Icons", 380),
    @("Public\Game\GUI\AssetsLowRes\Tooltips\Icons", 192),
    @("Public\Game\GUI\Assets\ControllerUIIcons\skills_png", 144),
    @("Public\Game\GUI\AssetsLowRes\ControllerUIIcons\skills_png", 72)
)
foreach ($s in $sizes) { New-Item -ItemType Directory -Force (Join-Path $Stage $s[0]) | Out-Null }
$atlas = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$ga = [System.Drawing.Graphics]::FromImage($atlas)
$ga.Clear([System.Drawing.Color]::Transparent)
foreach ($icon in $icons) {
    $pic = @("jpg", "png") | ForEach-Object { Join-Path $root "art\icons\$($icon.Key).$_" } | Where-Object { Test-Path $_ } |
        Select-Object -First 1
    if (-not $pic) { throw "missing picture art\icons\$($icon.Key).jpg (rebuild with tools\build.py)" }
    $img = [System.Drawing.Image]::FromFile($pic)
    try {
        $small = Resize $img $cell
        $ga.DrawImageUnscaled($small, $icon.X, $icon.Y)
        $small.Dispose()
        foreach ($s in $sizes) {
            $bmp = Resize $img $s[1]
            $p = Join-Path $tmp "$($icon.Name)_$($s[1]).png"
            $bmp.Save($p, [System.Drawing.Imaging.ImageFormat]::Png)
            $bmp.Dispose()
            $raw = [IO.Path]::ChangeExtension($p, ".dds")
            Invoke-Nvdxt $p $raw
            Convert-ToDx10 $raw (Join-Path (Join-Path $Stage $s[0]) "$($icon.Name).DDS")
        }
    } finally {
        $img.Dispose()
    }
}
$ga.Dispose()
$atlasPng = Join-Path $tmp "atlas.png"
$atlas.Save($atlasPng, [System.Drawing.Imaging.ImageFormat]::Png)
$atlas.Dispose()
$atlasDds = Join-Path (Join-Path $Stage "Public\FFTJobs") ($atlasPath -replace "/", "\")
New-Item -ItemType Directory -Force (Split-Path $atlasDds -Parent) | Out-Null
Invoke-Nvdxt $atlasPng $atlasDds -Mips
Write-Host "icons: $(@($icons).Count) pictures, atlas $size px -> $atlasDds"
