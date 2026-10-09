# Runs every check on Windows: generated files up to date, the Lua 5.4 test suites, the pacing simulator self-test.
#   powershell -ExecutionPolicy Bypass -File tools\run_tests.ps1 [filter]
# Python: $env:PYTHON, else the py launcher (py -3), else a python3/python that is not the Microsoft Store stub,
# else `uv run`. Lua: $env:LUA or lua54/lua5.4/lua on PATH; without a Lua 5.4 executable the suites run through
# Python + lupa (already installed, or provided by `uv run --with lupa`). Works with Windows PowerShell 5.1.
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

# Runs a command (array: program + leading arguments) with more arguments, output hidden; $true on exit code 0.
function Test-Quiet([string[]]$cmd, [string[]]$more) {
    $ErrorActionPreference = 'Continue'
    try {
        $rest = @($cmd | Select-Object -Skip 1)
        & $cmd[0] @rest @more *> $null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

# Runs a command (array) with more arguments, output shown; returns the exit code.
function Invoke-Cmd([string[]]$cmd, [string[]]$more) {
    $rest = @($cmd | Select-Object -Skip 1)
    & $cmd[0] @rest @more | Out-Host
    return $LASTEXITCODE
}

function Find-Python {
    if ($env:PYTHON) { return , @($env:PYTHON) }
    if ((Get-Command py -ErrorAction SilentlyContinue) -and (Test-Quiet @('py', '-3') @('-c', 'import sys'))) {
        return , @('py', '-3')
    }
    foreach ($name in 'python3', 'python') {
        $c = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($c -and ($c.Path -notlike '*\WindowsApps\*') -and
            (Test-Quiet @($c.Path) @('-c', 'import sys; sys.exit(sys.version_info[0] != 3)'))) {
            return , @($c.Path)
        }
    }
    if (Get-Command uv -ErrorAction SilentlyContinue) { return , @('uv', 'run', '--no-project', '--python', '3.12', 'python') }
    throw 'Python 3 not found: set $env:PYTHON, install the py launcher, or install uv'
}

function Find-Lua {
    $candidates = @('lua54', 'lua5.4', 'lua')
    if ($env:LUA) { $candidates = @($env:LUA) }
    foreach ($c in $candidates) {
        if (-not (Get-Command $c -ErrorAction SilentlyContinue)) { continue }
        $ErrorActionPreference = 'Continue'
        try { $v = (& $c -v 2>&1 | Out-String) } catch { $v = '' }
        if ($v -match 'Lua 5\.4') { return $c }
    }
    return $null
}

$py = Find-Python
Write-Host ('python: ' + ($py -join ' '))

Write-Host '== build check'
if ((Invoke-Cmd $py @('tools/build.py', '--check')) -ne 0) { exit 1 }

Write-Host '== Lua tests'
$lua = Find-Lua
if ($lua) {
    $code = Invoke-Cmd @($lua) (@('tests/run_all.lua') + $args)
} else {
    if (Test-Quiet $py @('-c', 'import lupa.lua54')) {
        $lupaPy = $py
    } elseif (Get-Command uv -ErrorAction SilentlyContinue) {
        $lupaPy = @('uv', 'run', '--no-project', '--python', '3.12', '--with', 'lupa', 'python')
    } else {
        throw 'No Lua 5.4 executable and no lupa: put lua54.exe on PATH, or pip install lupa, or install uv'
    }
    Write-Host ('(no Lua 5.4 executable: running the suites with ' + ($lupaPy -join ' ') + ' + lupa)')
    $code = Invoke-Cmd $lupaPy (@('tools/run_lua_tests.py') + $args)
}
if ($code -ne 0) { exit 1 }

Write-Host '== pacing simulator self-test'
if ((Invoke-Cmd $py @('tools/pacing_sim.py', '--selftest')) -ne 0) { exit 1 }
Write-Host 'ALL CHECKS PASSED'
