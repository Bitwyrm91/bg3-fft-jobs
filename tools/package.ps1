# Build build\FFTJobs.pak from Mod\ (strings converted to .loca on the way).
# Usage: powershell -ExecutionPolicy Bypass -File tools\package.ps1 [-Divine <path to Divine.exe>]
param(
    [string]$Divine = "C:\Users\berus\DOS2Modding\tools\lslib\Packed\Tools\Divine.exe",
    [string]$DotnetRoot = "C:\Users\berus\DOS2Modding\tools\dotnet8"
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
if (Test-Path $DotnetRoot) { $env:DOTNET_ROOT = $DotnetRoot; $env:PATH = "$DotnetRoot;$env:PATH" }

$build = Join-Path $root "build"
$stage = Join-Path $build "stage"
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Force (Join-Path $stage "Localization\English") | Out-Null
Copy-Item -Recurse (Join-Path $root "Mod\Mods") $stage
Copy-Item -Recurse (Join-Path $root "Mod\Public") $stage

# Icons: the textures from art\icons, and the atlas texture bank as .lsf like vanilla's ("[PAK]_UI" needs -LiteralPath).
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "make_icons.ps1") -Stage $stage
if ($LASTEXITCODE -ne 0) { throw "make_icons.ps1 failed" }
# Resources the game reads as .lsf: the atlas texture bank and the item root templates (the Soul Codex).
foreach ($rel in @("Public\FFTJobs\Content\UI\[PAK]_UI\_merged.lsx", "Public\FFTJobs\RootTemplates\_merged.lsx")) {
    $lsx = Join-Path $stage $rel
    if (-not (Test-Path -LiteralPath $lsx)) { continue }
    $lsf = [IO.Path]::ChangeExtension($lsx, ".lsf")
    & $Divine -g bg3 -a convert-resource -s $lsx -d $lsf
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $lsf)) { throw "convert-resource failed for $lsx" }
    Remove-Item -LiteralPath $lsx
}

# Divine needs absolute paths.
& $Divine -g bg3 -a convert-loca -s (Join-Path $root "Mod\Localization\English\FFTJobs.xml") `
    -d (Join-Path $stage "Localization\English\FFTJobs.loca")
if ($LASTEXITCODE -ne 0) { throw "convert-loca failed" }

$pak = Join-Path $build "FFTJobs.pak"
if (Test-Path $pak) { Remove-Item -Force $pak }
& $Divine -g bg3 -a create-package -s $stage -d $pak -c lz4
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $pak)) { throw "create-package failed" }
Write-Host "built $pak ($((Get-Item $pak).Length) bytes)"
