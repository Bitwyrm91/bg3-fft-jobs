# Fell Seal: Arbiter's Mark: research for a later BG3 pack

Research only (cloud session, 2026-10-11). **Not part of Part B: nothing here gets built yet.**

Roadmap (user, 2026-10-11):
1. Test the 6 FFT jobs in BG3.
2. Add the other 14 FFT jobs.
3. Then bring in Fell Seal: Arbiter's Mark (6 Eyes Studio, 2019) and its classes.

The user owns Fell Seal on their PC. Cloud sessions can't read it, so a local run must check the numbers below against the game (see "Data check").

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

## What the engine would need (later)

The engine is data-driven, so most of Fell Seal is data. These parts need code:
1. **One rule set at a time.** Pick FFT or Fell Seal per save in the config, each with its own data file, IDs and point pools. Recommended over running both at once.
2. **Level mode "abilities learned":** class level = number of abilities learned, instead of point thresholds.
3. **AP sources:**
   - per-battle AP (the victory source already exists);
   - lower AP when the party out-levels the enemies (BG3 has enemy levels);
   - a "big fight" multiplier;
   - a camp share;
   - the vicarious rule (15% of base AP into each class used in the fight). This is new; FFT's spillover is per action.
4. **Slots with counts:** 2 automatic main-class passives, 2 free passives and 1 counter, replacing FFT's 1 reaction, 1 support and 1 movement.
5. **Mastery grants:** a permanent passive per mastered class.
6. **Equipment by main class:** BG3 proficiencies through the class's built-in passive (FFT jobs already have one).
7. **Badge unlocks:** an item requirement (how badges are found in BG3 is open, see below).

## Questions for the user (when we get there)

1. One system per save (recommended), or FFT and Fell Seal at the same time?
2. **Badge classes:** find or craft crests in BG3, buy them from a vendor, or just require higher class levels?
3. **Story classes:**
   - give each to a BG3 origin companion;
   - let anyone unlock them;
   - or skip them.
4. **DLC:**
   - Samurai is easy.
   - Beastmaster and Wrangler could become summon-based classes, since BG3 has no monster recruiting.
   - Monster classes would be skipped.
5. **MP:** same open question as for FFT.
6. **Stats:** how Fell Seal stats and mastery bonuses map to BG3.

## Data check (local run on the user's PC)

Like FFT, the numbers above come from guides and get checked against the installed game.

**What to get:**
- every class with its exact unlock requirements;
- every ability with its AP cost and type (active, passive, counter);
- the mastery bonuses;
- the AP rules.

**Where it is (community reports, confirm locally):** Fell Seal is a Unity game with plain-text data.
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
