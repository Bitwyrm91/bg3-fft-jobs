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
  - Windows check by the desktop session (e6e1ddd, Windows 11, `core.autocrlf=true`): 78/79. The failure (`test_data :: every_localization_handle_exists`, "handles checked: 0") came from **CRLF line endings** in the checkout, not from path handling: the tests use a fixed file list, but a trailing `\r` broke the `data "..." "..."$` pattern. Reproduced in the cloud by converting a copy to CRLF. Fixed three ways:
    - `tests/test_data.lua` now ignores CR;
    - a new `.gitattributes` keeps LF in every checkout (verified: an `autocrlf=true` clone has 0 files with CR, 55 without it);
    - `tools/run_tests.ps1` now finds a real Python: `$env:PYTHON`, then `py -3`, then a python3/python that is not the Microsoft Store stub, then `uv run`. Without a Lua 5.4 executable it uses lupa, through `uv run --with lupa` if needed. The script was tested with PowerShell 7.6 (Linux): all checks pass, the filter argument passes through, and a stale build or a failing test exits 1. The CRLF copy also passes with Lua, lupa and the script.
- [x] 6. Pacing simulator `tools/pacing_sim.py` + preset tables (`DESIGN.md` section 14). **Classic** defaults: action JP ×0.5, XP share 0.15, victory 15 + 1/level, long rest 25, camp share 1/2, spillover 1/4. LOW estimate: every fighter masters 5 of the 6 jobs; TYPICAL: all 6 during Act 3; HIGH: all 6 by the end of Act 2.
- [x] 7. `PLAYTEST.md` (for the user) and this file.

Run every check: `tools/run_tests.sh` (Linux/Git Bash) or `powershell -ExecutionPolicy Bypass -File tools\run_tests.ps1` (Windows). It runs the build check, the Lua suites and the simulator self-test. The Lua suites use a Lua 5.4 executable if there is one; otherwise they run under Python + lupa, fetched by `uv run --with lupa` when it is not installed. Direct alternative on the user's PC: `uv run --no-project --python 3.12 --with lupa python tools/run_lua_tests.py`.

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

## FFT data to check against the installed game

FFT: The Ivalice Chronicles is installed on the user's PC at `C:\Games\FINAL FANTASY TACTICS - The Ivalice Chronicles` (user, 2026-10-10). The FFT numbers in `data/fft_jobs.json` come from guides that disagree in places, and the game settles them. Cloud sessions cannot see the PC, so this needs a local session, or screenshots the user sends to a cloud session. **Never commit game files or extracted data**: only the corrected numbers, with the source changed to "TIC in-game" or "TIC game data" plus the game version.

To check (value used now, with other values seen in guides in brackets):
- **Squire:** Focus 300 (400) · Rush 80 (200) · Throw Stone 90 (10/100) · Salve 150 (50/250) · Counter Tackle 180 (200).
- **Chemist:** Hi-Potion 200 (150) · Ether 300 (200) · Remedy 700 (300) · Phoenix Down 90 (200/300) · Treasure Hunter 100 (200).
- **Knight:** Rend Armor 400 (200/300) · Rend Weapon 400 (300) · Parry 200 (400) · Equip Heavy Armor 500 (250) · Equip Swords 400 (250).
- **Archer:** Aim +10 700 (400) · Aim +20 900 (500) · Equip Crossbows 350 (250/400) · Archer's Bane 450 (400) · the reaction: Speed Surge 900 or Adrenaline Rush 400.
- **White Mage:** Curaga 450 (200/350) · Reraise 1000 (420/540) · Regen 350 (70/80) · Esuna 300 (150/400) · Regenerate 400 (200) · the support's name: Magick Defense Boost or Arcane Defense.
- **Black Mage:** Firaga/Thundaga/Blizzaga 500 (300/400) · Magick Counter 800 (500) · the support's name: Magick Boost or Arcane Strength.
- **Rules:**
  - job level thresholds (Lv2 200, then 400 … Lv8 3000);
  - the unlock tree (spot-check Monk = Knight 3, Geomancer = Monk 4, Mime);
  - the JP-per-action constant (8 or 16);
  - the Enhanced-mode +30%;
  - JP Boost ×1.5 or ×2;
  - spillover: 1/4, and whether it goes into locked jobs.

