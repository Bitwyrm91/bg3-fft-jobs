# STATUS — BG3 × FFT job system

Handoff between sessions. Read this first, then `BRIEF.md` and `DESIGN.md`.

**Where the work is:** branch `claude/game-modding-research-setup-qgn88h` on GitHub (Bitwyrm91/bg3-fft-jobs). Not merged into `main` yet.

## Part A (cloud) progress

- [x] 1. Research + `DESIGN.md` (SE/Osiris APIs verified against Norbyte's docs and the generated story header, TIC data with sources, JP formulas, persistence, layout, mod UUID `3db7be3e-9387-4678-b172-044acc7ff0c2`)
- [x] 2. Data files: `data/fft_jobs.json` (all 20 TIC jobs with unlock rules, 6 implemented, 71 abilities with TIC JP costs and sources), `data/config_defaults.json` (JP config + presets), `data/strings.json`; `tools/build.py` generates `Shared/GeneratedData.lua`
- [x] 3. Lua engine (`Mod/Mods/FFTJobs/ScriptExtender/Lua/`): JP from `CastedSpell`/`CombatEnded`/XP polling/`LongRestFinished` with spillover and camp share, job levels, unlocks, learning, primary/secondary/reaction/support/movement, grant diffing with `AddSpell`/`AddPassive`/`ApplyStatus`, JSON config + presets + 22 `!fft_*` console commands, ModVars persistence, telemetry, IMGUI Job Board (client) over NetChannels; `meta.lsx` + SE `Config.json`
- [x] 4. Stats + localization drafts: `stats_src/` templates (62 spells, 26 passives, 12 statuses) -> `Mod/Public/FFTJobs/Stats/Generated/Data/`, 180 English strings -> `Mod/Localization/English/FFTJobs.xml` (convert to .loca in Part B); `docs/vanilla_refs.md` lists every vanilla ID they rely on; `tools/validate_vanilla.py` checks them against the extracted game data
- [x] 5. Tests: 78 Lua 5.4 tests in 7 suites (rules, config, engine events, save/load round trip, console commands, Job Board UI, data integrity) on a mock Ext/Osi (`tests/mocks.lua`); `tools/run_tests.sh` (Linux) / `tools/run_tests.ps1` (Windows) run them all plus the build check. Last run: 78 passed, 0 failed (Lua 5.4.6)
- [ ] 6. Pacing simulator + preset tables
- [ ] 7. `PLAYTEST.md` + final `STATUS.md` with the Part B checklist

## Unverified (could not be checked in the cloud)

- Every vanilla BG3 stats ID, `using` parent, status name and icon in the stats drafts.
- Everything that only shows in game: events firing as expected, grants, UI, notifications.
