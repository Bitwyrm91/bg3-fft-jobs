# Playtesting the FFT job system

Updated 2026-10-12 evening. **Already installed on your PC:** the Script Extender, the mod (`Mods\FFTJobs.pak`, **version 1.0.0.7**: four new jobs and the Fell Seal rules below, on top of the painted icons, the element looks and the **JP Training** test spell) and its entry at the end of your load order.

## New in 1.0.0.7: Monk, Thief, Time Mage, Mystic (phase 2, step 2, batch 1)

Every ability of the four jobs, with the TIC JP costs. New abilities wear borrowed vanilla icons for now. To reach them fast: cast **JP Training three times** (Squire/Chemist Lv5 → Knight, Archer, White Mage, Black Mage unlock; their Lv5 → Monk, Thief, Time Mage, Mystic unlock; the third cast pays for abilities). Each character unlocks with its own levels.

Worth trying, because the game decides whether they work:
- **Thief, Steal Weapon / Armor / Helm / Shield / Accessory:** on a hit, the enemy's item should land in your inventory and leave its body (a notice says what was stolen). Quest items stay. **Steal Gil** / **Steal EXP** give gold / experience (10 × the enemy's level), once per enemy.
- **Gil Snapper** (gold when hurt), **Poach** (gold when a monster you hit this turn dies), **Sticky Fingers** (thrown things do no damage).
- **Monk:** **Counter** and **First Strike** should ask "use your reaction?" like Riposte or Polearm Master. **Doom Fist** kills the target when Doom runs out after 3 turns (bosses are immune: a notice says so). **Chakra** and **Purification** work in combat. **Lifefont** heals a little when you move. Monk always has **Brawler** (stronger fists).
- **Time Mage:** **Gravity / Graviga** take a quarter / half of an enemy's maximum HP (bosses immune). **Stop** freezes an enemy; **Quick** gives an ally an extra action next turn; **Swiftspell** makes your first spell in each fight a bonus action; **Mana Shield** asks to spend a level 1 spell slot to cut damage; **Teleport** is a free Misty Step each turn.
- **Mystic:** status spells (blind, silence, sleep, confusion, berserk, stone, undead, atheist, fear), **Harmony** strips buffs, **Absorb MP** / **Manafont** give back a level 1 spell slot.
- Anything that does nothing, or a tooltip that looks wrong: tell me which ability. The SE console log shows each steal and Gravity hit.

**First games (2026-10-12):** the mod loaded, found your party, and JP Training, learning on the Job Board and the granted skills all worked. The "missing" Squire skills were on the hotbar all along, but wore borrowed vanilla icons (Focus looked exactly like the Job Board). Since 1.0.0.4 every ability, job and buff has its own icon, with a background colour per job: Squire amber, Chemist green, Knight blue, Archer forest green, White Mage pale gold, Black Mage indigo.

**Tip:** test in a separate save (Explorer or Balanced), not an Honour Mode run. Honour Mode has a single save that can't be reloaded, so anything the test mod does to your characters stays in that run.

## New in 1.0.0.6: the Fell Seal rules (phase 2, step 1)

What to try (JP Training makes it quick):
1. **The party sees unlocks; each character needs its own levels.** When Tav reaches Squire Lv2, Knight shows on everyone's Job Board as "Unlocked by the party; needs Squire Lv2 (has Lv1)". Shadowheart can learn Knight abilities and become a Knight once her own Squire is Lv2; the Knight JP she collects meanwhile (spillover, shared learning) waits for her.
2. **New slots (Fell Seal):** one reaction slot and **two free passive slots**, each taking any support or movement ability (two supports, or a support and a movement ability). With both full, the Job Board offers "Replace 1" / "Replace 2". Your old support and movement picks moved into the two passive slots.
3. **The main job's support and movement abilities need no slot.** As a Squire, learn JP Boost or Move +1: the Job Board says "Learned, always on while this is your job", the character sheet shows the passive, and the passive slots stay free for other jobs. Change job and they need a slot again. Reactions always need the reaction slot (as Fell Seal's counters do).
4. **Equipment by main job.** Each job's passive on the character sheet ("Job: Knight") now lists its equipment and gives the proficiency while it is the main job: for example, a Wizard who becomes a Knight can wear heavy armour and use a shield without penalties. Hover a job's name on the Job Board to see its equipment and mastery perk.
5. **Mastery perks.** Learn every ability of a job: you get a small permanent passive ("Squire Mastery: +5 maximum hit points") that stays after changing jobs and stacks with other jobs' perks. Squire +5 max HP, Chemist poison resistance, Knight +1 Constitution saves, Archer +1 to ranged weapon attacks (BG3 has no "+1 m range" bonus), White Mage +1 Wisdom saves, Black Mage +1 spell attacks.
6. Console: `!fft_equip <ability> 1` or `2` picks the passive slot, `!fft_unequip 1` clears it. Mastery perks can be switched off with `!fft_set Rules.MasteryPerks false`.

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

