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

## Peddler (Fell Seal) — skill set "Peddle" (pasted by the user on 2026-10-14; BUILT on branch `peddler`, not seen in game)

Requirements: Ranger 5 (ours: Archer job level 5). Move 3, Jump 5. Equipment: dagger, axe, crossbow, light armour,
shield. Starting ability: Lacerating Trap. Passives: Quick Fingers, Item Potency. Counter: Critical: Quicken.
Mastery bonus: HP/MP +5, SPD +3. "Relying on their wits, Peddlers prefer to stay out of direct combat. They set clever
traps and know how to get the most bang for the buck out of items." Required for: Duelist (Peddler 3 + Reaver 3).

| Ability | AP | MP | Range / area | Kind | Effect |
|---|---|---|---|---|---|
| Lacerating Trap | 0 | 8 | 1-3, vert 2 | skill | trap: Bleed + end the turn of an enemy that steps on it |
| Immobilizing Trap | 150 | 8 | 1-3, vert 2 | skill | trap: Root + end turn |
| Item Potency | 200 | | | passive | items have double potency |
| Painful Trap | 200 | 10 | 1-3, vert 2 | skill | trap: damage 1/2 of current HP + end turn |
| Quick Fingers | 150 | | | passive | situational commands (Open, Gather, Climb, Activate) cost no action |
| Alluring Trap | 250 | 12 | 1-3, vert 2 | skill | trap: Charm + end turn |
| Critical: Quicken | 225 | | | counter | an immediate turn when HP goes critical after damage |
| Critical Expertise | 150 | 6 | 0-2, vert 2 | spell | CRIT Up on the target |
| Sales Pitch | 250 | 12 | self, cross 3 | spell | Haste in a small area |
| Patented Usage | 400 | 14 | 0-3, vert 6; cross 3 | skill | the selected item is used on a small area (not Phoenix Ashes / Mana Stone) |

**BG3 mapping (user's answers, 2026-10-14):** job id `Peddler`, group `FellSeal` (a new group, shared with the Wizard
session: not a TIC job for the pacing/TIC checks; listed with the regular jobs on the Job Board and menus), unlock
Archer (Ranger) 5, JP = AP x 2.5 (Critical: Quicken 562.5 -> 560; total 4935), gear daggers, hand/battle axes, all
crossbows, light armour, shields; mastery +5 max HP, +3 initiative.
- **Traps** (user: the turn always ends; a Dexterity save resists only the status; once per short rest AND a level 1
  spell slot each): 4.5 m range, the trap stays until it springs or a long rest. Built like Glyph of Warding: the spell
  summons our trap item (root template = child of a vanilla glyph trap; tools/peddler.py), whose constellation fires
  `Projectile_FFTJ_<Trap>_Trap` at the enemy; that marks it (FFTJ_TRAP_SPRUNG_*) and Server/Peddler.lua ends its turn
  (Osi.EndTurn, only during its own turn) and applies FFTJ_TRAP_LACERATE / _IMMOBILIZE / _ALLURE (Dex save vs the
  owner's DC: statcast per-ability twins) = Bleeding 3 turns / FFTJ_TRAP_ROOTED 2 turns / FFTJ_ENTICED 3 turns (the
  Orator's Entice: fights on your side on its own, bosses immune). Painful Trap: config Abilities.PainfulTrapShare (0.5)
  of current HP, piercing, no save, bosses too. Owner = Osi.GetOwner(trap item), else the last party member who laid
  that trap.
- **Quick Fingers** (user): +1 bonus action every turn (BG3 Thief's Fast Hands).
- **Item Potency** (user: Chemist items + BG3 potions + grenades): FFTJ_ItemPotency_Heal (generated) rolls the healing
  of every Chemist potion spell (Potion / Hi / X, thrown, slot levels, Echo, Patented) a second time (Disciple of Life
  OnHeal pattern); BG3 healing potions drunk or thrown by the Peddler: a twin status heals again (Peddler.lua);
  grenades: DamageBonus of the vanilla dice (Acid Vial 2d6 acid, Smokepowder bombs 3d4+9 force, spore grenades 2d4+1
  poison); Alchemist's Fire: Burning 6 turns instead of 3 (re-applied by Peddler.lua). Fire/oil/poison/web grenades
  only make surfaces: nothing to double.
- **Critical: Quicken** = the Time Mage's Critical: Quick passive (FFTJ_CriticalQuick; the tooltip shows that name).
- **Critical Expertise**: crit on 19-20 for 3 turns, you or an ally within 3 m, once per short rest.
- **Sales Pitch**: Haste (3 turns, BG3 lethargy after) on you and allies within 3 m, once per long rest.
- **Patented Usage** (user: area Chemist items): a container; per learned Chemist item (Potion, Hi-Potion, X-Potion,
  Antidote, Eye Drops, Echo Herbs, Remedy) an area form: everyone within 3 m of a point up to 4.5 m away, enemies too;
  each once per short rest (X-Potion long rest). New data field `perLearned` (Rules.DesiredGrants).
- Unverified in game: all of it, above all the trap items (child templates keeping the glyph constellation, the 3 x 3 m
  trigger box, GetOwner on a summoned item, EndTurn), OnHeal with SpellId on our potion spells, the potion twins'
  causee, the container. Icons: art/icons/subjects.txt has the Peddler lines (paint them locally, BG3 closed).
