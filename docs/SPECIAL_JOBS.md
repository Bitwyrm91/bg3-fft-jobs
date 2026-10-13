# Special jobs and badges: proposal (phase 2 step 4, NOT built)

Written 2026-10-13 by the scheduled run while the user was away. **Nothing here is built.** The user approves or
changes the table first (PHASE2.md item 3: "Propose which boss drops which badge to the user before building it").

Sources: the vanilla TIC tables on the user's PC (`Job-en`, `JobCommand-en` in
`C:\Users\berus\GameModding\decomp\fft\enhanced\fft_enhanced.sqlite`; no modded files read) for the job names and
skillsets, and War of the Lions guides (Caves of Narshe) for the two WotL-only guest jobs (Sky Pirate, Game Hunter).

## How it works (already decided, PHASE2.md items 3 and 7)

- Each special job needs **a badge plus job levels**. A badge drops from one BG3 boss, **once for the whole party**
  (the badge system and `!fft_badge` already exist since 1.0.0.6). Each character still needs the job levels.
- Proposed drop: when the boss dies (Osiris `KilledBy`, already wired), the party gets the badge with a notification.
  A visible inventory item could come later.

## The list, checked against the TIC data

PHASE2.md listed 17 jobs. The TIC data confirms 15 of them. Two names differ: TIC calls Worker 8's job
**Automaton** (WotL: Steel Giant), and Ovelia's job is **Princess** with the **Holy Magicks** skillset. Sky Pirate
(Balthier) and Game Hunter (Luso) are War of the Lions only; they stay in because the user wants jobs from every
version.

## Proposed boss to badge table

