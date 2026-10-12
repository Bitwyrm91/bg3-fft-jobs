# Paints the icon art on the local GPU (stable-diffusion.cpp, Vulkan, Z-Image-Turbo: the same setup as the user's
# Divinity mods) from art\icons\subjects.txt. Each picture is made at 512 px (kept in art\_ai_raw, not in git) and
# saved at 380 px, the tooltip size, as art\icons\<key>.jpg (quality 95: a sixth of the PNG size in git; the game gets
# DDS files anyway). Keys that already have a picture are skipped unless -Force.
# Extra fields on a subjects line: a badge drawn on the picture (e.g. "+5" on Aim +5: the tiers of one ability look
# alike at 64 px), and seed=N for a picture kept from another seed (used unless -Seed is given). Painting needs the GPU
# memory BG3 uses: with the game running most runs fail at once ("failed: <key>"), so paint with the game closed.
#   powershell -ExecutionPolicy Bypass -File tools\generate_icon_art.ps1
#   powershell -ExecutionPolicy Bypass -File tools\generate_icon_art.ps1 -Only "Focus,Rush" -Force -Seed 12
#   powershell -ExecutionPolicy Bypass -File tools\generate_icon_art.ps1 -BadgeOnly   (redo pictures from art\_ai_raw)
# Then: tools\icon_sheet.ps1 to review, tools\build.py, tools\package.ps1 (which builds the DDS files).
param(
    [string]$Only = "",
    [switch]$Force,
    [switch]$BadgeOnly,
    [int]$Seed = 11,
    [string]$Sd = "C:\Users\berus\DOS2Modding\tools\sd"
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$art = Join-Path $root "art\icons"
$raw = Join-Path $root "art\_ai_raw"
New-Item -ItemType Directory -Force $raw | Out-Null
Add-Type -AssemblyName System.Drawing
# "jewel-tone colours" made the model scatter gems and orbs around the subject, and "small" gave a grid of tiny
# pictures (first test run): describe one large subject and plain colours.
$style = "Digital painting, fantasy game spell artwork in a medieval storybook style, painterly brushwork, warm " +
    "parchment undertones, rich deep colours, full-bleed composition that fills the entire canvas edge to edge, " +
    "dramatic lighting, one bold focal subject in the centre. Subject:"
$subjects = [ordered]@{}
$badges = @{}
$seeds = @{}
foreach ($line in [IO.File]::ReadAllLines((Join-Path $art "subjects.txt"))) {
    if ($line.Trim() -eq "" -or $line.StartsWith("#")) { continue }
    $parts = $line -split "\|"
    $k = $parts[0].Trim()
    $subjects[$k] = $parts[1].Trim()
    # extra fields: "seed=N" (the seed that made the kept picture), anything else is the badge
    foreach ($extra in @($parts | Select-Object -Skip 2)) {
        $x = $extra.Trim()
        if ($x -match '^seed=(\d+)$') { $seeds[$k] = [int]$Matches[1] } elseif ($x) { $badges[$k] = $x }
    }
}
$seedGiven = $PSBoundParameters.ContainsKey("Seed")
$want = @($Only -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ })

# Resizes to $size and draws the badge (warm gold text with a dark outline) in the bottom-right corner.
function Save-Icon([string]$src, [string]$dst, [int]$size, [string]$badge) {
    $img = [System.Drawing.Image]::FromFile($src)
    try {
        $bmp = New-Object System.Drawing.Bitmap $size, $size
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.DrawImage($img, 0, 0, $size, $size)
        if ($badge) {
            $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $path = New-Object System.Drawing.Drawing2D.GraphicsPath
            $fmt = New-Object System.Drawing.StringFormat
            $fmt.Alignment = [System.Drawing.StringAlignment]::Far
            $fmt.LineAlignment = [System.Drawing.StringAlignment]::Far
            $box = New-Object System.Drawing.RectangleF 0, 0, ($size * 0.95), ($size * 0.97)
            $family = New-Object System.Drawing.FontFamily "Georgia"
            $path.AddString($badge, $family, [int][System.Drawing.FontStyle]::Bold, [single]($size * 0.34), $box, $fmt)
            $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(235, 25, 18, 10)), ([single]($size * 0.045))
            $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
            $g.DrawPath($pen, $path)
            $fill = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 255, 228, 150))
            $g.FillPath($fill, $path)
            $pen.Dispose(); $fill.Dispose(); $path.Dispose(); $family.Dispose()
        }
        $g.Dispose()
        $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
        $ep = New-Object System.Drawing.Imaging.EncoderParameters 1
        $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), ([long]95)
        $bmp.Save($dst, $codec, $ep)
        $bmp.Dispose()
    } finally {
        $img.Dispose()
    }
}

if ($BadgeOnly) {
    $keys = @($badges.Keys | Where-Object { $want.Count -eq 0 -or $want -contains $_ } | Sort-Object)
    foreach ($k in $keys) {
        $rawFile = Join-Path $raw "$k.png"
        if (-not (Test-Path $rawFile)) { "skipped $k (no raw picture in art\_ai_raw)"; continue }
        Save-Icon $rawFile (Join-Path $art "$k.jpg") 380 $badges[$k]
        "badge $($badges[$k]) on $k"
    }
    return
}

$todo = @($subjects.Keys | Where-Object {
    ($want.Count -eq 0 -or $want -contains $_) -and ($Force -or -not (Test-Path (Join-Path $art "$_.jpg"))) })
"$($todo.Count) pictures to make (of $($subjects.Count) subjects)"
$ErrorActionPreference = "Continue"   # sd-cli writes its progress to stderr; that must not stop the script
$clock = [Diagnostics.Stopwatch]::StartNew()
$n = 0
$failed = @()
foreach ($k in $todo) {
    $n++
    $rawFile = Join-Path $raw "$k.png"
    if (Test-Path $rawFile) { Remove-Item $rawFile }
    & "$Sd\bin\sd-cli.exe" --diffusion-model "$Sd\models\z_image_turbo-Q8_0.gguf" --vae "$Sd\models\ae.safetensors" `
        --llm "$Sd\models\Qwen3-4B-Instruct-2507-Q8_0.gguf" -p "$style $($subjects[$k])" --cfg-scale 1.0 --diffusion-fa `
        -H 512 -W 512 --steps 8 --seed $(if (-not $seedGiven -and $seeds.ContainsKey($k)) { $seeds[$k] } else { $Seed }) `
        -o $rawFile 2>&1 | Out-Null
    $ok = Test-Path $rawFile
    if ($ok) { Save-Icon $rawFile (Join-Path $art "$k.jpg") 380 $badges[$k] } else { $failed += $k }
    "{0}/{1} {2} ok={3} t={4}s" -f $n, $todo.Count, $k, $ok, [math]::Round($clock.Elapsed.TotalSeconds)
}
"DONE in $([math]::Round($clock.Elapsed.TotalMinutes, 1)) min; failed: $($failed -join ', ')"
