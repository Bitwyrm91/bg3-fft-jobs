# NWP: Fell Seal Samurai and Assassin (source data)

Pasted by the user on 2026-10-13 from fellseal.fandom.com (Samurai, Assassin), condensed. Use this instead of fetching
the wiki (Fandom blocks WebFetch). Fell Seal numbers: AP = JP-like cost, MP cost, multipliers of ATK/MND. BG3 mapping
still to design (STATUS.md "NWP" items 1-2; ask the user first).

## Samurai (Fell Seal) — skill set "Martial Spirit"

Requirements: Knight 5, Ranger 4, mission "Assassin!" (DLC). Move 4, Jump 4. Equipment: sword, shield, heavy armour.
Starting ability: Overreach. Passives: Unbreakable Spirit, Razor Wind. Counter: Critical: Focus.
Mastery bonus: ATK +5, SPD +2, Crit +2. Theme: draws strength from its own debuffs.

| Ability | AP | MP | Range / area | Kind | Effect |
|---|---|---|---|---|---|
| Overreach | 0 | 6 | weapon | skill | 1.2x ATK physical; DEF Down on self; counts as a regular attack (weapon element/debuffs) |
| Unbreakable Spirit | 150 | | | passive | each debuff on self: +10% ATK and MND |
| Spirit Bow | 175 | 6 | 1-5, vert 20 | skill | 0.5x MND physical; target turns to face you; DEF Down + RES Down on target |
| Meditate | 150 | 8 | self | spell | removes all own debuffs, heals 0.6x MND per debuff removed; EVA 0 until next turn |
| Wind Spirit | 200 | 8 | self, cross 5 | skill | 0.35x ATK physical around you; targets turn to face you; Cripple |
| Razor Wind | 250 | | | passive | +6 MP: a single-target skill with range >= 1 works at range 4 (vert 12) |
| Restless Spirit | 200 | 6 | 1, vert 3 | skill | 0.7x ATK physical ignoring defence; RES Down on self |
| Critical: Focus | 200 | | | counter | when HP goes critical: Focus, Defend, half damage until next turn |
| Adrenaline | 250 | 4 | weapon | skill | 0.5x ATK; Bleed on self; regular attack; next turn comes 50% sooner |
| Finisher | 350 | 20 | weapon | skill | 2.4x ATK; ATK Down on self; regular attack |
| Spirit Sword | 300 | 14 | 1, vert 4 | skill | 2.6x MND physical; MND Down on self |

## Assassin (Fell Seal) — skill set "Lethality"

Requirements: Gunner 4. Move 4, Jump 6, Swim. Equipment: dagger, bow, robe, light armour.
Starting ability: Blind Powder. Passives: Cautious Step, Dual Wield. Counter: Critical: Mirage.
(No mastery bonus listed on the page.)

| Ability | AP | MP | Range / area | Kind | Effect |
|---|---|---|---|---|---|
| Blind Powder | 0 | 6 | 1-4, vert 5 | skill | 0.6x ATK physical at range; 75% Blind |
| Dispel Powder | 150 | 6 | 1-3, vert 5 | skill | 0.6x ATK magical at range; removes all buffs |
| Sabotage | 100 | 4 | 1-4, vert 14 | spell | swap places with the target; ignores Protect |
| Sleep Powder | 150 | 8 | 1-3, line 3 | skill | 0.5x ATK physical in a line; 50% Sleep |
| Cautious Step | 150 | | | passive | immune to traps, Root, Slow |
| Collect Bounty | 200 | | weapon | skill | 0.8x ATK; killing blow on a human gives a rare component; killed target can't be raised this fight; bosses immune |
| Mirage | 200 | 4 | self | spell | Mirage: auto-evade the next damaging action |
| Critical: Mirage | 250 | | | counter | Mirage when HP goes critical |
| Assassinate | 350 | 24 | 1-3, vert 8 | skill | 2.8x ATK physical at range; 50% each Poison, Bleed, Blind |
| Dual Wield | 450 | | | passive | two weapons (or shields); skills don't get the 2nd weapon's attack |

## Ranger (Fell Seal) — skill set "Survival" (pasted by the user on 2026-10-14; becomes our Archer, STATUS NWP 22)

Built in 1.0.0.66 (JP = AP x 2.5; Collect Pelt renamed Collect Trophy: a sellable trophy in the body's loot; Equip
Bows added; BG3 mapping in STATUS.md, 1.0.0.66).

