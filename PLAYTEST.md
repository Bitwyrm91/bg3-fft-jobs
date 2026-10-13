# Playtesting the FFT job system

Updated 2026-10-13. **Already installed on your PC:** the Script Extender, the mod (`Mods\FFTJobs.pak`, **version 1.0.0.23**: the Summoner, the Dragoon, a new Job Board layout with FFT colours and job emblems, four new jobs and the Fell Seal rules below, on top of the painted icons, the element looks and the **JP Training** test spell) and its entry at the end of your load order.

## New in 1.0.0.23: Cleric (special job 1 of 17)

- **Cleric** (Alma's job): needs the **Cleric Badge** (True Soul Gut, Act 1) plus **White Mage Lv4** and **Chemist Lv4**. To try it at once: `!fft_badge Cleric` and JP Training.
- **Holy Magicks**, as in TIC: the White Magicks (Cure ... Holy, the same spells as the White Mage's, learned again with Cleric JP) plus what the White Mage lacks in this mod: **Curaja** (800 JP: you and every ally within 9 m heal 5d8+5, once per long rest), **Protectja** / **Shellja** (600: Protect or Shell on you and every ally within 9 m for 5 turns, once per short rest), **Wall** (400: Protect + Shell on one creature, once per short rest), and Alma's own **Dispelna** (0 JP: ends every ailment on one creature, FFT's Doom, Stop, Stone, Toad, ... included; once per turn).
- **While Cleric is your job**, every spell you cast that restores hit points restores **1d6 more** (Holy Magicks passive). Main-job equipment: quarterstaffs, maces, light and medium armour. Mastery: resistance to radiant damage.
- Worth checking: does Curaja heal the whole party around you, does the 1d6 bonus show after a Cure, does Dispelna clear Stop or Toad?

## New in 1.0.0.22: bosses drop badges (special jobs, step 1)

- The **17 special jobs** (Holy Knight, Sword Saint, Cleric, ...) are on the Job Board as "soon" tiles. Each needs a **badge from one BG3 boss** plus job levels (the table you approved, `docs/SPECIAL_JOBS.md`); the jobs themselves come one by one in the next versions.
- **How a badge comes:** when the game counts the boss as **defeated** (killed, knocked out, surrendered, petrified, ...), when the boss **joins your party** (Minthara hands hers over), or, your rule for **spared bosses**: when you move on to the **next act** after meeting the boss (fought it or spoke with it) and leaving it alive. Commander Zhalk counts when you reach the shore. A notification says it, e.g. "True Soul Gut is defeated. The party found the Cleric Badge!".
- **Saves from before this version:** bosses you already beat count when the save loads (the game keeps its own "defeated" record). Bosses you spared before installing don't (the mod didn't see you meet them): use `!fft_badge <id>` for those.
- `!fft_badge list` shows every badge, its boss and act, and whether it was found or the boss met. Settings: `!fft_set Badges.FromBosses false` (no boss badges), `!fft_set Badges.SparedBosses false` (only defeated or recruited bosses count).
- Worth checking: load your Act 2 save and run `!fft_badge list`: the Act 1 bosses you beat should say "found". The SE log lines start with "boss badge" and "the party met".

## New in 1.0.0.21: the Dark Knight's area attacks hit everyone

- Your answer: **Abyssal Blade** and **Unholy Sacrifice** now hit everyone around the Dark Knight, allies too, as in FFT. Keep your party out of the 4.5 m / 5 m circle.

## New in 1.0.0.20: Onion Knight (War of the Lions)

- **Onion Knight** (unlock as in WotL: **Squire Lv6 + Chemist Lv6**). It has **no abilities**, and while it is your job your secondary, reaction and passive slots rest too (FFT's rule; `!fft_set Rules.OnionKnightBlocksSlots false` lets them work). In return it uses **every weapon, armour and shield** and grows with its job level: **Lv5** +1 AC and +1 to attack rolls; **Lv8** +2 to every ability score, +2 AC and +2 to attack rolls. Mastered at job level 8 (3,000 JP): +1 AC for good, whatever your job.
- Worth checking: with Onion Knight as the job, do the slotted passives and the secondary's actions disappear, and come back when you switch jobs? Do the Lv5 / Lv8 passives show on the character sheet?

## New in 1.0.0.19: JP re-tuned for 20 jobs, Dark Knight (War of the Lions)

- **More JP (your target):** a normal playthrough should open every job for someone in the party by late Act 2 and let each fighter master about half of the 20 jobs. Details at the end, under "Changing how fast JP comes".
- **Dark Knight**, a late bonus job from War of the Lions, unlocked the WotL way: **Knight and Black Mage mastered**, **Dragoon, Samurai, Ninja and Geomancer at Lv8**, and **20 enemies defeated** by that character (kills count from this version on; the job's tile shows how many you have). To try it right away: `!fft_unlockall`. Fell Sword:
  - **Sanguine Sword** (500 JP): a melee weapon attack that heals you for half the damage it deals (at will).
  - **Infernal Strike** (500): a weapon attack; the target gets -2 to spell attacks and spell DC for 2 turns and you regain a level 1 spell slot (once per short rest).
  - **Crushing Blow** (300): a weapon attack + 1d8 necrotic; Constitution save or Stopped for 1 turn, bosses immune (once per short rest).
  - **Abyssal Blade** (1000): costs a tenth of your maximum HP; **everyone else within 4.5 m, allies too** (your choice, as in FFT), takes 3d8 necrotic, 6d8 if right next to you (Dexterity save for half; once per short rest).
  - **Unholy Sacrifice** (1200): costs a quarter of your maximum HP; **everyone else within 5 m, allies too**, takes 8d8 necrotic and is Slowed for 2 turns (Constitution save for half and no Slow; once per long rest). The HP costs never take your last hit point.
  - **HP Boost** (2000): +20% maximum HP. **Vehemence** (400): +1d6 necrotic on weapon hits but -2 AC. **Movement +3** and **Jump +3** (1000 each). Mastery: resistance to necrotic damage. Main-job equipment: swords, greatswords, all armour, shields.
- Worth checking: does Sanguine Sword heal you? Do enemies next to you take more from Abyssal Blade than those farther away? Does the HP cost appear as necrotic damage on the Dark Knight?

## New in 1.0.0.18: Arithmetician (all 20 TIC jobs done)

- **Arithmetician** (unlock: White Mage Lv5, Black Mage Lv5, Time Mage Lv4, Mystic Lv4). Your design: **hits everyone whose number fits, like FFT**, with the magick **loaded on the Job Board**. Learn a **number** (Target Level = level, Target CT = current HP, Target EXP = maximum HP, Target Elevation = distance from you in metres) and a **rule** (Prime, Multiple of 3 / 4 / 5). On the Arithmetician's job page, click a learned White/Black/Time Mage or Mystic magick and a number to load them (the loaded one shows in [brackets]). In a fight, the rule spell casts the magick, free and instantly, at every creature within 30 m whose number fits: enemies, allies and yourself alike (Cure on everyone at a prime HP; Fire on every level-3 creature, friends included!). A notice lists who it hit.
- Also: **Cup of Life** (heals on you splash 1d4 to allies within 6 m), **Soulbind** (hit back 1d6 necrotic and heal 1d6), **EXP Boost** (+25% fight XP), **Accrue EXP** / **Accrue JP** (a little XP / 10 JP each turn in a fight). Mastery: +1 to Intelligence and Wisdom saves.
- Worth checking: does the Arithmetician cast the magick at each matching creature in turn (it queues one cast per target)?

## New in 1.0.0.17: Mime (Echo)

- **Mime** (unlock: Squire Lv8, Chemist Lv8, Summoner Lv5, Orator Lv5, Geomancer Lv5, Dragoon Lv5). Your design: **Echo**. In a fight, at the start of the Mime's turn it gets a copy of the **last job ability an ally used since the Mime's previous turn** (a notice says "Echo ready: ..."; the spell is called "Echo: <ability>"). It can be used once that turn, free of the ability's cooldown, and disappears when used, at the end of the turn or when the fight ends. Plain attacks and class spells aren't echoed, only Job Board abilities. The Mime has no abilities to learn (as in FFT), so it is mastered at job level 8 (+1 to all saves). Concentration (+2 weapon attack rolls), Brawler and **Beastmaster** (allied beasts, familiars and summons within 6 m: +1 attack and damage) are always on.
- Worth checking: does "Echo: ..." appear on the hotbar at the Mime's turn and vanish after use?

## New in 1.0.0.16: Bard and Dancer (open to everyone)

- **Performances** (Bard unlock: Summoner Lv5 + Orator Lv5; Dancer: Geomancer Lv5 + Dragoon Lv5). A song or dance takes your action and your concentration and lasts up to 3 turns; everyone within 9 m of you feels it while they stay close (one performance at a time).
  - **Bard songs** (you and allies): Seraph Song (a level 1 spell slot back, once per short rest), Life's Anthem (1d4 HP each turn, once per short rest), Rousing Melody (+3 m), Battle Chant (+1 attack and damage), Magickal Refrain (+1 spell attack and DC), Nameless Song (Blessed). **Finale**: allies within 9 m get an extra action next turn (once per long rest).
  - **Dancer dances** (enemies): Witch Hunt (-2 spell DC and spell attacks), Mincing Minuet (1d4 psychic each turn), Slow Dance (-3 m), Polka (2 less damage), Heathen Frolic (disadvantage on Int/Wis/Cha saves), Forbidden Dance (random ailments). **Last Waltz**: enemies within 9 m may lose their next turn (once per long rest).
  - Reactions: Magick Surge / Faith Surge (Bard), Strength Surge / Bravery Surge (Dancer): a 10-turn boost when you're hurt. Movement: **Fly** (both), Movement +3 (Bard), Jump +3 (Dancer).
- Worth checking: do allies get the song's status when they walk into the 9 m circle, and lose it when they leave or the song ends?

## New in 1.0.0.15: Ninja

- **Ninja** (unlock: Archer Lv4, Thief Lv5, Geomancer Lv2): **Throw** anything at a creature up to 18 m away, once per turn each and without using up items: shuriken, daggers, swords, flails, katana, ninja blades, axes, polearms, poles, knight's swords and books (1d6 to 2d6 by type, + your better of Strength and Dexterity; the target's Dexterity save avoids it), and **bombs** (2d6 fire on enemies within 2 m). **Dual Wield** is always on for Ninjas (Two-Weapon Fighting + non-light weapons in both hands) and a support for other jobs. **Vanish**: turn invisible when a weapon hits you (once per combat; attacking ends it). **Reflexes**: +1 AC, advantage on Dexterity saves. **Waterwalking**: deep water doesn't slow you and nothing makes you Wet. Mastery: advantage on Stealth.

## New in 1.0.0.14: Samurai (batch 3 starts)

- **Samurai** (unlock: Knight Lv4, Monk Lv5, Dragoon Lv2): **Iaido** draws out a legendary blade's spirit around you (no katana needed; BG3 has none). Damage ones hit only enemies within 3 m of you: **Ashura** at will (1d8 slashing, more at levels 5 and 11), then once per short rest **Kotetsu** (necrotic), **Bizen Osafune** (psychic + silence), **Ame-no-Murakumo** (cold + slow); once per long rest **Muramasa** (necrotic + confusion, rare Doom), **Kiku-ichimonji** (a 12 m line), **Chirijiraden** (8d6 fire, 5 m). Friendly ones touch you and allies within 3 m: **Murasame** heals 2d8, **Kiyomori** gives Protect + Shell, **Masamune** gives Regen + Haste. **Bonecrusher**: hit back hard when you drop to a quarter of your HP; **Shirahadori**: Uncanny Dodge; **Equip Katana**: longswords and scimitars; **Doublehand**: +2 damage with a versatile weapon in both hands; **Swim**: deep water doesn't slow you. Mastery: can't be Frightened.

## New in 1.0.0.13: Geomancer (batch 2 done)

- **Geomancer** (unlock: Monk Lv4). **Terrain decides** (your choice): each Geomancy skill works only while you stand on its terrain, and its button is greyed out elsewhere. Every skill hits the enemies within 2 m of a point up to 18 m away for cantrip damage that can't be dodged (1d6, 2d6 from level 5, 3d6 from 11); a failed save may add FFT's ailment (1 in 4, or 1 in 10 for the deadly ones):

  | Where you stand | Skills |
  |---|---|
  | Plain ground (no surface under you) | Sinkhole (Immobilize), Tremor (Confusion) |
  | In sunlight | Wind Slash (Disable), Sandstorm (Blind), Wind Blast (Slow) |
  | In shadow or darkness | Contortion (Stone), Will-o'-the-Wisp (Sleep) |
  | Water, or Wet (rain counts) | Torrent (Wet; Toad = turned into a sheep for 1 turn) |
  | Ice | Snowstorm (Silence) |
  | Fire or lava | Magma Surge (struck down at the end of its next turn) |
  | Mud, blood, acid or poison | Quicksand (Doom) |
  | Vines, overgrowth or webs | Tanglevine (Stop) |
  | Grease, oil or alcohol | Will-o'-the-Wisp |

  Tip: make your own terrain (Create Water, Grease, a fire...) and stand in it. **Nature's Wrath** (reaction): a weapon hit on you is answered by the ground (1d6+, once per turn). **Attack Boost**: +2 weapon damage. **Ignore Terrain**: difficult terrain doesn't slow you. **Lavawalking**: lava doesn't burn or slow you. Mastery: +1 to Strength and Constitution saves.
- Worth checking: do the buttons grey out and light up as you walk between plain ground, a puddle and the shade? Does the Toad sheep turn back after a turn?

## New in 1.0.0.12: Orator

- **Orator** (unlock: Mystic Lv3): talk skills that need no weapon, range 18 m. **Entice** (your choice): a foe that fails a Wisdom save **switches sides for 2 turns and fights for you on its own** (4 turns with **Tame** equipped; bosses immune, a notice says so). **Tame** (support) also gives a Tame action: a beast or monster at 25% HP or less fights for you for the rest of the fight. **Stall** takes away a creature's actions next turn; **Praise** blesses an ally; **Intimidate** banes a foe; **Preach** / **Enlighten** give Faith / Atheist; **Condemn** dooms (dies after 3 turns, once per long rest); **Defraud** steals gold from 9 m (shared with Steal Gil); **Insult** sends a creature berserk; **Mimic Darlavon** puts the enemies around a point to sleep. **Earplugs** (reaction): advantage on Wisdom saves. **Equip Guns**: hand and light crossbows for any job. **Beast Tongue**: Speak with Animals at will, always on for Orators. Mastery: +2 to Persuasion, Deception and Intimidation.
- Worth checking: an Enticed or Tamed enemy should act on its own turn and attack its old friends, then turn back when it runs out.

## New in 1.0.0.11: Summoner

- **Summoner** (unlock: Time Mage Lv3): 15 espers as big area spells that **spare your allies** (your choice): Shiva (cold), Ramuh (lightning), Ifrit (fire), Titan (earth, knocks prone), Sylph (thunder + silence), then once per long rest Bahamut (8d8 force), Odin (6d10 slashing), Leviathan (bludgeoning + soaked), Salamander (6d8 fire), Lich (necrotic), Cyclops (7d10). Moogle and Faerie heal up to 4 / 6 allies; Golem gives your group 15 temporary HP; Carbuncle gives them Reflect. **Critical: Recover MP** refills your level 1 spell slots when you're nearly down; **Halve MP** gives back a level 1 and a level 2 slot after each short rest. Mastery: +1 to Intelligence and Charisma saves.

## New in 1.0.0.10: Dragoon, softer Job Board colours

- **Dragoon** (phase 2 batch 2, first job; unlock: Thief Lv4). **Horizontal Jump** gives a **Jump** spell (your choice: leap and strike now): leap to a spot up to 6 m away (7.5 / 9 / 12 / 18 m with the higher tiers; only your best tier shows) and land on the enemies around it: weapon damage and prone unless they pass a Dexterity save. **Vertical Jump** tiers add landing damage (+1d4 up to +2d10; only the best counts). **Dragonheart** gives Death Ward when a weapon hits you (once per long rest), **Equip Polearms**, **Ignore Elevation** (jump 6 m farther, no falling damage). Mastery: jump 3 m farther. Jump abilities work while Dragoon is your job or secondary.
- **Job Board colours** toned down: the game draws them much brighter than set, so gold tiles came out bright yellow with unreadable labels. Mime's tile shows the Job Board picture until its emblem is painted.

## New in 1.0.0.9: Job Board colours and job emblems

Your feedback on 1.0.0.8: better to use, but still plain; "Learned" rows were too wordy. Now:
- **FFT's menu colours:** deep blue window, gold trim and headings. (1.0.0.8 asked for colours with a name your Script Extender version doesn't use, so none showed.)
- **A painted emblem on every job tile** (19 of 20 jobs; the 13 new ones were painted on your GPU in the same storybook style; Mime's failed because the GPU ran out of memory and comes later). Locked and coming-soon jobs are dimmed. Tile colours: bright blue = your job, gold = mastered, teal = unlocked, grey = locked, dark = coming soon.
- Learned abilities just say **Learned**; ones in use say "In your spells", "In passive 1" or "Always on".
- The level bar is gold and only shows below the top level.

## New in 1.0.0.8: a friendlier Job Board

Your feedback (2026-10-12): new jobs seemed impossible to unlock, and the window was hard to read. The board now shows **all 20 FFT jobs as a grid of coloured tiles**: blue = your job, gold = mastered (*), green = unlocked, grey = locked, dark = **coming in a later update** (Geomancer, Dragoon, ... are not built yet; their tile says what will unlock them). Click a tile for that job's details below: level bar, JP, Make job / Make secondary, equipment, mastery perk, and its abilities with icons and short coloured statuses. Hover a tile or an ability for the full text. The long explanations sit in a closed "How jobs work" section. Tell me what still feels awkward.

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
- **One source:** `!fft_set JP.XPShare 0.3` (more JP from XP; default 0.24), `!fft_set JP.Action.Multiplier 1.0` (more JP per action; default 0.8), `!fft_set JP.Victory.Base 35` (default 25). Undo with `!fft_unset JP.XPShare`.
- **Shared learning:** `!fft_set JP.Shared.Share 0.1` (10% instead of 15%), `!fft_set JP.Shared.Share 0` (off), `!fft_set JP.Shared.Scope AllJobs` (into every job, not only the ones used in combat).
- `!fft_config` shows every current value.

Changes are saved to `%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Script Extender\FFTJobs\config.json`. You can also edit that file and type `!fft_reload`. `config.reference.json` in the same folder lists every setting with a short explanation.

**Re-tuned for all 20 jobs (2026-10-13, the target you agreed):** with the default (Classic) numbers, the simulator estimates that a normal playthrough opens every job for someone in the party by late Act 2 and that each fighter masters 8-11 of the 20 jobs by the end of Act 3 (a light, story-focused one 5-7; a completionist 17-18). Classic now gives about 1.6x the JP it gave in the 6-job test (action JP 0.8, 0.24 JP per XP, victory 25 + 2 per level, long rest 40), and Fast and Grindy moved with it. Mastering every job costs 98,220 JP, so it stays a goal for long runs or the Fast preset. Numbers you changed yourself with `!fft_set` stay as you set them (they live in `config.json`).

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
