# Playtesting the FFT job system

Draft written in the cloud before the mod ever ran in the game. Monday's local run installs it and fills in anything that changes.

## What you need

- BG3 with the **Script Extender** installed (Monday's run installs it).
- **FFT Job System** active in BG3 Mod Manager.
- Optional but useful: the Script Extender console. Monday's run turns it on (`"CreateConsole": true` in `ScriptExtenderSettings.json` next to the game's `bg3.exe`). A second window then opens next to the game; click into it and press **Enter** to type a command such as `!fft_help`.

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
  - **shared learning** (a Fell Seal rule): whenever you earn JP, 15% of it also goes into each of your other jobs, even locked ones. It counts toward job levels, so it can unlock jobs too.
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
- **Shared learning:** `!fft_set JP.Shared.Share 0.1` (10% instead of 15%), `!fft_set JP.Shared.Share 0` (off), `!fft_set JP.Shared.Scope PartyJobs` (only into jobs someone in your party is using, closer to Fell Seal).
- `!fft_config` shows every current value.

Changes are saved to `%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Script Extender\FFTJobs\config.json`. You can also edit that file and type `!fft_reload`. `config.reference.json` in the same folder lists every setting with a short explanation.

With the default (Classic) numbers, the simulator estimates that each party member masters all 6 jobs by the end of Act 3 in a light playthrough and by the end of Act 2 in a normal one. That is quick on purpose for this 6-job test; the numbers get re-tuned when the other 14 jobs are added.

## What to report

1. Does the Job Board open, and do its buttons work?
2. Do learned abilities show up and do what their description says? Name any that are missing or broken and say what happened.
3. **JP pace:** after a few fights, does it feel too slow or too fast? `!fft_telemetry` shows the numbers.
4. Any `[FFTJobs] ERROR` or `WARNING` lines in the console.
5. If you can, attach `telemetry.jsonl` from the same folder as `config.json`. It records JP and XP per fight, which helps tune the numbers.

## Known gaps in this first version

- Many abilities borrow the look of vanilla spells (Throw Stone flies like Fire Bolt, item abilities look like healing spells).
- Abilities cost actions and cooldowns, not MP or real items.
- Reactions trigger automatically when you are hit; there is no reaction prompt.
- The numbers are a first draft based on estimates; your playtest is what tunes them.
- Multiplayer is untested.

## Removing the mod

Type `!fft_uninstall` (it removes every spell and passive the jobs gave), save, then disable the mod in BG3 Mod Manager. `!fft_enable` turns it back on if you change your mind.
