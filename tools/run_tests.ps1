# Runs every check on Windows: generated files up to date, the Lua 5.4 test suites, the pacing simulator self-test.
# Needs Lua 5.4 (lua54.exe or lua.exe on PATH, or set $env:LUA) and Python 3.
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
$py = if (Get-Command python -ErrorAction SilentlyContinue) { 'python' } else { 'python3' }
$lua = $env:LUA
if (-not $lua) { foreach ($c in 'lua54', 'lua5.4', 'lua') { if (Get-Command $c -ErrorAction SilentlyContinue) { $lua = $c; break } } }
if (-not $lua) { throw 'Lua 5.4 not found: put lua54.exe on PATH or set $env:LUA' }
$v = & $lua -v 2>&1 | Out-String
if ($v -notmatch 'Lua 5\.4') { throw "needs Lua 5.4, found: $v" }
Write-Host '== build check';  & $py tools/build.py --check;  if ($LASTEXITCODE) { exit 1 }
Write-Host '== Lua tests';    & $lua tests/run_all.lua @args; if ($LASTEXITCODE) { exit 1 }
if (Test-Path tools/pacing_sim.py) { Write-Host '== pacing simulator self-test'; & $py tools/pacing_sim.py --selftest; if ($LASTEXITCODE) { exit 1 } }
Write-Host 'ALL CHECKS PASSED'
