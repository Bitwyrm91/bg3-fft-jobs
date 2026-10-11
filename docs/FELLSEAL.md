# Fell Seal: Arbiter's Mark: research for a later BG3 pack

Research and design ideas (cloud session, 2026-10-11). **Not part of Part B: nothing here gets built yet**, except shared learning, which is already in the FFT mod.

Roadmap (user, 2026-10-11):
1. Test the 6 FFT jobs in BG3.
2. Add the other 14 FFT jobs.
3. Then bring in Fell Seal: Arbiter's Mark (6 Eyes Studio, 2019) and its classes.

The user owns Fell Seal on their PC (Steam). Cloud sessions can't read it, so a local run must check the numbers below against the game (see "Data check").

Sources are community wikis, guides and forum posts, listed at the end. A few values disagree; they are marked **(check)**. The cloud network blocks these sites, so everything came through web search.

## How close is it to FFT?

Very close; the core loop is the same.

| | FFT (TIC) | Fell Seal |
|---|---|---|
| Points | JP, earned **per action** | AP, earned **per battle** (about 140 per unit) |
| Points go to | the current job | the main class only (the subclass earns nothing) |
| Sharing | spillover: 1/4 of allies' JP into the same job | "vicarious learning": 15% of the battle's base AP into **every class deployed**, even locked ones |
| Job/class level | JP thresholds (200, 400 … 3000) | **1 level per ability learned** in that class |
| Unlocks | levels in other jobs | levels in other classes (same idea) |
| Secondary | secondary skill set | subclass: its actives only |
| Passive slots | 1 reaction, 1 support, 1 movement | the main class's **2 passives are on automatically** once learned, plus **2 free passive slots** and **1 counter** (reaction), from any class |
| Full mastery | nothing extra | **Mastery bonus**: about 3 small permanent stat boosts. They stack and stay after changing class. |
| Equipment | job + "Equip X" supports | decided by the main class |
| Basic jobs/classes | 20 | 20 |
| Extra classes | (none in TIC) | 6 story-unique, 6 badge (crest item), 3 DLC, Bzil classes, monster classes |

## Classes

### 20 basic classes (anyone can learn)

| Class | Needs | Class | Needs |
|---|---|---|---|
| Mercenary | (start) | Mender | (start) |
| Scoundrel | Mercenary 2 | Wizard | Mender 2 |
| Knight | Mercenary 3 | Plague Doctor | Mender 4 |
| Ranger | Scoundrel 4 | Alchemystic | Wizard 4 |
| Templar | Knight 4 | Druid | Mender 3, Wizard 5, Alchemystic 3 |
| Peddler | Ranger 5 | Sorcerer | Druid 5 |
| Reaver | Templar 5, Scoundrel 4 | Fellblade | Knight 3, Wizard 3 |
| Gunner | Mercenary 4, Knight 4, Ranger 4 | Warmage | Scoundrel 3, Mender 3 **(check: one guide says Plague Doctor 3, Fellblade 4)** |
| Assassin | Gunner 4 | Gambler | Scoundrel 3, Mender 3 |
| Duelist | Peddler 3, Reaver 3 | Gadgeteer | Scoundrel 3, Wizard 3 |

The class levels go up to about 7 in these requirements. Mercenary and Mender are the starting pair, like FFT's Squire and Chemist.

### 6 badge classes

Each needs a crest item plus class levels. One badge unlocks the class for one non-story character and is used up.

| Class | Needs |
|---|---|
| Werewolf | Mercenary 4 + Lunar Crest |
| Vampire | Alchemystic 3, Scoundrel 6 + Blood Crest |
| Vessel | Mender 5, Wizard 5 + Bone Crest |
| Lich | Plague Doctor 4, Sorcerer 6 + Phylactery **(check: one guide lists Mender 5, Wizard 5, which matches Vessel)** |
| Lord | Templar 6 + Lord Crest (male characters) |
| Princess | Mender 7 + Princess Crest (female characters) |

### 6 story-unique classes (one story character each)

| Class | Character | How |
|---|---|---|
| Marked | Kyrie | story, after battle 5 (Gyaum Tor) |
| Demon Knight | Anadine | story |
| Spymaster | Reiner | easy-to-miss side quest. Copies the last ability used in battle. |
| Anatomist | Yates | starting class |
| Bounty Hunter | Katja | starting class |
| The Exiled | Kairu | optional character, found at Lodestarhenge after finding the 4 Henge Fragments |

### DLC "Missions and Monsters": 3 classes, plus monsters

| Class | Needs |
|---|---|
| Wrangler | Knight 3, Mender 3 + its mission (after the Azure Fields story battle) |
| Beastmaster | Mercenary 5, Ranger 5, Mender 4 + its mission |
| Samurai | Knight 5, Ranger 4 + its mission |

