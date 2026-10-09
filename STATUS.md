# STATUS — BG3 × FFT job system

Handoff between sessions. Read this first, then `BRIEF.md` (Part B) and `DESIGN.md`.

**Where the work is:** branch **`claude/game-modding-research-setup-qgn88h`** on GitHub (Bitwyrm91/bg3-fft-jobs). It is **not merged into `main`**: the cloud session only pushes to its own branch and did not open a pull request. Part B step 1: `git fetch origin`, then `git checkout main`, `git merge origin/claude/game-modding-research-setup-qgn88h`, and push.

FFT data source: **The Ivalice Chronicles** (the user asked for the recent remakes, not PS1); War of the Lions values where TIC is not published.

## Part A (cloud, 2026-10-09): done

- [x] 1. Research + `DESIGN.md`: SE/Osiris APIs verified (section 2 says how), TIC data with sources, JP formulas, persistence, layout. Mod UUID **`3db7be3e-9387-4678-b172-044acc7ff0c2`** (never change it).
- [x] 2. Data: `data/fft_jobs.json` (all 20 TIC jobs with unlock rules, 6 implemented, 71 abilities with TIC JP costs and sources), `data/config_defaults.json` (every JP number + presets + help texts), `data/strings.json`. `tools/build.py` generates the Lua data module.
- [x] 3. Lua engine (`Mod/Mods/FFTJobs/ScriptExtender/Lua/`): JP from `CastedSpell`, `CombatEnded`, XP polling and `LongRestFinished`, with spillover and camp share; job levels, unlocks, learning; primary/secondary/reaction/support/movement; grant diffing with `AddSpell`/`AddPassive`/`ApplyStatus` that never removes what a character had before; JSON config + presets + 22 `!fft_*` console commands; ModVars persistence; telemetry log; IMGUI **Job Board** window over NetChannels; `meta.lsx` and SE `Config.json`.
- [x] 4. Stats + localization drafts: `stats_src/` → `Mod/Public/FFTJobs/Stats/Generated/Data/` (62 spells, 26 passives, 12 statuses), 180 English strings in `Mod/Localization/English/FFTJobs.xml`. `docs/vanilla_refs.md` lists every vanilla ID they rely on; `tools/validate_vanilla.py` checks them against the extracted game data.
- [x] 5. Tests: 79 Lua 5.4 tests in 7 suites (rules, config, engine events, save/load round trip, console commands, Job Board UI, data integrity) on a mock Ext/Osi (`tests/mocks.lua`). **Last run: 79 passed, 0 failed**, both with Lua 5.4.6 and with Python + lupa 2.8.
- [x] 6. Pacing simulator `tools/pacing_sim.py` + preset tables (`DESIGN.md` section 14). **Classic** defaults: action JP ×0.5, XP share 0.15, victory 15 + 1/level, long rest 25, camp share 1/2, spillover 1/4. LOW estimate: every fighter masters 5 of the 6 jobs; TYPICAL: all 6 during Act 3; HIGH: all 6 by the end of Act 2.
- [x] 7. `PLAYTEST.md` (for the user) and this file.

Run every check: `tools/run_tests.sh` (Linux/Git Bash) or `powershell -File tools\run_tests.ps1` (Windows). It runs the build check, the Lua suites (a Lua 5.4 executable, or Python with `pip install lupa` when there is none) and the simulator self-test.

## Verified vs. unverified

Verified in the cloud:
- Every `Ext.*` call and SE event used, against Norbyte's `Docs/API.md` and `ExtIdeHelpers.lua` (`DESIGN.md` section 3).
- Every Osiris call/event name and arity, against the story-header-generated `Osi.lua`/`Osi.Events.lua` (`DESIGN.md` section 4).
- The engine's logic, through the mock tests.

