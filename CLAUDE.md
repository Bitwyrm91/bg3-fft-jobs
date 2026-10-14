# BG3 × FFT Job System — instructions for Claude

Read first, every session: `STATUS.md` (handoff, newest versions at the top of each list, the "NWP" next-patch list,
"Future changes"; old version log: `docs/HISTORY.md`, only when needed), then the project skill `.claude/skills/bg3-fft-jobs/SKILL.md` (how the mod is built, BG3 facts,
gotchas). Design background: `DESIGN.md`, `docs/PHASE2.md`, `docs/SPECIAL_JOBS.md`, `docs/SOUL_COLLECTOR_MAP.md`.

## How the user works (Bitwyrm91; plays BG3 on Windows, often multiplayer with a friend)
- **Usage matters.** Before a change, say roughly how much usage it may take and how long; check usage after each
  step when a tool for it exists; stop and say so near the limit the user gave.
- **Ask design questions before building** anything unclear, with AskUserQuestion (the user likes it). Give a
  recommended option first.
- **Keep the chat short**: plain words, no long file dumps, no jargon walls.
- **General requests apply to every job/ability we made** unless the user names one.
- **Area abilities hit allies in range** unless the user's design says otherwise.
- **Mechanics over models**: ported mechanics matter more than looks.
- **JP numbers live in config** (`data/config_defaults.json`), never hard-coded.
- **Tester zip** (`FFTJobs-<version>-test.zip`, pak + HOW-TO-INSTALL.txt): only when the user asks.
- **GitHub:** never push to `main`, tag or make releases unless the user says so. A cloud session works on its own
  branch and pushes that branch (that is how the work reaches the user's PC); say what was pushed.
- **Backups:** the user likes a way back (git tags `backup-<version>-...`, old paks kept on the PC).

## What a cloud session can and cannot do
- Can: edit data/Lua/stats/tools, run `tools/build.py`, the Lua tests, the pacing self-test
  (`bash tools/run_tests.sh` runs them all), `tools/release.py <version>` (version bump + notes + build).
- Cannot: package (`tools/package.ps1` needs Divine.exe on Windows), install, play, or run the checks that need the
  extracted vanilla game data (`tools/validate_vanilla.py`, `tools/check_refs.py`, `tools/check_souls.py`,
  `tools/menu_gen.py --vanilla-icons`; the data is in `C:\Users\berus\GameModding\decomp\bg3` on the PC, never in
  the repo). Leave those for a local session: say in STATUS.md what still needs packaging/installing/checking.
- Install only with BG3 closed (local): `powershell -ExecutionPolicy Bypass -File tools\install.ps1`.

## Every change
1. Edit sources (`data/*.json`, `stats_src/*.txt`, `Mod/Mods/FFTJobs/ScriptExtender/Lua/**`, `tools/*.py`); never
   hand-edit generated files (they come from `tools/build.py`).
2. `python3 tools/release.py <next version> --playtest <notes.md> --status <paragraph.md>` (bumps the version,
   updates PLAYTEST.md / STATUS.md, rebuilds).
3. Tests: `bash tools/run_tests.sh` (or `uv run --no-project --python 3.12 --with lupa python tools/run_lua_tests.py`).
4. Commit with a clear message; mark what is unverified in game.