How:
- **Unmodded game only.** The user may install TIC mods (2026-10-10). Mods that change JP or abilities (JP Boost for All, Global JP Boost, WotL Restoration, …) change these numbers: untick every mod but the loader in Reloaded-II before checking in game. To remove mods completely, the loader's README says to delete the `modded` files in the game's `data` folder.
- **In game (simplest).** The Job menu shows each ability's JP cost and each job's requirements. For the formula: in Enhanced mode, note the JP shown after a basic attack by a unit whose job level and character level are known, then again with JP Boost equipped. Compare with `8 + 2 × job level + floor(character level / 4)`, then ×1.3 and ×1.5.
- **Game files (thorough).** If Nenkai's FFT Mod Loader for Reloaded-II is installed, its own folder (under Reloaded-II's `Mods` folder) has a `TableData` folder with the game's hard-coded tables as XML (`AbilityData.xml`, `JobCommandData.xml`, …), probably including the JP costs. FF16Tools extracts the other game files ([mod-making guide](https://nenkai.github.io/ffxvi-modding/modding/creating_mods_fft/)). Copy or extract to `C:\Users\berus\GameModding\decomp\fft` (outside the repo) and compare with `data/fft_jobs.json`.
- **After changes:** `python tools\build.py`, then the tests and `python tools\pacing_sim.py`. If mastery costs moved a lot, check the Classic preset still meets the target (LOW masters 4+ jobs).

## Part B checklist (local run on the user's PC)

1. [ ] Pull and merge the branch into `main` (see above). A checkout made before `.gitattributes` existed still has CRLF files; refresh it once, but only when there are no local changes: `git rm -r --cached -q .` then `git reset --hard`. Run `powershell -ExecutionPolicy Bypass -File tools\run_tests.ps1` and expect 79 passed.
2. [ ] The Ivalice Chronicles is installed at `C:\Games\FINAL FANTASY TACTICS - The Ivalice Chronicles`: check the FFT numbers in the section above, with mods off, and update `data/fft_jobs.json` (numbers and sources only, no game files). Record what changed here.
3. [ ] Extract the vanilla data with LSLib: `Divine.exe -g bg3 -a extract-package -s "<BG3>\Data\Shared.pak" -d C:\Users\berus\GameModding\decomp\bg3\Shared`, then the same for `Gustav.pak` and the icon/GUI paks. Check the action names with `Divine.exe --help`.
4. [ ] Run `python tools\validate_vanilla.py C:\Users\berus\GameModding\decomp\bg3`. It checks every vanilla ID (`docs/vanilla_refs.json`), every `data` key against `Modifiers.txt`, name clashes and icons. Fix `stats_src/*.txt` (follow the `// VALIDATE` notes and compare with the vanilla entries), then run `python tools\build.py`. Repeat the validator and the tests until both are clean. Record what changed here.
5. [ ] Check unverified items 1-3 against the extracted data:
   - copy Revivify's own SpellProperties into `Target_FFTJ_Arise` and add the heal;
   - drop `IsConcentration` from the Protect/Shell flags;
   - pick better visual parents where an obvious one exists.
6. [ ] Convert the strings: `Divine.exe -g bg3 -a convert-loca -s Mod\Localization\English\FFTJobs.xml -d Mod\Localization\English\FFTJobs.loca` (check the action name), and keep the `.loca` in the package.
7. [ ] Package: `Divine.exe -g bg3 -a create-package -s Mod -d build\FFTJobs.pak` (check the flags; `build/` is git-ignored).
8. [ ] Install the Script Extender (official Norbyte/bg3se release) and the pak. Enable the pak in `modsettings.lsx` (back it up first; follow the load-order field note) and write `uninstall.ps1`. Create `ScriptExtenderSettings.json` next to `bg3.exe` with `{"CreateConsole": true, "LogRuntime": true}`.
9. [ ] Smoke test to the main menu only (do not play). In the SE console/log, look for `[FFTJobs]` lines and check there are no Lua errors and no stats errors for `FFTJ_` entries. The server side only loads with a game session, so at the main menu expect only the client side.
10. [ ] Finish `PLAYTEST.md` (install details, anything that changed) and this file (done / not done / unverified).
11. [ ] Update the memory files and send the final message, as `BRIEF.md` Part B says.

## Open questions for the user

- MP: abilities use cooldowns instead of an FFT MP pool. An MP resource (a custom `ActionResourceDefinition`) is possible later. Wanted?
- JP Boost is not assumed in the pacing numbers. With it equipped, JP is +50% (`DESIGN.md` section 14).
