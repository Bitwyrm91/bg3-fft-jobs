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
$bankLsx = Join-Path $stage "Public\FFTJobs\Content\UI\[PAK]_UI\_merged.lsx"
if (Test-Path -LiteralPath $bankLsx) {
    $bankLsf = [IO.Path]::ChangeExtension($bankLsx, ".lsf")
    & $Divine -g bg3 -a convert-resource -s $bankLsx -d $bankLsf
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $bankLsf)) { throw "convert-resource failed for $bankLsx" }
    Remove-Item -LiteralPath $bankLsx
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
