# BG3 × Final Fantasy Tactics: job system — project brief

Written 2026-10-09 for the agents that build this mod. Part A is for a **cloud session** (no access to the game or the user's PC). Part B is for the **local run on the user's Windows PC** (scheduled for Monday 2026-10-12 06:30 EDT). Both read the shared sections. `STATUS.md` is the handoff between sessions: read it first, update it at every milestone.

## Goal and the user's requirements

Bring Final Fantasy Tactics' job system into Baldur's Gate 3 as a mod. The user cares about mechanics, not character models. They playtest and report back; write to them in plain, short language.

- Using a job earns Job Points (JP) for it; JP buys that job's abilities; job levels unlock new jobs.
- FFT's slots: the primary job's skill set + ONE secondary skill set + ONE reaction + ONE support + ONE movement ability, each from any job the character has learned.
- **Pacing (the user's main concern):** BG3 fights are finite (nothing respawns), unlike FFT where you can grind random battles. JP income must let a normal playthrough unlock and master jobs. Make the system WORK first, but every JP number must be easy to change later without touching code (JSON config + presets + console commands).
- FFT data (job tree, unlock requirements, JP thresholds, ability lists and costs) comes from The Ivalice Chronicles (the user's choice; reliable public references, sources noted in the data files). Since 2026-10-10 the game is installed on the user's PC at `C:\Games\FINAL FANTASY TACTICS - The Ivalice Chronicles`: the local run checks the numbers against it (STATUS.md, "FFT data to check against the installed game"). Never copy FFT game files into the repo.
- Be honest: anything not seen working inside the game is "unverified".

## Design (decided; refine the details in DESIGN.md)

1. **Overlay, not replacement:** BG3 classes, levels and subclasses stay as they are. Each player-controlled party member (player character and companions) gets: a current (primary) job, unlocked jobs, JP per job (total earned + unspent), learned abilities, and 4 equipped slots: secondary skill set (a job), reaction, support, movement. Default: Squire and Chemist unlocked for everyone; starting primary configurable (e.g. Squire for martial classes, Chemist for casters).
2. **Abilities are real BG3 spells/passives/statuses**, granted only while slotted or part of the primary job (Osi.AddSpell/RemoveSpell, AddPassive/RemovePassive, statuses) and removed cleanly when unslotted. Reuse vanilla spells through stats `using` inheritance where an FFT ability has a close BG3 match.
3. **Job level** comes from total JP earned in that job; FFT thresholds (levels 2-8: 200/400/700/1100/1600/2200/3000) are the default, configurable. "Mastered" = every ability of the job learned. Unlock rules are data (FFT tree, e.g. Knight/Archer need Squire Lv2, White/Black Mage need Chemist Lv2; verify against a reference).
4. Job changes only out of combat (configurable).
5. **JP sources**, each its own config value, all scaled by a global multiplier: per action used in combat (FFT-style base + bonus per job level); a bonus per combat won; a share of the XP the character gains (ties JP to BG3's own pacing, since quests, exploration and skill checks give XP too); optional small long-rest "training" JP; FFT spillover to allies who have that job unlocked (FFT gave 1/4); a share for party members waiting in camp. A "JP Boost" support ability multiplies JP.
6. **Pacing simulator** (Python, `tools/pacing_sim.py`): takes the config plus estimates (combats per act, actions per character per fight, BG3's XP curve) and prints, for LOW/TYPICAL/HIGH estimates, when each job unlocks and is mastered. Defaults must let a character master 4+ jobs and unlock most of the tree by the end of the game even in the LOW estimate. Presets (e.g. Fast / Classic / Grindy) with their tables in DESIGN.md. Also log real numbers in game (per combat: actions, JP, XP per character) to a file in the Script Extender user folder for data-driven tuning later.
7. **Config:** a JSON file in the Script Extender user folder (written with defaults on first run, reloadable in game), presets + per-value overrides, plus console commands for testing and tuning (status, add JP, set multiplier, reload config, reset a character). Mod Configuration Menu support optional; the JSON stays the source of truth.
8. State persists in the save (the Script Extender's current recommended way; check its docs).
9. **UI:** start with whatever is fastest to make usable: console commands + a hotbar spell-container "Job Board" (change job, learn ability, equip slots), or the Script Extender's IMGUI window if available and stable. A polished board can come later.
10. **Data-driven:** jobs, abilities (type, JP cost, the BG3 spell/passive/status they grant) and unlock rules in data files, so adding a job later is data entry.

**MVP:** the whole loop for 6 jobs: Squire, Chemist, Knight, Archer, White Mage, Black Mage, with at least one ability of each type (action, reaction, support, movement) among them. Later jobs (not now): Monk, Thief, Time Mage, Summoner, Geomancer (BG3 surfaces), Dragoon (Jump), Arithmetician, Mime, Orator, etc.

API rule: Norbyte's BG3 Script Extender docs (github.com/Norbyte/bg3se, docs/API.md and related) are the reference. Verify every `Ext.`/`Osi.` call and Osiris event against them; never guess names. Mark anything you could not verify in STATUS.md.

Repository rules: never commit game files, extracted game data, or anything copied from the game. Commit often with clear messages.

## Part A — cloud session (no game, no Windows)

Do, in order, committing and pushing after each step:
1. **Research + DESIGN.md:** the Script Extender APIs/events you will use (with doc links), FFT data with sources, the JP formulas, the persistence approach, the mod folder layout (Mods/<Name>/meta.lsx with a newly generated UUID that never changes afterwards, ScriptExtender/Config.json, ScriptExtender/Lua/*, Public/<Name>/Stats/Generated/Data/*.txt, Localization/English/*.xml).
2. **Data files** for the 6 MVP jobs + abilities + unlock rules, with sources.
3. **Lua engine** (server side, client only if needed): JP from events, levels, unlocks, purchases, slots, granting/removing, config + presets + console commands, persistence, telemetry log.
4. **Stats + localization drafts** for the abilities (BG3 stats syntax; spell/passive IDs from bg3.wiki and the SE docs). Mark every `using` parent and vanilla ID "to validate in Part B against the extracted game data".
5. **Tests** in a standalone Lua 5.4 with mock Ext/Osi: JP awards, thresholds, unlocks, purchases, slot changes, config reload, save/load round trip. Run them; keep a script that runs them all.
6. **Pacing simulator** + preset tables in DESIGN.md.
7. Draft PLAYTEST.md (how to try it, console commands, what to report, how to change JP rates) and STATUS.md with a checklist for Part B.

Cannot be done here (leave for Part B): extracting vanilla data, validating stats against it, packaging the .pak, installing, launching the game.
Branches: if your session works on its own branch, merge it into `main` (or open a pull request) before you finish, and say in STATUS.md where the work is.
Scope: stop when Part A is done. The user pays for this session with cloud credits, so stay focused.

## Part B — local run on the user's PC (Monday)

**Rules for this unattended run**
- Permission (user, 2026-10-09): "anything you need to make it work": download and install what the mod needs (BG3 Script Extender, a newer LSLib, a Lua runtime for tests, Mod Configuration Menu if needed) and install the mod. Official sources only (the projects' own GitHub releases), check SHA-256 when published, back up every user file you change, write an uninstall script. Never create accounts or enter credentials.
- Usage cap: stop at a clean checkpoint when WEEKLY usage reaches 30%. Check it with `mcp__ccd_session_mgmt__get_usage` (load it via ToolSearch) at the start and after every milestone. Also stop at a checkpoint if the 5-hour window reaches 90%; then, only if weekly usage is under 30% and work remains, create ONE one-time continuation run about 5h15m later with `mcp__scheduled-tasks__create_scheduled_task` (fireAt, local time, EDT = -04:00) whose prompt is: "Continue the BG3 FFT job system build: in C:\Users\berus\GameModding\projects\bg3-fft-jobs run git pull, read STATUS.md and BRIEF.md (Part B), and follow it with the same caps and rules." At most 2 continuation runs in total; record them in STATUS.md.
- New desktop shortcuts go in the user's `Desktop\Claude Tools` folder (OneDrive desktop), never loose on the desktop.

**Environment**
- Project clone: C:\Users\berus\GameModding\projects\bg3-fft-jobs (origin https://github.com/Bitwyrm91/bg3-fft-jobs.git; Git Credential Manager is set up). Start with `git pull`; if the cloud work is only on a `claude/*` branch, merge it into main locally (and push).
- Toolkit: C:\Users\berus\GameModding (README.md lists every tool). Git Bash: `source /c/Users/berus/GameModding/env.sh`; PowerShell: `. C:\Users\berus\GameModding\env.ps1` (Python 3.12 via uv, .NET 10 SDK, Node 24, Ghidra, ILSpy, the `um` CLI).
- LSLib Divine.exe v1.20.4: C:\Users\berus\DOS2Modding\tools\lslib\Packed\Tools\Divine.exe (needs .NET 8: DOTNET_ROOT=C:\Users\berus\DOS2Modding\tools\dotnet8 on PATH). Use `-g bg3`. Check Norbyte/lslib's latest release; if a newer one is needed for the current BG3 patch, install it to C:\Users\berus\GameModding\tools\lslib-<version>.
- BG3: C:\Program Files (x86)\Steam\steamapps\common\Baldurs Gate 3 (Steam app 1086940). On 2026-10-09: no Script Extender (no bin\DWrite.dll); %LOCALAPPDATA%\Larian Studios\Baldur's Gate 3 had no Mods folder, no PlayerProfiles\Public\modsettings.lsx and no saves (the game has probably never been started on this PC).
- The user manages BG3 mods with **BG3 Mod Manager**: C:\Users\berus\GameModding\tools\BG3ModManager\BG3ModManager.exe (shortcut in Desktop\Claude Tools). When you enable this mod, keep every other mod already in modsettings.lsx, and tell the user to check it shows as active in BG3 Mod Manager.
- **FFT: The Ivalice Chronicles** is installed at `C:\Games\FINAL FANTASY TACTICS - The Ivalice Chronicles` (user, 2026-10-10). Use it for Part B step 2 in STATUS.md (FFT data check). Extracted FFT data goes to C:\Users\berus\GameModding\decomp\fft, never into the repo. **FFT mods are completely excluded** (user, 2026-10-11): the user plays TIC with mods (e.g. FFTIVC: Difficulty Enhanced), and nothing from any FFT mod goes into the BG3 mod. Vanilla TIC Enhanced only; rules in STATUS.md.
- Read: C:\Users\berus\GameModding\repos\universal-modder\knowledge\games\baldur-s-gate-3\ (6 field notes, incl. stats/Osiris patches and load order by hand) and the universal-modder skills (mod-any-game; BG3 notes in references\engines\big-frameworks.md). Extracted vanilla data goes to C:\Users\berus\GameModding\decomp\bg3 (never into the repo).

**Steps** (after each: commit, push, update STATUS.md, check usage)
1. Pull; read STATUS.md; finish anything from Part A that is missing.
2. Extract the vanilla stats/localization you need with LSLib; validate every `using` parent and referenced spell/passive/status; fix the drafts.
3. Package with LSLib (-g bg3), then install: the Script Extender (official Norbyte/bg3se release, into the game's bin folder), the pak into %LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Mods, enabled in modsettings.lsx (back it up first; follow the load-order field note). If the user folder or modsettings.lsx does not exist yet, launch BG3 once to the main menu and close it by PID so it creates them, or leave an install script and tell the user to run it after starting BG3 once. Write uninstall.ps1.
4. Smoke test: with Steam running, start bin\bg3.exe directly with the Script Extender console/log enabled, wait for the main menu, read the log for this mod loading and for Lua errors, then close the game by PID. Do not try to play, create characters or click through menus.
5. Finish PLAYTEST.md and STATUS.md (done / not done / unverified, next steps).
6. Memory: update C:\Users\berus\.claude\projects\C--Users-berus-OneDrive-Documents-1Claude\memory\bg3-fft-job-system.md (keep its frontmatter; build state, file locations, verified vs not) and, if you installed new tools, game-mashup-toolkit.md; keep the pointers in MEMORY.md accurate.
7. Final message: plain language, short: what works, what is untested, how to try it, which JP defaults you chose and how to change them, any questions.