Requirements: Scoundrel 4 (ours keeps the Archer's unlock). Move 4, Jump 5, Swim. Equipment: axe, bow, crossbow, light
armour (ours: no axes, user). Starting ability: Rooting Shot. Passives: Know Weakness, Evasion Up. Counter: Countershot.
"Survivalists who have honed their skill in archery to deadly effect."

| Ability | AP | MP | Range / area | Kind | Effect |
|---|---|---|---|---|---|
| Rooting Shot | 0 | 0 | weapon | skill | 0.85x ATK physical; 75% Root |
| Balm | 100 | 6 | 0-1, vert 4 | skill | removes Poison, Bleed, Blind, Root, Mute, Cripple, Sleep, Weaken |
| Scout | 200 | 6 | self, cross 13 | skill | reveals traps within 6; Crit Up on self |
| Collect Pelt | 200 | 0 | weapon | skill | 0.8x ATK; killing blow on a monster gives a rare component; can't be raised this fight; bosses immune |
| Know Weakness | 200 | | | passive | +25% critical hit chance |
| Rain of Arrows | 250 | 0 | 1, vert 7; line 4 | skill | 0.9x ATK physical in a line |
| Evasion Up | 200 | | | passive | +13% EVA |
| Multishot | 300 | 0 | weapon; cross 3 | skill | 0.85x ATK physical in a small area |
| Countershot | 250 | | | counter | counters ranged attacks/skills with a regular attack |
| Sniper Shot | 400 | 36 | weapon | skill | 3.8x ATK physical; Root on self |

Mapping notes for later: Fell Seal "Gunner 4" has no job here (closest: Machinist, a special job, or Archer);
"Ranger" = Archer; Mirage ~ BG3 Blink/Mirror Image-style evade; Critical: X counters = our reaction slot with an
HP-below-threshold trigger; Fell Seal MP costs → our cooldowns (no MP pool, user's rule).

## Wizard (Fell Seal) — skill set "Elementalism" (pasted by the user on 2026-10-14; a NEW job beside the Black Mage)

Requirements: Mender 2 (ours, user: half the maximum job level as both Black Mage and White Mage = level 4 each).
Move 3, Jump 4. Equipment: rod, robe, light armour (ours: quarterstaffs, clubs, light armour, like the Black Mage).
Starting ability: Water I / Fire I. Passives: Smart Casting, Boon. Counter: Magic. Mastery: MP+5, MND+5, RES+5 (ours:
one extra level 1 spell slot, user). "These spell-slingers can take out large groups of enemies at once by unleashing
destructive magic upon the battlefield." Base for Alchemystic, Druid, Fellblade, Gadgeteer, Vessel.

| Ability | AP | MP | Range / area | Kind | Effect |
|---|---|---|---|---|---|
| Water I / Fire I | 0 | 8 | 0-3, vert 10; cross 3 | spell | 1x MND water/fire damage in a small area |
| Earth I / Thunder I | 200 | 8 | 0-3, vert 10; cross 3 | spell | 1x MND earth/thunder damage in a small area |
| Smart Casting | 200 | | | passive | offensive multi-target abilities skip allies, helpful ones skip enemies |
| Water II / Fire II | 200 | 14 | 0-3, vert 14; cross 3 | spell | 1.5x MND water/fire damage in a small area |
| Magic | 200 | | | counter | counters an offensive spell with a non-elemental version cast back at the attacker |
| Earth II / Thunder II | 200 | 14 | 0-3, vert 14; cross 3 | spell | 1.5x MND earth/thunder damage in a small area |
| Boon | 250 | | | passive | after felling an enemy, the next action is a guaranteed critical; wears off at the end of the next turn |
| Water Locus / Fire Locus | 300 | 18 | 0-4, vert 18; single | spell | 2x MND water/fire damage to one target |
| Earth Locus / Thunder Locus | 300 | 18 | 0-4, vert 18; single | spell | 2x MND earth/thunder damage to one target |

Built (user's answers, 2026-10-14): JP = AP x 2.5 (Ranger rule): 0, 500, 500, 500, 500, 500, 625, 750, 750 = 4625.
Group "FellSeal" (with the Peddler; shown in the main Jobs list). Elements: Water = cold + Wet, Fire = fire, Earth =
bludgeoning, Thunder = lightning. Costs: Tier I cantrip + spell-slot version (level picker 1-6), Tier II level 1 slot,
Locus level 2 slot (spell attacks), higher slots add dice. Smart Casting covers every area ability of the mod
(tools/smartcast.py + Effects.Spared), not BG3's own spells. Magic -> "Return Magic": half the spell's damage back as
force damage. Boon: attack rolls only (BG3 rules: saving-throw spells can't crit).
