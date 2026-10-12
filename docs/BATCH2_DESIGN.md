# Phase 2, batch 2: design notes for the next session

Done: **Dragoon** (v1.0.0.10). Left: **Summoner**, **Orator**, **Geomancer**. The user's decisions are in `docs/PHASE2.md`
(item 7, "Batch 2"). Build each job like batch 1 (`STATUS.md`): costs from the TIC game table (all match the RPGSite
lists below), effects from the game's `Ability-en` descriptions, vanilla parents, tests, build, validate, install only
with BG3 closed, commit after each job, no GPU image generation without asking.

## Summoner (designed 2026-10-12, not built)

Espers **spare allies** (user): damage espers use `TargetConditions "Enemy() and not Dead()"` (a Target spell's
TargetConditions filter every creature in its area, as vanilla Sculpt Spells shows on Flame Strike); heal/buff espers
target allies only. Range 18 m. Magick: Constitution/Dexterity saves against `SourceSpellDC()`, half damage on a save.

| Esper (JP) | BG3 effect | Parent (look) | Cooldown |
|---|---|---|---|
| Moogle (110) | up to 4 allies regain 2d8 HP | Target_CureWounds_Mass | short rest |
| Shiva (200) | enemies within 3 m: 4d6 cold | Target_IceStorm | short rest |
| Ramuh (200) | enemies within 3 m: 4d6 lightning | Target_CallLightning_LightningBolt | short rest |
| Ifrit (200) | enemies within 3 m: 4d6 fire | Target_FlameStrike (no ignite) | short rest |
| Titan (220) | enemies within 3 m: 4d6 bludgeoning, prone on a failed save | Target_Shatter | short rest |
| Golem (500) | allies within 6 m of you gain 15 temporary HP (FFT: blocks physical damage) | Shout_Aid | long rest |
| Carbuncle (350) | allies within 6 m gain Reflect (FFTJ_REFLECT) for 3 turns | Shout_Aid | long rest |
| Bahamut (1000) | enemies within 5 m: 8d8 force | Target_Shatter | long rest |
| Odin (900) | enemies within 4 m: 6d10 slashing | Target_Shatter | long rest |
| Leviathan (860) | enemies within 5 m: 5d8 bludgeoning + WET (vanilla) | Target_IceStorm | long rest |
| Salamander (860) | enemies within 5 m: 6d8 fire | Target_FlameStrike | long rest |
| Sylph (400) | enemies within 3 m: 3d6 thunder + Silenced 2 turns on a failed Con save | Target_Shatter | short rest |
| Faerie (400) | up to 6 allies regain 4d8 HP | Target_CureWounds_Mass | short rest |
| Lich (600) | enemies within 4 m: 4d10 necrotic | Target_Blight | long rest |
| Cyclops (1000) | enemies within 5 m: 7d10 bludgeoning | Target_Shatter | long rest |

- Critical: Recover MP (400, reaction): at 20% HP or less after damage, regain all level 1 spell slots
  (`RestoreResource(SELF,SpellSlot,100%,1)`, vanilla form), once per long rest.
- Halve MP (1000, support): FFT halves MP costs; here: after a short rest, regain one level 1 and one level 2 spell slot
  (`StatsFunctorContext "OnShortRest"`, vanilla context).
- Job: equip Rod/Staff → quarterstaffs, clubs, light armour (TIC help text). Mastery: +1 to Intelligence and Charisma
  saving throws. Unlock: Time Mage Lv3. Emblem exists (Job_Summoner).
- Check before writing: Target_Shatter / Target_IceStorm / Target_FlameStrike lend IsConcentration? (Ice Storm and
  Flame Strike no; check Shatter), their surfaces (clear SpellProperties), `AoEConditions` where present (Black Hole).

## Orator (user: Entice = the enemy fights for you on its own for 2 turns; bosses immune)

Research first: a vanilla status that switches a creature to the caster's side under AI control for N turns
(candidates: DOMINATE_PERSON / Dominate Beast statuses, "Command", MADNESS-style AiArchetypeOverride, faction-change
boosts). Talk skills (Praise/Intimidate = bravery, Preach/Enlighten = faith, Condemn = Doom, Insult = berserk, Mimic
Darlavon = sleep, Stall = delay, Defraud = steal gil?) map to existing statuses (FFTJ_FAITH, FFTJ_BERSERK, FFTJ_DOOM,
SLEEP, ...). Beast Tongue is innate (TIC help text). Equip: dagger, gun (hand crossbows), clothing/robe.

## Geomancer (user: terrain decides)

Research first: BG3 surface conditions usable in `RequirementConditions` (e.g. whether the caster stands in water,
fire, ice, mud, grease, webs: look for conditions like `InSurface(...)` or `HasStatus('WET')`-style checks in vanilla
spells), and a plain-ground fallback (Tremor/Sinkhole/Wind Slash?). Twelve abilities at 150 JP each; reaction
Nature's Wrath 300, support Attack Boost 400, movement Ignore Terrain 220 and Lavawalking 150.