- **Taming:** Beastmaster and Wrangler mostly tame and recruit monsters.
- **Monster classes:** monsters have their own class system with 20+ variants. Therva, Daodrenner and Vangal unlock automatically; the rest need 5 essences each. With the DLC, a monster can take up to 2 subclasses.
- **Bzil classes:** Bzaro can use every Bzil class and nothing else.

Totals: 32 human classes in the base game (20 basic, 6 story, 6 badge), 3 more in the DLC, and over 200 abilities.

## AP (Fell Seal's JP)

These come from the wiki and forums; check them in the game.
- **Per battle:** each deployed unit gets a base of about 140 AP. It is less when the party's average level is above the map's level, and story battles give ×1.75.
- **Main class only:** AP goes to the main class, never the subclass.
- **Benched units:** they get a smaller share, about half per one guide **(check)**.
- **Vicarious learning:** every unit gets 15% of the battle's base AP in each class that a deployed unit used, including classes it hasn't unlocked yet.
- **AP costs:** each ability's AP cost is unknown here. Players call 500+ AP for a class's last abilities a lot. The exact costs come from the data check.
- **Game options:** `GameOptions.txt` has options such as AP gain, but the names are unknown.

## Mastery bonuses (examples)

| Class | Bonus |
|---|---|
| Mercenary | HP, DEF |
| Knight | HP, DEF, RES |
| Mender | HP, MND, RES |
| Wizard | MP, MND, RES |
| Vessel | MP +5, MND +5, +5 water/fire/earth/thunder resistance |

Fell Seal's stats (HP, MP, ATK, DEF, MND, RES, SPD …) need a mapping to BG3, like FFT's.

## Engine plan: one hybrid rule set (recommended)

Fell Seal alone has 32+ classes and 200+ abilities. Together with FFT's 20 jobs, that is far too much to level the FFT way in one BG3 playthrough. So the plan is one set of rules for every class from both games, taking from each what fits BG3 best:

| Piece | From | Why it fits BG3 |
|---|---|---|
| Points mostly per fight and from XP, plus a smaller per-action share | both | BG3 has fewer, bigger fights, and its XP already reflects how hard they were. The current Classic preset already works this way. |
| **Shared learning:** 15% of every gain also goes into all other classes | Fell Seal | Keeps 50+ classes from becoming a grind. **Done:** in the FFT mod since 2026-10-11 (`JP.Shared`, see `DESIGN.md` sections 6 and 7). |
| Class level = abilities learned | Fell Seal | One rule for classes from both games, easy to read on the Job Board. FFT's JP thresholds stay available as a setting. |
| Main class's passives always on, plus free passive slots, 1 reaction and 1 movement slot | both | BG3 has real reactions; FFT brings the movement slot. |
| Mastery bonus for every class | Fell Seal | A small permanent reward for finishing a class, so finishing some classes matters without needing all of them. |
| **Class packs** switched on or off per save: FFT, Fell Seal basic, badge, story, DLC, monsters | new | Choose how long the class list is; test one pack at a time. |
| **Party-wide unlocks** (option) | new | Unlocking a class once unlocks it for the whole party: the biggest cut in grind when there are many classes. |
| About 6-8 abilities per class | new | Fewer spells on the hotbar, less JP to master, less to build: keep each class's best abilities. |
| Look-alike classes merged or linked | new | Knight/Knight, Archer/Ranger, White Mage/Mender, Black Mage/Wizard, Thief/Scoundrel, Samurai/Samurai, Ninja/Assassin, Mime/Spymaster: either one class with abilities from both games, or two classes that share more JP with each other. |

Engine work still needed (later):
- level mode "abilities learned";
- slots with counts and automatic class passives;
- mastery grants;
- class packs and party-wide unlocks;
- badge requirements (items);
- merged or linked classes.

Equipment by main class works through each class's built-in passive, as for FFT jobs.

## Monster classes: ideas

In Fell Seal, monsters are units with their own classes, and BG3 has no monster party members. Ways to let normal BG3 characters use them:

1. **Essence hunting** (closest to Fell Seal, where most monster classes unlock with 5 essences):
   - defeating BG3 creatures of a family gives an essence, and 5 essences unlock that monster class for anyone;
   - each Fell Seal monster family maps to a BG3 creature type, e.g. Arpia to harpies, Cadaver and Mummified to undead, Draekon and Bulldrake to drakes. The full list comes from the game files.
