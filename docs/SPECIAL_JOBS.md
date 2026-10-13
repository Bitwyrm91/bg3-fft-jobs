# Special jobs and badges (phase 2 step 4; table APPROVED by the user 2026-10-13; boss badges built in 1.0.0.22, jobs being built one by one)

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
| 5 | **Steel Giant** (Worker 8; TIC calls it "Automaton") | Work: crushing mechanical blows | **Grym** (Act 1, Adamantine Forge; optional, usual) | a forge construct (alternative: the Steel Watch Titan, Act 3) | Squire Lv6, Geomancer Lv4 |
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

## The user's answers (2026-10-13)

1. **Spared or recruited bosses still give the badge** (when spared, or when they join: Minthara hands it over).
2. **Keep the act spread** (8 / 4 / 5).
3. **Add all 7 extra TIC special jobs, after the 17** (bosses as suggested above).
4. **Job levels as proposed.**
5. **A found badge = a notification and the Job Board** for now; a visible item later, with the art.
6. Worker 8's special job is called **Steel Giant** (War of the Lions' name), because "Automaton" is the construct
   Soul form.

## The questions that were asked

1. **Spared or recruited bosses:** Minthara can join you, Zhalk usually escapes, Ethel can be bargained with, Yurgir
   can be freed from his contract. Should the badge come anyway (when they are spared or join), or turn up somewhere
   later (for example in the camp traveller's chest in the next act)?
2. **Act spread:** is 8 badges in Act 1 fine, or move some later? For example, the Astrologer could come from Lorroakan
   (Act 3) instead of Ethel.
3. **The extra TIC jobs:** add some or all of the 7 above?
4. **Job levels:** keep the proposed pairs?
5. **The badge:** a visible item in the inventory, or only the Job Board unlock and a notification?

Built so far: Cleric (1.0.0.23), Fell Knight (1.0.0.24), Divine Knight (1.0.0.25), Templar (1.0.0.26).

## Built: boss badge detection (1.0.0.22)

`Server/Bosses.lua`; the boss characters are in `data/fft_jobs.json` (`badges[].characters`), found in the vanilla level
data (`Mods/Gustav*/{Globals,Levels}/<level>/Characters/_merged.lsf`, converted with Divine into
`C:\Users\berus\GameModding\decomp\bg3\levels`) and checked against the English names (`decomp\bg3\loca`):

| Badge | Boss character (`S_` name, English name) | GUID |
|---|---|---|
| Cleric | S_GOB_GoblinPriest ("True Soul Gut") | b983c336-9a14-4e9b-adb9-4689e7e0afa9 |
| Fell Knight | S_GOB_DrowCommander ("Nightwarden Minthara", also the companion) | 25721313-0c15-4935-8176-9f134385451b |
| Divine Knight | S_UND_TheDrowNere ("Nere") | 06bf05c5-216b-4eaf-91f5-8f1dd3d57f30 |
| Templar | S_CRE_Templar ("Ch'r'ai W'wargaz") | 378ac93e-03a0-40b4-904c-f37989ac7a8c |
| Steel Giant | S_UND_KethericCity_AdamantineGolem ("Grym") | 2a5997fc-5f2a-4a13-b309-bed16da3b255 |
| Astrologer | S_HAG_Hag ("Auntie Ethel"; her illusion doubles don't count) | c457d064-83fb-4ec6-b74d-1f30dfafd12d |
| Game Hunter | S_PLA_ConflictedFlind_Boss ("Flind") | 34464430-fed8-4f50-86d5-bd35846920a0 |
| Sky Pirate | S_TUT_Helm_Devil_005 ("Commander Zhalk") | ed103005-fd71-457d-ae6c-39654bbd8f2e |
| Netherseer | S_SHA_Necromancer ("Balthazar") | 53651a9f-7ea8-444f-ba2d-224390b72f7d |
| Skyseer | S_HAV_FlamingSpy ("Fist Marcus") | acb1dd9e-952b-4281-8e30-ec6f671493a6 |
| Soldier | S_GLO_Orthon ("Yurgir") | 1dc8091d-2af6-4d33-9268-998ef266d19c |
| Holy Knight | S_MOO_Ketheric, S_MOO_Ketheric_Transforming, S_GLO_Myrkul | e9918f3e-5b87-40a3-a9bd-61545151573f, 5222b192-2ea3-4ecc-8434-79c9f28169f8, 9061c1d3-5965-4251-9c07-bcebe53d0660 |
| Machinist | S_GLO_Gortash ("Lord Enver Gortash") | b878a854-f790-4999-95c4-3f20f00f65ac |
| Ark Knight | S_GLO_Cazador ("Cazador Szarr") | 2f1880e6-1297-4ca3-a79c-9fabc7f179d3 |
| Princess | S_LOW_Viconia ("Viconia DeVir") | b1ea974d-96fb-47ca-b6d9-9c85fcb69313 |
| Dragonkin | S_WYR_SkeletalDragon ("Ansur") | 67770922-5e0a-40c5-b3f0-67e8eb50493a |
| Sword Saint | S_LOW_MurderTribunal_Sarevok | ae9f784a-ea64-4297-95a7-8377e85231b6 |

For the 7 extra jobs later: S_GLO_Orin bf24e0ec-a3a6-4905-bd2d-45dc8edf8101, S_GLO_Monitor ("Raphael")
f65becd6-5cd7-4c88-b85e-6dd06b60f7b8, S_LOW_Lorroakan a9d4b71d-b0ef-429e-8210-6dc8be986ee9, S_TWN_Hospital_Surgeon
("Malus Thorm") e58b8b34-038b-4858-b817-c2a8096a9381, S_SCL_Drider ("Kar'niss") aa59ce01-3d2e-42e8-a539-c07e0ea292ab,
S_TWN_Distillery_Brewer ("Thisobald Thorm") 4d9e3db3-9a78-4f4b-8101-1dd73c0f3be5; the Steel Watch Titan is not found
yet.

How "defeated" is read: the vanilla story keeps `DB_Defeated` (`Mods/Shared/Story/RawFiles/Goals/__AAA_FirstGoal.txt`:
dead, knocked out, surrendered, petrified, banished, iron-flasked, dominated then released; saved with the game). The
story goals were extracted to `C:\Users\berus\GameModding\decomp\bg3\story`.

## Notes for building it later

- Recognise the boss: `KilledBy` (already handled in `Service:OnKilledBy`) plus the dead creature's root template or
  GUID, compared with a table of boss templates looked up in the extracted game data. Check `Osi.IsBoss` too.
- Data: a `boss` list on each entry of `badges` in `data/fft_jobs.json`. Each special job gets
  `unlock: [{"badge": ...}, {"job": ..., "level": ...}]` and `group` `Special` (outside the pacing target, like WotL).
- Abilities: TIC tables (`Ability`, cost = `JpCost1 + 256 × JpCost2`, names in `Ability-en`); WotL guides for Sky
  Pirate and Game Hunter.
