# STATUS — BG3 × FFT job system

Handoff between sessions. Read this first, then `BRIEF.md` (Part B) and `DESIGN.md`.

**Cloud handoff (2026-10-14):** the user continues in a Claude Code cloud session (their cloud usage). Start with
`CLAUDE.md` (the user's rules, what the cloud can't do) and the project skill `.claude/skills/bg3-fft-jobs/SKILL.md`.
State at handoff: 1.0.0.60 on `main`, installed on the user's PC, tester zip 1.0.0.60 made; nothing unverified is
pending locally except the in-game checks listed in PLAYTEST.md (1.0.0.55-60).

**Where the work is:** `main` (the cloud branch `claude/game-modding-research-setup-qgn88h` was merged on 2026-10-12).

## Next week's patch — "NWP" (user, 2026-10-13; notes only, nothing started)

When the user says "NWP", this is the list:
1. **Samurai: possibly switch to Fell Seal's Samurai abilities** (https://fellseal.fandom.com/wiki/Samurai#Abilities).
   "Possibly": ask before replacing the TIC Iaido set (Ark Knight shares the Samurai's spells, so check it too).
2. **New job: Assassin, from Fell Seal** (https://fellseal.fandom.com/wiki/Assassin). Ask where it sits in the tree
   (unlock requirement, group) and whether it is renamed (earlier rule: Fell Seal classes linked to FFT look-alikes
   get renamed).
3. **Ninja replaced by the classic WoW Rogue** (stealth, combo points?, poisons, Sinister Strike, Backstab, Eviscerate,
   Kick, Sap, Vanish, Sprint...). Design questions first: keep the Ninja name/tile or a new "Rogue" job, Ninja's
   unlocks and dual wield, how combo points work in BG3 (an action resource?), what happens to saves with Ninja
   learned.
4. **Keep improving the Job Board** (Future changes 1 and 10 below: dropdown groups, built in 1.0.0.61; the progress bar is already gone).
5. **Soul Collector development PAUSED** (Future changes 4, 5, 8 wait: JP-cost forms, form strength). Its job is left out of the hotbar job menus of 1.0.0.55 (user: "anything related to soul devourer should be for NWP").
6. **NEW BG3 BASE CLASS: the WoW Warlock** (user, 2026-10-13: "NWP - create a WoW warlock as a base class in BG3"; a
   SEPARATE mod, not part of FFTJobs; WoW-style, not D&D, under a new cool name). How BG3 classes are built:
   `C:\Users\berus\GameModding\notes\BG3_CLASS_MODS.md` (from the user's Death Knight / Succubus / Blood Mage mods).
   Spell ideas, numbers and demon models come from the DOS2 Warlock (memory "warlock-mod",
   C:\Users\berus\DOS2Modding\mods\Warlock, tools\warlock-spells.ps1). Ask design questions first (name, subclasses,
   soul shards as a custom resource, spells per level).
7. **[BUILT in 1.0.0.55, not seen in game] Change jobs and learn abilities through BG3's own UI** (user, 2026-10-13: "I'd love that"). MCM (option A) does NOT
   do it: it is drawn with the same SE IMGUI as our Job Board (settings only). Native route = spell containers (the
   flyout menus of Wild Shape / Chromatic Orb): a "Change Job" container with one subspell per job (locked ones greyed
   out by RequirementConditions on a hidden FFTJ_JobOpen_<Job> passive, or refused by Lua), the same for "Secondary
   Skill Set", and per-job "Learn" containers whose subspells are the abilities (JP cost in the tooltip; dynamic text
   via `Ext.Loca.UpdateTranslatedString`). Casting = Service:SetPrimary / Learn. Optional extras: level-up screen
   picks (Progression selectors added at runtime) and Job Mastery feats. The Job Board stays for overview at first.
   User's budget for it: ~5% weekly; weekly was 89% when asked, so it waits for a fresh session after the reset.
8. **Collaboration with another Claude agent on a different PC** (user, 2026-10-14: "use CIC if that's easiest to
   setup to be shared with another claude agent from a different PC, basically a collaboration dump for when one of
   us makes changes it automatically goes to the github"). Goal: every change from either PC lands on GitHub by
   itself, so the other agent always starts from the latest. **CIC = Claude in Chrome** (user's answer, 2026-10-14).
   It drives the user's Chrome (pages, clicks, forms); it does not move git changes between PCs, so the sync is still
   the pieces below; Chrome can do the web-only steps (collaborator invite, GitHub settings). Ask the rest of the
   design first. Likely pieces: auto-push after each local commit (git post-commit hook,
   or a step in tools/release.py) - this replaces the "never push unless asked" rule, so confirm it; each agent pulls
   (rebase) before it starts and before it pushes; a GitHub Actions workflow running tools/run_tests.sh +
   `build.py --check` on every push (the cloud session ran these tests on Linux before); straight to main or short
   branches + pull requests?; the other PC needs access to Bitwyrm91/bg3-fft-jobs (collaborator invite) and its own
   paths (env.sh, decomp\bg3 for the vanilla checks, BG3 install for package/install); generated files are committed,
   so both run build.py before committing; binary icons (art/icons/*.jpg) can't be merged, so one side owns art.
   STATUS.md stays the handoff both agents read first.
**NWP additions after the first multiplayer playtest of 1.0.0.55 (user, 2026-10-14; the user and a friend, MP):**
9. **[SKIPPED by the user, 2026-10-14: "the JB is working fine"; half-done code parked on the local branch
   `nwp-9-parked`, not built or tested]** **Learn menus: no way to see current JP** while learning from the hotbar menus (the "<name> has N <job> JP to
   spend" ExtraDescription line did not show or update). Ideas: JP in the Learn container's own name/description,
   or an overhead/notification line when a Learn menu opens.
10. **Show JP gains above the head**, like the floating "+HP" numbers (research the Osiris/SE call for overhead
    text; maybe a short-lived status with the amount, or DisplayText).
11. **New separate mod: skip the nautiloid**, start at level 2 on the beach.
12. **Multiplayer support**: works in MP but "weird stuff". Fixed in 1.0.0.56: Dummy/Player tabs (character-creation
    placeholders). **1.0.0.63 (not seen in game):** the Job Board opens only for the player who asked, each player
    changes only the characters they control (user's pick), party news reaches every player. Still to watch: the JP
    line per client (Learn menus, item 9).
13. **Throw Stone: no animation when the friend uses it** (MP client). 1.0.0.57 gave it the player throw animation; not seen in game.
14. **Enemies get jobs** (already planned, PHASE2.md).
15. **Learn entries cast from the hotbar don't seem to work** (user: not a huge priority). Log of 2026-10-14 01:47 UTC
    (MP session): every job change came from the Job Board ("Job Board: ..."); NO "Not done:"/menu cast at all, so
    CastedSpell never reached Service:OnMenuSpell for a menu entry. Check: are the children castable (greyed?), does
    CastedSpell fire for container children (try the Change Job entries too), is the event's spell name the child
    ID, does it matter that the caster is a client player? Use `tools\se_console.ps1` + a cast test.
16. **Shadowheart's portrait changed** (screenshot: a short dark-haired woman with horns, not her own); the user wants
    "something sexy" for her portrait. Find out why it changed first (a mod? the MP save?).
17. **Chemical Mixup: no throw animation** (at least in MP). Fixed with 13 in 1.0.0.57; not seen in game.
18. **[BUILT in 1.0.0.62, not seen in game] Highest-stat scaling step 2** (1.0.0.56 did damage + heals): hit chance and save DCs
    from the highest ability. User's answers (2026-10-14): weapon skills keep the weapon's stat to hit; the highest
    ability is chosen again at level-up only. The Chemist flasks follow it too (general rule).

**NWP additions (user, 2026-10-14, cloud session):**
19. **Job equipment limits, FFT rules** (user: "If you're a knight, you should only be able to use knightly weapons").
    User's answers: hard lock (gear the main job can't use comes off and can't go back on, with a message; a config
    switch turns it off); weapons, shields AND armor; what counts = the main job's `equip` list (TIC "Usable
    Equipment", already in data/fft_jobs.json) + the FFT "Equip X" supports slotted (EquipAxes, EquipSwords,
    EquipShields, EquipHeavyArmor, EquipCrossbows, EquipPolearms, EquipGuns, EquipKatana; user: "be a White Mage but
    use the Squire skill Equip Axes"); BG3 class proficiencies do NOT count. Estimate given: ~2-3% weekly, 1-1.5 h.
    User: "continue with the normal list first". Open: clothes/robes (no armor proficiency) always allowed?; the
    Mime's empty list (FFT Mimes wear no weapons); cursed/story items that can't come off; check needs item fields
    (weapon proficiency group, ArmorType, shield) verified in game.
20. **[APPROVED 2026-10-14, build right after the Monk (21)] Chemist weapon coatings**, ONLY the Chemist's four
    effects (user): Venom Oil = Poisoned, Naphtha Oil = Burning, Acid Etch = Acid, Glass Grit = Bleeding, plus
    **Strange Fluid** (user's name and text: "You coat your weapon in a strange liquid and believe." = the Mixup Oil
    effect: each hit adds one of the four effects the target lacks). Not chosen: Holy Water, Slumber Resin, Field
    Alchemy. Estimate given: ~2-3%, 1-1.5 h. Original idea (user idea: "toxins applied to weapons... enchant your allies' weapon"). Brainstorm in
    chat, user to pick: Venom Oil (+1d4 poison, Poisoned on a failed Con save), Naphtha Oil (+1d4 fire, Burning), Acid
    Etch (+1d4 acid, Acid), Glass Grit (+1d4 slashing, Bleeding), Mixup Oil (each hit adds a missing Chemist effect),
    Holy Water (+1d6 radiant, double vs undead/fiends), Slumber Resin (first hit: Wis save or Asleep), Field Alchemy
    (support: +2 turns, area coat at slot 3+). Shared rules proposed: toss to an ally within 9 m, 3 turns, one coating
    per ally, saves vs your spell DC, free once per short rest + a spell-slot version with the 1-6 level picker.

21. **[NEXT] FFT Monk martial arts** (user, 2026-10-14: "make sure monk deals increased dmg while unarmed"; it already
    has Brawler = CharacterUnarmedDamage(1d6) + 1 to hit, mastery +1d4, unverified in game). User's picks: the extra
    unarmed die grows with character level (1d6 -> 1d8 at 5 -> 1d10 at 9), unarmed hits use the higher of Str/Dex
    (BG3 Monk's Dextrous Attacks), a bonus-action unarmed strike after attacking. ~1%.
22. **Archer -> Ranger with Fell Seal's Ranger skills** (user, 2026-10-14; build after the coatings). User's answers:
    keep the job id `Archer` (Thief, Ninja, GameHunter, SkyPirate, Machinist, Nightblade unlock through it), name
    Ranger, skillset Survival; replace all 13 Archer abilities with the 10 Fell Seal ones (docs/NWP_FELLSEAL.md,
    Ranger); JP = AP x 2.5 (Rooting Shot 0 = startLearned, Balm 250, Scout 500, Collect Pelt 500, Know Weakness 500,
    Rain of Arrows 625, Evasion Up 500, Multishot 750, Countershot 625, Sniper Shot 1000; total 5250 ~ the Archer's
    5300); saves that learned Archer skills get their JP refunded as unspent Ranger JP; gear bows, crossbows, light
    armor (no axes); keep Equip Crossbows, ADD a new Equip Bows support (so other jobs can use bows), keep the mastery
    perk (+1 ranged attack); Jump +1, Aim 1-20, Speed Surge, Archer's Bane, Concentration go. Proposed BG3 mapping
    (user saw it, no objection; MP costs -> cooldowns): Rooting Shot = bow shot + can't move 1 turn on a failed save;
    Balm = touch, removes Poisoned/Bleeding/Blinded/can't-move/Silenced/Asleep/weakened; Scout = reveal traps within
    6 m + crit on 19-20 for 3 turns; Collect Pelt = weapon hit, a beast/monster killed by it gives a rare crafting item
    and can't be revived, bosses immune (like Thief's Poach); Know Weakness = crit on 19-20; Rain of Arrows = weapon
    damage in a line; Evasion Up = +1 AC; Multishot = weapon damage in a small area (hits allies too); Countershot =
    reaction: shoot back when a ranged attack hits you; Sniper Shot = 3x weapon damage, self can't move until the
    next turn, once per long rest. Mark the abilities `source: custom` / Fell Seal so tools/check_fft_data.py and the
    TIC pacing data skip them; re-run the pacing self-test. Estimate given: ~4-6%, 2-3 h.

**Queue (user, 2026-10-14):** Monk (21) -> coatings (20) -> Ranger (22) -> 7 (menu learn diagnostics) -> 10 (JP above
the head) -> 8 (two-PC sync; CIC = Claude in Chrome) -> 4 (Job Board) -> 14 enemy jobs LAST. 19 (equipment limits,
~2-3%) waits for the user's go. Session rules from the user: do NOT push or publish until the user says so (commit
locally, tell the user about every change); tell the user when each item is done; usage estimate before each.

Samurai + Assassin data (pasted by the user): docs/NWP_FELLSEAL.md. Note: Fandom pages answered 402 to WebFetch before (2026-10-13); if they still do, try the browser pane or another
Fell Seal source.

## Future changes (user, 2026-10-13; mod work PAUSED by the user, nothing below is started)

1. **Job Board: "Jobs and special jobs should be a dropdown menu."** Each group (Jobs, Special jobs; probably the
   Monster job too) collapses/expands. Plan: own toggle buttons ("[-] Jobs (22)" / "[+] Special jobs (24)") with the
   open state in `JobBoard.OpenGroups[id]` (kept between redraws and board openings), drawn in `JobBoard:RenderTiles`
   instead of the `AddSeparatorText` title. Reason not to use `AddCollapsingHeader`: the board is rebuilt on every
   click (`self:Render`), and whether SE v33's CollapsingHeader keeps its open state across a rebuild, or has
   `DefaultOpen`/`OnExpand`, is unverified. Update `tests/test_bosses.lua` (special_jobs_have_their_own_section_...
   looks for the SeparatorText title). Ask the user: which groups start open (proposal: Jobs open, Special closed).
2. **Console test helper (user asked how to spawn and kill something for a test):** add `!fft_soul spawn <type>`
   (the type's BG3-form template beside the host via `Game:SpawnNear`, remembered as the test target) and
   `!fft_soul kill` (FFTJ_SOUL_BRAND from the host, then `Osi.ApplyDamage(target, 999, "Force", host)`), so a soul can
   be devoured without a fight. Until then the raw SE console lines in the reply of 2026-10-13 do it (server context:
   `H = Osi.GetHostCharacter(); X,Y,Z = Osi.GetPosition(H)`, `G = Osi.CreateAt("<root template>", X+3, Y, Z, 0, 1, "")`,
   `Osi.ApplyStatus(G, "FFTJ_SOUL_BRAND", 6, 1, H); Osi.ApplyDamage(G, 999, "Force", H)`).
   **User's try (screenshot, 2026-10-13): failed with "X is nil"** — the first line was typed before the console
   was in Lua mode (no `S >>` prompt; "Entering server Lua console." came after it), so it never ran. Press Enter on
   an empty line until `S >>` shows, then run the lines; or one line:
   `H = Osi.GetHostCharacter(); X,Y,Z = Osi.GetPosition(H); G = Osi.CreateAt("35e843cf-bc73-4754-aaee-fd8272d99ea6", X+3, Y, Z, 0, 1, "")`.
4. **Soul forms far too strong (user screenshot: a level 1 Imp kill gave a form with Wounding Ray 4d8+3 necrotic,
   18 m, Eyestalk Action).** Cause: the Imp's F form (Ahriman) borrows the Spectator body 319efbbe, and the Wild Shape
   rule we use (WildShapeKeepName 9c580a1d) has `ApplySpellsFromTemplate=true`, so a form gets the body's whole
   vanilla kit. Same body: Spectator B, Quasit F; every form on a creature (non-Wild-Shape) template may carry its
   kit. Fix idea: own shapeshift rule with `ApplySpellsFromTemplate=false` (only our skills; check the unarmed attack
   from `UnarmedAbilityFromTemplate`), test at the menu + a load first (custom data files crashed before, cf. DOS2
   Alignment); audit every form's template kit/HP.
5. **Soul forms should cost JP to learn, not be learned automatically.** Now Rules.DesiredGrants (Rules.lua ~792)
   grants both forms at soul tiers 1/3/5. Plan: devouring a soul makes its forms *learnable* on the Soul Collector's
   board page (only devoured types listed), Learn spends Soul Collector JP (costs in config), grants only learned
   forms. Size: medium, not huge (one session: Rules + board list + Learn message + config + tests). Ask first:
   cost per form, do tier upgrades (3/5 souls) also cost JP, both forms bought separately?
6. Item 1 repeated by the user on 2026-10-13 (job + special job dropdowns).
8. **Mind flayer form ("squidraken") is "like an Act 2-3 god, way too strong in every way"** (screenshot: Extract
   Brain 10d10+6d6, 71 HP). Same cause as item 4 (body's vanilla kit copied); also cut its HP/damage. Rebalance
   every soul form for the act it comes from.
9. **Console helper confirmed wanted:** the spawn line worked; the user killed the goblin by hand and wants a
   command that applies Soul Brand and kills the target (item 2's `!fft_soul kill`).
10. **Job Board UI "needs work, going in a good direction":** REMOVE the job-level progress bar entirely (user: "I
    don't need a progress bar for job levels"); keep a plain text line like "Level 2 at 200 JP", nothing clipped.
11. **Heals too strong for easy skills** (screenshot: Hi-Potion = Heal 4d4+4 once per short rest). User: make the
    potion/heal tiers small steps up; the strong versions should need a spell slot. Audit every heal (Chemist
    potions, White Magicks Cure line, Cleric/Princess copies, Salve, Chakra, etc.) against BG3 potions/Cure Wounds.
7. **GitHub:** pushed up to 1.0.0.60 on 2026-10-14 (user: "publish zip"; earlier 1.0.0.55 + tag backup-1.0.0.54-before-menus) at the user's request
   ("publish everything to github"); no GitHub release. Otherwise still no push / release until the user says so
   (NWP item 8 may change that). The repo is private. Tester zip: Documents\1Claude\FFTJobs-1.0.0.60-test.zip.

**State (2026-10-12, local run):** Part B is done up to the in-game playtest. Built, installed and enabled on the user's PC; at the main menu the mod loads, its client script runs without errors and all 100 stats entries are in the game. **Not seen in an actual game yet** (no save loaded, nothing cast): the server side, JP, the Job Board, every ability. Next: the user's playtest (`PLAYTEST.md`), then fix what they report, then the other 14 jobs.

**Version 1.0.0.2 (2026-10-12, user's request "something that gives me a bunch of job points so I can test without fighting everything"):** a free **JP Training (test)** spell (`Shout_FFTJ_JPTraining`, Inspiring Leader icon) and `!fft_train [amount]`: every party member gets `Test.JPPerCast` (1,000) JP in each job unlocked before the cast; config `Test.Tools` (true) hides it when false. 90 tests pass, `validate_vanilla.py` OK (27 references, 101 entries), packaged and installed (both modsettings copies at version 1.0.0.2). Not smoke-tested at the menu: the only new stats entry is a copy of the Job Board one (which loaded fine) plus a vanilla icon.

**First real game (2026-10-12, 11:10-11:25, the user's Honour Mode save, Act 2 camp, level 9 party; log `%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Script Extender Logs\Extender Runtime 2026-10-12 15-12-04.log`):** the server side loaded (1.0.0.2) with no errors; party tracked: Dan (Fighter/Bard → Squire), Soulbane (the Dark Urge, Warlock), Lae'zel (respecced to Druid), Shadowheart, Wyll (→ Chemist); summons skipped. JP Training cast 4 times worked (one summary each; every job Lv8 for everyone). The Job Board opened and Learn worked ("Lae'zel mastered Squire!"). One WARNING: `DB_IsPlayer` is nil.
**RESOLVED the same day (second game, new Rogue "Kholek Suneater", v1.0.0.3): not a grant bug.** `!fft_grants` said "in game" for all; server and client `SpellBook`, `AddedSpells` (`PrepareType` AlwaysPrepared, `SourceType` Osiris) and `HotbarContainer` all had Focus/Rush/Throw Stone/Salve, and BG3 placed them on the main hotbar (2-row bar, slots are column-major: slot 9 = column 5 bottom). They were invisible to the user because **they wear borrowed vanilla icons** (Focus = `Skill_Fighter_SecondWind`, the same as the Job Board; Rush = the main-hand attack dagger; Throw Stone = Fire Bolt; Salve = a potion flask) and look like normal BG3 actions; the spellbook lists Level 0 ones as Cantrips. Next: give every ability its own icon (distinct vanilla icons first, maybe custom FFT icons later). The original report follows. **Original report:** the user learned Squire abilities and says Squire was set ("I DID have the squire equipped") but saw no new skills. Not explained yet: the same `AddSpell` call made the Job Board and JP Training spells appear; the save could not tell (its entity data, mod variables included, is a binary "NewAge" ScratchBuffer, no plain strings). It may be the hotbar (level 9 hotbars are full), the user equipping Squire's passives rather than setting the job, or `AddSpell` failing for these spells.
**1.0.0.3 (installed, game closed):** `DB_Players`; the board says for each learned ability whether it is in use and what to do if not ("make this job the job or secondary", "equip it"), and so do the Learn / Set job / Secondary messages; every board click and every grant change is logged (`Job Board: ...`, `<name>: added ...; removed ...`); `!fft_grants [who]` lists what the jobs should grant and whether the game has each one. **Next game:** read the log after the user sets a job; run `!fft_grants`. "in game" = the spells exist but are not shown (look at the hotbar/spellbook; if they never appear, grant actions through passives with `UnlockSpell`); "MISSING in game" = `AddSpell` failed for them.

**1.0.0.4 (2026-10-12 ~12:40, built, installed with the game closed; NOT yet seen in game): every entry has its own icon.** The user chose AI-painted FFT-style icons ("try 2") over distinct vanilla ones. 79 pictures (71 abilities, Job Board, JP Training, an emblem per job) in `art/icons/*.jpg` from `art/icons/subjects.txt` (`tools/generate_icon_art.ps1` on the user's GPU; review sheets `tools/icon_sheet.ps1`; the Aim tiers carry a "+N" badge because four archers looked alike at 64 px; Rush, Rend Weapon, Esuna and Archer's Bane were redone for being too close to other icons). All 101 stats entries use `FFTJ_Icon_<key>`; package.ps1 builds the atlas, the texture bank and 316 tooltip/controller DDS files (`tools/make_icons.ps1`, layout in DESIGN section 8 "Icons"). 95 tests pass, `validate_vanilla.py` OK (19 references, 101 entries), pak 10.4 MB. **Seen in game 13:01 (screenshot): hotbar icons render** (Throw Stone, Rush, Focus, Salve, JP Training, Job Board). The user then asked for a weapon (not shield) Rush: redone (`seed=13` on its subjects line). **Check in game:** tooltip pictures, passives on the character sheet, buff icons on portraits.

**1.0.0.5 (2026-10-12, installed 14:12 with the game closed; committed locally only: the user said "forget github unless i say", so never push without being asked):** new Rush icon; spell looks matched to their element (DESIGN section 8, "The look comes from the using parent"): Thundara/Thundaga/Blizzaga/Death are `Target_` spells now (renamed; saves swap the old grant for the new one on load through `Grants.Apply`); Throw Stone is a rock throw and no longer a spell; Fira/Firaga explode at their own radius (ExplodeRadius); Job Board tooltips start indented past BG3's large cursor (user's screenshot: it hid the first word); `tools/vanilla_spell.py` shows vanilla spells through their `using` chain. 96 tests pass, `validate_vanilla.py` OK (27 references). **Check in game:** each new look, Blizzara needs a creature target (Ice Knife's projectile), Death refuses undead and constructs, a target killed by Flare leaves a body. If an icon shows as a blank/white square: the atlas or its texture bank is not picked up (compare with vanilla `Public/SharedDev/Content/UI/[PAK]_UI/_merged.lsf`); if only tooltips lack the picture: the `Public/Game/GUI/Assets/Tooltips/Icons/*.DDS` (BC3 under a DX10 header, vanilla is BC7) are not read.

**Phase 2 step 1 DONE (2026-10-12, v1.0.0.6, installed ~17:00 with the game closed, committed locally; NOT seen in game yet):** the Fell Seal rules from `docs/PHASE2.md` item 7 with the user's answers of the same evening: unlocks per character (the party sees them: `Meta.PartyUnlocked`, "Unlocked by the party; needs ..."), Fell Seal slots (reaction + 2 free passive slots; old saves migrate in `Rules.Normalize`), the main job's support/movement always on (`Rules.MainJobAlwaysOn`; reactions slotted), mastery perks (`FFTJ_Mastery_<Job>`, `Rules.MasteryPerks`), main-job equipment proficiencies on `FFTJ_Job_<Job>` (`equip` lists, `{{prof:Job}}`), party-wide badges (`badges` data, `Meta.Badges`, `!fft_badge`). DESIGN section 6, PLAYTEST "New in 1.0.0.6". 114 tests pass, `validate_vanilla.py` OK (27 refs, 107 entries). **Next:** the user tests (PLAYTEST list); step 2 (TIC jobs in batches of 3-4: Monk, Thief, Time Mage, Mystic first; re-tune the presets with all 20 jobs' costs from the TIC tables).

**Phase 2 step 2, batch 1 DONE (2026-10-12 evening, v1.0.0.7):** Monk, Thief, Time Mage, Mystic: 62 abilities (every TIC one; costs = TIC game data, `check_fft_data.py` 0 differences; lists = RPGSite; effects from the game's own `Ability-en` descriptions), job markers with equipment from the TIC job help texts (`UiJobAbilityHelp-en`: "Usable Equipment"), mastery perks (Monk +1d4 unarmed, Thief +2 initiative, Time Mage +1.5 m, Mystic +1 spell DC), Monk's innate Brawler. New `stats_src/Interrupt_FFTJ.txt` (Counter, First Strike, Mana Shield as interrupts modelled on Hellish Rebuke/Sentinel, Polearm Master, Deflect Missiles). New `Server/Effects.lua` + Osiris events StatusApplied/AttackedBy/KilledBy: real-loot Steal (GetEquippedItem/Unequip/ToInventory, story items excluded), Steal Gil/EXP once per creature (`Meta.Robbed`), Gravity/Graviga share of max HP (`Health.MaxHp`, ApplyDamage), bosses immune to Doom/Stop/Stone/Gravity (`Osi.IsBoss`), Gil Snapper, Poach; numbers in config `Abilities.*`. `validate_vanilla.py` now accepts status groups (SG_*). 124 tests, validate OK (113 refs, 205 entries), every function/flag value occurs in vanilla. **Unverified in game:** everything new, in particular the equipment slot names, `IsShield` (item `Data.StatsId` + `ModifierList`), interrupts, the Swiftspell variant status, OnMovedDistance passives, Doom's Kill on timeout. Pacing simulator: its party plans still list only the first 6 jobs (re-tune after all 20 jobs).

**1.0.0.8 (2026-10-12 ~18:00, installed):** the user's first look at 1.0.0.7 (screenshot): batch 1 unlocked and learned fine (log clean), but the board hid jobs not built yet ("I can't unlock new jobs") and was hard to read. New Job Board (the user chose the job grid): every job in the data as a coloured tile (built or "soon"), click for details (progress bar, Make job/secondary, equipment, mastery perk, ability table with icons and short coloured statuses), help in a collapsing header. View sends all 20 jobs (Built flag), icons via `Game:StatIcon` (Ext.Stats), FFT text per ability (`Fft`). IMGUI calls from the SE source header (BG3Extender/Extender/Client/IMGUI/Objects.h): AddIcon, AddProgressBar, AddCollapsingHeader, SetStyleColor, TextWrapPos, Window:SetSize; styling is pcall-protected. Learn message: no more "..". 124 tests. **Unverified:** how it looks in game.

**1.0.0.9 (2026-10-12 ~18:20):** user on 1.0.0.8 (screenshot): more usable, colours still plain, "Learned" rows too wordy, offered the PC's image generation for the board's looks. Found why no colours showed: the installed SE v33 names the call `SetColor` (its DLL has no `SetStyleColor`, which newer SE source uses); JobBoard.Style tries both. FFT blue theme set on the window (WindowBg, TitleBg, Header, TableHeaderBg, Button, PlotHistogram, Separator/Border gold); 13 new job emblems (Job_Mime failed: the AMD GPU reported 0 MB free after a stalled run; retry later) (art/icons/Job_<Job>.jpg, subjects.txt; Data.Jobs[].Emblem when the art exists) shown as AddImageButton tiles (Tint dims locked/soon); statuses "Learned"; progress bar gold, hidden at the top level. 125 tests.

**1.0.0.10 (2026-10-12 ~18:45):** user on 1.0.0.9: "looks way wayy better"; colours rendered much brighter than set → palette darkened (IMGUI colours are drawn brighter in BG3; tune by eye). Batch 2 started with the **Dragoon** (15 abilities, TIC costs 0 diffs): Jump = Projectile_FFTJ_Jump1/2/3/4/7 on Brutal Leap (range per Horizontal tier) + Projectile_FFTJ_JumpLanding (jump knockdown blast: weapon damage + best Vertical tier via HasPassive, prone; Dex save); new grant-variant condition `learned` (a lower tier grants nothing once a higher one is learned, tested); Dragonheart = Death Ward once per long rest; Ignore Elevation = jump +6 m and IgnoreFallDamage(). 126 tests. Next in batch 2: Summoner (designed in docs/BATCH2_DESIGN.md), Orator, Geomancer (research notes there too).

**1.0.0.11 (2026-10-12 late):** **Summoner** built from docs/BATCH2_DESIGN.md (17 abilities, TIC costs 0 diffs; espers spare allies via TargetConditions + AoEConditions; Golem = FFTJ_GOLEM TemporaryHP(15); Halve MP on OnShortRest). 126 tests, validate OK. Next: Orator, Geomancer (research pointers in docs/BATCH2_DESIGN.md).

**1.0.0.12 (2026-10-12 night):** **Orator** (14 abilities, TIC costs 0 diffs). Entice/Tame = FFTJ_ENTICED / FFTJ_TAMED `using DOMINATE_PERSON` (FactionOverride(Source) + LoseControl, no save-on-damage), 2 turns (4 with Tame equipped, grant variant equippedEffect Tame), Tame 10 turns on a non-humanoid at <=25% HP; both in Effects.BossImmune. Talk skills on Vicious Mockery / Heroism / Hypnotic Pattern (Mimic Darlavon) parents with SourceSpellDC saves; Defraud reuses the FFTJ_STEAL_GIL marker. Beast Tongue = Shout_FFTJ_BeastTongue (wraps Shout_SpeakWithAnimals_Barbarian). 126 tests, validate OK. Next: Geomancer (terrain decides; research first).

**1.0.0.13 (2026-10-12 night):** **Geomancer** (16 abilities, TIC costs 0 diffs) = batch 2 done. Terrain decides: `{{terrain:Key|Key}}` placeholder in tools/build.py expands to conditions on the caster (InSurface(..., context.Source) groups Water/Ice/Fire/Swamp/Plants/Oil, Plain = none of them, IsInSunlight, HasObscuredState Lightly/Heavily; Water also counts WET). Used in RequirementConditions (vanilla uses context.Source there too, e.g. HasObscuredState) and AoEConditions. Damage always lands (TIC: can't be dodged), LevelMapValue(D6Cantrip); ailment on a failed ManeuverSaveDC save at 25%/10%. Toad = FFTJ_TOAD using POLYMORPH_SHEEP, boss immune (could bring back Black Mage Toad / Maiden's Kiss from leftOut). Nature's Wrath = OnAttacked + SWAP damage (Armour of Agathys pattern). 126 tests (UI tests now use Samurai as the 'soon' job). Next: Samurai, Ninja, Arithmetician, Bard, Dancer, Mime (batch 3), pacing retune for 20 jobs.

**1.0.0.14 (2026-10-12 night):** **Samurai** (15 abilities, TIC costs 0 diffs; lists from RPGSite's TIC jobs guide, effects from TIC Ability-en). Iaido = Shouts on Arms of Hadar (enemies within 3 m, ManeuverSaveDC), Kiku-ichimonji = Zone on Lightning Bolt (12 m line), friendly ones on Mass Healing Word / the Golem shout. Bonecrusher = OnDamaged + SWAP below 25% HP; Shirahadori `using UncannyDodge`; Doublehand IF(HasVersatileTwoHanded()). Tests now use Mime (the last job) as the unbuilt example. Batch 3 plan (designs in docs/BATCH3_DESIGN.md): Ninja, Bard, Dancer, then Arithmetician and Mime (script work).

**1.0.0.15 (2026-10-12 night):** **Ninja** (16 abilities, TIC costs 0 diffs). Throws = Projectile_Javelin children, Dex save vs ManeuverSaveDC, damage dice + max(DexterityModifier,StrengthModifier) (vanilla form), OncePerTurn each, weapon item icons; bombs on Projectile_Fireball (2 m, no ignite). FFTJ_DualWield = TwoWeaponFighting();DualWielding(true);DualWielding(false), innate for Ninja and the 1000 JP support. Vanish = OnAttacked → FFTJ_VANISH (INVISIBILITY without the on-damage removal), OncePerCombat. Next: Bard, Dancer (docs/BATCH3_DESIGN.md), then Arithmetician and Mime.

**1.0.0.16 (2026-10-12 night):** **Bard** and **Dancer** (22 abilities, TIC costs 0 diffs). Performance = Shout on Song of Rest (concentration) applying FFTJ_SONG_*/FFTJ_DANCE_* for 3 turns (StackId FFTJ_PERFORMANCE); that status carries AuraRadius 9 + AuraStatuses "TARGET:IF(...):ApplyStatus(<key>_FX,100,-1)" (Aura of Protection / Spirit Guardians pattern); FX statuses reuse FOCUS / SPEED_SURGE / BLESS / REND_* or tick (StartTurn). Seraph Song: OnApplyFunctors RestoreResource(SpellSlot,1,1) + a 3-turn DONE marker so stepping out and back in doesn't farm slots. Finale = Golem shout + FFTJ_QUICK; Last Waltz = Ashura shout + FFTJ_DISABLE. Fly = Projectile_Fly wrapper (both jobs; two ability entries share the spell). Next: Arithmetician and Mime (script work; ask the user about the Arithmetician design first: docs/BATCH3_DESIGN.md).

**1.0.0.17 (2026-10-12 night):** **Mime** = Echo (user's design). tools/build.py generates Stats/Generated/Data/Spell_FFTJ_Echo.txt: a `<spell>_Echo` twin (`using` the spell, Cooldown "", name "Echo: <ability>") for every action spell of the other implemented jobs (186), plus Data.Echo. Service: TrackEcho (OnCastedSpell, in combat: last echoable ability + sequence number), OfferEcho (TurnStarted: char.Echo = twin if an ally used one since the Mime's last TurnEnded; Rules.DesiredGrants grants it), cleared after use, on TurnEnded (new Osiris listener, arity 1) and CombatEnded. Rules.IsMastered(data, char, job, cfg): a job without abilities is mastered at the top job level. Innate: Concentration, Brawler, Beastmaster (passive OnTurn;OnCombatStarted renews a 1-turn 6 m aura). 128 tests (Echo flow + Mime mastery); unbuilt example in tests = Arithmetician. 19/20 TIC jobs done; left: Arithmetician (ask the user), pacing retune.

**1.0.0.18 (2026-10-12 late night):** **Arithmetician** = all 20 TIC jobs implemented (user: hits everyone whose number fits; magick loaded on the Job Board). Build: Spell_FFTJ_Arith.txt = a free single-target `<spell>_Arith` twin (UseCosts/Cooldown empty, AreaRadius/ExplodeRadius 0, TargetConditions not Dead(), range 40) for every Target_/Projectile_ action spell of White/Black/Time Mage and Mystic (47), Data.ArithMagicks, Data.ArithRules. Server: SetArith (board op), CastArithmeticks (rule shout → Osi.UseSpell of the twin at every in-combat creature within 30 m whose number fits: Level / HP / MaxHP / distance; _Arith casts don't earn JP), Accrue EXP/JP on TurnStarted, EXP Boost at CombatEnded (Abilities.* config). View.Arith + JobBoard:RenderArith. Tests simulate an unbuilt job where needed. 131 tests. Next: pacing retune for 20 jobs, Mime emblem (ask about the GPU), then phase 2 step 3 (Dark Knight, Onion Knight).

**Pacing retune for 20 jobs (2026-10-13, scheduled run while the user was away; ships with the next installed version):** `tools/pacing_sim.py` plans now cover all 20 jobs along the unlock tree (`pick_job`: master the plan's jobs in order, level the missing prerequisite when the next one is locked; Mime mastered at job level 8 as in `Rules.IsMastered`; implemented jobs missing from a plan join its end), and the report shows jobs unlocked per act and when every job is open in the party. Target (user): a TYPICAL playthrough opens every job in the party by Act 3 and each fighter masters about half. New Classic = action ×0.8, 0.24 JP per XP, victory 25 + 2/level, long rest 40 (the old Fast); Fast 1.3 / 0.4 / 40 + 3 / 65; Grindy 0.45 / 0.13 / 14 + 1 / 20; PureFFT unchanged. Classic TYPICAL: 8-11 of 20 mastered per fighter, every job open at A2.25; LOW 5-7; HIGH 17-18. `--selftest` checks the new target. DESIGN section 14 regenerated, PLAYTEST "Changing how fast JP comes" updated. 131 tests pass.

**1.0.0.19 (2026-10-13, scheduled run; installed 03:13 with the game closed, not seen in game): Dark Knight** (War of the Lions, phase 2 step 3; data from Caves of Narshe's WotL pages: 9 abilities, 7,900 JP; `group` `WotL`, so `check_fft_data.py` and the pacing target skip it). New unlock kinds: `{job, mastered}` and `{kills}` (`char.Kills`, counted on `KilledBy` for the party member or the summon's owner, never for party deaths; Service:CountKill / CheckUnlocksNow, also after a mastery). Fell Sword: Sanguine Sword (weapon attack, heals half the damage done), Infernal Strike (weapon attack, FFTJ_REND_MAGICK + `RestoreResource(SELF,SpellSlot,1,1)`), Crushing Blow (Trip Attack's save pattern + FFTJ_STOP 1 turn), Abyssal Blade / Unholy Sacrifice (Arms of Hadar shouts, enemies only; the HP cost is taken on CastedSpell by Effects.OnCastedSpell, config `Abilities.AbyssalBladeHPCost` 0.1 / `UnholySacrificeHPCost` 0.25, never the last HP, Echo twins pay too; Abyssal Blade's nearest-enemy bonus via `IF(not DistanceToTargetGreaterThan(2))`, unverified in a SpellSuccess). HP Boost `IncreaseMaxHP(20%)`, Vehemence `CharacterWeaponDamage(1d6,Necrotic);AC(-2)`, Move/Jump +3 share the Bard/Dancer passives. Mastery: necrotic resistance. Job-count tests now follow the data. 134 tests, validate OK (197 refs, 639 entries), FFT check 0 differences.

**1.0.0.20 (2026-10-13, scheduled run; installed 03:16 with the game closed, not seen in game): Onion Knight** (War of the Lions; Squire Lv6 + Chemist Lv6; `group` `WotL`; no abilities, mastered at job level 8 like the Mime). Two engine features: job `levelGrants` (passives the main job gives by its job level, highest tier reached: `FFTJ_OnionKnight_5` = +1 AC, +1 attack; `FFTJ_OnionKnight_8` = +2 all abilities, +2 AC, +2 attack) and `noSlots` (`Rules.BlocksSlots`: while it is the main job, ActivePassives is empty and the secondary grants nothing; config `Rules.OnionKnightBlocksSlots`, default true). Equipment: simple + martial weapons, all armour, shields (new proficiency key `SimpleWeapons`). Mastery perk +1 AC. 135 tests, validate OK (643 entries), FFT check 0 differences. Phase 2 step 3 (WotL jobs) done.

**User's answers to the proposals (2026-10-13, three AskUserQuestion rounds; details in `docs/SPECIAL_JOBS.md` and `docs/SOUL_COLLECTOR_MAP.md`):** spared or recruited bosses still give their badge; keep the act spread and the proposed job levels; add the 7 extra TIC special jobs after the 17; a found badge = notification + Job Board for now (an item later); Worker 8's special job is named **Steel Giant** (the Soul form keeps "Automaton"); unmatched FFT monsters (Elder Treant, Blue Dragon, the hydras) become powerful Act 3 forms, but build the Act 1 forms first; the nearest fits and the Lucavi boss forms stay; Classic JP stays; the Dark Knight's area attacks hit everyone (**1.0.0.21**: `TargetConditions` = Arms of Hadar's own minus the dead); the Onion Knight keeps FFT's slot rule. **New Soul Collector rule (user): Soul Brand** replaces the killing-blow Devour Soul: a debuff that lasts 1 turn, can't be resisted and has no cooldown; a branded enemy that dies while branded gives up its soul.

**1.0.0.22 (2026-10-13, phase 2 step 4 started; built, installed with the game closed, NOT seen in game): boss badges.** The 17 special jobs are in the data as "soon" tiles (`group` `Special`, unlock = badge + the approved job levels). `Server/Bosses.lua` gives each boss's badge once: on `Died`, when the story's `DB_Defeated` lists the boss (read on load and after every fight: saves made before the mod count), when the boss joins the party (Minthara), or on reaching a later act (`levelActs`) after meeting the boss in a fight or in a dialog with a party member and leaving it alive (Zhalk: always). Boss GUIDs from the vanilla level data (extracted with Divine to `decomp\bg3\levels`, names checked in `decomp\bg3\loca`; table in `docs/SPECIAL_JOBS.md`). Config `Badges.FromBosses` / `Badges.SparedBosses`; `!fft_badge list` shows bosses and found/met. Requirement texts name the boss. 148 tests (new `tests/test_bosses.lua`; the made-up test special job is now "Test Knight"). **Unverified in game:** `DB_Defeated:Get(nil)` rows and their GUID format, `Died` / `DialogActorJoined` firing for these bosses, `GetRegion` after a reset. Next: the special jobs one by one, in act order (Cleric first).

**1.0.0.23 (2026-10-13; built, installed with the game closed, NOT seen in game): Cleric** (special job 1; Alma). TIC's Holy Magicks = the White Magicks + Alma's Dispelna (Caves of Narshe IC character page: Dispelna 0 JP, her only own ability). Built as: the 11 White Magicks the mod has, as Cleric abilities sharing the White Mage's spells (ids `Cleric<Id>`, TIC costs), the four the White Mage leaves out (Curaja `Shout_FFTJ_Curaja` on Mass Healing Word, Protectja/Shellja shouts on the Golem shout, Wall on Protect) and Dispelna (`Target_FFTJ_Dispelna` on Greater Restoration, every SG_ ailment group + the mod's FFT ailments). Innate `FFTJ_HolyMagicks` = Disciple of Life's OnHeal pattern for level 0 spells (+1d6). Equipment quarterstaffs, maces, light/medium armour; mastery radiant resistance. My choices (no FFT rule): the Cleric gets the group magicks so it is more than a White Mage copy; Dispelna an action once per turn. 150 tests, validate OK (206 refs, 656 entries).

**1.0.0.24 (2026-10-13; built, installed with the game closed, NOT seen in game): Fell Knight** (special job 2; Gaffgarion). TIC's Fell Sword = Shadowblade (100, absorb HP from a distant unit) and Duskblade (500, absorb MP), TIC `Ability-en` 164/165. New carrier for TIC's ranged knight sword techniques: `Zone_FFTJ_Shadowblade` on vanilla `Zone_Mag_WeaponAction_RazorGale` (MeleeWeaponAttack roll, flying slash) as a 6 m line (Shape Square, Base 1.5), recharge/requirement/ground functors cleared; Duskblade = Infernal Strike's effects at range. Mastery `CharacterWeaponDamage(1,Necrotic)`. New generic test `every_built_special_job_unlocks_learns_and_grants`. 151 tests, validate OK (207 refs, 662 entries). Unverified in game: a melee weapon attack roll from a Zone at 6 m, the slash look.

**1.0.0.25 (2026-10-13; built, installed with the game closed, NOT seen in game): Divine Knight** (special job 3; Meliadoul). TIC Unyielding Blade = Crush Armor 200 / Helm 400 / Weapon 500 / Accessory 800 (`Ability-en` 160-163: strike a distant unit and destroy that item). Built on the Fell Knight's 6 m slash; a hit applies `FFTJ_CRUSH_*` (technical markers) and `Effects.CrushItem` unequips the first item in the slots (Steal's slot lists) and drops it (`Osi.Drop`, new `Game:Drop`): my choice, so the loot isn't lost; story items hold. Mastery +1 Strength saves. 152 tests (new crush test), validate OK (209 refs, 676 entries). Unverified in game: `Osi.Drop` on an unequipped NPC item, whether the AI picks the weapon up again.

**1.0.0.26 (2026-10-13; built, installed with the game closed, NOT seen in game): Templar** (special job 4; Beowulf). TIC Spellblade = 14 arts (`Ability-en` 234-247, "channels magick through one's blade to ... a distant unit"), the same 14 effects as the Mystic's arts. Built as `Zone_FFTJ_Spellblade<Art>` on the 6 m slash: weapon damage + `IF(not SavingThrow(..., ManeuverSaveDC())):ApplyStatus(<the Mystic art's status>)`; Syphon = spell slot back, Drain = +2d6 necrotic and heal half, Faith no save, Dispel = Harmony's RemoveStatus list. Cooldowns follow the Mystic arts. Mastery +1 Charisma saves. 152 tests, validate OK (217 refs, 706 entries). My choices: ManeuverSaveDC (martial job) instead of the spell DC.

**1.0.0.27 (2026-10-13; built, installed with the game closed, NOT seen in game): Steel Giant** (special job 5; Worker 8, WotL name per the user; TIC Automaton "Tasks"). TIC `Ability-en` 351-354 Destroy / Compress / Dispose / Pulverize, 0 JP, recoil small / moderate / large. Built: melee ones on `Target_MainHandAttack`, Dispose on Guiding Bolt with a ranged weapon attack roll; recoil `DealDamage(SELF,(DamageDone)/4|3|2,Force)` (vanilla has DealDamage(SELF,...); DamageDone inside DealDamage is unverified in game). Innate `FFTJ_SteelBody` (poison resistance + SG_Poisoned immunity), mastery force resistance. 152 tests, validate OK (222 refs, 717 entries).

**1.0.0.28 (2026-10-13; built, installed with the game closed, NOT seen in game): Astrologer** (special job 6; Orran). TIC Astrology = Celestial Stasis only (`Ability-en` 168, 0 JP; Caves of Narshe IC). Built as `Shout_FFTJ_CelestialStasis` on Arms of Hadar's enemy burst, 12 m (FFT: the whole map), Wisdom save vs SourceSpellDC (as the other mage jobs), FFTJ_STOP + FFTJ_IMMOBILIZE + FFTJ_DISABLE for 1 turn, once per long rest. My additions so a one-art job is worth taking: innate `FFTJ_StarReading` (Initiative(3)), mastery StatusImmunity(SURPRISED). 152 tests, validate OK (224 refs, 722 entries).

**1.0.0.29 (2026-10-13; built, installed with the game closed, NOT seen in game): Sky Pirate** (special job 7; Balthier, WotL). Caves of Narshe WotL (Balthier): Piracy = Barrage 1200 + Plunder Gil 0 / Heart 250 / Helm 450 / Armor 550 / Shield 450 / Weapon 750 / Accessory 600 / EXP 350 (these costs are TIC's unnamed `Ability-en` 357-366). Plunder spells are children of the Thief's Steal spells with weapon damage + the same marker (Effects.lua steal); Barrage = one roll, 4 x MainMeleeWeapon/2. My choice: Plunder = steal + damage, so it differs from the Thief. Test fix: the generic special-job test skips the "needs its badge" check when the Act 1 boot already gave Zhalk's. 152 tests, validate OK (225 refs, 742 entries).

**1.0.0.30 (2026-10-13; built, installed with the game closed, NOT seen in game): Game Hunter** (special job 8; Luso, WotL). Caves of Narshe WotL: Luso has the Squire's abilities plus an innate poach. Built: the 4 Squire actions as shared-spell abilities (`GameHunter<Id>`), innate `FFTJ_Poach` (the Thief's support) + `FFTJ_MonsterHunter` (Colossus Slayer's OnDamage pattern, +1d6 vs not HUMANOID). Mastery Skill(Survival, 2). All 8 Act 1 / prologue special jobs are built. 152 tests, validate OK (226 refs, 745 entries).

**1.0.0.31 (2026-10-13; built, installed with the game closed, NOT seen in game): Skyseer** (special job 9; Rapha). TIC Sky Mantra = `Ability-en` 169-174 (Heaven's Wrath 0, Ashura 200, Adamantine Blade 300, Maelstrom 400, Celestial Void 500, Divinity 600: random strikes in an area by element). Built with a generator (scratchpad mantra.py, also for the Netherseer): Magic Missile carrier (Scorching Ray for fire), AmountOfTargets = bolts, no roll, per-bolt damage; Celestial Void = ApplyStatus(X,20,2) chances. Not IsSpell. My choice: aimed bolts instead of FFT's random strikes. 152 tests, validate OK (233 refs, 759 entries).

**1.0.0.32 (2026-10-13; built, installed with the game closed, NOT seen in game): Netherseer** (special job 10; Marach). TIC Nether Mantra = `Ability-en` 175-180, same shapes as the Sky Mantra. Same generator: d10 bolts (d8 at will) instead of the Skyseer's d8 (d6). My choice for FFT's faith rule (BG3 has no Faith): simply stronger dice. 152 tests, validate OK (233 refs, 773 entries).

**1.0.0.33 (2026-10-13; built, installed with the game closed, NOT seen in game): Soldier** (special job 11; Cloud). TIC Limit = `Ability-en` 257-264 (256 Vengeance is a Spellblade-type extra, not Cloud's). Lines on the slash carrier (Range 6/9), Meteorain and Cherry Blossom on the Time Mage's Meteor (Flame Strike) with ManeuverSaveDC Dex saves; HP-loss damage as bonus dice under 50% HP via `HasHPPercentageLessThan(50, context.Source|Target)`; Finishing Touch = Stop + 25% Stone (no instant KO). Mastery ReduceCriticalAttackThreshold(1). 152 tests, validate OK (234 refs, 791 entries).

**1.0.0.34 (2026-10-13; built, installed with the game closed, NOT seen in game): Holy Knight** (special job 12; Agrias). TIC Holy Sword = `Ability-en` 155-159. Slash carrier, radiant dice, ManeuverSaveDC saves for Stop/Doom/Silence/Confusion. My choice: Northswain's Strike's instant KO becomes 4d8 radiant (a `Kill()` could end scripted boss fights such as immortal Ketheric). Mastery StatusImmunity(SG_Frightened). All prologue/Act 1/Act 2 special jobs built. 152 tests, validate OK (237 refs, 803 entries).

**1.0.0.35 (2026-10-13; built, installed with the game closed, NOT seen in game): Machinist** (special job 13; Mustadio). TIC Aimed Shot = `Ability-en` 213-215. Ranged weapon attacks on `Projectile_MainHandAttack` (the Archer's carrier), ManeuverSaveDC saves; Seal Evil only on `Tagged('UNDEAD')` or `FFTJ_UNDEAD`. My addition for a three-art job: innate `FFTJ_EngineeredShots` (+1d4 on ranged weapon hits, Colossus Slayer pattern). Mastery Skill(Investigation, 2). 152 tests, validate OK (238 refs, 812 entries).

**1.0.0.36 (2026-10-13; built, installed with the game closed, NOT seen in game): Ark Knight** (special job 14; Elmdore). TIC: Sword Spirit (job 27) = katana spirits, Blade of Ruin (jobs 8/51) = `Ability-en` 196-199 (0 JP), Blood Drain 200. Built: the Samurai's Iaido actions as shared-spell abilities (`ArkKnight<Id>`), saps on the slash carrier with the Knight's Rend statuses for 10 turns (Magicksap = Silence: no MP in BG3), Blood Drain on Target_MainHandAttack healing DamageDone. Mastery +1 Dex saves. 152 tests, validate OK (239 refs, 824 entries).

**1.0.0.37 (2026-10-13; built, installed with the game closed, NOT seen in game): Princess** (special job 15; Ovelia). TIC Holy Magicks (job 12) without Alma's unique Dispelna. Built: the Cleric's 15 non-unique abilities as shared-spell abilities (`Princess<Id>`), innate `FFTJ_RoyalGrace` (Blessed Healer's OnHeal pattern, RegainHitPoints(SELF,1d6)). Mastery Skill(Persuasion, 2). My choice to tell her from the Cleric: the healing trait heals the caster. 152 tests, validate OK (241 refs, 827 entries).

**1.0.0.38 (2026-10-13; built, installed with the game closed, NOT seen in game): Dragonkin** (special job 16; Reis). TIC Dragon = `Ability-en` 248-255. Breaths on Zone_ConeOfCold / Zone_BurningHands / Zone_LightningBolt (Dex save vs ManeuverSaveDC, half on a save); Gift on our Cure, Might on our Protect (the Surge statuses), Speed on the Time Mage's Quick, Charm on the Orator's Entice limited to `not Tagged('HUMANOID')`. My choice: FFT's dragon/hydra-only support works on any ally. Mastery fire resistance. 152 tests, validate OK (245 refs, 845 entries).

**1.0.0.39 (2026-10-13; built, installed with the game closed, NOT seen in game): Sword Saint** (special job 17; Orlandeau) = **all 17 special jobs built**. TIC Swordplay = all sword techniques: the Holy Knight's, Divine Knight's and Fell Knight's 11 abilities as shared-spell abilities (`SwordSaint<Id>`). Mastery RollBonus(MeleeWeaponAttack,1). 152 tests, validate OK (245 refs, 847 entries). **Next:** the user's playtest of 1.0.0.22-1.0.0.39 (boss badges and the 17 jobs); then the 7 extra TIC special jobs (Gallant Knight, White Knight, Assassin, Sorcerer, Celebrant, Nightblade, Rune Knight; bosses and GUIDs in `docs/SPECIAL_JOBS.md`, Steel Watch Titan still to find), then the Soul Collector, then enemy jobs.

**1.0.0.40 (2026-10-13; installed with the game closed): robustness.** `Events.Register` wraps each `Ext.Osiris.RegisterListener` in pcall and logs `could not listen to Osiris <name>/<arity>` instead of aborting the remaining registrations (the new Died / DialogActorJoined / DialogEnded arities come from the story-header-generated list, not from this game version). 152 tests.

**1.0.0.41 (2026-10-13, second session; built, installed with the game closed, NOT seen in game): badges for the 7 extra TIC special jobs.** User's answers (AskUserQuestion): Gallant Knight = Squire mastered + any 5 badges (new unlock kind `{"badges": N}`: `Rules.BadgeCount`, requirement text "any 5 badges found", missing "(the party has N)"); Rune Knight = the Steel Watch Titan (found: `S_LOW_SteelWatcher_Prototype` 51db791d-4378-448a-86ba-3e3ae2748db6, Lower City); job levels as proposed; copy jobs share spells + own trait. Six boss badges (Malus Thorm, Kar'niss, Lorroakan, Raphael, Orin, the Titan) and 7 "soon" tiles; board section "Special jobs: badges from bosses + job levels"; boss reasons capitalised. The generic special-job test handles a badge count and mastered requirements. New helper tools: `tools/jobtool.py` (upsert jobs/badges/abilities/strings into the data files, layout kept) and `tools/release.py` (version bump + PLAYTEST/STATUS/SPECIAL_JOBS entries + build). 155 tests. **User (same day): stop at ~90% weekly; focus on a playtestable early game and finish the Soul Collector; the 7 jobs wait** (docs/SPECIAL_JOBS.md, last section).

**1.0.0.42 (2026-10-13, second session; built, installed with the game closed, NOT seen in game): the Soul Collector, Act 1.** New `data/souls.json` (26 Act 1 soul types from docs/SOUL_COLLECTOR_MAP.md, 2 forms each, 96 skills) and `tools/souls_gen.py` (called by build.py: `Spell_FFTJ_Soul.txt` / `Status_FFTJ_Soul.txt`, strings, `Data.Souls`). A form tier = POLYMORPHED status on Wild Shape's shapeshift rule `WildShapeKeepName` 9c580a1d (template body/HP/natural attacks, mental stats kept, gear off; `Public/Shared/Shapeshift/Rulebook.lsx` extracted to decomp\bg3\Shared) + `IncreaseMaxHP(Level*hp)` + `UnlockSpell` skills; StackId WILDSHAPE, groups SG_Polymorph_BeastShape (vanilla Dismiss works), WILDSHAPE_ACTIVE while in form; transform spells are children of `Shout_FFTJ_SoulIncarnation` (Shout_WildShape container pattern), cost BonusActionPoint + WildShape (refills on a short rest; `ActionResource(WildShape,2,0)` from the Soul Incarnation ability, job levels 4/7, Deep Reserves, mastery). Templates: Wild Shape player templates where they exist (dire wolf, spider, owlbear, badger, panther, sabre-tooth, dilophosaurus = Chocobo, deep rothe), else the creature's level template (twig blight borrows the myconid: Act 1 blights are spawned by script). Skills: melee on Target_UnarmedAttack with `LevelMapValue(WildShapeDamageLow/Medium)` (vanilla Wild Shape scaling), saves vs ManeuverSaveDC with cantrip dice. `Server/Souls.lua`: brand tracking (StatusApplied/StatusRemoved + 1.5 s grace, new StatusRemoved listener), Died → `Game:CreatureKeys` (GetTemplate + Data.StatsId + name, lower case) → `Souls.TypeOf` patterns → party `Meta.Souls` (copied into each char by Rules.SyncParty) → `Rules.DesiredGrants` grants both forms at tier 1/3/5 while Soul Incarnation is in use; FFTJ_SOUL_KNOWN on EnteredCombat. Soul Codex = a badge without a boss (`Rules.BadgeCount` counts boss badges only). Job Board: "Monster job" section + Soul Codex panel. `!fft_soul list|add <type> [n]|unlock`. 164 tests (new tests/test_souls.lua), validate OK (263 refs, 1281 entries). **Not built yet:** the Soul Codex item in a chest near "Us" on the nautiloid + camp-chest fallback (until then `!fft_soul unlock`), boss forms, Act 2-3 souls, "free outside combat". **Unverified in game:** NPC templates as player shapeshift forms (Wild Shape templates are safe), `Osi.GetTemplate` / `Data.StatsId` strings, Died vs StatusRemoved order, `ActionResource(WildShape,...)` on non-druids, `UnlockSpell` skills inside forms.

**1.0.0.43 (2026-10-13, second session; built, installed with the game closed, NOT seen in game): the Soul Codex is found in play.** `Souls.GiveCodex`: a party member and Us (`S_TUT_Lab_IntellectDevourer` 40bd6b82-2728-410a-bb8a-a805f98556a1, TUT_Avernus_C) in one dialog, or Us joining, gives the SoulCodex badge ("Beside the brain in the jar ..."); any level of act 1 or later without it gives it as found in the camp's traveller's chest (also on loading a later save). My choice for the budget: a notification + Job Board, like the boss badges (the user's rule for badges), instead of a real item in a chest (that needs a custom root template; later, with the art). 166 tests.

**1.0.0.44 (2026-10-13, second session; built, installed with the game closed, NOT seen in game): Act 1 boss souls; forms free outside fights.** 9 boss souls in data/souls.json (`boss: true`, `guids` = the boss characters; `Data.SoulByGuid` is checked before the creature patterns, so Gut is not a plain goblin; every skill at 1 soul): Zhalk, Ethel, Gut, Minthara (Gigas/Belias: Nanoflare, Dark Whisper, Grand Cross), Nere, Grym, W'wargaz (Red Dragon on the Wild Shape dilophosaurus: no red dragon is a level character), the Flind, the phase spider matriarch (`S_FOR_Bottomless_SpiderQueen`). Dror Ragzlin is not in the extracted levels: he counts as a Bugbear soul. Boss templates are the bosses' own level templates (unverified as player forms). Out of combat, a `Shout_FFTJ_Soul_*` cast gets FFTJ_SOUL_REFUND for 0 turns (`RestoreResource(WildShape,1,0)`). 35 soul types, 135 skills, 1415 stats entries, 168 tests.

**1.0.0.45 (2026-10-13, third session; built, installed with the game closed, NOT seen in game; the user chose "playtest later", so no game was run): the Soul Collector checked against the game's data and fixed.** New checkers: `tools/check_refs.py` (every status/spell/passive/parent/level map/resource/status group our 1415 entries name exists in vanilla: 0 problems) and `tools/check_souls.py` (Act 1 level characters → soul type the way Souls.TypeOf sees them in game, form templates exist and are characters, `templateHp` = vanilla Vitality; needs root templates extracted to `decomp\bg3\rt` with Divine + `english.xml`). Fixes: Soul Codex from the RIGHT Us (`S_TUT_Lab_TrappedDevourer` 6ca92237-eb1e-4ed8-a1ee-18b3bef21558 = the story's DB_PartyMembers/dialog speaker; the old 40bd6b82 is another lab devourer, both count now); Soul Incarnation `ContainerSpells` empty (a container shows its whole list learned or not, e.g. Disguise Self; the forms join by SpellContainerID as granted, like vanilla `Shout_END_AllyAbilities_MultipleSummon` and Wild Shape's Deep Rothe); new job field `startLearned` (SoulBrand + SoulIncarnation known at unlock; `Rules.LearnStart`, also repairs older unlocks in CheckUnlocks); templates: Myconid/Malboro/Greater Malboro/Twig Blight/Dryad borrowed `Duergar_Male_Civilian`, now Myconid_Slender / Myconid_Slender_Green / Myconid_Burly / BLIGHT_NeedleBlight_A / WoodWoad, Kuo-toa = BASE_Kuotoa (was an END ally), Minthara B = Elves_Female_Drow_Guard_Lolth_Melee (her own root is a player template without Vitality); body HP clamped (`hpRange` normal 12-50, boss 40-70, `IncreaseMaxHP(clamped - templateHp)`; Grym was 300); a vanilla icon per form (was Action_Shove x70); forms keep Soul Brand (`UnlockSpell`), add WILDSHAPE_TECHNICAL on removal; matching: hellsboars excluded from Boar (Act 3 Wild Boar per the map), Zhentarim ranger / duergar spider-master / BOOOAL (now Kuo-toa) false positives fixed; the out-of-combat refund only for form spells (`^Shout_FFTJ_Soul_%a+_[BF][135]$`), not skills; "an Imp soul". 168 tests, validate OK, check_refs 0, check_souls 0. Not covered by Act 1 souls (not in the approved map): Deep Rothé, kobolds, gremishka, ochre jelly, lava elementals, wood woads, mimics, bears, quasits, phasm, cambions/merregons (Act 3 Byblos).

**1.0.0.46 (2026-10-13, third session; installed with the game closed, NOT seen in game): grants wait while a form is active.** `Service:Reconcile` holds every grant change while the character has WILDSHAPE_ACTIVE (`PendingReconcile[guid]`, repair flag kept) and `OnStatusRemoved(WILDSHAPE_ACTIVE)` re-runs it with repair after `FORM_END_MS` (1 s) once the status is really gone: a polymorph swaps the spellbook (rule `RemovePrevSpells`), so AddSpell/RemoveSpell inside a form may not survive it (unverified either way; this is the safe order). New test `grants_wait_until_the_form_ends`; 169 tests. All 25 boss badge GUIDs checked against the extracted levels (right characters; scratchpad script, same method as tools/check_souls.py).

**1.0.0.47 (2026-10-13, third session; installed with the game closed, NOT seen in game): the Soul Codex item + 10 more Act 1 souls (user: "souls for uncovered act 1 creatures"; the codex "in a chest ... accessible right away without further restriction"; Soul Brand 0 JP = already so).** Codex: our first item root template, `Public/FFTJobs/RootTemplates/_merged.lsx` written by build.py from `souls.json` `codex` (MapKey 3ee4acf3-0164-4966-a312-2cdfdbfd19bf, parent BOOK_Wizards_Tome_Ornate_H 02f7446a (look, OBJ_Book via BASE_BOOK), maxStackAmount 1, DisplayName/Description loca handles) and converted to .lsf by package.ps1 (same loop as the texture bank). `Souls.PlaceCodex` on StartGameplay: no SoulCodex badge and no chest on this level yet → `Game:SpawnNear(CONT_MF_Chest_A 813c005f, host, 1.5)` (GetPosition + FindValidPosition(x,y,z,5,host,1) + `CreateAt(t,x,y,z,0,1,"")`) + `TemplateAddTo(codex, chest, 1, 0)`; meta.CodexChest/CodexLevel; CreateAt failing → badge at once. Osiris `TemplateAddedTo/4` (template, item, holder, addType) with a party holder → badge. The Us dialog/join route is removed. New souls (data/souls.json, map in docs/SOUL_COLLECTOR_MAP.md "Added"): DeepRothe, Kobold, Gremishka, OchreJelly, LavaElemental, WoodWoad, Mimic, Bear (`%f[%a]bear%f[%A]`), Quasit, Phasm; 20 new skills; F forms reuse family skill sets; "rothe" matched "brother" → `deep_rothe`/`deep roth`. 45 soul types, 1555 stats entries, 170 tests, validate/check_refs/check_souls clean. **Unverified in game:** the custom root template loading and its look, CreateAt/FindValidPosition on the nautiloid floor, TemplateAddedTo's holder for a looted item.

**1.0.0.48 (2026-10-13, small changes while paused, NOT seen in game):** Future changes 2/9 (`!fft_soul spawn <type>` / `kill`) and 10 (progress bar removed, text line instead) done; souls_gen exports `Template` per form.

**1.0.0.49 (2026-10-13, user request, NOT seen in game):** Chemist **Chemical Mixup** (custom, not FFT; 250 JP cantrip, no cooldown): Projectile_FFTJ_ChemicalMixup (rock-throw animation + acid bottle flask trajectory) applies FFTJ_CHEM_MIXUP on hit; Effects.ChemicalMixup picks fire/acid/poison/slashing at random, ApplyDamage 1d4 (+1 die at levels 5/10; config Abilities.Mixup*) and BURNING/ACID/POISONED/BLEEDING for 2 turns.

**1.0.0.50 (2026-10-13, user design, NOT seen in game):** Chemist **Chemical Burns** (Projectile_FFTJ_ChemicalBurns on the Mixup spell; FFTJ_CHEM_BURNS trigger; 3-turn recharge = FFTJ_CHEM_BURNS_CD on the caster + RequirementConditions, no numeric Cooldown in BG3) and the new Mixup rules (Effects.ChemicalMixup/ChemicalBurns, Game:HasStatus/StatusTurns/IsEnemy via Osi.HasActiveStatus/GetStatusTurns/IsEnemy; durations re-set by applying again: the four vanilla statuses have no StackType). Config Abilities.Mixup*/Burns*. Unverified: GetStatusTurns/IsEnemy in game, re-applying BURNING also deals its own 1d4 on apply.

**1.0.0.51 (2026-10-13, user: "dont reapply burning, just increase the duration"):** lengthening uses the vanilla functor `SetStatusDuration(<STATUS>,2,Add)` (in turns; Burns SpellSuccess; Mixup via technical FFTJ_MIXUP_EXTEND_<STATUS> with OnApplyFunctors); the 2 extra turns live in the stats now (config keys MixupFullExtendTurns/BurnsExtendTurns removed). Unverified in game.

**1.0.0.52 (2026-10-13, user design, NOT seen in game):** Chemist **Fulminate Flask**: spell (SpellSlotsGroup:1:1:1, recharge status FFTJ_FULMINATE_CD) applies FFTJ_FULMINATE; Effects.Fulminate applies FFTJ_FULMINATE_BLAST (OnApplyFunctors: 1d6 + IF(not SavingThrow(Con, SourceSpellDC())) → FFTJ_FULMINATE_STUNNED → BLINDED 1 + new FFTJ_DEAFENED 2) to every creature within Abilities.FulminateRadius (1 m, centre distance) or FulminateBurningRadius (2 m) if the target burns, + BURNING on enemies then. Burst hits allies too (it is a bomb); fire only enemies. No burst visual yet. Unverified: SourceSpellDC() inside a status, the save roll in game.

**1.0.0.53 (2026-10-13, user design, NOT seen in game):** Catalyst (Abilities.MixupCatalystAt 2), Saturation passive (FFTJ_SATURATE_* +1 turn on the shortest other effect, once per throw), Fulminate fire hits everyone (user rule: area effects hit allies unless specified), HitEffect 41de42e1 (Fireball/Alchemist fire). **Intelligence:** the three flasks are granted by hidden passives FFTJ_Int_<Ability> with `UnlockSpell(<spell>,,,,Intelligence)` (slot spell: `AddChildren,d136c5d9-0ff0-43da-acce-a74a07f8d6bf`), RangedSpellAttack; Fulminate save DC `CalculateSpellDC(Ability.Intelligence, context.Source)`. Damage dice unchanged (cantrip-style 5/10). Unverified in game: UnlockSpell via an Osiris-added passive, the DC inside a status.

**1.0.0.54 (2026-10-13, user design, NOT seen in game):** Chemist Caustic Flask + Unstable Flask (Effects.Bursts / Effects.FlaskBurst, config Abilities.FlaskBurstRadius 1.5; recharge statuses FFTJ_CAUSTIC_CD/FFTJ_UNSTABLE_CD 2 turns; Intelligence via FFTJ_Int_*). User dropped the Chain Reaction idea (never built); Catalyst + Saturation stay. Chemist: 19 abilities, 4990 JP.

**1.0.0.55 (NWP item 7, 2026-10-14, installed, NOT seen in game): job menus in BG3's own UI.** tools/menu_gen.py
(called by build.py) writes Spell_FFTJ_Menu.txt (569 entries): containers Shout_FFTJ_ChangeJob / Shout_FFTJ_SecondaryJob
(+ _None) / Shout_FFTJ_LearnFrom_<Job>, children join by SpellContainerID (the Soul Incarnation pattern; containers list
nothing). User's answers: regular jobs (no group + WotL) always listed, locked ones as greyed "???" (`_Locked` twin,
RequirementConditions on the never-granted passive FFTJ_MenuLocked, tooltip = requirement); special jobs only once
unlocked; Soul Collector left out (NWP); Learn menus for job + secondary only; not enough JP = refused with a
notification. Rules.AddMenuGrants (in DesiredGrants), Service:MenuSpells / OnMenuSpell (before JP awarding, so menu
casts earn nothing) / MenuJP + PushMenuJP (XP poll tick, sent on change over channel FFTJ_MenuJP), Client/JobMenu.lua
rewrites each job's ExtraDescription string (`menu.have.<Job>`) with the controlled character's JP via
Ext.Loca.UpdateTranslatedString (controlled character = ClientControl component; both unverified, pcall'd).
Learn entry icons = the ability's icon, resolved through our entries and data/vanilla_icons.json
(`python tools/menu_gen.py --vanilla-icons` after new vanilla parents). tests/test_menu.lua (5 tests), 184 tests.
Backup of 1.0.0.54: git tag `backup-1.0.0.54-before-menus`, pak in C:\Users\berus\GameModding\backups.
Unverified in game: container children staying off the hotbar, the order of entries (alphabetical by spell id, as
granted), greyed look of the ??? entries, the JP line refresh.

**1.0.0.56 (2026-10-14, installed only with BG3 closed, NOT seen in game): user's "changes to make NOW" after the
first multiplayer playtest of 1.0.0.55.** (1) Poisoned/Acid tick 1d4 (user: whole game) via Lua, not a stats
override: Effects.OnTurnStarted deals damage to any creature with the exact status POISONED/ACID at its turn start
(vanilla children like POTION_OF_POISON / CAMP_DAISY_SICK would inherit a stats TickFunctors); config
Abilities.PoisonTickDie / AcidTickDie; the client appends a sentence to the vanilla tooltips (UpdateTranslatedString).
(2) Highest-stat scaling step 1 = tools/scaling.py at build time: + max(max(max(Str,Dex),max(Con,Int)),max(Wis,Cha))
modifier on 234 dice/LevelMapValue DealDamage/RegainHitPoints formulas of Spell_FFTJ.txt (not weapon/unarmed, not
existing modifiers, not Chemist FFT items); descriptions of changed abilities get a sentence. Nested max() is
unverified in game (vanilla has max() with expressions inside). Step 2 (hit chance + DCs) after the weekly reset.
(3) Potion 1d4+2 (user's pick; items flat). (4) "Dummy"/"Player" Job Board tabs (MP character-creation placeholders,
tracked at new-game start on SYS_CC_I): no tracking on SYS_CC_* levels, placeholders (name Dummy/Player, not in
party or camp) are forgotten on load (Meta.Forgotten), new `!fft_forget <name|guid>`. tests/test_scaling.lua; 189
tests. Backup of 1.0.0.55: C:\Users\berus\GameModding\backups\FFTJobs-1.0.0.55.pak.

**1.0.0.57 (2026-10-14, not seen in game):** Phoenix Down = Level 1 + `SpellSlotsGroup:1:1:1` on top of its
OncePerShortRest (user). No throw animation (user's MP playtest): Throw Stone and Chemical Mixup used
Projectile_FOR_GnomeGoblin_ThrowRock, whose SpellAnimation fills one slot with a goblin-only animation, so player
characters showed none; both now carry vanilla Throw_Throw's SpellAnimation (the flasks inherit it from Mixup).

**1.0.0.58 (2026-10-14, not seen in game): Chemist upcasting (user).** tools/upcast.py (build.py, before the Echo
twins) writes Spell/Status_FFTJ_Upcast.txt: vanilla pattern `<root>_<N>` + RootSpellID + PowerLevel + level N slot.
Flasks: level N applies `<STATUS>_<N>`, Effects.SplitLevel reads N (Mixup N-1 extra dice + max(catalyst, N) effects;
Caustic/Unstable N-1 extra dice; Fulminate uses FFTJ_FULMINATE_BLAST_<N> = Nd6). Mixup/Caustic keep the free cantrip
+ a `<root>_Slot` root at level 2 (unlocked by their Int passives with AddChildren); Unstable Flask + Chemical Burns
now level 1 + slot (user); Fulminate variants 2-6. Potions: `<root>_Slot` level 1 = base dice + 1, +1 per level, no
cooldown, granted with base and thrown variants. Unverified in game: the upcast picker for spells granted by
AddSpell / UnlockSpell, Lua damage does not add the highest-stat modifier (scaling.py covers stats formulas only).

**1.0.0.59 (2026-10-14, not seen in game):** IsSpell on Projectile_FFTJ_ChemicalMixup (all flasks and upcasts inherit it) so Sorcerer Metamagic applies (user wants Twinned): vanilla TwinnedProjectileSpellCheck = single target, AreaRadius 0, SpellFlags.Spell, SpellType Projectile (CommonConditions.khn, now extracted to decompg3\scripts).

**1.0.0.60 (2026-10-14):** JP Boost nerfed to +20% (config JP.Boost.Multiplier 1.5 -> 1.2, user); tests pin their own 1.5. Tester zip FFTJobs-1.0.0.60-test.zip (user asked).

**1.0.0.61 (2026-10-14):** Job Board groups (Jobs / Special jobs / Monster job) are dropdowns = Future changes 1 /
NWP 4 (part): own toggle buttons "[+] <title> (N)" / "[-] ...", open state in `JobBoard.OpenGroups` (client, kept
while the game runs, not saved), all start closed (user's pick). Not AddCollapsingHeader (board rebuilt on every
click). Tests open groups through the toggles (test_ui findButton). Not seen in game.

**1.0.0.62 (2026-10-14, cloud session, NOT packaged or seen in game): NWP 18, highest ability for hit chance and
save DCs (user: weapon skills keep the weapon's stat; re-check at level-up only).** New `tools/statcast.py` (build.py,
after the Echo/Arith twins): every job spell (ability grants and variants, jobs' innate/level/mastery spells) and its
Echo twin get six hidden passives `FFTJ_Cast_<Str|Dex|Con|Int|Wis|Cha>_<spell>` = `UnlockSpell(<spell>,,,,<Ability>)`
(slot spells: `AddChildren,d136c5d9-0ff0-43da-acce-a74a07f8d6bf`), 3402 entries in Passive_FFTJ_Cast.txt; statuses with
a fixed `CalculateSpellDC(Ability.Intelligence, context.Source)` (the Fulminate blasts) get per-ability twins
(Status_FFTJ_Cast.txt, picked by Effects.Fulminate via Rules.CastStatus). `Rules.BestStat` (highest score; a tie in
modifier keeps the current one), `Rules.StatCastGrants` (end of DesiredGrants: job spells -> the passive of
`char.BestStat`), `Service:UpdateBestStat` (first Reconcile without a BestStat; LeveledUp + 1 s), `Game:AbilityScores`
(SE `Stats.Abilities`, None first: Strength = [2]; UNVERIFIED), `!fft_beststat [who|all]`, config
`Rules.HighestStatCasting` (true). scaling.py: ManeuverSaveDC() -> SourceSpellDC() at build time (51 lines of
Spell_FFTJ.txt; souls untouched). Chemist flasks grant their spells now (`castStat: Intelligence` = their stat when
the switch is off; FFTJ_Int_<X> kept as legacy for old saves); so they get Echo twins. upcast.py (user, same day):
Mixup/Caustic slot roots start at level 1 (picker 1-6), slot roots and levels carry the base Icon (the playtest showed
no icon on them). Grants on old saves: plain-added job spells are removed and the passives added on the first
Reconcile (hotbar may move once). release.py: --status now goes after the whole newest entry (it split 1.0.0.55-61,
fixed by hand). tests/test_statcast.lua (9), 201 tests. Unverified in game: Stats.Abilities indexing, the UnlockSpell
ability on DCs/attack rolls, the level picker with AddChildren (user: Potion (spell slot) "did nothing" in 1.0.0.61,
where it was added plainly), 3402 hidden passives' load time. Not covered: Arithmeticks twins (cast by the server
without a spellbook entry), Lua-rolled flask damage still adds no highest modifier.

**1.0.0.63 (2026-10-14, cloud session, NOT packaged or seen in game): NWP 12, multiplayer.** Job Board open goes to
the caster's player only: `NetServer.SendTo` = `NetChannel:SendToClient(payload, characterGuid)` in a pcall, Broadcast
if that fails. Ownership (user's pick: only the controlling player changes a character; config
`Rules.EditOthersInMultiplayer`, default false): the client sends `From` = its ClientControl character
(`JobBoard.Controlled`, via JobMenu.Controlled) with every board request; `Service:MayChange(from, guid)` compares
`Game:UserOf` of both (`Osi.GetReservedUserID`, else the UserReservedFor component); an unknown player on either side
allows it (single player). Views stay open to all. `Service:NotifyParty(text, preferred)`: party unlock / badge news
to one character per player (Game:UserOf), the host alone when no player is known. Mocks: c.user, world.controlled,
channel sentTo, world.notified. tests/test_multiplayer.lua (7), 208 tests. Unverified in game: SendToClient with a
character GUID, GetReservedUserID, ClientControl on a client in MP.

**1.0.0.64 (2026-10-14, cloud session, NOT packaged or seen in game): NWP 21, Monk martial arts.** Brawler tiers
`FFTJ_Brawler_5` (1d8) / `FFTJ_Brawler_9` (1d10) chosen by `Rules.LevelTiers` / `Rules.ApplyLevelTiers` from
`char.Level` (kept by Service:Reconcile from Game:CharLevel; re-reconciled 1 s after a level-up when it changed).
New Monk innate `FFTJ_MartialArts`: Dex-over-Str difference added to unarmed attack and damage rolls
(`IF(IsMeleeUnarmedAttack() and not HasPassive('MartialArts_DextrousAttacks')):RollBonus(Attack,max(0,Dex-Str))` +
`DamageBonus(...)`, no armour rule) and OnAttack `IsMeleeUnarmedAttack() and not SpellId('Target_FFTJ_MartialStrike')`
-> FFTJ_MARTIAL_ARTS 1 turn, which opens innate `Target_FFTJ_MartialStrike` (Target_UnarmedAttack, BonusActionPoint,
RequirementConditions HasStatus). Test `brawler_die_grows_with_character_level`. **Check locally:** validate_vanilla /
check_refs (the vanilla passive name `MartialArts_DextrousAttacks` is a guess, used only to skip the bonus for BG3
Monks; RollBonus with a max() formula). Unverified in game: all of it.

**Next (2026-10-13 evening, after 1.0.0.44; weekly usage 75%, the user stops this mod at ~90%):** the user's playtest of an early game (Act 1): the 1.0.0.22-44 badges, special jobs and the Soul Collector (PLAYTEST.md "New in" sections list what to watch; read the newest SE runtime log first). Then, if usage allows: enemy jobs for Act 1 (first check in game that the AI casts spells added with AddSpell, PHASE2.md item 24), Act 2-3 souls, the 7 extra special jobs (docs/SPECIAL_JOBS.md, last section), the Soul Codex as a real item (custom root template). Helper tools: `tools/jobtool.py`, `tools/release.py`; soul data in `data/souls.json` (`tools/souls_gen.py`).

**Special jobs: proposal written, NOT built (2026-10-13, scheduled run): `docs/SPECIAL_JOBS.md`** = the boss → badge table for the 17 special jobs (checked against the TIC tables `Job-en` / `JobCommand-en`: TIC calls Worker 8's job Automaton (WotL Steel Giant); Sky Pirate and Game Hunter are WotL only), proposed job levels, 7 more TIC special jobs to choose from, 5 open questions. The user approves before building.

**Soul Collector: mapping proposal written, NOT built (2026-10-13, scheduled run): `docs/SOUL_COLLECTOR_MAP.md`** = every devourable BG3 creature type (from the vanilla `Character.txt` entries) → an FFT monster from the TIC `Job-en` roster by theme and tier (family member 1/2/3 ≈ Act 1/2/3), a boss table (Lucavi forms for the big villains), 5 open choices (unmatched FFT monsters: Elder Treant, Blue Dragon, the hydras; nearest fits; the Automaton name clash). The user approves before building. Enemy jobs not started (as asked).

**Next (after the user's answers):** build the special jobs from `docs/SPECIAL_JOBS.md`, then the Soul Collector, then enemy jobs; the user's playtest of 1.0.0.19-1.0.0.20 (Dark Knight, Onion Knight, new JP numbers) and of batches 2-3.

**NEXT: phase 2, decided with the user on 2026-10-12. Read `docs/PHASE2.md`** (every FFT job from every version, Fell Seal rules, the Soul Collector monster job; build order and ground rules: no icons for now, no GitHub push unless asked, preserve usage).

FFT data source: **The Ivalice Chronicles** (the user asked for the recent remakes, not PS1); War of the Lions values where TIC is not published.

## Decisions made while you were away (2026-10-13 scheduled run)

The user asked this run not to ask questions. Every choice below is a default you can change; tell me which to redo.

1. **Pacing target, measured:** "opens every job by Act 3" = every job unlocked for at least one party member by the end of Act 3 (unlocks stay per character; the party sees them); "masters about half" = each of the four fighters masters 8+ of the 20 jobs in TYPICAL. Result: 8-11 mastered, every job open at fight 25 of Act 2.
2. **Simulated players:** one fighter (the Healer plan) chases Mime right after its first four jobs, as FFT players do; the others master their branch first. Without a Mime chaser no plan reaches Mime before mastering 19 jobs.
3. **Classic became the old Fast** (+60% JP) instead of raising one source: all four income sources keep their old proportions. Fast and Grindy keep their old ratios to Classic (≈1.6× and ≈0.55×). PureFFT stays FFT's own numbers as the reference.
4. **Dark Knight unlock = War of the Lions' rule unchanged:** Knight and Black Mage mastered, Dragoon / Samurai / Ninja / Geomancer Lv8, 20 kills. A kill = any creature outside the party defeated by that character (or its summon); kills before 1.0.0.19 were not counted. In the simulated TYPICAL playthrough nobody reaches the Dark Knight (it is WotL's end-game reward); HIGH players might.
5. **Fell Sword in BG3:** Sanguine Sword heals half the damage dealt (BG3's Vampiric Touch rule; FFT absorbs all of it) and is at will; Infernal Strike turns "absorb MP" into -2 spell attack/DC on the target and a level 1 spell slot for you (once per short rest); Crushing Blow hits one target (FFT's small area dropped) and Stops for 1 turn on a failed Constitution save (once per short rest); Abyssal Blade costs 10% of max HP (4.5 m, 3d8, 6d8 for enemies next to you; once per short rest); Unholy Sacrifice costs 25% (5 m, 8d8 + Slow; once per long rest). The HP costs never kill. ~~Both area skills spare allies~~ **User's answer (2026-10-13): hit everyone, as in FFT** (allies too; 1.0.0.21).
6. **Supports:** Vehemence = +1d6 necrotic on weapon hits and -2 AC (FFT: +50% attack, -50% defence); HP Boost = +20% max HP; Movement +3 / Jump +3 reuse the Bard's / Dancer's passives at WotL's 1000 JP. Mastery perk: resistance to necrotic damage. Equipment as the Knight.
7. **Onion Knight = FFT's rule:** no abilities and, while it is the main job, no slots or secondary (switchable: `Rules.OnionKnightBlocksSlots`). FFT's "terrible growth until Lv8, then the best" became two job-level tiers (Lv5 small, Lv8 big: +2 to all six ability scores, +2 AC, +2 attack). Its FFT-only Onion gear and "gains no EXP" are left out. Mastery perk +1 AC.

## Roadmap (user, 2026-10-11)

1. Test the 6 FFT jobs in BG3: Part B below.
2. Then add the other 14 FFT jobs.
3. Then Fell Seal: Arbiter's Mark and its classes (installed on the user's PC through Steam). The research and design ideas are in `docs/FELLSEAL.md`. Not part of Part B: don't start it.

## Part A (cloud, 2026-10-09): done

- [x] 1. Research + `DESIGN.md`: SE/Osiris APIs verified (section 2 says how), TIC data with sources, JP formulas, persistence, layout. Mod UUID **`3db7be3e-9387-4678-b172-044acc7ff0c2`** (never change it).
- [x] 2. Data: `data/fft_jobs.json` (all 20 TIC jobs with unlock rules, 6 implemented, 71 abilities with TIC JP costs and sources), `data/config_defaults.json` (every JP number + presets + help texts), `data/strings.json`. `tools/build.py` generates the Lua data module.
- [x] 3. Lua engine (`Mod/Mods/FFTJobs/ScriptExtender/Lua/`): JP from `CastedSpell`, `CombatEnded`, XP polling and `LongRestFinished`, with spillover and camp share; job levels, unlocks, learning; primary/secondary/reaction/support/movement; grant diffing with `AddSpell`/`AddPassive`/`ApplyStatus` that never removes what a character had before; JSON config + presets + 22 `!fft_*` console commands; ModVars persistence; telemetry log; IMGUI **Job Board** window over NetChannels; `meta.lsx` and SE `Config.json`.
- [x] 4. Stats + localization drafts: `stats_src/` → `Mod/Public/FFTJobs/Stats/Generated/Data/` (62 spells, 26 passives, 12 statuses), 180 English strings in `Mod/Localization/English/FFTJobs.xml`. `docs/vanilla_refs.md` lists every vanilla ID they rely on; `tools/validate_vanilla.py` checks them against the extracted game data.
- [x] 5. Tests: 86 Lua 5.4 tests in 7 suites (rules, config, engine events, save/load round trip, console commands, Job Board UI, data integrity) on a mock Ext/Osi (`tests/mocks.lua`). **Last run (2026-10-11): 86 passed, 0 failed**, both with Lua 5.4.6 and with Python + lupa 2.8.
  - Windows check by the desktop session (e6e1ddd, Windows 11, `core.autocrlf=true`): 78/79. The failure (`test_data :: every_localization_handle_exists`, "handles checked: 0") came from **CRLF line endings** in the checkout, not from path handling: the tests use a fixed file list, but a trailing `\r` broke the `data "..." "..."$` pattern. Reproduced in the cloud by converting a copy to CRLF. Fixed three ways:
    - `tests/test_data.lua` now ignores CR;
    - a new `.gitattributes` keeps LF in every checkout (verified: an `autocrlf=true` clone has 0 files with CR, 55 without it);
    - `tools/run_tests.ps1` now finds a real Python: `$env:PYTHON`, then `py -3`, then a python3/python that is not the Microsoft Store stub, then `uv run`. Without a Lua 5.4 executable it uses lupa, through `uv run --with lupa` if needed. The script was tested with PowerShell 7.6 (Linux): all checks pass, the filter argument passes through, and a stale build or a failing test exits 1. The CRLF copy also passes with Lua, lupa and the script.
- [x] 6. Pacing simulator `tools/pacing_sim.py` + preset tables (`DESIGN.md` section 14). **Classic** defaults: action JP ×0.5, XP share 0.15, victory 15 + 1/level, long rest 25, camp share 1/2, spillover 1/4, shared learning 15% into the jobs used in combat. LOW estimate: every fighter masters all 6 jobs by the end of Act 3; TYPICAL: 5 by the end of Act 2, all 6 in Act 3; HIGH: 4-5 in Act 1. Quick on purpose for the 6-job test; re-tune when the other 14 jobs are added.
- [x] Added 2026-10-11 (user's request): **shared learning**, Fell Seal's "vicarious learning" rule. 15% of every JP gain also goes into each of the character's other jobs that the party used in combat (the current fight, or the latest one), locked ones included (`JP.Shared`: `Share`, `Scope` `FightJobs` (the user's choice) or `AllJobs`, `RequireUnlocked`, per-source `Sources`; off in the PureFFT preset). Engine, simulator, 7 new tests, `DESIGN.md` sections 6, 7, 14 and `PLAYTEST.md`.
- [x] 7. `PLAYTEST.md` (for the user) and this file.

Run every check: `tools/run_tests.sh` (Linux/Git Bash) or `powershell -ExecutionPolicy Bypass -File tools\run_tests.ps1` (Windows). It runs the build check, the Lua suites and the simulator self-test. The Lua suites use a Lua 5.4 executable if there is one; otherwise they run under Python + lupa, fetched by `uv run --with lupa` when it is not installed. Direct alternative on the user's PC: `uv run --no-project --python 3.12 --with lupa python tools/run_lua_tests.py`.

## Verified vs. unverified

Verified in the cloud:
- Every `Ext.*` call and SE event used, against Norbyte's `Docs/API.md` and `ExtIdeHelpers.lua` (`DESIGN.md` section 3).
- Every Osiris call/event name and arity, against the story-header-generated `Osi.lua`/`Osi.Events.lua` (`DESIGN.md` section 4).
- The engine's logic, through the mock tests.

**Unverified (nothing ran in the game):**
1. **Stats drafts**: every `using` parent, status name, icon, functor/boost syntax (`Force(2)`, `RestoreResource(SpellSlot,1,1)`, `RegainHitPoints(1000)`, `IF(...)` in SpellProperties, `DamageReduction`, `JumpMaxDistanceBonus`, `Skill(Perception,2)`, `SpellResistance(Advantage)`, `ActionResource(Movement,-3,0)`, `TickType`/`TickFunctors`), the cooldown names (`OncePerTurn`, `OncePerShortRest`, `OncePerRest`), and the `OnDamaged` passives (who the functor targets). The `// VALIDATE` comments in `stats_src/` say what each entry should do and what to compare it with.
2. **Spells added with `AddSpell` to non-casters**: which ability modifier and DC they use. Magic is auto-hit or uses a saving throw to limit the impact. Alternative if needed: grant a passive with `UnlockSpell(<spell>,AddChildren,,,Intelligence)`.
3. `meta.lsx`: header version and empty Dependencies are copied from the common BG3 template. Also unverified: whether the stats parser accepts the generated files.
4. Party discovery: **seen in game 2026-10-12:** `Osi.DB_IsPlayer` is nil in BG3 (one WARNING); `GetAllEntitiesWithComponent("PartyMember")` found the whole party (5, all in camp at the time, summons skipped). 1.0.0.3 reads `DB_Players` instead (still unverified).
5. `CastedSpell` firing for weapon attacks, item use and Extra Attack: each counted cast earns JP. Also the jump spell's ID: `Projectile_Jump` is excluded from JP.
6. `Ext.Entity.Get(guid).Experience.TotalExperience` keeps growing after level 12 (XP share).
7. `Osi.ShowNotification(character, text)` with plain text: it may need a localization handle. The messages also go to the console.
8. The Job Board: the IMGUI window and NetChannel calls in game, `Ext.Stats.Get(spell).UseCosts` being a string, and `ModuleUUID` at bootstrap.
9. Multiplayer: untested, and the Job Board opens on every client.

## FFT data to check against the installed game

FFT: The Ivalice Chronicles is installed on the user's PC at `C:\Games\FINAL FANTASY TACTICS - The Ivalice Chronicles` (user, 2026-10-10). The FFT numbers in `data/fft_jobs.json` come from guides that disagree in places, and the game settles them. Cloud sessions cannot see the PC, so this needs a local session, or screenshots the user sends to a cloud session. **Never commit game files or extracted data**: only the corrected numbers, with the source changed to "TIC in-game" or "TIC game data" plus the game version.

**Result (2026-10-12, local run): every JP cost and every unlock rule already matched the game.** Read from the vanilla Enhanced nex tables (`Ability`: cost = `JpCost1 + 256 × JpCost2`; `GeneralJob`: `RequiredJobExp`, `RequiredJobIds`/`RequiredJobLevels`, keys 0-19 in the classic job order) with FF16Tools 1.13.3 (`C:\Users\berus\GameModding\tools\ff16tools-1.13.3`), from `data\enhanced\0004.pac` and `0004.en.pac` only, extracted to `C:\Users\berus\GameModding\decomp\fft\enhanced` (no modded pack, no `Reloaded\Mods`, FFT never launched, the mod setup untouched). `tools/check_fft_data.py <sqlite> [--apply]` repeats the check and tagged every entry with the source `tic_game_data`. Details:
- all 71 abilities + 17 left-out abilities: 0 differences (the guide values in the list below were already the game's);
- unlock tree for all 20 jobs: 0 differences;
- job level thresholds: the game table is `[0, 100, 200, 400, 700, 1100, 1600, 2200, 3000]` (index = job level), so Lv2..Lv8 = ours; it also has Lv1 = 100, which the mod does not use;
- spillover: the game's own guide text (`GuidePage` 3006) says every other ally on the field earns a quarter of the JP in the acting unit's job; it does not say whether that includes locked jobs;
- **not found in the tables** (they live in the game's code): the JP-per-action constant (8 or 16), the Enhanced +30% and the JP Boost multiplier. Still unverified; checking them needs the in-game method below or reverse engineering `FFT_enhanced.exe`.
- Side effect, fixed: FF16Tools' `list-files` writes `<pack>_files.txt` next to the pack, i.e. into the game's `data\enhanced` folder. The 7 lists were moved out to `decomp\fft\filelists`; use `unpack-all -o` instead.

To check (value used now, with other values seen in guides in brackets):
- **Squire:** Focus 300 (400) · Rush 80 (200) · Throw Stone 90 (10/100) · Salve 150 (50/250) · Counter Tackle 180 (200).
- **Chemist:** Hi-Potion 200 (150) · Ether 300 (200) · Remedy 700 (300) · Phoenix Down 90 (200/300) · Treasure Hunter 100 (200).
- **Knight:** Rend Armor 400 (200/300) · Rend Weapon 400 (300) · Parry 200 (400) · Equip Heavy Armor 500 (250) · Equip Swords 400 (250).
- **Archer:** Aim +10 700 (400) · Aim +20 900 (500) · Equip Crossbows 350 (250/400) · Archer's Bane 450 (400) · the reaction: Speed Surge 900 or Adrenaline Rush 400.
- **White Mage:** Curaga 450 (200/350) · Reraise 1000 (420/540) · Regen 350 (70/80) · Esuna 300 (150/400) · Regenerate 400 (200) · the support's name: Magick Defense Boost or Arcane Defense.
- **Black Mage:** Firaga/Thundaga/Blizzaga 500 (300/400) · Magick Counter 800 (500) · the support's name: Magick Boost or Arcane Strength.
- **Rules:**
  - job level thresholds (Lv2 200, then 400 … Lv8 3000);
  - the unlock tree (spot-check Monk = Knight 3, Geomancer = Monk 4, Mime);
  - the JP-per-action constant (8 or 16);
  - the Enhanced-mode +30%;
  - JP Boost ×1.5 or ×2;
  - spillover: 1/4, and whether it goes into locked jobs.

How:
- **FFT mods are completely excluded** (user, 2026-10-11). The user plays TIC with mods through Vortex and Reloaded-II (Reloaded-II is in the game folder under `Reloaded`): the FFT mod loader and FFTIVC: Difficulty Enhanced, maybe more later. Nothing from any mod goes into the BG3 mod. Never read, extract or copy anything from `Reloaded\Mods`, Vortex's mod folders, or `modded*.pac` files in the game's `data` folders. Before checking in game, untick every mod except the loader in Reloaded-II: the loader alone changes no game data and deletes leftover `modded*.pac` files at launch. Leave them unticked afterwards: the user wants every mod but the loader kept off while the BG3 mod is being built (2026-10-11). Don't uninstall anything.
- **In game (simplest).** The Job menu shows each ability's JP cost and each job's requirements. For the formula: in Enhanced mode, note the JP shown after a basic attack by a unit whose job level and character level are known, then again with JP Boost equipped. Compare with `8 + 2 × job level + floor(character level / 4)`, then ×1.3 and ×1.5.
- **Game files (thorough).** The values the game uses are in its nex tables (`.nxd`) inside the original `.pac` files in `data\enhanced`; the `Ability` nex table holds the JP costs. Extract the original packs (skip `modded*.pac`) with FF16Tools ([mod-making guide](https://nenkai.github.io/ffxvi-modding/modding/creating_mods_fft/)) to `C:\Users\berus\GameModding\decomp\fft` (outside the repo) and compare with `data/fft_jobs.json`.
- **After changes:** `python tools\build.py`, then the tests and `python tools\pacing_sim.py`. If mastery costs moved a lot, check the Classic preset still meets the target (LOW masters 4+ jobs).

## Part B checklist (local run on the user's PC)

Done in one local run on 2026-10-12 (Opus 5.5; weekly usage 3% → about 8%; no continuation runs were needed or created).

1. [x] Merged the cloud branch into `main` and pushed. The clone had no CRLF files after the merge, so no refresh was needed. `tools\run_tests.ps1`: 86 passed, build check and simulator self-test OK (also after every change below).
2. [x] FFT data: see "Result" above. Nothing changed but the source tags.
3. [x] Extracted with LSLib Divine 1.20.4 (still the latest release) from Shared, Gustav, GustavX, Patch8_HotFix9, Patch8_HotFix10: only `Stats/Generated`, GUI `.lsx` atlases and meta files (`-x <regex> --use-regex`), to `C:\Users\berus\GameModding\decomp\bg3`. The game is v4.76.31.656 (launcher 4.1.1.7631656).
4. [x] `validate_vanilla.py`: 6 problems at first, now `OK: 26 vanilla references and 100 entries checked`. Fixed:
   - `Target_MassCureWounds` does not exist: Cura/Curaga use `Target_CureWounds_Mass`, which picks up to N allies (`AmountOfTargets` 3/4). No Target-type area heal exists in vanilla, so the descriptions now say "up to 3/4 allies".
   - `Target_Revivify` does not exist: vanilla Revivify is `Teleportation_Revivify` (SpellType Teleportation, revives through `OriginSpellProperties` inherited from `Teleportation_Resurrection`). Raise, Arise, Phoenix Down (+ `_Throw`) were renamed `Teleportation_FFTJ_*` (grants in `data/fft_jobs.json` updated); Arise copies the parent's `OriginSpellProperties` and adds `RegainHitPoints(4d8)` after the revive.
   - Icons: `PassiveFeature_Alert/Athlete/Lucky/Mobile` do not exist; now `PassiveFeature_Observant_Bonuses`, `PassiveFeature_RemarkableAthlete_Jump`, `PassiveFeature_Lucky_RollAdditionalDie`, `PassiveFeature_Mobile_DashAcrossDifficultTerrain`.
   - A new check (run inline, not yet a script): every functor/boost name in our stats (27) occurs in vanilla stats, and every value we use for Cooldown, SpellType, StatusType, TickType, SpellFlags, StatusPropertyFlags, StackType etc. occurs in vanilla. Argument forms compared by hand: `Force(2)`, `RestoreResource(SpellSlot,1,n)`, `ActionResource(Movement,-3,0)`, `DamageReduction(Type,Flat,n)`, `JumpMaxDistanceBonus(3)`, `Skill(Perception,2)`, `RollBonus(MeleeSpellAttack|RangedSpellAttack|MeleeWeaponAttack|Attack,n)` all have vanilla twins. Changed: `SpellResistance(Advantage)` (vanilla only uses Resistant/Immune) → Magic Resistance's `IF(HasSpellFlag(SpellFlags.Spell)):Advantage(AllSavingThrows)` on Shell; Elixir `RegainHitPoints(1000)` → `RegainHitPoints(MaxHP)`.
5. [x] Protect/Shell: Shield of Faith's flags minus `IsConcentration`. Chemist items: the parents' flags minus `IsSpell` and verbal/somatic components (thrown versions also minus `IsMelee`). Visual parents left as they are (Throw Stone still flies like Fire Bolt).
6. [x] Strings → `.loca` in the package (`tools\package.ps1`; Divine needs absolute paths).
7. [x] `tools\package.ps1` → `build\FFTJobs.pak` (lz4, 86 KB): `Mods/FFTJobs/{meta.lsx, ScriptExtender/...}`, `Public/FFTJobs/Stats/Generated/Data/*.txt`, `Localization/English/FFTJobs.loca`.
8. [x] `tools\install.ps1` (backs up first, records what it installed in `FFTJobs-backups\FFTJobs-install.json`) and `tools\uninstall.ps1` (`-RemoveScriptExtender` optional). Installed: Script Extender v32 (`BG3SE-Updater-20260621.zip`, SHA-256 2b451d04…ac25a matches the release digest; `bin\DWrite.dll`; it downloaded `BG3ScriptExtender.dll` 32.0.0.0 on first start), `bin\ScriptExtenderSettings.json` (`CreateConsole`, `LogRuntime`), `Mods\FFTJobs.pak`, and the entry at the end of **both** `PlayerProfiles\Public\modsettings.lsx` (the one the game reads: verified by marking GustavX's version) and `<user>\Public\modsettings.lsx` (a copy BG3 Mod Manager 1.0.12.9 keeps). No other mods were installed; GustavX stays first. `meta.lsx` now uses the community form (`LSWString` for Author/Description/Folder/Tags, `GMTemplate`), version **1.0.0.1**.
9. [x] **Smoke test passed at the main menu** (DX11 build, the user's default; started with `steam.exe -applaunch 1086940 --skip-launcher`, because starting `bin\bg3.exe` directly hands over to Steam and the Larian launcher): SE log shows `'FFT Job System': SE v30; flags: Lua`, `Loading bootstrap script: Mods/FFTJobs/ScriptExtender/Lua/BootstrapClient.lua`, `[FFTJobs] client side loaded ...`, no errors. Through the SE client console: `Ext.Mod.IsModLoaded(<uuid>)` = true, load order 14 modules, and `Ext.Stats` has all our entries (SpellData 62, PassiveData 26, StatusData 12) with the expected parents and values (Arise: Teleportation / Teleportation_Revivify / OncePerRest; Cura: Target_CureWounds_Mass, 3 targets; Shell boost; Potion flags without IsSpell). The server side was not started (no save loaded).
   - **Gotcha that cost most of the run:** the first four launches silently dropped the mod (in-game `Settings.Mods` = GustavX only, file untouched). Cause: `%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\ModCrashSanityCheck`. The game creates it while loading mods and deletes it when the main menu appears; I closed the game by PID on the title screen ("Press any key"), the folder stayed, and every following start dropped all mods. Neither `meta.lsx` nor the modsettings content was the cause (the `meta.lsx` change was kept anyway). `install.ps1` now deletes an empty leftover folder; `PLAYTEST.md` tells the user. For future smoke tests: press a key to reach the main menu before closing, close with `CloseMainWindow()`, and delete the folder if it remains.
   - Side note: `ModuleUUID`-based checks from the console work in the client context (`client` command); typing into the console was done with `WriteConsoleInput` (no focus change).
10. [x] `PLAYTEST.md` and this file updated.
11. [x] Memory updated; final message sent.

### Still unverified (needs a real game)
Everything in "Verified vs. unverified" items 1-2 and 4-9 above, except what the smoke test showed: the stats parse and inherit as intended, and the client bootstrap runs. In particular: the server bootstrap and all JP events, the Job Board window and NetChannels, `AddSpell` on non-casters (ability modifier/DC), revive spells actually reviving through `AddSpell`-granted Teleportation spells, the OnDamaged reactions, `Osi.ShowNotification`, party discovery, and the JP formula constants (FFT side).

## Open questions for the user

- MP: abilities use cooldowns instead of an FFT MP pool. An MP resource (a custom `ActionResourceDefinition`) is possible later. Wanted?
- JP Boost is not assumed in the pacing numbers. With it equipped, JP is +50% (`DESIGN.md` section 14).
