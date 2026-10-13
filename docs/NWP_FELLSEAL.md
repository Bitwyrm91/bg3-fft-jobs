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

Mapping notes for later: Fell Seal "Gunner 4" has no job here (closest: Machinist, a special job, or Archer);
"Ranger" = Archer; Mirage ~ BG3 Blink/Mirror Image-style evade; Critical: X counters = our reaction slot with an
HP-below-threshold trigger; Fell Seal MP costs → our cooldowns (no MP pool, user's rule).
