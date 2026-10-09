# BG3 x Final Fantasy Tactics: job system

A Baldur's Gate 3 mod (Script Extender) that adds FFT-style jobs: Job Points, job levels, an unlock tree and secondary/reaction/support/movement ability slots. FFT data from The Ivalice Chronicles. Work in progress: built and tested outside the game, not yet run in BG3.

- Plan and rules for the build: [BRIEF.md](BRIEF.md)
- Design, sources and pacing tables: [DESIGN.md](DESIGN.md)
- Progress and handoff: [STATUS.md](STATUS.md)
- How to try it: [PLAYTEST.md](PLAYTEST.md)

## Layout

| Path | What |
|---|---|
| `data/` | jobs, abilities, unlock rules, JP config and presets, strings: edit these |
| `stats_src/` | BG3 stats templates for the abilities |
| `Mod/` | the mod as it goes into the .pak (Lua engine, generated data/stats/strings, meta.lsx) |
| `tools/build.py` | regenerates the files in `Mod/` from `data/` and `stats_src/` |
| `tools/pacing_sim.py` | JP pacing simulator |
| `tools/validate_vanilla.py` | checks the stats against the extracted game data |
| `tests/` | Lua 5.4 tests with a mock Script Extender |

Run all checks: `tools/run_tests.sh` or `tools\run_tests.ps1`.
