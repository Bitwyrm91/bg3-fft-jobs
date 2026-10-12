# Install the FFT Job System into BG3 (run tools\package.ps1 first).
# - copies build\FFTJobs.pak into %LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Mods
# - adds the mod at the end of modsettings.lsx, in the profile and in <user>\Public if that copy exists
#   (keeps every other entry; backup first)
# - installs the Script Extender's DWrite.dll into the game's bin folder if it is missing (-ScriptExtenderDll)
# - writes bin\ScriptExtenderSettings.json (console + log) if there is none
# What it changed is recorded in FFTJobs-install.json next to the backups, so tools\uninstall.ps1 can undo it.
# Usage: powershell -ExecutionPolicy Bypass -File tools\install.ps1 [-ScriptExtenderDll <DWrite.dll>] [-GameDir <BG3 folder>]
param(
    [string]$GameDir = "C:\Program Files (x86)\Steam\steamapps\common\Baldurs Gate 3",
    [string]$ScriptExtenderDll = "C:\Users\berus\GameModding\tools\bg3se-v32\files\DWrite.dll"
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$pak = Join-Path $root "build\FFTJobs.pak"
if (-not (Test-Path $pak)) { throw "build\FFTJobs.pak not found: run tools\package.ps1 first" }

$user = Join-Path $env:LOCALAPPDATA "Larian Studios\Baldur's Gate 3"
$mods = Join-Path $user "Mods"
# The profile's file is the documented one; BG3 Mod Manager 1.0.12.9 also keeps a copy in <user>\Public.
$settingsFiles = @((Join-Path $user "PlayerProfiles\Public\modsettings.lsx"), (Join-Path $user "Public\modsettings.lsx")) |
    Where-Object { Test-Path $_ }
$bin = Join-Path $GameDir "bin"
if (-not $settingsFiles) { throw "modsettings.lsx not found: start BG3 once to the main menu, then run this again" }

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backups = Join-Path $user "FFTJobs-backups"
$backup = Join-Path $backups $stamp
New-Item -ItemType Directory -Force $backup | Out-Null
foreach ($f in $settingsFiles) {
    $rel = $f.Substring($user.Length + 1)
    New-Item -ItemType Directory -Force (Split-Path (Join-Path $backup $rel)) | Out-Null
    Copy-Item $f (Join-Path $backup $rel)
}

$statePath = Join-Path $backups "FFTJobs-install.json"
$state = @{ installedScriptExtender = $false; installedSESettings = $false }
if (Test-Path $statePath) {
    $old = Get-Content $statePath -Raw | ConvertFrom-Json
    $state.installedScriptExtender = [bool]$old.installedScriptExtender
    $state.installedSESettings = [bool]$old.installedSESettings
}

# Script Extender
$dwrite = Join-Path $bin "DWrite.dll"
if (-not (Test-Path $dwrite)) {
    if (-not (Test-Path $ScriptExtenderDll)) { throw "Script Extender DWrite.dll not found at $ScriptExtenderDll" }
    Copy-Item $ScriptExtenderDll $dwrite
    $state.installedScriptExtender = $true
    Write-Host "installed Script Extender: $dwrite"
} else { Write-Host "Script Extender already present: $dwrite" }
$seSettings = Join-Path $bin "ScriptExtenderSettings.json"
if (-not (Test-Path $seSettings)) {
    [IO.File]::WriteAllText($seSettings, "{`n  `"CreateConsole`": true,`n  `"LogRuntime`": true`n}`n")
    $state.installedSESettings = $true
    Write-Host "wrote $seSettings"
}

# Pak
New-Item -ItemType Directory -Force $mods | Out-Null
Copy-Item $pak (Join-Path $mods "FFTJobs.pak") -Force
Write-Host "copied FFTJobs.pak to $mods"

# modsettings.lsx: identity from our meta.lsx
[xml]$meta = Get-Content (Join-Path $root "Mod\Mods\FFTJobs\meta.lsx") -Raw
$info = $meta.SelectSingleNode("//node[@id='ModuleInfo']")
function MetaAttr($id) { $info.SelectSingleNode("attribute[@id='$id']").value }
$uuid = MetaAttr "UUID"; $folder = MetaAttr "Folder"; $name = MetaAttr "Name"; $version = MetaAttr "Version64"

foreach ($settings in $settingsFiles) {
    [xml]$doc = Get-Content $settings -Raw
    $modsNode = $doc.SelectSingleNode("/save/region[@id='ModuleSettings']/node[@id='root']/children/node[@id='Mods']")
    if ($null -eq $modsNode) { throw "unexpected modsettings.lsx layout (no /root/Mods node); nothing changed" }
    $children = $modsNode.SelectSingleNode("children")
    if ($null -eq $children) { $children = $doc.CreateElement("children"); [void]$modsNode.AppendChild($children) }
    $existing = $children.SelectSingleNode("node[@id='ModuleShortDesc'][attribute[@id='UUID' and @value='$uuid']]")
    if ($existing) {
        $existing.SelectSingleNode("attribute[@id='Version64']").value = $version
        $existing.SelectSingleNode("attribute[@id='Folder']").value = $folder
        Write-Host "${settings}: already listed, version updated"
    } else {
        $node = $doc.CreateElement("node"); $node.SetAttribute("id", "ModuleShortDesc")
        foreach ($a in @(@("Folder","LSString",$folder), @("MD5","LSString",""), @("Name","LSString",$name),
                         @("PublishHandle","uint64","0"), @("UUID","guid",$uuid), @("Version64","int64",$version))) {
            $e = $doc.CreateElement("attribute"); $e.SetAttribute("id",$a[0]); $e.SetAttribute("type",$a[1]); $e.SetAttribute("value",$a[2])
            [void]$node.AppendChild($e)
        }
        [void]$children.AppendChild($node)
        Write-Host "${settings}: added $name at the end of the load order"
    }
    $ws = New-Object System.Xml.XmlWriterSettings
    $ws.Indent = $true; $ws.Encoding = New-Object System.Text.UTF8Encoding($false)
    $w = [System.Xml.XmlWriter]::Create($settings, $ws); $doc.Save($w); $w.Close()

    # check what we wrote
    [xml]$check = Get-Content $settings -Raw
    $found = $check.SelectNodes("/save/region/node[@id='root']/children/node[@id='Mods']/children/node[@id='ModuleShortDesc'][attribute[@id='UUID' and @value='$uuid']]")
    if ($found.Count -ne 1) { throw "modsettings.lsx check failed ($($found.Count) entries); restore it from $backup" }
}

$state.lastBackup = $backup
$state.gameDir = $GameDir
$state | ConvertTo-Json | Set-Content -Encoding utf8 $statePath
Write-Host "done. Backup: $backup"
