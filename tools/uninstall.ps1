# Remove the FFT Job System from BG3.
# - removes its entry from modsettings.lsx (backup first) and deletes Mods\FFTJobs.pak
# - with -RemoveScriptExtender: also removes DWrite.dll and ScriptExtenderSettings.json, but only if
#   tools\install.ps1 put them there (other mods may need the Script Extender, so it stays by default)
# Saves made with the mod enabled will ask for it; keep the pak if you want to load them.
# Usage: powershell -ExecutionPolicy Bypass -File tools\uninstall.ps1 [-RemoveScriptExtender]
param([switch]$RemoveScriptExtender)
$ErrorActionPreference = "Stop"
$uuid = "3db7be3e-9387-4678-b172-044acc7ff0c2"
$user = Join-Path $env:LOCALAPPDATA "Larian Studios\Baldur's Gate 3"
$backups = Join-Path $user "FFTJobs-backups"
$statePath = Join-Path $backups "FFTJobs-install.json"

foreach ($settings in @((Join-Path $user "PlayerProfiles\Public\modsettings.lsx"), (Join-Path $user "Public\modsettings.lsx"))) {
    if (-not (Test-Path $settings)) { continue }
    $rel = $settings.Substring($user.Length + 1)
    $backup = Join-Path $backups ("uninstall-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
    New-Item -ItemType Directory -Force (Split-Path (Join-Path $backup $rel)) | Out-Null
    Copy-Item $settings (Join-Path $backup $rel)
    [xml]$doc = Get-Content $settings -Raw
    $nodes = $doc.SelectNodes("//node[@id='ModuleShortDesc'][attribute[@id='UUID' and @value='$uuid']]")
    foreach ($n in @($nodes)) { [void]$n.ParentNode.RemoveChild($n) }
    $ws = New-Object System.Xml.XmlWriterSettings
    $ws.Indent = $true; $ws.Encoding = New-Object System.Text.UTF8Encoding($false)
    $w = [System.Xml.XmlWriter]::Create($settings, $ws); $doc.Save($w); $w.Close()
    Write-Host "${settings}: removed $($nodes.Count) entry(ies); backup in $backup"
}

$pak = Join-Path $user "Mods\FFTJobs.pak"
if (Test-Path $pak) { Remove-Item $pak; Write-Host "deleted $pak" }

if ($RemoveScriptExtender -and (Test-Path $statePath)) {
    $state = Get-Content $statePath -Raw | ConvertFrom-Json
    $bin = Join-Path $state.gameDir "bin"
    if ($state.installedScriptExtender -and (Test-Path "$bin\DWrite.dll")) { Remove-Item "$bin\DWrite.dll"; Write-Host "removed $bin\DWrite.dll" }
    if ($state.installedSESettings -and (Test-Path "$bin\ScriptExtenderSettings.json")) { Remove-Item "$bin\ScriptExtenderSettings.json"; Write-Host "removed $bin\ScriptExtenderSettings.json" }
}
Write-Host "done"
