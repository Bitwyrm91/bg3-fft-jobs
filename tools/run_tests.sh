#!/usr/bin/env bash
# Runs every check: generated files up to date, the Lua 5.4 test suites, the pacing simulator's self-test.
set -euo pipefail
cd "$(dirname "$0")/.."
PY=$(command -v python3 || command -v python)
LUA=$(command -v lua5.4 || command -v lua54 || command -v lua)
"$LUA" -v 2>&1 | grep -q "Lua 5.4" || { echo "needs Lua 5.4 (found: $("$LUA" -v 2>&1))"; exit 1; }
echo "== build check";   "$PY" tools/build.py --check
echo "== Lua tests";     "$LUA" tests/run_all.lua "$@"
if [ -f tools/pacing_sim.py ]; then
  echo "== pacing simulator self-test"; "$PY" tools/pacing_sim.py --selftest
fi
echo "ALL CHECKS PASSED"
