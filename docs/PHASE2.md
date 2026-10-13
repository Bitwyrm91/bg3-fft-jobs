# Phase 2: every FFT job, Fell Seal rules, the Soul Collector

The user's decisions of 2026-10-12 (a long Q&A in the coordinator chat) and the plan for a **fresh local session** to build them. Read `STATUS.md` first for the state of the mod (1.0.0.5 installed and working in game).

## Ground rules (user)

- **Get things in the game and working.** Looks and art come later.
- **No icons for now:** new abilities borrow a fitting vanilla icon. The icon pipeline (DESIGN section 8, "Icons") is ready for when the user asks.
- **Preserve usage:** work in batches, keep context lean (read only what a step needs), don't re-derive what this file and STATUS.md already say.
- **Never push to GitHub unless the user says so.** Commit locally.
- **Install only with BG3 closed** (`tools\install.ps1`). After an install, the user tests. Read the newest SE runtime log and use `tools\se_console.ps1` for in-game checks (STATUS.md has how).
- Spell looks: borrow a vanilla spell of the same element through `using` and override everything it lends (DESIGN section 8; `tools/vanilla_spell.py`).

## Decisions

### Jobs: everything from every FFT version
1. The **14 remaining TIC jobs**: Monk, Thief, Orator, Mystic, Time Mage, Geomancer, Dragoon, Summoner, Samurai, Ninja, Arithmetician, Bard, Dancer, Mime. Costs and unlocks come from the TIC game data, checked the same way as the first 6 (`tools/check_fft_data.py`, FF16Tools, `C:\Users\berus\GameModding\decomp\fft`).
2. **War of the Lions:** Dark Knight and Onion Knight, as late bonus jobs (their numbers come from WotL guides).
3. **Special character jobs**, about 15-18: Holy Knight, Divine Knight, Sword Saint, Fell Knight, Ark Knight, Machinist, Skyseer, Netherseer, Templar, Dragonkin, Steel Giant, Soldier, Princess, Cleric, Astrologer, Sky Pirate, Game Hunter. Confirm the list against the data and guides.
   - **Unlock Fell Seal style:** a badge item dropped by a fitting BG3 boss **plus** job-level requirements.
   - Propose which boss drops which badge to the user before building it.