## Testing without grinding: JP Training

Every party member also gets a free **JP Training (test)** spell (the Inspiring Leader icon). Each cast gives **every party member 1,000 JP in each job they have unlocked**. Jobs that a cast unlocks get JP from the next cast:

- **1 cast:** Squire and Chemist reach job level 4, and Knight, Archer, White Mage and Black Mage unlock.
- **3 casts:** every job is at least level 6.
- **About 7 casts:** enough JP to learn every ability in every job (Archer's are the most expensive, 5,300 JP in all).

Each cast shows one summary message; the level-ups and unlocks are listed in the console. Then open the **Job Board** to learn abilities, switch jobs and fill the slots.

- Console version: `!fft_train` (same as one cast) or `!fft_train 5000` (a bigger batch).
- More per cast: `!fft_set Test.JPPerCast 3000`.
- When you're done testing: `!fft_set Test.Tools false` removes the spell; `!fft_unset Test.Tools` brings it back.
- Training JP is logged as its own source (`Test`), so it doesn't skew the pace numbers in `!fft_telemetry`. For a real pace test, start a fresh save or `!fft_reset` the character first.

## Where learned abilities show up

- **Actions** (Focus, Rush, Potion, Cure, ...) are added to the character's spells only while their job is the character's **job** or **secondary** (Job Board: **Set job** or **Secondary** on the job's row). The Job Board's status column says "Learned, in the spells" when they are, and "make this job the job or secondary" when they aren't.
- **Reaction, support and movement** abilities do nothing until you click **Equip** next to them. Most are passives, so they show on the character sheet, not the hotbar.
- **Can't find them?** Type `!fft_grants` in the console (or `!fft_grants laezel` for someone else). It lists every spell and passive the character's jobs should give and says **in game** or **MISSING in game** for each. Claude can read the result from the log, so you don't need to copy it.

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
| `!fft_train [amount]` | JP Training: every party member gets JP in each unlocked job (for testing) |
| `!fft_grants [who]` | what the character's jobs give right now, and whether the game has each one (for bug reports) |
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

- Many abilities borrow their animation and effects from vanilla spells (Throw Stone flies like Fire Bolt, item abilities look like healing spells). Their icons are their own since 1.0.0.4.
- Abilities cost actions and cooldowns, not MP or real items.
- Reactions trigger automatically when you are hit; there is no reaction prompt.
- The numbers are a first draft based on estimates; your playtest is what tunes them.
- Multiplayer is untested.

## Removing the mod

Type `!fft_uninstall` (it removes every spell and passive the jobs gave), save, then disable the mod in BG3 Mod Manager. `!fft_enable` turns it back on if you change your mind.

To take it off the PC completely (game closed), run this in the project folder `C:\Users\berus\GameModding\projects\bg3-fft-jobs`: `powershell -ExecutionPolicy Bypass -File tools\uninstall.ps1`. Add `-RemoveScriptExtender` to also remove the Script Extender. Backups of your load order are in `%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\FFTJobs-backups`.

## Rebuilding after a change (for later sessions)

`tools\run_tests.ps1`, then `tools\package.ps1`, then `tools\install.ps1` (game closed; each with `powershell -ExecutionPolicy Bypass -File`).