| # | Job (FFT character) | FFT skillset (TIC text) | BG3 boss (act; story or optional) | Why this boss | Proposed job levels |
|---|---|---|---|---|---|
| 1 | **Cleric** (Alma) | Holy Magicks: recovery and protection | **Priestess Gut** (Act 1, Shattered Sanctum; optional, usual) | the goblins' priestess | White Mage Lv4, Chemist Lv4 |
| 2 | **Fell Knight** (Gaffgarion) | Fell Sword: steal life force with a sword | **Minthara** (Act 1, Shattered Sanctum or the grove raid) | a paladin who turned from her goddess to the Absolute; TIC: "a fallen knight who has turned his back on the light of the gods" | Knight Lv4, Black Mage Lv4 |
| 3 | **Divine Knight** (Meliadoul) | Unyielding Blade: attacks that destroy equipment | **Nere** (Act 1, Grymforge) | a True Soul: the Absolute's church militant | Knight Lv5, Monk Lv4 |
| 4 | **Templar** (Beowulf) | Spellblade: sword strikes that inflict ailments | **Inquisitor W'wargaz** (Act 1, Crèche Y'llek) | the enforcer of the githyanki faith | Knight Lv5, Mystic Lv4 |
| 5 | **Automaton** (Worker 8; WotL "Steel Giant") | Work: crushing mechanical blows | **Grym** (Act 1, Adamantine Forge; optional, usual) | a forge construct (alternative: the Steel Watch Titan, Act 3) | Squire Lv6, Geomancer Lv4 |
| 6 | **Astrologer** (Orran) | Astrology: the stars' influence on men's fates | **Auntie Ethel** (Act 1, Riverside Teahouse; optional) | a hag who trades in fates and bargains | Time Mage Lv5, Mystic Lv4 |
| 7 | **Game Hunter** (Luso, WotL) | Hunt: monster-hunting skills | **the Flind** (Act 1, gnoll war band; optional) | the pack's huntmaster | Archer Lv5, Thief Lv4 |
| 8 | **Sky Pirate** (Balthier, WotL) | Piracy: stealing in style | **Commander Zhalk** (prologue nautiloid; optional, hard) | the captain of a flying ship | Thief Lv6, Archer Lv4 |
| 9 | **Netherseer** (Marach) | Nether Mantra: otherworldly power, stronger as faith decreases | **Balthazar** (Act 2, Gauntlet of Shar; story) | Myrkul's necromancer | Mystic Lv5, Black Mage Lv5 |
| 10 | **Skyseer** (Rapha) | Sky Mantra: arcane power from the heavens | **Marcus** (Act 2, the winged knight who raids Last Light; optional) | he strikes from the sky | Mystic Lv5, Time Mage Lv4 |
| 11 | **Soldier** (Cloud) | Limit: all-out strikes with a materia blade | **Yurgir** (Act 2, orthon; optional, Raphael's contract) | an otherworldly mercenary of the Blood War (TIC: "an otherworldly traveler") | Squire Lv8, Knight Lv6 |
| 12 | **Holy Knight** (Agrias) | Holy Sword: holy sword strikes with ailments | **Ketheric Thorm** (Act 2 finale; story) | once a holy knight (paladin) of Selûne | Knight Lv6, White Mage Lv5 |
| 13 | **Machinist** (Mustadio) | Aimed Shot: strikes body parts to impede movement | **Enver Gortash** (Act 3, Wyrm's Rock; story) | the engineer of the Steel Watch (TIC: "an engineer striving to revive lost technologies") | Archer Lv6, Chemist Lv5 |
| 14 | **Ark Knight** (Elmdore) | Sword Spirit, Vampire, Blade of Ruin | **Cazador Szarr** (Act 3, his palace; Astarion's story) | a vampire lord, like Elmdore | Samurai Lv5, Black Mage Lv5 |
| 15 | **Princess** (Ovelia) | Holy Magicks: recovery and protection | **Viconia DeVir** (Act 3, House of Grief; Shadowheart's story) | a drow noblewoman (House DeVir) and high priestess | White Mage Lv6, Orator Lv5 |
| 16 | **Dragonkin** (Reis) | Dragon: draconic power | **Ansur** (Act 3, the Wyrmway; optional) | a bronze dragon | Dragoon Lv6, Summoner Lv5 |
| 17 | **Sword Saint** (Orlandeau) | Swordplay: every sword technique | **Sarevok Anchev** (Act 3, Murder Tribunal; optional) | the Sword of Bhaal, a legendary swordsman | Knight Lv8, Samurai Lv8 |

Spread: 8 badges in Act 1 (the longest act), 4 in Act 2, 5 in Act 3. The strongest jobs come last: Holy Knight at the
end of Act 2, Sword Saint in Act 3. The job levels are my proposal (FFT's special characters have no unlock rules):
each pair matches the job's style, and the strongest jobs need the highest levels.

## More special jobs the TIC data has (not in the list; the user's call)

| Job (FFT character) | Skillset (TIC text) | Suggested boss |
|---|---|---|
| **Gallant Knight** (Ramza) | Mettle: the Squire's Fundaments plus Ramza's own techniques | Orin the Red (Act 3), or a reward for mastering Squire with 5 badges found |
| **White Knight** (Wiegraf) | Holy Sword plus Pugilism (fists) | Raphael (Act 3): Wiegraf too made a pact with a demon |
| **Assassin** (Celia, Lede) | Subdual Arts: ailments that send foes to their graves | Orin the Red (Act 3), Bhaal's assassin |
| **Sorcerer** (Kletian) | Magick Arts: spells from the pinnacle of every school | Lorroakan (Act 3, Sorcerous Sundries) |
| **Celebrant** (Zalmo) | Priest Magicks: heal wounds, cure ailments; hunts heretics | Malus Thorm (Act 2, House of Healing) |
| **Nightblade** (Barich) | Arts of War: destroy equipment or devastate attributes | Kar'niss (Act 2, the drider) |
| **Rune Knight** | Swordsmanship: Holy Sword plus Unyielding Blade | Thisobald Thorm (Act 2) or the Steel Watch Titan (Act 3) |

Byblos and the Holy Dragon are monster jobs in the TIC data: they belong to the Soul Collector
(`docs/SOUL_COLLECTOR_MAP.md`).

## Open questions for the user

1. **Spared or recruited bosses:** Minthara can join you, Zhalk usually escapes, Ethel can be bargained with, Yurgir
   can be freed from his contract. Should the badge come anyway (when they are spared or join), or turn up somewhere
   later (for example in the camp traveller's chest in the next act)?
2. **Act spread:** is 8 badges in Act 1 fine, or move some later? For example, the Astrologer could come from Lorroakan
   (Act 3) instead of Ethel.
3. **The extra TIC jobs:** add some or all of the 7 above?
4. **Job levels:** keep the proposed pairs?
5. **The badge:** a visible item in the inventory, or only the Job Board unlock and a notification?

## Notes for building it later

- Recognise the boss: `KilledBy` (already handled in `Service:OnKilledBy`) plus the dead creature's root template or
  GUID, compared with a table of boss templates looked up in the extracted game data. Check `Osi.IsBoss` too.
- Data: a `boss` list on each entry of `badges` in `data/fft_jobs.json`. Each special job gets
  `unlock: [{"badge": ...}, {"job": ..., "level": ...}]` and `group` `Special` (outside the pacing target, like WotL).
- Abilities: TIC tables (`Ability`, cost = `JpCost1 + 256 × JpCost2`, names in `Ability-en`); WotL guides for Sky
  Pirate and Game Hunter.
