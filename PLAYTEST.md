# Playtesting the FFT job system

Updated 2026-10-12 after the local install. **Already installed on your PC:** the Script Extender v32, the mod (`Mods\FFTJobs.pak`, version 1.0.0.1) and its entry at the end of your load order. Checked at the main menu: the mod loads, its script starts without errors and all 100 of its spells, passives and statuses are in the game. **Nothing has been tried in an actual game yet**: that part is yours.

## What you need

- Start BG3 as usual (Steam or the Larian launcher). The main menu should say "Script Extender v32 loaded" in the bottom left.
- **FFT Job System** should show as active in BG3 Mod Manager. If you change your load order there, keep it in the list.
- The Script Extender console opens as a second window next to the game (`"CreateConsole": true` in `ScriptExtenderSettings.json` in the game's `bin` folder). Click into it and press **Enter** to type a command such as `!fft_help`. Set `CreateConsole` to `false` there if the window bothers you.

### If the mod (or any mod) suddenly stops loading

BG3 has a crash check: while it loads mods it creates the folder `%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\ModCrashSanityCheck`, and deletes it once the **main menu** appears. If the game closes or crashes before that (even on the "Press any key" screen), the folder stays and the next start quietly drops every mod. Fix: with the game closed, delete that folder (BG3 Mod Manager also has a button for it), or run `tools\install.ps1` again, which removes it.

## Getting started

1. Start a new game or load a save. Your party is picked up automatically when the level loads.
2. Every party member gets a free **Job Board** spell. Cast it to open the Job Board window. If it is not on your hotbar, look in the spell list, or type `!fft_board` in the console.
3. Starting jobs: **Squire** for martial classes, **Chemist** for spellcasters (Wizard, Sorcerer, Warlock, Cleric, Druid, Bard). Everyone starts with both unlocked.

## How it works

- **Earning JP** (Job Points) goes to your current job:
  - every action or bonus action in combat (attacks, spells, items);
  - every fight you win (if you are still standing);
  - every bit of XP you gain, from quests and exploration too;
  - each long rest;
  - party members waiting in camp get half of what the fighters earned;
  - when an ally acts, everyone else in the fight gets 1/4 of that JP in the ally's job (FFT's "spillover");
  - **shared learning** (a Fell Seal rule): whenever you earn JP, 15% of it also goes into each other job your party used in combat (in the current fight, or the latest one), even locked ones. It counts toward job levels, so it can unlock jobs too.
- **Job levels** at 200 / 400 / 700 / 1,100 / 1,600 / 2,200 / 3,000 JP earned in the job.
- **New jobs** unlock from job levels, as in The Ivalice Chronicles: Knight and Archer at Squire Lv2, White Mage and Black Mage at Chemist Lv2.
- **Learning**: spend a job's JP on its abilities in the Job Board. Learned **actions** of your current job appear as spells. A **secondary** job adds its learned actions too. One learned **reaction**, one **support** and one **movement** ability can be equipped from any job.
- Job, ability and slot changes only work **outside combat**.
- A job is **mastered** when you have learned all of its abilities.

## Console commands

Type these in the Script Extender console (`who` = a party member's name, e.g. `shadowheart`; leave it out for your main character):

| Command | What it does |
|---|---|
| `!fft_help` | list all commands |
| `!fft_party` | one line per party member |
| `!fft_status [who]` | jobs, levels, JP and learned abilities |
| `!fft_board [who]` | open the Job Board |
| `!fft_job knight [who]` | change job |
| `!fft_secondary chemist [who]` / `!fft_secondary none` | set or clear the secondary skill set |
| `!fft_learn Focus [who]` | learn an ability (no spaces: `Aim1`, `XPotion`, `PhoenixDown`) |
| `!fft_equip JPBoost [who]` / `!fft_unequip support [who]` | equip or clear a reaction/support/movement slot |
| `!fft_addjp 500 [job] [who]` | add JP (for testing) |
| `!fft_unlockall [who]` | unlock every job (for testing) |
| `!fft_telemetry` | JP and XP totals logged so far |

## Changing how fast JP comes

All numbers can be changed without touching the mod:

- **Presets:** `!fft_preset Fast` (about 1.6x), `!fft_preset Grindy` (about half), `!fft_preset Classic` (default).
- **One knob for everything:** `!fft_mult 1.5` (50% more JP from every source), `!fft_mult 0.75` (25% less).
- **One source:** `!fft_set JP.XPShare 0.2` (more JP from XP), `!fft_set JP.Action.Multiplier 0.8` (more JP per action), `!fft_set JP.Victory.Base 30`. Undo with `!fft_unset JP.XPShare`.
- **Shared learning:** `!fft_set JP.Shared.Share 0.1` (10% instead of 15%), `!fft_set JP.Shared.Share 0` (off), `!fft_set JP.Shared.Scope AllJobs` (into every job, not only the ones used in combat).
- `!fft_config` shows every current value.

Changes are saved to `%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Script Extender\FFTJobs\config.json`. You can also edit that file and type `!fft_reload`. `config.reference.json` in the same folder lists every setting with a short explanation.

With the default (Classic) numbers, the simulator estimates that each party member masters all 6 jobs by the end of Act 3, even in a light playthrough (a normal one has 5 by the end of Act 2). That is quick on purpose for this 6-job test; the numbers get re-tuned when the other 14 jobs are added.

## What to report

1. Does the Job Board open, and do its buttons work?
2. Do learned abilities show up and do what their description says? Name any that are missing or broken and say what happened.
3. **JP pace:** after a few fights, does it feel too slow or too fast? `!fft_telemetry` shows the numbers.
4. Any `[FFTJobs] ERROR` or `WARNING` lines in the console.
5. If you can, attach `telemetry.jsonl` from the same folder as `config.json`. It records JP and XP per fight, which helps tune the numbers.

## Changes made while installing (2026-10-12)

- **Cura / Curaga** heal up to 3 / 4 allies you pick (BG3 has no area heal of that kind to build on), not everyone in a radius.
- **Raise, Arise, Phoenix Down** work like BG3's Revivify (target a dead ally). Arise also heals 4d8.
- **Elixir** heals to full HP.
- **Shell** gives advantage on saving throws against spells (BG3's Magic Resistance boost).
- **Protect / Shell** no longer need concentration.
- Chemist **items** are not spells: Silence and Counterspell don't stop them.
- Every JP cost and unlock rule was checked against the game data of your installed FFT: The Ivalice Chronicles (vanilla Enhanced, no mods). They all matched.

## Known gaps in this first version

- Many abilities borrow the look of vanilla spells (Throw Stone flies like Fire Bolt, item abilities look like healing spells).
- Abilities cost actions and cooldowns, not MP or real items.
- Reactions trigger automatically when you are hit; there is no reaction prompt.
- The numbers are a first draft based on estimates; your playtest is what tunes them.
- Multiplayer is untested.

## Removing the mod

Type `!fft_uninstall` (it removes every spell and passive the jobs gave), save, then disable the mod in BG3 Mod Manager. `!fft_enable` turns it back on if you change your mind.

To take it off the PC completely (game closed), run this in the project folder `C:\Users\berus\GameModding\projects\bg3-fft-jobs`: `powershell -ExecutionPolicy Bypass -File tools\uninstall.ps1`. Add `-RemoveScriptExtender` to also remove the Script Extender. Backups of your load order are in `%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\FFTJobs-backups`.

## Rebuilding after a change (for later sessions)

`tools\run_tests.ps1`, then `tools\package.ps1`, then `tools\install.ps1` (game closed; each with `powershell -ExecutionPolicy Bypass -File`).
