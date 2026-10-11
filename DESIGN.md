# BG3 × FFT job system — design

Written in Part A (cloud session, 2026-10-09). This document holds the research behind the build, the rules the engine implements, and the pacing tables. `BRIEF.md` holds the requirements, `STATUS.md` what is done, verified or still open.

Contents: [1 Scope](#1-scope) · [2 How things were verified](#2-how-things-were-verified) · [3 Script Extender API](#3-script-extender-api-used) · [4 Osiris API](#4-osiris-calls-and-events-used) · [5 FFT data](#5-fft-data-the-ivalice-chronicles) · [6 Rules](#6-rules-the-engine-implements) · [7 JP sources](#7-jp-sources-and-formulas) · [8 Abilities in BG3](#8-fft-abilities-as-bg3-spells-passives-statuses) · [9 Persistence](#9-persistence) · [10 Mod layout and build](#10-mod-layout-and-build) · [11 UI](#11-ui) · [12 Config, presets, console](#12-config-presets-and-console-commands) · [13 Telemetry](#13-telemetry) · [14 Pacing](#14-pacing-simulator-and-preset-tables) · [15 Open questions](#15-open-questions-and-unverified-items)

## 1. Scope

An overlay on BG3's own classes: classes, levels and subclasses stay as they are. Every player-controlled party member (main character, companions, hirelings; not summons) gets FFT-style jobs on top:

- a **primary job**, the set of **unlocked jobs**, **JP per job** (total earned and unspent), **learned abilities**;
- four slots: **secondary skill set** (a job), **reaction**, **support**, **movement**;
- abilities are real BG3 spells, passives and statuses, granted only while they are part of the primary job's skill set, the secondary skill set or a slot.

MVP: six jobs (Squire, Chemist, Knight, Archer, White Mage, Black Mage), 71 abilities covering all four ability types. The other 14 generic jobs of the TIC tree are in the data with their unlock rules (`"implemented": false`), so adding one is data entry plus stats.

FFT data comes from **Final Fantasy Tactics: The Ivalice Chronicles** (TIC, 2025), the user's choice. Where TIC numbers are not published, War of the Lions (WotL, 2007) values are used and marked.

## 2. How things were verified

The cloud environment's network policy blocks most reference sites (docs.baldursgate3.game, bg3.wiki, wiki.bg3.community, mod.io, gist.github.com, Fandom, GameFAQs, Game8 pages). Only `raw.githubusercontent.com` and web search were usable. So:

| What | Checked against |
|---|---|
| `Ext.*` calls, events, persistence | Norbyte's [Docs/API.md](https://github.com/Norbyte/bg3se/blob/main/Docs/API.md) (API v30 text, release notes up to v32) and the official [ExtIdeHelpers.lua](https://github.com/Norbyte/bg3se/blob/main/BG3Extender/IdeHelpers/ExtIdeHelpers.lua) |
| Osiris calls/events (names and arity) | [LaughingLeader/BG3ModdingTools `generated/Osi.lua` and `Osi.Events.lua`](https://github.com/LaughingLeader/BG3ModdingTools/tree/master/generated), generated from the game's `story_header.div` (commit `ab343b6`) |
| FFT/TIC data | Web search summaries of Game8 and RPGSite (they agree with each other), cross-checked against Hack the Minotaur and a GameFAQs guide; exact URLs in `data/fft_jobs.json` |
| BG3 stats IDs (vanilla spells, statuses, `using` parents, icons) | **Not verifiable here.** Every one is listed in `docs/vanilla_refs.md` (generated) for Part B to check against the extracted game data with `tools/validate_vanilla.py` |

## 3. Script Extender API used

All server side unless marked. Links go to the API doc sections.

| Call / event | Use | Reference |
|---|---|---|
| `Mods/FFTJobs/ScriptExtender/Config.json` (`RequiredVersion`, `ModTable`, `FeatureFlags: ["Lua"]`) | enables Lua | [Getting started](https://github.com/Norbyte/bg3se/blob/main/Docs/API.md#getting-started) |
| `BootstrapServer.lua`, `BootstrapClient.lua`, `Ext.Require(path)` | entry points, module loading (only at bootstrap) | [Bootstrap scripts](https://github.com/Norbyte/bg3se/blob/main/Docs/API.md#bootstrap-scripts) |
| `ModuleUUID` global | mod UUID, valid only while loading: captured once at bootstrap | ExtIdeHelpers line 9 |
| `Ext.Vars.RegisterModVariable(ModuleUUID, name, opts)`, `Ext.Vars.GetModVariables(ModuleUUID)` | save-game persistence | [Mod variables](https://github.com/Norbyte/bg3se/blob/main/Docs/API.md#mod-variables) |
| `Ext.Events.SessionLoaded`, `Ext.Events.ResetCompleted` | load state after a save is loaded / after `reset` | [Engine events](https://github.com/Norbyte/bg3se/blob/main/Docs/API.md#engine-events) |
| `Ext.Osiris.RegisterListener(name, arity, "after", fn)` | Osiris events | [Capturing events](https://github.com/Norbyte/bg3se/blob/main/Docs/API.md#calling-lua-from-osiris) |
| `Osi.<Name>(...)`, `Osi.DB_IsPlayer:Get(nil)` | Osiris calls/queries/DB reads | [Calling Osiris from Lua](https://github.com/Norbyte/bg3se/blob/main/Docs/API.md#calling-osiris-from-lua), `DB_IsPlayer` from ExtIdeHelpers `OsiCommonDatabases` |
| `Ext.RegisterConsoleCommand(name, fn)` | `!fft_*` console commands; args arrive as strings | [SE console](https://github.com/Norbyte/bg3se/blob/main/Docs/API.md#console) |
| `Ext.IO.LoadFile(path)`, `Ext.IO.SaveFile(path, text)` | config and telemetry files in `%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Script Extender\` | [IO](https://github.com/Norbyte/bg3se/blob/main/Docs/API.md#io) |
| `Ext.Json.Parse`, `Ext.Json.Stringify(v, {Beautify=true})` | config/telemetry | [JSON](https://github.com/Norbyte/bg3se/blob/main/Docs/API.md#json-support) |
| `Ext.Timer.WaitFor(ms, fn)` | XP polling loop (game clock) | [Timers](https://github.com/Norbyte/bg3se/blob/main/Docs/API.md#timers) |
| `Ext.Timer.ClockTime()` | telemetry time stamps | Timers, ExtIdeHelpers `Ext_Timer` |
| `Ext.OnNextTick(fn)` | coalesce save-state writes once per tick | [Engine events](https://github.com/Norbyte/bg3se/blob/main/Docs/API.md#engine-events) (Tick) |
| `Ext.Utils.Print` (`_P`) | log lines | [Helper functions](https://github.com/Norbyte/bg3se/blob/main/Docs/API.md#helper-functions) |
| `Ext.Entity.Get(guid)` → `.Experience.TotalExperience`, `.Classes.Classes[i].ClassUUID`, `.DisplayName.Name:Get()` | XP, starting job by class, names | [Entity class](https://github.com/Norbyte/bg3se/blob/main/Docs/API.md#entity-class); fields from ExtIdeHelpers (`EocExpExperienceComponent`, `ClassesComponent`, `DisplayNameComponent`) |
| `Ext.StaticData.Get(uuid, "ClassDescription").Name` | class name ("Wizard"…) | [Static data](https://github.com/Norbyte/bg3se/blob/main/Docs/API.md#static-data), `ResourceClassDescription.Name` |
| `Ext.Loca.GetTranslatedString(handle)` | resolve `Osi.GetDisplayName` handles | [Localization](https://github.com/Norbyte/bg3se/blob/main/Docs/API.md#loca) |
| `Ext.Stats.Get(spell).UseCosts` | is a cast an action, a bonus action or a reaction | [Stats](https://github.com/Norbyte/bg3se/blob/main/Docs/API.md#stats) |
| `Ext.Net.CreateChannel(ModuleUUID, name)`, `:SetRequestHandler`, `:RequestToServer`, `:SetHandler`, `:Broadcast` (C+S) | Job Board UI ↔ server (added in SE v22) | [NetChannel API](https://github.com/Norbyte/bg3se/blob/main/Docs/API.md#net-channel-api) |
| `Ext.IMGUI.NewWindow`, `AddButton`, `AddText`, `AddTable`/`AddRow`/`AddCell`, `AddSeparatorText`, `AddGroup`, `OnClick`, `Destroy`, `Open`, `Closeable` (C) | Job Board window | ExtIdeHelpers `Ext_ClientIMGUI`, `ExtuiTreeParent`, `ExtuiWindow` (not in API.md) |

`RequiredVersion` is set to 30, the API version the doc describes; Part B installs the current release (v32 or later).

## 4. Osiris calls and events used

Signatures as generated from `story_header.div` (see section 2). Arity is what `RegisterListener` needs.

| Event | Arity | Use |
|---|---|---|
| `CastedSpell(caster, spell, spellType, spellElement, storyActionID)` | 5 | action JP, Job Board spell |
| `EnteredCombat(object, combatGuid)` | 2 | combat roster |
| `CombatStarted(combatGuid)` / `CombatEnded(combatGuid)` | 1 / 1 | combat bookkeeping, victory JP, camp share, telemetry |
| `CombatRoundStarted(combatGuid, round)` | 2 | telemetry (rounds) |
| `TurnStarted(object)` | 1 | per-turn JP cap |
| `LongRestFinished()` | 0 | training JP, grant check |
| `LeveledUp(character)` | 1 | XP check, grant check |
| `CharacterJoinedParty(character)` | 1 | start tracking a companion |
| `LevelGameplayStarted(levelName, isEditorMode)` | 2 | party discovery, grant check, XP baseline |

| Call / query | Returns | Use |
|---|---|---|
| `AddSpell(character, spell, showNotification, addContainerSpells)` / `RemoveSpell(character, spell, removeContainerSpells)` | – | grant/remove spells |
| `AddPassive(entity, passiveID)` / `RemovePassive(entity, passiveID)` | – | grant/remove passives |
| `ApplyStatus(object, status, duration, force, source)` / `RemoveStatus(target, status, cause)` | – | grant/remove permanent statuses (duration -1) |
| `HasSpell(character, spell)` / `HasPassive(entity, passiveID)` / `HasActiveStatus(target, status)` | 0/1 | never take away something the character had before |
| `GetHostCharacter()` | guid | console default target |
| `IsInCombat(entity)`, `IsDead(character)`, `IsSummon(potentialSummon)`, `IsPartyMember(character, includeNotControlable)` | 0/1 | rules, roster, camp share |
| `GetLevel(object)` | int | JP formula |
| `GetDisplayName(target)` | loca handle | names |
| `ShowNotification(character, text)` | – | level-up / unlock / mastery messages |
| `DB_IsPlayer(guid)` (database, read with `:Get(nil)`) | rows | party discovery |

Osiris has no "experience gained" event, so XP is polled from the `Experience` component (section 7).

## 5. FFT data (The Ivalice Chronicles)

Full tables with per-number sources: `data/fft_jobs.json`. Summary:

**Job levels** (total JP earned in the job; WotL/TIC values, PS1 used lower ones): Lv2 200, Lv3 400, Lv4 700, Lv5 1100, Lv6 1600, Lv7 2200, Lv8 3000. Sources: metroidcomposite's TIC guide on GameFAQs ("Changes to JP, abilities and special characters": Lv3 400 … Lv8 3000, "TIC uses WotL job unlock values"), Lv2 200 from the WotL table credited to Qu_Marsh's FAQ.

**Unlock tree** (Game8 "List of All Jobs and Unlock Requirements", GameRant agrees; TIC uses the WotL values, generally one level higher than PS1 US):

| Job | Requires | | Job | Requires |
|---|---|---|---|---|
| Squire, Chemist | start | | Summoner | Time Mage 3 |
| Knight, Archer | Squire 2 | | Orator | Mystic 3 |
| White Mage, Black Mage | Chemist 2 | | Samurai | Knight 4, Monk 5, Dragoon 2 |
| Monk | Knight 3 | | Ninja | Archer 4, Thief 5, Geomancer 2 |
| Thief | Archer 3 | | Arithmetician | White Mage 5, Black Mage 5, Time Mage 4, Mystic 4 |
| Time Mage | Black Mage 3 | | Bard (male in FFT) | Summoner 5, Orator 5 |
| Mystic | White Mage 3 | | Dancer (female in FFT) | Geomancer 5, Dragoon 5 |
| Geomancer | Monk 4 | | Mime | Squire 8, Chemist 8, Summoner 5, Orator 5, Geomancer 5, Dragoon 5 |
| Dragoon | Thief 4 | | | |

The gender locks are not used in BG3.

**JP per action** (FFT formula, from the Design Oriented analysis of FFT and Steam threads on TIC): `8 + 2 × job level + floor(character level / 4)`. TIC Enhanced adds +30% to JP from a unit's own actions, after the formula and not to spillover (metroidcomposite). JP Boost multiplies by 1.5 (sources split between 1.5 and 2; 1.5 used). Reactions earn no JP (Game8). Fan analysis suggests the TIC constant may be 16 instead of 8; unresolved, so the constant is a config value.

**Spillover**: allies in the battle receive 1/4 of the JP an ally earns, in that ally's job, computed before JP Boost. In TIC it goes to allies even if they have not unlocked that job (Steam/GameFAQs reports).

**Abilities and JP costs** (Game8 + RPGSite; they match each other, Hack the Minotaur contradicts itself and was not used). The MVP keeps the abilities that translate to BG3. **Bold** = left out of the MVP (no good BG3 equivalent yet), cost kept for reference.

| Job (skill set) | Action abilities (JP) | Reaction | Support | Movement | MVP total |
|---|---|---|---|---|---|
| Squire (Fundaments) | Focus 300, Rush 80, Throw Stone 90, Salve 150 | Counter Tackle 180 | Equip Axes 170, Evasive Stance 50, JP Boost 250 | Movement +1 200 | 1,470 |
| Chemist (Items) | Potion 30, Hi-Potion 200, X-Potion 300, Ether 300, Elixir 900, Antidote 70, Eye Drops 80, Echo Herbs 120, Remedy 700, Phoenix Down 90, **Hi-Ether 400, Maiden's Kiss 200, Gold Needle 250, Holy Water 400** | Auto-Potion 400 | Throw Items 350, **Safeguard 250, Reequip 50** | Treasure Hunter 100 | 3,640 |
| Knight (Arts of War) | Rend Armor 400, Rend Weapon 400, Rend Speed 250, Rend Power 250, Rend Magick 250, **Rend Helm 300, Rend Shield 300, Rend MP 250** | Parry 200 | Equip Heavy Armor 500, Equip Shields 250, Equip Swords 400 | – | 2,900 |
| Archer (Aim) | Aim +1 100, +2 150, +3 200, +4 250, +5 300, +7 400, +10 700, +20 900 | Speed Surge 900, Archer's Bane 450 | Equip Crossbows 350, Concentration 400 | Jump +1 200 | 5,300 |
| White Mage (White Magicks) | Cure 50, Cura 180, Curaga 450, Raise 200, Arise 600, Reraise 1000, Regen 350, Protect 70, Shell 70, Esuna 300, Holy 600, **Curaja 800, Protectja 600, Shellja 600, Wall 400** | Regenerate 400 | Magick Defense Boost 400 | – | 4,670 |
| Black Mage (Black Magicks) | Fire 50, Fira 200, Firaga 500, Thunder 50, Thundara 200, Thundaga 500, Blizzard 50, Blizzara 200, Blizzaga 500, Poison 150, Death 600, Flare 1000, **Firaja/Thundaja/Blizzaja 900, Toad 500** | Magick Counter 800 | Magick Boost 400 | – | 5,200 |

Contested values (sources disagree): Squire's Focus/Throw Stone/Salve, Knight's Rend Weapon and Equip Heavy Armor, Archer's Aim +10/+20 and Equip Crossbows. The Game8/RPGSite value is used and the alternative is noted in the data file.

## 6. Rules the engine implements

- **Job level** = 1 + number of thresholds reached by the job's total earned JP (max 8).
- **Unlock**: a job unlocks when every requirement `{job, level}` is met. Squire and Chemist start unlocked (config). Unlocks are checked after every JP gain and on load.
- **Starting job**: by BG3 class (config): Wizard, Sorcerer, Warlock, Cleric, Druid, Bard start as Chemist, everyone else as Squire.
- **Learning** an ability costs its JP from the unspent JP of the ability's job; the job must be unlocked. Out of combat only (config).
- **Mastered** = every implemented ability of the job learned.
- **Primary job**: any unlocked job, out of combat only (config). If it equals the secondary, the secondary is cleared.
- **Secondary skill set**: any unlocked job other than the primary; grants that job's learned action abilities.
- **Reaction / support / movement**: one learned ability of that type each, from any job.
- **Granted** = learned actions of primary and secondary job + the three slotted abilities + the job's innate passive (`FFTJ_Job_<Job>`, shows the current job on the character sheet; no stats yet) + the Job Board spell. Everything else the mod granted is removed. Before granting, the engine checks `HasSpell`/`HasPassive`/`HasActiveStatus`: if the character already has it from elsewhere it is not marked as ours and never removed.
- **Variants**: an ability can grant a different spell when a condition holds. Chemist items grant a short-range spell normally and a thrown 9 m spell when Chemist is the primary job or Throw Items is the equipped support (FFT: Chemists throw items, other jobs need Throw Items).
- **JP Boost**: the equipped support with `"effect": "JPBoost"` multiplies the character's own JP.
- JP goes to the **primary job**, also for actions from the secondary skill set (FFT rule).
- **Shared learning** (from Fell Seal: Arbiter's Mark, added at the user's request on 2026-10-11): 15% of every JP gain a character makes also goes into each of that character's other jobs, locked ones included. Fell Seal itself gives 15% of a battle's AP only to the classes used in that battle; here it covers every job by default (`Scope` `AllJobs`), and `PartyJobs` limits it to the jobs the party uses. Shared JP counts toward job levels, so it can unlock jobs. Spillover, console JP and shared JP itself are not shared again.

## 7. JP sources and formulas

Every number below is a config value (section 12). `G` = global multiplier, `B` = JP Boost multiplier (1 without JP Boost).

| Source | When | JP to the primary job | FFT/TIC basis |
|---|---|---|---|
| Action | `CastedSpell` by a tracked character in combat, if the spell costs an action (bonus action: × `BonusActionWeight`; reactions, the jump spell and listed spells: 0) | `(Base + PerJobLevel × jobLv + floor(charLv / CharLevelDivisor)) × (1 + EnhancedBonus) × Action.Multiplier × B × G` | FFT formula + TIC Enhanced +30% |
| Spillover | same cast, to every other tracked character in the same combat, into the **caster's** job | `formula × Action.Multiplier × Spillover.Share × G` (no Enhanced, no Boost) | FFT 1/4; TIC: also into locked jobs |
| Victory | `CombatEnded`, each participant still alive | `(Victory.Base + Victory.PerCharLevel × charLv) × B × G` | BG3 adaptation |
| XP share | any XP gain (quests, exploration, checks, combat) | `xpGained × XPShare × B × G` | BG3 adaptation, ties JP to BG3's own pacing |
| Camp share | `CombatEnded`, tracked characters who were not in the fight | `average own JP of the participants in this fight × Camp.Share × G` | BG3 adaptation |
| Training | `LongRestFinished` | `LongRest × B × G` | BG3 adaptation |
| Shared learning | every gain above except spillover (per source: `Shared.Sources`), into each of the character's **other** jobs: all of them (`Scope` `AllJobs`, default) or the jobs someone in the party uses as primary (`PartyJobs`); `RequireUnlocked` limits it to unlocked jobs | `gain × Shared.Share` (the gain already includes B and G) | Fell Seal: Arbiter's Mark's vicarious learning (15%), extended to every job |

Fractions are kept per job (`frac`) so small amounts are not lost to rounding. `Action.MaxPerTurn` (0 = off) caps action JP per turn.

**XP detection**: Osiris has no XP event, so the engine polls `Ext.Entity.Get(guid).Experience.TotalExperience` every `XPPollMs` (game clock) and right after combat ends and level-ups. The first reading only sets a baseline (no retroactive JP; `!fft_addjp` can top up a save the mod was added to).

## 8. FFT abilities as BG3 spells, passives, statuses

Stats drafts: `stats_src/*.txt` (templates; the build fills in localization handles) → `Mod/Public/FFTJobs/Stats/Generated/Data/*.txt`. Naming: spells `Target_FFTJ_*`, `Projectile_FFTJ_*`, `Shout_FFTJ_*`, `Zone_FFTJ_*`; passives `FFTJ_*`; statuses `FFTJ_*` (upper case).

Design choices:
- **Class-independent costs.** BG3 casting runs on spell slots, which martial classes do not have, so FFT abilities cost an action or bonus action plus a cooldown instead of MP: cheap abilities have no cooldown or `OncePerTurn`, mid tiers `OncePerShortRest`, top tiers `OncePerRest`. An FFT-style MP resource is possible later (custom `ActionResourceDefinition`).
- **No spellcasting-ability dependence** where possible: magic is auto-hit or uses a saving throw, because the ability modifier used by spells added with `AddSpell` to non-casters is unverified (Part B checks; the alternative is a passive with `UnlockSpell(...,Intelligence)`).
- **Reuse vanilla** through `using` where BG3 has a close match: weapon attacks (`Target_MainHandAttack`, `Projectile_MainHandAttack`) for Knight rends and Archer aims, `Target_CureWounds`, `Target_Revivify`, `Target_DeathWard`, `Projectile_FireBolt`, `Projectile_Fireball` and similar for magic.
- Support/movement abilities are passives with static boosts (proficiencies, AC, movement, jump distance, roll bonuses). Reactions are passives with an `OnDamaged` functor (BG3 interrupts would be the faithful version; left for later).

The per-ability BG3 effect is described in each ability's `description` in `data/fft_jobs.json`.

## 9. Persistence

One mod variable, `State`, registered with `Ext.Vars.RegisterModVariable(ModuleUUID, "State", {Server=true, Client=false, Persistent=true, SyncToClient=false})` on both server and client at bootstrap (the doc recommends registering on both sides with the same settings). PersistentVars are deprecated per the doc and not used.

- In memory the engine owns a plain Lua table; after every change it writes `vars.State = state` (coalesced to once per tick). Writes to sub-tables do not mark a variable dirty, so the whole table is reassigned.
- The state is read once per Lua session, after `SessionLoaded`. Events that arrive earlier are ignored, so an empty state never overwrites a saved one.
- Schema (`schema = 1`): `chars[uuid] = {name, primary, secondary, reaction, support, movement, unlocked{job=true}, jobs[job] = {earned, unspent, frac, learned{ability=true}}, granted = {spells{}, passives{}, statuses{}}, lastXP, stats{...}}`. Keys are the 36-character UUID part of Osiris GUID strings.
- `!fft_uninstall` removes every granted spell/passive/status from every character before the mod is removed.

## 10. Mod layout and build

Mod UUID **`3db7be3e-9387-4678-b172-044acc7ff0c2`** (generated 2026-10-09; never change it). Folder/ModTable `FFTJobs`, display name "FFT Job System", version 1.0.0.0 (`Version64` 36028797018963968).

```
Mod/                                    <- pack this folder with LSLib (-g bg3)
  Mods/FFTJobs/meta.lsx
  Mods/FFTJobs/ScriptExtender/Config.json
  Mods/FFTJobs/ScriptExtender/Lua/BootstrapServer.lua, BootstrapClient.lua
  Mods/FFTJobs/ScriptExtender/Lua/Shared/   GeneratedData.lua (generated), Util.lua, Log.lua
  Mods/FFTJobs/ScriptExtender/Lua/Server/   Config, State, Rules, Game, Grants, Service, Events, Commands, View, NetServer, Telemetry
  Mods/FFTJobs/ScriptExtender/Lua/Client/   JobBoard.lua
  Public/FFTJobs/Stats/Generated/Data/      Spell_FFTJ.txt, Passive_FFTJ.txt, Status_FFTJ.txt (generated)
  Localization/English/FFTJobs.xml          (generated; Part B converts it to FFTJobs.loca)
data/        fft_jobs.json, config_defaults.json, strings.json   <- edit these
stats_src/   stats templates with {{name:...}} / {{desc:...}} / {{str:...}} placeholders
tools/       build.py, pacing_sim.py, validate_vanilla.py, run_tests.sh, run_tests.ps1
tests/       Lua 5.4 tests with mock Ext/Osi
```

`python3 tools/build.py` regenerates the Lua data module, the stats files, the localization XML and `docs/vanilla_refs.md` from `data/` and `stats_src/`, and checks that every ID the data grants exists in the stats. `--check` fails if the committed generated files are stale (run by the test script). Adding a job: add it to `data/fft_jobs.json` (set `implemented`), add its abilities and stats entries, run the build and the tests.

Localization handles are derived from the mod UUID and the string key (UUID v5), so they never change between builds.

## 11. UI

- **Job Board window** (SE IMGUI, client): opened by casting the **Job Board** spell (`Shout_FFTJ_JobBoard`, granted to every tracked character, free) or with `!fft_board`. One row of buttons per party member; for the selected character: current job and slots, a jobs table (level, JP, unlock requirements, set primary/secondary) and the selected job's abilities (cost, learn, equip/unequip). Every button sends a request to the server over a NetChannel; the server applies the rules and replies with the new view.
- **Console commands** (section 12) do everything the window does, plus tuning.

A hotkey is not used: the key-input event's name differs between the SE doc and ExtIdeHelpers, so it is left for Part B to confirm.

## 12. Config, presets and console commands

File: `%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Script Extender\FFTJobs\config.json`, written with defaults on first run, reloaded with `!fft_reload`:

```json
{ "Preset": "Classic", "Overrides": { "JP": { "XPShare": 0.2 } } }
```

Effective config = defaults (`data/config_defaults.json`) ← preset ← `Overrides`. The engine also writes `config.reference.json` next to it with every key, its effective value and a help text. Console changes (`!fft_set`, `!fft_mult`, `!fft_preset`) are saved into `config.json`.

Console commands (`who` = `host` (default), a party member's name or a GUID):

| Command | Does |
|---|---|
| `!fft_help` | list commands |
| `!fft_status [who]` / `!fft_party` | jobs, JP, slots / one line per party member |
| `!fft_board [who]` | open the Job Board window |
| `!fft_job <job> [who]` / `!fft_secondary <job\|none> [who]` | set primary / secondary |
| `!fft_learn <ability> [who]` / `!fft_equip <ability> [who]` / `!fft_unequip <reaction\|support\|movement> [who]` | learn / slot abilities |
| `!fft_addjp <amount> [job] [who]` | add JP (default: primary job) |
| `!fft_unlockall [who]` | unlock every implemented job (testing) |
| `!fft_preset <name>` / `!fft_mult <x>` / `!fft_set <key.path> <value>` / `!fft_config` | tuning |
| `!fft_reload` | reload `config.json` |
| `!fft_reset [who]` / `!fft_regrant [who]` / `!fft_uninstall` | reset a character / re-apply grants / remove all grants |
| `!fft_telemetry` | totals from the telemetry log |

## 13. Telemetry

`Script Extender\FFTJobs\telemetry.jsonl`, one JSON object per line, capped at `Telemetry.MaxLines`:
- `"t":"combat"`: id, rounds, start/finish clock, and per character: name, job, job level, character level, actions counted, JP by source (action, spillover, victory, shared), XP gained during the fight;
- `"t":"rest"`: per character since the previous long rest: XP gained, JP by source;
- `"t":"session"`: preset and multiplier at load.

`!fft_telemetry` prints the totals. These logs feed the pacing simulator's estimates later.

## 14. Pacing simulator and preset tables

`tools/pacing_sim.py` plays a whole party through a BG3 playthrough with the engine's formulas (it mirrors `Server/Rules.lua`; its self-test checks the same numbers as the Lua tests) and reports when jobs unlock and are mastered.

**Model.** Six tracked characters: four fighters in the active party and two companions in camp, each with a job plan (Fighter: Squire → Knight → Archer → Chemist → White Mage → Black Mage; Caster: Chemist → Black Mage → White Mage → …; Healer: Chemist → White Mage → …; Ranger: Squire → Archer → …). Everyone learns the cheapest affordable ability in any unlocked job after every fight and switches to the next job in the plan once the current one is mastered. No JP Boost unless `--jp-boost`. All JP sources of section 7.

**Estimates** (assumptions; replace them with telemetry once there is real play data):

| Estimate | Fights per act (1/2/3) | Counted casts per character per fight | Cumulative XP at end of act (1/2/3) | Long rests per act |
|---|---|---|---|---|
| LOW (story-focused, skips fights) | 30 / 20 / 30 | 4 | 9,000 / 40,000 / 85,000 (≈ L5 / L8 / L11) | 8 / 6 / 8 |
| TYPICAL | 45 / 30 / 45 | 6 | 18,000 / 55,000 / 100,000 (≈ L6 / L9 / L12) | 12 / 9 / 12 |
| HIGH (completionist) | 65 / 40 / 65 | 9 | 30,000 / 75,000 / 100,000 (≈ L7 / L10 / L12) | 16 / 12 / 16 |

Sources for the estimates: BG3 XP table (L12 = 100,000; Wargamer/Gamer Guides; eip.gg lists slightly lower L6-11 values), Larian's 80 combat encounters in Early Access (≈ Act 1), player reports of levels per act (Steam forums: about L7 after a full Act 1, L10-11 after Act 2, L12 early in Act 3). A quarter of the casts are assumed to be bonus actions.

**Presets** (everything else as in section 7: FFT formula `8 + 2 × job level + floor(level / 4)`, TIC +30% on own actions, spillover 1/4 also into locked jobs, JP Boost ×1.5, camp share 1/2, shared learning 15% into every other job):

| Preset | `Action.Multiplier` | `XPShare` | Victory | Long rest | Shared learning | Meant for |
|---|---|---|---|---|---|---|
| **Classic** (default) | 0.5 | 0.15 | 15 + 1 per level | 25 | 15% | the pacing target below |
| Fast | 0.8 | 0.24 | 25 + 2 per level | 40 | 15% | short runs, trying many jobs (≈1.65× Classic) |
| Grindy | 0.3 | 0.08 | 8 + 1 per level | 10 | 15% | FFT-like scarcity (≈0.55× Classic) |
| PureFFT | 1.0 | 0 | 0 | 0 (no camp share) | off | reference: FFT's own per-action JP only |

**Results** (`python3 tools/pacing_sim.py --markdown`). "Jobs mastered" counts the 6 MVP jobs; "JP vs full TIC tree" divides a fighter's total JP by the 17,600 JP that unlocking every one of the 20 TIC jobs needs (Squire and Chemist to Lv8, Knight/Archer/Time Mage/Mystic to Lv4, eight more jobs to Lv5), a forward look at when the other 14 jobs are added.

| Preset | Estimate | JP per fighter | Fighters' jobs mastered by end of Act 1 / 2 / 3 | Camp members' jobs mastered | First mastery | JP vs full TIC tree unlock need |
|---|---|---|---|---|---|---|
| Classic | LOW | 36,822 | 1 / 3 / 6 | 5-5 | A1.13 | 2.1x |
| Classic | TYPICAL | 57,834 | 1-2 / 6 / 6 | 6-6 | A1.10 | 3.3x |
| Classic | HIGH | 91,346 | 5-6 / 6 / 6 | 6-6 | A1.8 | 5.2x |
| Fast | LOW | 60,146 | 1-2 / 5-6 / 6 | 6-6 | A1.9 | 3.4x |
| Fast | TYPICAL | 94,580 | 4-5 / 6 / 6 | 6-6 | A1.7 | 5.4x |
| Fast | HIGH | 149,088 | 6 / 6 / 6 | 6-6 | A1.5 | 8.5x |
| Grindy | LOW | 20,185 | 0-1 / 1-2 / 3-4 | 2-3 | A1.23 | 1.1x |
| Grindy | TYPICAL | 32,239 | 1 / 3 / 6 | 4-4 | A1.17 | 1.8x |
| Grindy | HIGH | 52,329 | 2-3 / 6 / 6 | 5-6 | A1.14 | 3.0x |
| PureFFT | LOW | 12,763 | 0-1 / 1-2 / 1-2 | 0-0 | A1.17 | 0.7x |
| PureFFT | TYPICAL | 32,017 | 1-2 / 3-4 / 6 | 0-0 | A1.12 | 1.8x |
| PureFFT | HIGH | 74,437 | 5 / 6 / 6 | 0-0 | A1.8 | 4.2x |

**Shared learning** (2026-10-11) is the biggest single source in Classic: about 40% of the JP, spread over the other jobs. With only the 6 MVP jobs it makes the test fast: every fighter masters all six by the end of Act 3 even in LOW, and by the end of Act 2 in TYPICAL. Without it (`--set JP.Shared.Share=0`) Classic gave LOW 1 / 2-3 / 5, TYPICAL 1-2 / 4 / 6, HIGH 3-4 / 6 / 6. `AllJobs` shares into every job, so the effect grows as jobs are added: re-tune once the other 14 FFT jobs are in (`PartyJobs` or a lower `Share` are the first knobs; at 10% Classic gives LOW 1 / 2-3 / 6, TYPICAL 1-2 / 5 / 6).

**Why Classic looks like this.** FFT's own per-action JP (PureFFT) leaves a light BG3 playthrough with 1-2 mastered jobs and camp companions with none: BG3 has too few, finite fights. Classic halves action JP and adds an XP share, so progress follows BG3's own pacing (quests, exploration and skill checks give XP too) and the gap between a light and a completionist run shrinks from 5.8× to 2.5×. Where Classic's JP comes from (`--sources`):

| Estimate | Who | Action | Spillover | Victory | XP share | Camp share | Long rest | Shared learning | Total |
|---|---|---|---|---|---|---|---|---|---|
| LOW | fighter | 4,527 (12%) | 2,612 (7%) | 1,722 (5%) | 12,750 (35%) | 0 | 550 (1%) | 14,661 (40%) | 36,822 |
| LOW | camp | 0 | 0 | 0 | 12,750 (44%) | 3,124 (11%) | 550 (2%) | 12,318 (43%) | 28,743 |
| TYPICAL | fighter | 10,930 (19%) | 6,306 (11%) | 2,690 (5%) | 15,000 (26%) | 0 | 825 (1%) | 22,084 (38%) | 57,834 |
| TYPICAL | camp | 0 | 0 | 0 | 15,000 (38%) | 6,810 (17%) | 825 (2%) | 16,976 (43%) | 39,611 |
| HIGH | fighter | 24,187 (26%) | 13,954 (15%) | 3,937 (4%) | 15,000 (16%) | 0 | 1,100 (1%) | 33,168 (36%) | 91,346 |
| HIGH | camp | 0 | 0 | 0 | 15,000 (28%) | 14,062 (27%) | 1,100 (2%) | 22,621 (43%) | 52,783 |

With JP Boost equipped as soon as it is learned (`--jp-boost`), Classic gives 50,700 / 80,500 / 127,300 JP per fighter (LOW / TYPICAL / HIGH).

**When a typical player gets each job** (Classic, TYPICAL, `--detail TYPICAL`; "unlocked / **mastered**", A2.14 = Act 2, 14th fight of the act):

| Character | Squire | Chemist | Knight | Archer | White Mage | Black Mage | JP total |
|---|---|---|---|---|---|---|---|
| Fighter | start / **A1.10** | start / **A2.10** | A1.2 / **A1.27** | A1.2 / **A2.4** | A1.6 / **A2.18** | A1.6 / **A2.26** | 57,655 |
| Caster | start / **A2.3** | start / **A1.22** | A1.6 / **A2.16** | A1.6 / **A2.24** | A1.2 / **A2.13** | A1.2 / **A2.3** | 57,958 |
| Healer | start / **A2.2** | start / **A1.22** | A1.6 / **A2.16** | A1.6 / **A2.13** | A1.2 / **A2.1** | A1.2 / **A2.25** | 57,934 |
| Ranger | start / **A1.10** | start / **A2.4** | A1.2 / **A2.17** | A1.2 / **A1.39** | A1.6 / **A2.14** | A1.6 / **A2.26** | 57,788 |
| Camp A (camp) | start / **A1.15** | start / **A2.25** | A1.3 / **A1.38** | A1.3 / **A2.16** | A1.13 / **A3.8** | A1.13 / **A3.22** | 39,611 |
| Camp B (camp) | start / **A2.19** | start / **A1.33** | A1.13 / **A3.2** | A1.13 / **A3.18** | A1.3 / **A2.11** | A1.3 / **A2.27** | 39,611 |

**Retuning.** Change the numbers in game (`!fft_set JP.XPShare 0.2`, `!fft_mult 1.3`, `!fft_preset Fast`) or in `config.json`; try them first with `python3 tools/pacing_sim.py --set JP.XPShare=0.2`. The engine logs every fight and long rest to `telemetry.jsonl` (`!fft_telemetry` sums it up): real actions per fight, JP by source and XP per act can then replace the estimates above. When jobs are added, mastering the MVP six gets relatively easier; re-run the simulator and lower `Action.Multiplier`/`XPShare` if the tree should take longer.

## 15. Open questions and unverified items

Tracked in `STATUS.md` ("Unverified").
