# Review sheet for the icon art: each picture at -Cell px with its key under it and, beside it, the same picture at
# 64 px (its size on the hotbar). Keys come from art\icons\subjects.txt order.
#   powershell -ExecutionPolicy Bypass -File tools\icon_sheet.ps1 -Out sheet.png [-Keys "Focus,Fire"] [-From 0 -Count 20]
param(
    [Parameter(Mandatory = $true)][string]$Out,
    [string]$Keys = "",
    [int]$From = 0,
    [int]$Count = 20,
    [int]$Cell = 160,
    [int]$Columns = 5
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$art = Join-Path $root "art\icons"
Add-Type -AssemblyName System.Drawing
$all = @()
foreach ($line in [IO.File]::ReadAllLines((Join-Path $art "subjects.txt"))) {
    if ($line.Trim() -eq "" -or $line.StartsWith("#")) { continue }
    $all += ($line -split "\|", 2)[0].Trim()
}
$want = @($Keys -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$list = if ($want.Count -gt 0) { $want } else { @($all | Select-Object -Skip $From -First $Count) }
function Find-Picture([string]$key) {
    @("jpg", "png") | ForEach-Object { Join-Path $art "$key.$_" } | Where-Object { Test-Path $_ } | Select-Object -First 1
}
$list = @($list | Where-Object { Find-Picture $_ })
if ($list.Count -eq 0) { throw "no pictures to show" }
$w = $Cell + 64 + 12
$h = $Cell + 22
$rows = [math]::Ceiling($list.Count / $Columns)
$sheet = New-Object System.Drawing.Bitmap ($Columns * $w), ($rows * $h)
$g = [System.Drawing.Graphics]::FromImage($sheet)
$g.Clear([System.Drawing.Color]::FromArgb(30, 30, 30))
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$font = New-Object System.Drawing.Font "Segoe UI", 10
$brush = [System.Drawing.Brushes]::White
for ($i = 0; $i -lt $list.Count; $i++) {
    $x = ($i % $Columns) * $w
    $y = [math]::Floor($i / $Columns) * $h
    $img = [System.Drawing.Image]::FromFile((Find-Picture $list[$i]))
    $g.DrawImage($img, $x + 2, $y + 2, $Cell, $Cell)
    $g.DrawImage($img, $x + $Cell + 8, $y + 2, 64, 64)
    $img.Dispose()
    $g.DrawString($list[$i], $font, $brush, $x + 2, $y + $Cell + 3)
}
$g.Dispose()
$sheet.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$sheet.Dispose()
"wrote $Out ($($list.Count) pictures)"