4. **Bard and Dancer are open to everyone** (FFT's male/female locks are dropped).
5. **Mime = Echo action:** on its turn the Mime can repeat the last ability an ally used this round, ignoring that ability's cooldown. FFT's automatic out-of-turn echo would misbehave in BG3's turn order.

### Rules
6. **Job levels keep FFT's JP thresholds.** The user's view: in practice it comes out the same as Fell Seal's "1 level per ability learned". Job level gives no power by itself; it drives unlocks and adds 2 JP per action per level.
7. **Fell Seal mix, all four ideas chosen ("I love it"):**
   - **Mastery bonus:** mastering a job gives a small **themed** permanent perk that stacks and stays after switching jobs. Examples: Squire +5 max HP, Knight +1 to Constitution saves, Archer +1 m range. One perk per job: noticeable, never game-breaking.
   - **Main job's passives always on:** support and movement abilities learned in the main job work without a slot. **Reactions need the reaction slot** (user, 2026-10-12: as in Fell Seal, where counters always need the counter slot).
   - **Slots, Fell Seal style (user, 2026-10-12):** 1 reaction slot + **2 free passive slots** that take any support or movement ability (replaces FFT's support + movement slots).
   - **Party unlocks, revised (user, 2026-10-12: "make sure there are job level requirements for the character using it"; chose "see it, wait for levels"):** a job one character unlocks shows as unlocked by the party on everyone's Job Board, with what each character still needs. Learning its abilities and taking it as job or secondary need the character's **own** job levels (FFT / Fell Seal rule). JP from spillover and shared learning keeps collecting in it.
   - **Equipment:** the main job grants its own proficiencies (Knight: heavy armour + shields while Knight is the main job); FFT's "Equip X" supports carry a proficiency to other jobs.
   - Already in: shared learning (15%, the jobs used in combat).
   - **Magic cost (user, 2026-10-12):** keep cooldowns, no MP bar.
   - **Thief (user, 2026-10-12):** Steal takes **real loot** from enemies (gold, the item itself; Steal Heart charms); quest and story items can't be stolen.
   - **Badges (user, 2026-10-12):** one per boss, found once for the **whole party**; each character still needs the special job's job levels.
   - **Batch 2 (user, 2026-10-12):** Geomancy: **terrain decides** (each learned Geomancy ability only works on its terrain or BG3 surface: Torrent on water, Magma Surge on fire/lava, Snowstorm on ice, Quicksand on mud, Tanglevine on grass, ...). Dragoon Jump: **leap and strike now** (Horizontal Jump = reach, Vertical Jump = height). Summoner: espers **spare allies** (damage hits enemies only, healing espers allies only). Orator's Entice: **the enemy fights for you on its own (AI-controlled) for 2 turns** of the battle; bosses immune.
   - **Arithmetician (user, 2026-10-12):** Arithmeticks hit **everyone whose number fits, like FFT** (allies too); the magick is **loaded on the Job Board** and each rule (Prime, Multiple of 3/4/5) is a button.
8. **Later Fell Seal phase:** keep the look-alike classes as separate jobs but **link** them (JP earned in one also feeds its twin, about 50%). **Never two jobs with one name:** rename the Fell Seal one (Knight → Defender, etc.).

### The Soul Collector (the monster job; user's name)
9. **A job on the Job Board.** Proposed names: Devour Soul; Soul Incarnation (the transformation); Soul Codex (the list of forms on the Job Board); Soul Known (the marker on enemies). The user may rename them.
10. **Unlock:** a special chest on the nautiloid near where the intellect devourer ("Us", the brain ally) can be recruited. It holds an item that **unlocks the job for the whole party when picked up**.
    - My default for saves already past the nautiloid (like the user's test saves): the item appears in the camp traveller's chest.
11. **Devour Soul is a killing blow:** a damaging attack; if it kills the target, the party devours its soul essence and can take its form at will (within the charges).
12. **Targets:** monsters, goblinoids (goblins, gnolls, bugbears, …) and **all bosses**, humanoid ones too (Minthara, Nere, Dror Ragzlin, Ketheric, Orin…). Boss forms are toned down, with the boss's signature moves. Ordinary humans/elves/dwarves only if needed to fit more FFT monsters.
13. **Souls are party-wide:** a shared Soul Codex; any party member with the Soul Collector job can use every collected form.
14. **Two forms per devoured BG3 monster type:**
    - **The BG3 monster itself,** with new skills scaled to its power. A goblin gets one or two weak, annoying skills (e.g. dust in the eyes) and maybe one reaction or passive. A nautiloid demon gets more and stronger abilities.
    - **An FFT monster** mapped by theme **and** tier: early FFT monsters (Chocobo, Goblin, Bomb, Skeleton, …) come from early BG3 monsters, late ones (Behemoth, Dragon, Hydra, Tiamat, …) from late BG3 monsters. FFT's roster lines up well: Goblin ↔ goblins, Floating Eye ↔ Spectator, Dryad/Treant ↔ twig blights, Mindflayer family ↔ mind flayers / intellect devourers, Skeleton/Ghoul ↔ undead, Bull Demon/Minotaur ↔ minotaurs, Chocobo ↔ owlbear or harpies (the user: a goblin should not give a Chocobo; keep it relevant).
    - **Propose the full mapping table to the user before building the forms.** Pacing is my call.
15. **Forms work Wild Shape style:** the monster's body, HP pool, natural attacks and physical stats, **scaled to the character's level** (a level 10 character's goblin form has level-10 numbers). Spells and gear are locked while transformed; you revert at 0 HP or by choice.
16. **Limits: charges like Wild Shape.** My default: 2 per short rest, more at higher job levels. Transforming is a bonus action in combat, free outside.
17. **Soul essences (Fell Seal):** devouring more of the same type powers up its form. My default: 1 soul unlocks the form, 3 souls add an ability, 5 souls a stronger one.
18. **Marker:** a status on enemies whose type the party has already devoured (e.g. "Soul Known").
19. **Models:** each FFT form uses a fitting BG3 creature model for now; real models later.

### Enemies get jobs too (user: "the new fun shouldn't be limited to only players")
20. **Humanoid enemies** (goblins, drow, duergar, bandits, cultists, …) get **jobs like players do**, chosen to fit the enemy: a goblin brute is a Squire or Thief, never a Black Mage; a goblin archer an Archer; a priestess a White Mage.
21. **Monsters** keep their BG3 skills **and** get a fitting **FFT monster class** (the monster skills of their FFT family, from the same mapping table as the Soul Collector). A monster never gets a human job (a Chocobo-like enemy is never a Squire).
22. **Strength: like a player.** An enemy's kit is what a player of the same level would have with that job or monster class. **Bosses get extra special stuff** on top (e.g. an advanced or special job, signature abilities).
    - Keep it configurable (off / lighter / as designed). This makes fights noticeably harder.
23. **Visible:** a marker status on each enemy ("Job: Archer", "Monster: Chocobo") so the player can plan, as FFT shows every unit's job.
24. **Comes last**, after the Soul Collector (the user's choice).
    - Check early whether BG3's AI uses spells added with `AddSpell` (it should; verify on one enemy before building it all).

### Order and place
25. **Order:** all the jobs first (14 TIC, then Dark Knight + Onion Knight, then special jobs with badges), **then** the Soul Collector, **then** enemy jobs.
26. **Where:** a fresh local session (this file is its brief).

## Build plan (each batch: data → stats → Lua → tests → package → install → the user tests)

1. **Rules engine** (item 7, plus badges): party-wide unlocks, the main job's passives always on, main-job proficiencies (innate passives per job), mastery perks (data per job), badge requirements (item held/used) alongside job levels. Mock tests for each. Retune the presets for 20+ jobs with `tools/pacing_sim.py` (the user's pacing rule: a normal playthrough should master a good share; every number stays in config).
2. **TIC jobs, in batches of 3-4,** checked against the game tables. Keep each job's FFT ability list; where BG3 can't do something, write the nearest fair version and say so in the description. Mime: Echo action (item 5).
3. **Dark Knight, Onion Knight.**
4. **Special jobs + badges:** propose the boss → badge table to the user first.
5. **Soul Collector:**
   - research BG3 shapeshifting in the extracted data (Wild Shape statuses, shapeshift rules, how a form's stats and spells are set, level scaling) and reading a dead enemy's type/template with SE;
   - then Devour Soul, the Soul Codex (Job Board section + transform list), forms with charges, essences, the marker, the nautiloid chest and its camp-chest fallback;
   - the mapping table goes to the user first.
6. **Enemy jobs** (items 20-24):
   - assign a job (humanoids) or an FFT monster class (monsters) per enemy template/type when combat starts or the level loads, scaled like a player of the enemy's level; bosses get extras;
   - add the marker status and a config switch;
   - first check that the AI uses added spells.

## Open details (defaults above; the user can change them)
- Do the main job's reactions also work without the slot? (Default: no.)
- How many transformation charges, and how they grow with level?
- Soul essence steps (default 1 / 3 / 5).
- Which boss drops which badge; which BG3 monster maps to which FFT monster.
- The camp-chest fallback for the Soul Collector item.
