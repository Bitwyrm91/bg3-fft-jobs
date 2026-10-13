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
| `Osi.<Name>(...)`, `Osi.DB_Players:Get(nil)` | Osiris calls/queries/DB reads | [Calling Osiris from Lua](https://github.com/Norbyte/bg3se/blob/main/Docs/API.md#calling-osiris-from-lua). The first draft used `DB_IsPlayer` (ExtIdeHelpers `OsiCommonDatabases`), which is nil in BG3 (seen in game 2026-10-12) |
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
| `Died(character)` | 1 | a boss's badge (special jobs) |
| `DialogActorJoined(dialog, instanceID, actor, speakerIndex)` / `DialogEnded(dialog, instanceID)` | 4 / 2 | a boss met in a dialog with a party member (spared-boss rule) |

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
| `DB_Players(guid)` (database, read with `:Get(nil)`) | rows | party discovery (with the `PartyMember` component, which found the whole party in the first game) |
| `DB_Defeated(guid)` (database of the vanilla story, `:Get(nil)`) | rows | bosses the story counts as defeated: dead, knocked out, surrendered, petrified, banished, iron-flasked (`__AAA_FirstGoal`); saved with the game |
| `GetRegion(object)` | level name | the act after a console `reset` |

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
- **Unlock**: a job unlocks when every requirement is met: `{job, level}` (a job level of that character), `{job, mastered}` (every ability of that job learned; War of the Lions' Dark Knight), `{kills}` (enemies that character defeated: `Kills`, counted on Osiris `KilledBy` for the party member or the owner of the summon that landed the blow, never for party members' deaths) or `{badge}` (a badge the party found, for the special jobs of phase 2). Squire and Chemist start unlocked (config). Unlocks are checked after every JP gain, after a job is mastered, after a kill, when a badge is found and on load. A job may give passives by its own job level while it is the main job (`levelGrants`: the highest tier reached; the Onion Knight's growth) and may rest every slot and the secondary while it is the main job (`noSlots`, `Rules.BlocksSlots`, config `Rules.OnionKnightBlocksSlots`). Jobs with a `group` (`WotL` for Dark Knight and Onion Knight) come from other FFT versions: the pacing target and `tools/check_fft_data.py` (TIC tables) leave them out.
- **Unlocks stay per character** (FFT and Fell Seal; the user's rule of 2026-10-12, "see it, wait for levels"): each character needs its own job levels to learn a job's abilities or take it as job or secondary. A job some member has unlocked is recorded in `Meta.PartyUnlocked` and shows on every Job Board as "Unlocked by the party; needs Squire Lv2 (has Lv1)"; JP from spillover and shared learning keeps collecting in it meanwhile. (The first build of phase 2 shared the unlocks themselves; the user asked for per-character levels.)
- **Badges** (phase 2): found once, they serve the whole party (the user's choice; Fell Seal uses one up per character, which would leave one character per boss). `Meta.Badges` in the save, copied into every character's `Badges` by `Rules.SyncParty`, members who join later included; each character still needs the special job's levels. Data: `badges` in `data/fft_jobs.json` (`id`, `name`, `description`), unlock entry `{"badge": "<id>"}`. Each special job's badge belongs to a BG3 boss (`docs/SPECIAL_JOBS.md`; data: `boss`, `act`, `characters` = the boss's level-character GUIDs from the vanilla level data, `spared`); `Server/Bosses.lua` gives it once when the story counts the boss as defeated (`DB_Defeated`, read on load and after every fight, so bosses beaten before the mod was installed count; `Died` gives it at once), when the boss joins the party (Minthara), or when the party reaches a later act (`levelActs`: level name -> act) after meeting the boss (it entered a fight, or spoke in a dialog with a party member: `Meta.BossMet`) and leaving it alive (`spared` `met`; `always` = met or not: Zhalk; the first act seen on a save only sets `Meta.Act`). Config `Badges.FromBosses` / `Badges.SparedBosses`; `!fft_badge list` shows each boss and whether its badge was found or the boss met; `!fft_badge <id>` for testing.
- **Starting job**: by BG3 class (config): Wizard, Sorcerer, Warlock, Cleric, Druid, Bard start as Chemist, everyone else as Squire.
- **Learning** an ability costs its JP from the unspent JP of the ability's job; the job must be unlocked. Out of combat only (config).
- **Mastered** = every implemented ability of the job learned.
- **Primary job**: any unlocked job, out of combat only (config). If it equals the secondary, the secondary is cleared.
- **Secondary skill set**: any unlocked job other than the primary; grants that job's learned action abilities.
- **Slots, Fell Seal style** (the user's choice, 2026-10-12): one **reaction** slot and two free **passive** slots (`Passive1`, `Passive2`), each taking any learned support or movement ability from any job (FFT had one support and one movement slot; saves from 1.0.0.5 move them into the passive slots on load, `Rules.Normalize`). Equip goes into the first free slot of the right kind; with both passive slots full the player names the slot to replace (Job Board "Replace 1/2", `!fft_equip <ability> 1|2`). An ability moves rather than sitting in two slots.
- **Main job's abilities always on** (Fell Seal rule, phase 2; `Rules.MainJobAlwaysOn`, default `["Support", "Movement"]`): learned abilities of those types from the primary job work without a slot, so the slots stay free for other jobs' abilities. Reactions need the reaction slot, as Fell Seal's counters do (the user's choice; adding `"Reaction"` to the list changes it). Equipping one anyway is allowed and harmless (granted once).
- **Main job's equipment** (Fell Seal rule, phase 2): the primary job's marker passive `FFTJ_Job_<Job>` carries `Proficiency()` boosts for the job's FFT equipment, from the job's `equip` list in the data (`{{prof:<Job>}}` in `stats_src`, BG3 names checked by `tools/build.py`; the passive's description lists them). FFT's "Equip X" supports carry one group to other jobs. Mapping (FFT → BG3): Squire daggers, swords, axes, flails, light armour; Chemist daggers, hand crossbows (guns), light armour; Knight swords, light/medium/heavy armour, shields; Archer bows, crossbows, light armour; White Mage quarterstaffs, light armour; Black Mage quarterstaffs, clubs (rods), light armour. Vanilla passives do the same (Dwarven Armour Training, Githyanki Martial Prodigy).
- **Mastery perk** (Fell Seal rule, phase 2; `Rules.MasteryPerks`, on): a mastered job grants its perk passive `FFTJ_Mastery_<Job>` for good; perks stack and stay after changing jobs. Small and themed: Squire +5 max HP, Chemist poison resistance, Knight +1 Constitution saves, Archer +1 ranged weapon attack rolls (the user's "+1 m range" has no BG3 boost), White Mage +1 Wisdom saves, Black Mage +1 spell attack rolls. Data: the job's `mastery` (`passives`, `description`; keep the description in step with the passive's `Boosts`).
- **Granted** = learned actions of primary and secondary job + the three slotted abilities + the main job's always-on abilities + the job's innate passive (`FFTJ_Job_<Job>`: the current job on the character sheet and its equipment proficiencies) + every earned mastery perk + the Job Board spell. Everything else the mod granted is removed. Before granting, the engine checks `HasSpell`/`HasPassive`/`HasActiveStatus`: if the character already has it from elsewhere it is not marked as ours and never removed.
- **Variants**: an ability can grant a different spell when a condition holds. Chemist items grant a short-range spell normally and a thrown 9 m spell when Chemist is the primary job or Throw Items is the equipped support (FFT: Chemists throw items, other jobs need Throw Items).
- **JP Boost**: the active support (equipped, or always on through the main job) with `"effect": "JPBoost"` multiplies the character's own JP.
- JP goes to the **primary job**, also for actions from the secondary skill set (FFT rule).
- **Shared learning** (from Fell Seal: Arbiter's Mark, added at the user's request on 2026-10-11): 15% of every JP gain a character makes also goes into each of that character's other jobs that the party used in combat, locked ones included. During a fight these are the jobs of everyone in it; for gains outside a fight (quest XP, long rests, camp share) they are the jobs of the party's latest fight, saved in the state. This is Fell Seal's rule, where every unit gets 15% of a battle's AP in each class used in it. `Scope` `AllJobs` shares into every job instead. Shared JP counts toward job levels, so it can unlock jobs. Spillover, console JP and shared JP itself are not shared again.

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
| Shared learning | every gain above except spillover (per source: `Shared.Sources`), into each of the character's **other** jobs used in combat: the jobs of everyone in the current fight, or outside a fight those of the party's latest fight (`Scope` `FightJobs`, default), or every job (`AllJobs`); `RequireUnlocked` limits it to unlocked jobs | `gain × Shared.Share` (the gain already includes B and G) | Fell Seal: Arbiter's Mark's vicarious learning (15% into each class used in the battle) |

Fractions are kept per job (`frac`) so small amounts are not lost to rounding. `Action.MaxPerTurn` (0 = off) caps action JP per turn.

**XP detection**: Osiris has no XP event, so the engine polls `Ext.Entity.Get(guid).Experience.TotalExperience` every `XPPollMs` (game clock) and right after combat ends and level-ups. The first reading only sets a baseline (no retroactive JP; `!fft_addjp` can top up a save the mod was added to).

## 8. FFT abilities as BG3 spells, passives, statuses

Stats drafts: `stats_src/*.txt` (templates; the build fills in localization handles) → `Mod/Public/FFTJobs/Stats/Generated/Data/*.txt`. Naming: spells `Target_FFTJ_*`, `Projectile_FFTJ_*`, `Shout_FFTJ_*`, `Zone_FFTJ_*`; passives `FFTJ_*`; statuses `FFTJ_*` (upper case).

Design choices:
- **Class-independent costs.** BG3 casting runs on spell slots, which martial classes do not have, so FFT abilities cost an action or bonus action plus a cooldown instead of MP: cheap abilities have no cooldown or `OncePerTurn`, mid tiers `OncePerShortRest`, top tiers `OncePerRest`. An FFT-style MP resource is possible later (custom `ActionResourceDefinition`).
- **No spellcasting-ability dependence** where possible: magic is auto-hit or uses a saving throw, because the ability modifier used by spells added with `AddSpell` to non-casters is unverified (Part B checks; the alternative is a passive with `UnlockSpell(...,Intelligence)`).
- **Reuse vanilla** through `using` where BG3 has a close match: weapon attacks (`Target_MainHandAttack`, `Projectile_MainHandAttack`) for Knight rends and Archer aims, `Target_CureWounds`, `Target_Revivify`, `Target_DeathWard`, `Projectile_FireBolt`, `Projectile_Fireball` and similar for magic.
- **The look comes from the `using` parent** (its `SpellAnimation`, `PrepareEffect`, `CastEffect`, `Trajectories` = the projectile, `HitEffect`/`TargetEffect`/`PositionEffect` = the impact, sounds); the values are effect resource IDs, so looks are borrowed, never written. 1.0.0.5 (user's report: every area spell exploded like Fireball, Throw Stone flew like Fire Bolt) matched each spell to its element: Throw Stone = the goblins' rock throw (`Projectile_FOR_GnomeGoblin_ThrowRock`), Fira/Firaga = Fireball, Thunder = Chromatic Orb (lightning), Thundara/Thundaga = Call Lightning's bolt from the sky (`Target_CallLightning_LightningBolt`, so they became `Target_` spells), Blizzard = Ray of Frost, Blizzara = Ice Knife, Blizzaga = Ice Storm (`Target_`), Poison = Chromatic Orb (poison), Death = Blight (`Target_`; undead and constructs cannot be targeted), Flare = Disintegrate's beam, Holy = Guiding Bolt. A parent also lends mechanics, so every entry sets its own numbers and clears what does not fit (found while doing this: Fireball's "ignite the ground" on the cold/lightning areas and on Throw Stone, Fire Bolt's `IsSpell` on Throw Stone, Fireball's `ExplodeRadius` 4 on the 3 m areas, Ice Storm's 6 m ice sheet, Call Lightning's NPC `RechargeValues` and `Temporary` flag, Disintegrate's `DeathType`). **To change a look:** pick a vanilla spell of the same `SpellType` (`python tools/vanilla_spell.py <extracted-root> --find lightning`, then `... <SpellName> --visual` for its look fields and without `--visual` for what else it would lend), put it in the entry's `using` line in `stats_src/Spell_FFTJ.txt`, override what does not fit, then build, package and install.
- Support/movement abilities are passives with static boosts (proficiencies, AC, movement, jump distance, roll bonuses). Reactions are passives with an `OnDamaged` functor (BG3 interrupts would be the faithful version; left for later).

The per-ability BG3 effect is described in each ability's `description` in `data/fft_jobs.json`.

**Icons (1.0.0.4).** Until then every entry borrowed its parent's vanilla icon, so in the first real game the user could not tell the learned abilities from vanilla actions (Focus had the Job Board's icon). Now each ability, job and the two utility spells have their own painted icon, made on the user's GPU (`tools/generate_icon_art.ps1`: stable-diffusion.cpp + Z-Image-Turbo, the setup of the user's Divinity mods; one subject per line in `art/icons/subjects.txt`, a background colour per job: Squire amber, Chemist mossy green, Knight royal blue, Archer forest green, White Mage pale gold, Black Mage deep indigo). `tools/build.py` gives every stats entry the icon `FFTJ_Icon_<key>` when `art/icons/<key>.jpg` (or `.png`) exists: the key is the ability that grants the entry (variants included), `Job_<JobId>` for job marker passives, `JobBoard`, `JPTraining`; a status takes the key of the first ability (data order) whose entries apply it. Entries without a picture keep their vanilla icon. The files mirror what vanilla ships for one spell icon (checked in `Icons.pak`/`Game.pak`/`Shared.pak`):

| File | Vanilla example | Ours |
|---|---|---|
| Atlas UV list | `Public/SharedDev/GUI/Icons_Skills.lsx` (2048 px, 64 px cells, UVs half a pixel inside each cell) | `Public/FFTJobs/GUI/Icons_FFTJobs.lsx` (1024 px, 64 px cells), generated by build.py |
| Atlas texture | `Public/SharedDev/Assets/Textures/Icons/Icons_Skills.dds`; `Icons_Items_Dev.dds` is 1024 px DXT5 with 11 mips | `Public/FFTJobs/Assets/Textures/Icons/Icons_FFTJobs.dds`, DXT5 + mips (same size in bytes as `Icons_Items_Dev.dds`) |
| Texture resource | `Public/SharedDev/Content/UI/[PAK]_UI/_merged.lsf`, `TextureBank` resource (ID = the atlas UUID, `Type 1`, `SRGB False`, `Streaming True`) | same path, generated as `.lsx` by build.py, converted to `.lsf` by package.ps1 |
| Tooltip picture | `Public/Game/GUI/Assets/Tooltips/Icons/<icon>.DDS`, 380 px, BC7 under a DX10 header | same path, 380 px, BC3 under a DX10 header (nvdxt cannot write BC7); upper-case `.DDS` (the lookup is case-sensitive) |
| Controller picture | `.../Assets/ControllerUIIcons/skills_png/<icon>.DDS`, 144 px | same |
| Low-res copies | `.../AssetsLowRes/Tooltips/Icons/` 192 px, `.../AssetsLowRes/ControllerUIIcons/skills_png/` 72 px | same |

`tools/make_icons.ps1` (Windows: System.Drawing + nvdxt from the Divinity Engine 2) builds the textures into the package stage from `art/icons` and the atlas layout. Prompt lessons: "jewel-tone colours" made the model scatter gems around the subject and "small ..." gave a grid of tiny pictures; describe one large subject. Adding an ability later: add its `key|subject` line, run `tools/generate_icon_art.ps1` (only missing pictures are made), review with `tools/icon_sheet.ps1`, then build and package.

## 9. Persistence

One mod variable, `State`, registered with `Ext.Vars.RegisterModVariable(ModuleUUID, "State", {Server=true, Client=false, Persistent=true, SyncToClient=false})` on both server and client at bootstrap (the doc recommends registering on both sides with the same settings). PersistentVars are deprecated per the doc and not used.

- In memory the engine owns a plain Lua table; after every change it writes `vars.State = state` (coalesced to once per tick). Writes to sub-tables do not mark a variable dirty, so the whole table is reassigned.
- The state is read once per Lua session, after `SessionLoaded`. Events that arrive earlier are ignored, so an empty state never overwrites a saved one.
- Schema (`schema = 1`): `chars[uuid] = {name, primary, secondary, reaction, support, movement, unlocked{job=true}, jobs[job] = {earned, unspent, frac, learned{ability=true}}, granted = {spells{}, passives{}, statuses{}}, lastXP, stats{...}}`. Keys are the 36-character UUID part of Osiris GUID strings. `meta = {Disabled, LastFightJobs}`: the uninstall flag and the jobs used in the latest fight (for shared learning).
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
  Public/FFTJobs/GUI/Icons_FFTJobs.lsx      icon atlas layout (generated)
  Public/FFTJobs/Content/UI/[PAK]_UI/_merged.lsx   atlas texture resource (generated; packaged as .lsf)
  Localization/English/FFTJobs.xml          (generated; package.ps1 converts it to FFTJobs.loca)
art/icons/   subjects.txt (one prompt per icon) and the 380 px pictures <key>.jpg   <- section 8, Icons
data/        fft_jobs.json, config_defaults.json, strings.json   <- edit these
stats_src/   stats templates with {{name:...}} / {{desc:...}} / {{str:...}} placeholders
tools/       build.py, pacing_sim.py, validate_vanilla.py, run_tests.sh, run_tests.ps1, package.ps1, install.ps1,
             generate_icon_art.ps1, icon_sheet.ps1, make_icons.ps1 (icon textures, run by package.ps1)
tests/       Lua 5.4 tests with mock Ext/Osi
```

`python3 tools/build.py` regenerates the Lua data module, the stats files, the localization XML and `docs/vanilla_refs.md` from `data/` and `stats_src/`, and checks that every ID the data grants exists in the stats. `--check` fails if the committed generated files are stale (run by the test script). Adding a job: add it to `data/fft_jobs.json` (set `implemented`), add its abilities and stats entries, run the build and the tests.

Localization handles are derived from the mod UUID and the string key (UUID v5), so they never change between builds.

## 11. UI

- **Job Board window** (SE IMGUI, client): opened by casting the **Job Board** spell (`Shout_FFTJ_JobBoard`, granted to every tracked character, free) or with `!fft_board`. One row of buttons per party member; for the selected character: current job and slots, a jobs table (level, JP, unlock requirements, set primary/secondary) and the selected job's abilities (cost, learn, equip/unequip). Every button sends a request to the server over a NetChannel; the server applies the rules and replies with the new view.
- **Console commands** (section 12) do everything the window does, plus tuning.
- **JP Training (test)** spell (`Shout_FFTJ_JPTraining`, free, granted while config `Test.Tools` is true; added 2026-10-12 for the playtest): every tracked party member gets `Test.JPPerCast` (1,000) JP in each job unlocked before the cast, as source `Test` (never shared, not in combat telemetry). Level-up and unlock notices only go to the console; the caster gets one summary notification. `!fft_train [amount]` does the same.
- **Ability status on the board** (1.0.0.3, after the first game: the user learned Squire abilities and could not find them): each learned ability says whether it is in use: actions "Learned, in the spells" while their job is the primary or secondary, otherwise "make this job the job or secondary"; reaction/support/movement "equip it to use it". The Learn, Set job and Secondary messages say the same.
- **Playtest log** (1.0.0.3): every Job Board click's result (`Job Board: ...`) and every grant change (`<name>: added ...; removed ...`) is logged, so the SE runtime log shows what the player did and what the game was given. `!fft_grants [who]` lists what the jobs should grant now and whether the game reports it (`HasSpell`/`HasPassive`/`HasActiveStatus`).

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
| `!fft_learn <ability> [who]` / `!fft_equip <ability> [1\|2] [who]` / `!fft_unequip <reaction\|1\|2> [who]` | learn / slot abilities (1 and 2 = the passive slots) |
| `!fft_addjp <amount> [job] [who]` | add JP (default: primary job) |
| `!fft_unlockall [who]` | unlock every implemented job for one character (testing) |
| `!fft_badge <badge\|list>` | give the party a badge (testing; special jobs need one plus job levels) |
| `!fft_train [amount]` | JP Training: every party member gets JP in each unlocked job (testing) |
| `!fft_grants [who]` | what the jobs grant now and whether the game has it (debugging) |
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

**Model.** Six tracked characters: four fighters in the active party and two companions in camp, each with a plan of all 20 jobs along the unlock tree (Fighter: Squire → Knight → Monk → Archer → Thief → Geomancer → Dragoon → Samurai → Ninja → Dancer → the mage jobs; Caster: Chemist → Black Mage → White Mage → Time Mage → Mystic → Summoner → Orator → Arithmetician → Bard → the physical jobs; Healer: Chemist → White Mage → Mystic → Orator → **Mime** → …, the party member who chases FFT's last job; Ranger: Squire → Archer → Thief → Dragoon → …; the camp companions have mixed plans). A character masters the jobs of its plan in order; when the next one is still locked it first levels the missing prerequisite, as FFT players do (Mime sends the Healer to Squire Lv8, Geomancer Lv5, Dragoon Lv5, …). Everyone learns the cheapest affordable ability in every unlocked job after each fight. A job without abilities (Mime) counts as mastered at job level 8, as in the engine. Implemented jobs missing from a plan (new ones) go to its end. Badges are assumed found. No JP Boost unless `--jp-boost`. All JP sources of section 7.

**Estimates** (assumptions; replace them with telemetry once there is real play data):

| Estimate | Fights per act (1/2/3) | Counted casts per character per fight | Cumulative XP at end of act (1/2/3) | Long rests per act |
|---|---|---|---|---|
| LOW (story-focused, skips fights) | 30 / 20 / 30 | 4 | 9,000 / 40,000 / 85,000 (≈ L5 / L8 / L11) | 8 / 6 / 8 |
| TYPICAL | 45 / 30 / 45 | 6 | 18,000 / 55,000 / 100,000 (≈ L6 / L9 / L12) | 12 / 9 / 12 |
| HIGH (completionist) | 65 / 40 / 65 | 9 | 30,000 / 75,000 / 100,000 (≈ L7 / L10 / L12) | 16 / 12 / 16 |

Sources for the estimates: BG3 XP table (L12 = 100,000; Wargamer/Gamer Guides; eip.gg lists slightly lower L6-11 values), Larian's 80 combat encounters in Early Access (≈ Act 1), player reports of levels per act (Steam forums: about L7 after a full Act 1, L10-11 after Act 2, L12 early in Act 3). A quarter of the casts are assumed to be bonus actions.

**Pacing target** (user, 2026-10-12, for the 20 TIC jobs): a TYPICAL playthrough opens every job in the party by Act 3 (unlocks are per character; the party sees them) and each fighter masters about half of the jobs. `--selftest` checks it with the default preset: TYPICAL, every job open by the end of Act 3 and every fighter at 8+ of 20 mastered; LOW, every fighter at 5+.

**Presets** (everything else as in section 7: FFT formula `8 + 2 × job level + floor(level / 4)`, TIC +30% on own actions, spillover 1/4 also into locked jobs, JP Boost ×1.5, camp share 1/2, shared learning 15% into the other jobs used in combat):

| Preset | `Action.Multiplier` | `XPShare` | Victory | Long rest | Shared learning | Meant for |
|---|---|---|---|---|---|---|
| **Classic** (default) | 0.8 | 0.24 | 25 + 2 per level | 40 | 15% | the pacing target above |
| Fast | 1.3 | 0.4 | 40 + 3 per level | 65 | 15% | short runs, trying many jobs (≈1.6× Classic) |
| Grindy | 0.45 | 0.13 | 14 + 1 per level | 20 | 15% | FFT-like scarcity (≈0.55× Classic) |
| PureFFT | 1.0 | 0 | 0 | 0 (no camp share) | off | reference: FFT's own per-action JP only |

Retuned on 2026-10-13 for the 20 jobs (98,220 JP to master them all; Time Mage 10,670, Summoner 9,200, Dragoon 9,150 and Samurai 8,000 cost the most). The old Classic (0.5 / 0.15 / 15 + 1 per level / 25), tuned for the 6 MVP jobs, gave a TYPICAL fighter 5-7 mastered jobs and never opened Mime; the new Classic is the old Fast, and Fast and Grindy were rescaled around it.

**Results** (`python3 tools/pacing_sim.py --markdown`). Spans are the lowest and highest of the four fighters. "Every job open in the party" is the fight after which each of the 20 jobs is unlocked for at least one party member (A2.25 = Act 2, 25th fight of the act; "never" = not within the playthrough).

| Preset | Estimate | JP per fighter | Jobs mastered per fighter, end of Act 1 / 2 / 3 | Jobs unlocked per fighter, end of Act 1 / 2 / 3 | Every job open in the party | Camp members' jobs mastered | First mastery |
|---|---|---|---|---|---|---|---|
| Classic | LOW | 48,378 | 1-2 / 3-4 / 5-7 | 10-11 / 14-15 / 17-20 | A3.16 | 4-7 | A1.9 |
| Classic | TYPICAL | 75,357 | 2-3 / 4-6 / 8-11 | 13-14 / 17-20 / 19-20 | A2.25 | 7-9 | A1.7 |
| Classic | HIGH | 116,741 | 4-6 / 7-11 / 17-18 | 17-18 / 19-20 / 19-20 | A2.2 | 10-11 | A1.5 |
| Fast | LOW | 80,199 | 2 / 4-6 / 9-12 | 11-12 / 17-20 / 19-20 | A2.19 | 9-10 | A1.6 |
| Fast | TYPICAL | 121,498 | 3-5 / 7-10 / 18-19 | 17-18 / 19-20 / 19-20 | A2.6 | 13 | A1.4 |
| Fast | HIGH | 185,365 | 6-8 / 17-19 / 20 | 19-20 / 19-20 / 20 | A1.44 | 18 | A1.4 |
| Grindy | LOW | 25,899 | 0-1 / 2 / 3-4 | 6-7 / 11-12 / 14-15 | never | 3-4 | A1.15 |
| Grindy | TYPICAL | 40,700 | 1-2 / 3-4 / 4-6 | 10-11 / 13-16 / 17-20 | A3.37 | 4-5 | A1.12 |
| Grindy | HIGH | 64,356 | 2-3 / 4-6 / 6-9 | 13-14 / 17-20 / 19-20 | A2.37 | 4-7 | A1.9 |
| PureFFT | LOW | 12,296 | 0-1 / 1-2 / 1-2 | 6-7 / 8-9 / 10-11 | never | 0 | A1.17 |
| PureFFT | TYPICAL | 30,178 | 1-2 / 2-3 / 3-5 | 10-11 / 13 / 14-16 | never | 0 | A1.12 |
| PureFFT | HIGH | 67,241 | 3-4 / 4-6 / 7-10 | 14-15 / 15-18 / 19-20 | A2.35 | 0 | A1.8 |

**Shared learning** (2026-10-11) now gives a fighter about 26% of its JP (TYPICAL), spread over the jobs the party uses (the model's fighters use four different jobs and route through prerequisites). Without it (`--set JP.Shared.Share=0`) Classic's fighters master LOW 1-2 / 3-4 / 5-6, TYPICAL 2-3 / 4-6 / 7-10, HIGH 3-6 / 7-10 / 14 jobs by the end of Act 1 / 2 / 3; with `Scope` `AllJobs` (every job gets 15%) LOW 1-2 / 3-6 / 16-18, TYPICAL 3-4 / 14-15 / 20, HIGH 10-12 / 20 / 20.

**Why Classic looks like this.** FFT's own per-action JP (PureFFT) leaves a TYPICAL BG3 playthrough with 1-2 / 2-3 / 3-5 mastered jobs per fighter (end of Act 1 / 2 / 3) and camp companions with none: BG3 has too few, finite fights. Classic scales action JP to 0.8 and adds an XP share (about 32% of a typical fighter's JP), so progress follows BG3's own pacing (quests, exploration and skill checks give XP too) and the gap between a light and a completionist run shrinks from 5.5× (PureFFT) to 2.4×. Where Classic's JP comes from (`--sources`):

| Estimate | Who | Action | Spill | Victory | XP | Camp | Rest | Shared | Total |
|---|---|---|---|---|---|---|---|---|---|
| LOW | fighter | 6,822 (14%) | 3,936 (8%) | 3,044 (6%) | 20,400 (42%) | 0 (0%) | 880 (2%) | 13,296 (27%) | 48,378 |
| LOW | camp | 0 (0%) | 0 (0%) | 0 (0%) | 20,400 (51%) | 4,933 (12%) | 880 (2%) | 14,048 (35%) | 40,261 |
| TYPICAL | fighter | 16,233 (22%) | 9,365 (12%) | 4,780 (6%) | 24,000 (32%) | 0 (0%) | 1,320 (2%) | 19,659 (26%) | 75,357 |
| TYPICAL | camp | 0 (0%) | 0 (0%) | 0 (0%) | 24,000 (44%) | 10,507 (19%) | 1,320 (2%) | 19,037 (35%) | 54,864 |
| HIGH | fighter | 36,204 (31%) | 20,887 (18%) | 7,024 (6%) | 24,000 (21%) | 0 (0%) | 1,760 (2%) | 26,866 (23%) | 116,741 |
| HIGH | camp | 0 (0%) | 0 (0%) | 0 (0%) | 24,000 (34%) | 21,614 (30%) | 1,760 (2%) | 23,497 (33%) | 70,871 |

With JP Boost equipped as soon as it is learned (`--jp-boost`), Classic gives 60,786 / 94,653 / 149,813 JP per fighter (LOW / TYPICAL / HIGH).

**When a typical player gets each job** (Classic, TYPICAL, `--detail TYPICAL --markdown`; "unlocked / **mastered**"):

| Job | Fighter | Caster | Healer | Ranger | Camp A (camp) | Camp B (camp) |
|---|---|---|---|---|---|---|
| Squire | start / **A1.7** | start / - | start / **A2.18** | start / **A1.7** | start / **A1.9** | start / **A3.26** |
| Chemist | start / **A3.43** | start / **A1.14** | start / **A1.14** | start / **A2.25** | start / **A3.3** | start / **A1.21** |
| Knight | A1.2 / **A1.19** | A1.4 / - | A1.4 / - | A1.2 / **A2.30** | A1.2 / **A1.25** | A2.16 / **A3.33** |
| Archer | A1.2 / **A2.5** | A1.4 / - | A1.4 / - | A1.2 / **A1.27** | A1.2 / **A2.3** | A2.16 / - |
| White Mage | A1.4 / - | A1.2 / **A2.1** | A1.2 / **A1.32** | A1.4 / **A3.40** | A1.9 / **A3.42** | A1.2 / **A1.45** |
| Black Mage | A1.4 / - | A1.2 / **A1.34** | A1.2 / **A3.11** | A1.4 / - | A1.9 / - | A1.2 / **A2.12** |
| Monk | A1.9 / **A1.39** | A1.14 / - | A1.14 / - | A1.15 / **A3.10** | A1.12 / **A2.15** | A2.27 / - |
| Thief | A1.15 / **A2.12** | A1.14 / - | A1.14 / - | A1.9 / **A1.44** | A1.22 / **A2.25** | A1.22 / - |
| Time Mage | A1.21 / - | A1.16 / **A2.23** | A1.22 / **A3.30** | A1.21 / - | A1.29 / - | A1.29 / **A3.23** |
| Mystic | A1.21 / - | A1.22 / **A3.3** | A1.16 / **A2.6** | A1.21 / - | A1.29 / - | A1.23 / **A2.26** |
| Geomancer | A1.23 / **A2.19** | A1.31 / - | A1.31 / - | A1.31 / **A3.15** | A2.4 / **A3.10** | A3.3 / - |
| Dragoon | A1.38 / **A3.4** | A1.38 / - | A1.39 / - | A1.31 / **A2.19** | A2.9 / **A3.31** | A2.9 / - |
| Summoner | A2.6 / - | A2.2 / **A3.24** | A2.6 / **A3.43** | A2.6 / - | A2.8 / - | A2.8 / - |
| Orator | A1.39 / - | A1.39 / **A3.31** | A1.34 / **A2.15** | A1.39 / - | A2.1 / - | A2.1 / - |
| Samurai | A2.2 / **A3.23** | A2.2 / - | A2.2 / - | A1.45 / - | A2.5 / - | - / - |
| Ninja | A2.13 / **A3.31** | A2.15 / - | A2.15 / - | A2.15 / **A3.25** | A2.16 / - | - / - |
| Arithmetician | A2.9 / - | A2.3 / **A3.41** | A2.9 / - | A2.9 / - | A3.42 / - | A2.13 / - |
| Bard | A3.27 / - | A3.25 / - | A2.24 / - | A3.27 / - | - / - | - / - |
| Dancer | A2.15 / **A3.38** | A3.14 / - | A2.25 / - | A3.11 / **A3.34** | A3.5 / - | - / - |
| Mime | - / - | - / - | A2.25 / **A3.2** | - / - | - / - | - / - |
| Jobs mastered | 11 | 8 | 9 | 11 | 9 | 7 |
| JP total | 75,359 | 75,702 | 75,319 | 75,051 | 55,108 | 54,620 |

**Retuning.** Change the numbers in game (`!fft_set JP.XPShare 0.2`, `!fft_mult 1.3`, `!fft_preset Fast`) or in `config.json`; try them first with `python3 tools/pacing_sim.py --set JP.XPShare=0.2`. The engine logs every fight and long rest to `telemetry.jsonl` (`!fft_telemetry` sums it up): real actions per fight, JP by source and XP per act can then replace the estimates above. New jobs (Dark Knight, Onion Knight, the special jobs) join the end of every plan automatically; re-run `--selftest` and these tables after adding them.

## 15. Open questions and unverified items

Tracked in `STATUS.md` ("Unverified").