**Unverified (nothing ran in the game):**
1. **Stats drafts**: every `using` parent, status name, icon, functor/boost syntax (`Force(2)`, `RestoreResource(SpellSlot,1,1)`, `RegainHitPoints(1000)`, `IF(...)` in SpellProperties, `DamageReduction`, `JumpMaxDistanceBonus`, `Skill(Perception,2)`, `SpellResistance(Advantage)`, `ActionResource(Movement,-3,0)`, `TickType`/`TickFunctors`), the cooldown names (`OncePerTurn`, `OncePerShortRest`, `OncePerRest`), and the `OnDamaged` passives (who the functor targets). The `// VALIDATE` comments in `stats_src/` say what each entry should do and what to compare it with.
2. **Spells added with `AddSpell` to non-casters**: which ability modifier and DC they use. Magic is auto-hit or uses a saving throw to limit the impact. Alternative if needed: grant a passive with `UnlockSpell(<spell>,AddChildren,,,Intelligence)`.
3. `meta.lsx`: header version and empty Dependencies are copied from the common BG3 template. Also unverified: whether the stats parser accepts the generated files.
4. Party discovery: `Osi.DB_IsPlayer:Get(nil)` (listed in Norbyte's `OsiCommonDatabases`) and `Ext.Entity.GetAllEntitiesWithComponent("PartyMember")`. Unknown whether companions waiting in camp show up; they only get the camp share if they are tracked. If both return nothing, try `DB_Players` in the console.
5. `CastedSpell` firing for weapon attacks, item use and Extra Attack: each counted cast earns JP. Also the jump spell's ID: `Projectile_Jump` is excluded from JP.
6. `Ext.Entity.Get(guid).Experience.TotalExperience` keeps growing after level 12 (XP share).
7. `Osi.ShowNotification(character, text)` with plain text: it may need a localization handle. The messages also go to the console.
8. The Job Board: the IMGUI window and NetChannel calls in game, `Ext.Stats.Get(spell).UseCosts` being a string, and `ModuleUUID` at bootstrap.
9. Multiplayer: untested, and the Job Board opens on every client.

## Part B checklist (local run on the user's PC)

1. [ ] Pull and merge the branch into `main` (see above); run `tools\run_tests.ps1` (install Lua 5.4, or `uv pip install lupa`). Expect 79 passed.
2. [ ] Extract the vanilla data with LSLib: `Divine.exe -g bg3 -a extract-package -s "<BG3>\Data\Shared.pak" -d C:\Users\berus\GameModding\decomp\bg3\Shared`, then the same for `Gustav.pak` and the icon/GUI paks. Check the action names with `Divine.exe --help`.
3. [ ] Run `python tools\validate_vanilla.py C:\Users\berus\GameModding\decomp\bg3`. It checks every vanilla ID (`docs/vanilla_refs.json`), every `data` key against `Modifiers.txt`, name clashes and icons. Fix `stats_src/*.txt` (follow the `// VALIDATE` notes and compare with the vanilla entries), then run `python tools\build.py`. Repeat the validator and the tests until both are clean. Record what changed here.
4. [ ] Check unverified items 1-3 against the extracted data:
   - copy Revivify's own SpellProperties into `Target_FFTJ_Arise` and add the heal;
   - drop `IsConcentration` from the Protect/Shell flags;
   - pick better visual parents where an obvious one exists.
5. [ ] Convert the strings: `Divine.exe -g bg3 -a convert-loca -s Mod\Localization\English\FFTJobs.xml -d Mod\Localization\English\FFTJobs.loca` (check the action name), and keep the `.loca` in the package.
6. [ ] Package: `Divine.exe -g bg3 -a create-package -s Mod -d build\FFTJobs.pak` (check the flags; `build/` is git-ignored).
7. [ ] Install the Script Extender (official Norbyte/bg3se release) and the pak. Enable the pak in `modsettings.lsx` (back it up first; follow the load-order field note) and write `uninstall.ps1`. Create `ScriptExtenderSettings.json` next to `bg3.exe` with `{"CreateConsole": true, "LogRuntime": true}`.
8. [ ] Smoke test to the main menu only (do not play). In the SE console/log, look for `[FFTJobs]` lines and check there are no Lua errors and no stats errors for `FFTJ_` entries. The server side only loads with a game session, so at the main menu expect only the client side.
9. [ ] Finish `PLAYTEST.md` (install details, anything that changed) and this file (done / not done / unverified).
10. [ ] Update the memory files and send the final message, as `BRIEF.md` Part B says.

## Open questions for the user

- MP: abilities use cooldowns instead of an FFT MP pool. An MP resource (a custom `ActionResourceDefinition`) is possible later. Wanted?
- JP Boost is not assumed in the pacing numbers. With it equipped, JP is +50% (`DESIGN.md` section 14).