2. **Monster arts** (like Final Fantasy's Blue Mage):
   - a monster class works only as the secondary skill set: your character uses that monster's abilities (a breath, a web, a charge) without changing shape;
   - optional twist: you learn a monster ability by being hit by it while that class is equipped.
3. **Monster forms** (like Wild Shape):
   - as the main class, a monster class turns you into that monster, with its abilities, and gives small perks in normal form;
   - this fits Fell Seal's Werewolf and Vampire badge classes too.
4. **Tamers:**
   - Beastmaster and Wrangler (DLC) summon a tamed monster, using BG3 summons;
   - its abilities come from the monster classes you have unlocked, and it gets stronger as that class levels.
5. **Monster passives:** the simplest version. Monster classes are short (3-5 abilities), mostly passives and counters that any class can put in a free slot.

Suggested order: 1 and 2 first (essences unlock monster classes, used as secondary skill sets); add 3 and 4 later if they are fun. To check when we get there: reading a defeated enemy's creature type with the Script Extender.

## Questions for the user (when we get there)

1. **Hybrid rules:** is the plan above OK?
   - Should FFT jobs keep FFT's JP thresholds, or should everything level by "abilities learned"?
2. **Party-wide unlocks:** on or off by default?
3. **Look-alike classes:** merge them, or keep both and link them?
4. **Badge classes:** find or craft crests in BG3, buy them from a vendor, or just require higher class levels?
5. **Story classes:**
   - give each to a BG3 origin companion;
   - let anyone unlock them;
   - or skip them.
6. **Monster classes:** which of the ideas above?
7. **MP:** same open question as for FFT.
8. **Stats:** how Fell Seal stats and mastery bonuses map to BG3.

## Data check (local run on the user's PC)

Like FFT, the numbers above come from guides and get checked against the installed game.

**What to get:**
- every class with its exact unlock requirements;
- every ability with its AP cost and type (active, passive, counter);
- the mastery bonuses;
- the AP rules.

**Where it is (community reports, confirm locally):** Fell Seal is a Unity game with plain-text data. It is installed through Steam (user, 2026-10-11): Steam → Fell Seal: Arbiter's Mark → Manage → Browse local files opens the game folder.
- **Data files:** `Jobs.xml` (classes) and `Abilities.xml` (every active, passive and counter, for every class and monster) are in the game's StreamingAssets folder.
- **Copies:** `Documents\Fell Seal\customdata_examples\` has copies of the default files; it appears once the game has run.
- **Text:** in language files such as `abilities.txt`.
- **Mods:** they go in `Documents\Fell Seal\customdata`; leave it empty.

**Rules:**
- Read only.
- Never copy game files, text or art into the repo. Bring over only the numbers and names, write our own descriptions, and name the source as "Fell Seal game data" with the game version.
- Like FFT: no mod content. Nexus has custom-class packs; never use them as a source.

## Sources

- [Classes, official Fell Seal wiki (Fandom)](https://fellseal.fandom.com/wiki/Classes): class lists, requirements, slots
- [Ability Points, official Fell Seal wiki](https://fellseal.fandom.com/wiki/Ability_Points): AP base, story ×1.75, vicarious 15%
- [Mastery Bonus, official Fell Seal wiki](https://fellseal.fandom.com/wiki/Mastery_Bonus)
- [Badges, official Fell Seal wiki](https://fellseal.fandom.com/wiki/Badges), [Vessel](https://fellseal.fandom.com/wiki/Vessel)
- [Story Characters, official Fell Seal wiki](https://fellseal.fandom.com/wiki/Story_Characters), [Passives](https://fellseal.fandom.com/wiki/Passives)
- [Neoseeker: Unlocking Classes](https://www.neoseeker.com/fell-seal-arbiters-mark/class/Unlocking_Classes), [Class/Build Guide](https://www.neoseeker.com/fell-seal-arbiters-mark/class/Class_Guide), [EXP and AP](https://www.neoseeker.com/fell-seal-arbiters-mark/class/Exp_and_AP)
- [Steam guide: Class Chart](https://steamcommunity.com/sharedfiles/filedetails/?id=1721025712)
- Steam discussions: [secondary classes](https://steamcommunity.com/app/699170/discussions/0/1676938384260469342/), [AP for secondary class](https://steamcommunity.com/app/699170/discussions/0/1733216261951374709/), [class AP](https://steamcommunity.com/app/699170/discussions/0/1733216261942741196/), [class mastery](https://steamcommunity.com/app/699170/discussions/0/1813170373231999441/), [passive slots](https://steamcommunity.com/app/699170/discussions/0/1727575977542373192/)
- [PSNProfiles trophy guide](https://psnprofiles.com/guide/10075-fell-seal-arbiters-mark-trophy-guide): badge requirements (one conflict, see Lich)
- DLC: [GameBanshee](https://gamebanshee.com/38849), [Xbox Tavern review](https://www.xboxtavern.com/fell-seal-arbiters-mark-missions-and-monsters-review/), [Nintendo eShop](https://nintendo.com/en-gb/DLC/Fell-Seal-Arbiter-s-Mark-Missions-Monsters-1801804.html)
- Data files and modding: [Steam: Modding 101](https://steamcommunity.com/sharedfiles/filedetails/?id=1525239791), [Steam: custom class name](https://steamcommunity.com/app/699170/discussions/2/3220528325735426325/), [Steam: GameOptions.txt](https://steamcommunity.com/app/699170/discussions/2/3491891042505670483/)
