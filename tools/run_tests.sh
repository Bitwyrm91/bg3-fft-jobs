#!/usr/bin/env bash
# Runs every check: generated files up to date, the Lua 5.4 test suites, the pacing simulator self-test.
# Lua: lua5.4/lua54/lua on PATH; without a Lua 5.4 executable the suites run through Python + lupa (pip install lupa).
set -euo pipefail
cd "$(dirname "$0")/.."
PY=$(command -v python3 || command -v python)
LUA=""
for c in lua5.4 lua54 lua; do
  if command -v "$c" >/dev/null && "$c" -v 2>&1 | grep -q "Lua 5.4"; then LUA=$(command -v "$c"); break; fi
done
echo "== build check";   "$PY" tools/build.py --check
echo "== Lua tests"
if [ -n "$LUA" ]; then "$LUA" tests/run_all.lua "$@"; else echo "(no Lua 5.4 executable: using Python + lupa)"; "$PY" tools/run_lua_tests.py "$@"; fi
echo "== pacing simulator self-test"; "$PY" tools/pacing_sim.py --selftest
echo "ALL CHECKS PASSED"
