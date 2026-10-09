#!/usr/bin/env python3
"""Runs the Lua test suites (tests/run_all.lua) inside Python with lupa's embedded Lua 5.4.
For machines without a Lua 5.4 executable (e.g. Windows):

    pip install lupa          (or: uv pip install lupa)
    python tools/run_lua_tests.py [filter]
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def main(argv):
    try:
        from lupa.lua54 import LuaRuntime
    except ImportError:
        print("lupa is not installed: pip install lupa")
        return 2
    lua = LuaRuntime(unpack_returned_tuples=True)
    if lua.eval("_VERSION") != "Lua 5.4":
        print("lupa did not provide Lua 5.4: " + str(lua.eval("_VERSION")))
        return 2
    script = (ROOT / "tests" / "run_all.lua").as_posix()
    set_args = lua.eval("function(t) arg = t end")
    set_args(lua.table_from({0: script, **{i + 1: a for i, a in enumerate(argv)}}))
    lua.execute('EXIT_CODE = 0; os.exit = function(c) '
                'EXIT_CODE = (c == nil or c == true or c == 0) and 0 or 1; error("__FFTJ_EXIT__") end')
    sys.stdout.flush()
    try:
        lua.execute('dofile("' + script.replace('"', '\\"') + '")')
    except Exception as e:  # lupa.LuaError; os.exit is turned into an error so Python can return the code
        if "__FFTJ_EXIT__" not in str(e):
            print("Lua error: " + str(e))
            return 1
    return int(lua.eval("EXIT_CODE"))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
