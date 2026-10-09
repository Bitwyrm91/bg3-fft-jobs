# Runs every check on Windows: generated files up to date, the Lua 5.4 test suites, the pacing simulator self-test.
# Lua: lua54.exe / lua.exe on PATH (or $env:LUA); without one, the suites run through Python + lupa
# (pip install lupa). Python 3 is required.
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
$py = if (Get-Command python -ErrorAction SilentlyContinue) { 'python' } else { 'python3' }
$lua = $env:LUA
if (-not $lua) { foreach ($c in 'lua54', 'lua5.4', 'lua') { if (Get-Command $c -ErrorAction SilentlyContinue) { $lua = $c; break } } }
if ($lua -and ((& $lua -v 2>&1 | Out-String) -notmatch 'Lua 5\.4')) { $lua = $null }
Write-Host '== build check';  & $py tools/build.py --check;  if ($LASTEXITCODE) { exit 1 }
Write-Host '== Lua tests'
if ($lua) { & $lua tests/run_all.lua @args } else { Write-Host '(no Lua 5.4 executable: using Python + lupa)'; & $py tools/run_lua_tests.py @args }
if ($LASTEXITCODE) { exit 1 }
Write-Host '== pacing simulator self-test'; & $py tools/pacing_sim.py --selftest; if ($LASTEXITCODE) { exit 1 }
Write-Host 'ALL CHECKS PASSED'
