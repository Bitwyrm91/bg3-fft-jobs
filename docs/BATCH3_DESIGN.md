# Phase 2, batch 3: Samurai, Ninja, Arithmetician, Bard, Dancer, Mime

Ability lists: RPGSite's TIC jobs guide (`docs` sources in `data/fft_jobs.json` meta). Costs and effect texts: the TIC
game table `Ability-en` (read with sqlite from `C:\Users\berus\GameModding\decomp\fft\enhanced\fft_enhanced.sqlite`;
`tools/check_fft_data.py` must report 0 differences). Build each job like batch 2: vanilla parents, tests, build,
validate, install only with BG3 closed, commit after each job, no GPU image generation without asking.

## Samurai: BUILT in v1.0.0.14

Iaido = shouts around the Samurai (enemies only for damage; Murasame, Kiyomori, Masamune help you and allies within
3 m). Ashura at will (cantrip dice), the next four once per short rest, the top four once per long rest.

## Ninja (unlock Archer 4, Thief 5, Geomancer 2): BUILT in v1.0.0.15

- Equip: daggers, shortswords (ninja blades), flails, light armour. Innate: Dual Wield (also a 1000 JP support for
  other jobs): BG3's Two-Weapon Fighting style (off-hand attacks add your ability modifier).
- Throw (12 actions, TIC: throws the item from the inventory): built as javelin throws at 18 m that use up no
  item, Dexterity save against the physical DC, 1d6 to 2d6 by item type + the better of Str/Dex; bombs 2d6 fire in
  2 m. Once per turn each.
- Vanish (reaction): turn invisible when a weapon attack hits you. Reflexes: +1 AC and advantage on Dexterity saves.
  Waterwalking: water neither slows you nor leaves you Wet.

## Bard and Dancer (open to everyone: PHASE2.md): BUILT in v1.0.0.16

FFT: the performer keeps singing or dancing each turn, and every ally (song) or foe (dance) feels it each turn.
BG3: a concentration shout that wraps the performer in an aura (vanilla aura statuses, 9 m) for up to 3 turns;
the aura applies a short status to allies (songs) or enemies (dances) inside it.

- Songs: Seraph Song (a level 1 spell slot back once per song), Life's Anthem (regain 1d4 HP each turn), Rousing
  Melody (+3 m movement: FFTJ_SPEED_SURGE), Battle Chant (+1 attack and damage: FFTJ_FOCUS), Magickal Refrain (+1
  spell attack and DC), Nameless Song (Blessed), Finale (one shout, once per long rest: allies within 9 m get an extra
  action next turn: FFTJ_QUICK).
- Dances: Witch Hunt (-2 spell DC and spell attacks: FFTJ_REND_MAGICK), Mincing Minuet (1d6 psychic each turn), Slow
  Dance (-3 m: FFTJ_REND_SPEED), Polka (2 less damage: FFTJ_REND_POWER), Heathen Frolic (disadvantage on Int/Wis/Cha
  saves), Forbidden Dance (each turn a chance of blind, silence, poison or slow), Last Waltz (one shout, once per long
  rest: enemies within 9 m lose their actions next turn on a failed Wisdom save: FFTJ_DISABLE).
- Bard: Magick Surge, Faith Surge (reactions), Movement +3, Fly. Dancer: Strength Surge, Bravery Surge, Jump +3, Fly.
  Equipment: Bard musical instruments + light armour; Dancer daggers + light armour.

## Arithmetician (unlock White Mage 5, Black Mage 5, Time Mage 4, Mystic 4)

FFT: pick a variable (CT, Level, EXP, Elevation) and a trigger (prime, multiple of 5/4/3); a learned magick then hits
every unit (friend or foe) whose value matches, instantly and for free. BG3 idea: the variables become things BG3
creatures have (level, HP, AC, distance); the Arithmetician's action casts one of the FFT magicks the character has
learned on every creature in sight that matches. Needs script support (choose spell + rule, find matching
creatures, cast with Osi.UseSpell / ApplyStatus). Ask the user before building: it is the most complicated job.

## Mime (PHASE2.md: Echo action)

On its turn the Mime can repeat the last ability an ally used this round, ignoring that ability's cooldown. Needs the
server script to remember each ally's last cast (CastedSpell event) and grant/trigger it for the Mime. Innate:
Concentration (attacks can't be dodged), Brawler, Beastmaster. Emblem art still to paint (ask before using the GPU).
