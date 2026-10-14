# STATUS — BG3 × FFT job system

Handoff between sessions. Read this first, then `BRIEF.md` (Part B) and `DESIGN.md`.

**Cloud handoff (2026-10-14):** the user continues in a Claude Code cloud session (their cloud usage). Start with
`CLAUDE.md` (the user's rules, what the cloud can't do) and the project skill `.claude/skills/bg3-fft-jobs/SKILL.md`.
State at handoff: 1.0.0.60 on `main`, installed on the user's PC, tester zip 1.0.0.60 made; nothing unverified is
pending locally except the in-game checks listed in PLAYTEST.md (1.0.0.55-60).

**Where the work is:** GitHub branch `claude/game-modding-research-setup-qgn88h` = `main` (1.0.0.61) + 1.0.0.62-1.0.0.64
(pushed 2026-10-14 at the user's request; not merged, not packaged, never checked against vanilla data). `main` is 1.0.0.61.

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
20. **[FINAL DESIGN 2026-10-14, NOT built; build in a FRESH session after the 5-hour reset] Chemist coating = ONE
    coating, "Strange Fluid"** (user's name and text: "You coat your weapon in a strange liquid and believe."). User's
    final answers (replace everything below): bonus action, once per short rest, 300 JP (Chemist, source custom); coat
    yourself or an ally within 9 m; lasts 3 turns, EVERY weapon hit counts; each hit = Mixup's effect: 1d4 of a type
    + its status (Burning/Acid/Poisoned/Bleeding, 2 turns), picking one the target does NOT have yet; WITHOUT Mixup's
    four-effect bonus (no +1 die / +2 turns when all four are on). Build plan: Target spell -> status
    FFTJ_STRANGE_FLUID (3 turns) with `data "Passives"` = an OnAttack passive (Poach's condition: weapon hit) that
    applies a marker status to the target (source = the attacker); Effects.OnStatusApplied runs the Mixup pick
    without the bonus (reuse Effects.afflictions/afflict/rollDamage); tests like the Mixup ones; icon on the GPU
    (BG3 closed). Version: the next free number when it lands (Peddler session took 1.0.0.68, the Wizard takes the
    next; check the branch head first).
    Older notes: **Chemist weapon coatings**, ONLY the Chemist's four
    effects (user): Venom Oil = Poisoned, Naphtha Oil = Burning, Acid Etch = Acid, Glass Grit = Bleeding, plus
    **Strange Fluid** (user's name and text: "You coat your weapon in a strange liquid and believe." = the Mixup Oil
    effect: each hit adds one of the four effects the target lacks). Not chosen: Holy Water, Slumber Resin, Field
    Alchemy. Estimate given: ~2-3%, 1-1.5 h. Original idea (user idea: "toxins applied to weapons... enchant your allies' weapon"). Brainstorm in
    chat, user to pick: Venom Oil (+1d4 poison, Poisoned on a failed Con save), Naphtha Oil (+1d4 fire, Burning), Acid
    Etch (+1d4 acid, Acid), Glass Grit (+1d4 slashing, Bleeding), Mixup Oil (each hit adds a missing Chemist effect),
    Holy Water (+1d6 radiant, double vs undead/fiends), Slumber Resin (first hit: Wis save or Asleep), Field Alchemy
    (support: +2 turns, area coat at slot 3+). Shared rules proposed: toss to an ally within 9 m, 3 turns, one coating
    per ally, saves vs your spell DC, free once per short rest + a spell-slot version with the 1-6 level picker.

21. **[BUILT in 1.0.0.64, not seen in game] FFT Monk martial arts** (user, 2026-10-14: "make sure monk deals increased dmg while unarmed"; it already
    has Brawler = CharacterUnarmedDamage(1d6) + 1 to hit, mastery +1d4, unverified in game). User's picks: the extra
    unarmed die grows with character level (1d6 -> 1d8 at 5 -> 1d10 at 9), unarmed hits use the higher of Str/Dex
    (BG3 Monk's Dextrous Attacks), a bonus-action unarmed strike after attacking. ~1%.
22. **[BUILT in 1.0.0.66, not seen in game] Archer -> Ranger with Fell Seal's Ranger skills** (user, 2026-10-14). User's answers:
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
    **More answers (user, 2026-10-14, local session; built in 1.0.0.66):** Collect Pelt is renamed **Collect Trophy**: a
    beast/monster (not HUMANOID, like Poach) killed by it gives a valuable trophy item, no other effect, sells well:
    three tiers by the creature's level, 1-4 = 75 gold, 5-8 = 150, 9+ = 300 (level bands in config); bosses immune;
    the trophy is **lootable from the slain creature's body** (user), not put in the hunter's bag.
    **Equip Bows** = 350 JP, proficiency with every bow AND crossbow; **Equip Crossbows is merged into it** (saves that
    learned Equip Crossbows get Equip Bows learned, no refund) -> Ranger total 5600 JP. The user's GPU image generator
    may now paint icons for the new skills (tools/generate_icon_art.ps1, art/icons/subjects.txt; only with BG3 closed).
    How it was built: see the 1.0.0.66 entry below (trophy look = vanilla `LOOT_Underdark_Fang_A`, plain loot, not
    an alchemy ingredient; retired abilities = `leftOut` entries with `retired`, not a separate list).

**Queue (user, 2026-10-14, after 1.0.0.64):** Ranger (22) built in 1.0.0.66 (a local session on the user's second
Claude account; a parallel "Wizard" session builds a Fell Seal Wizard job in the worktree bg3-fft-jobs-wizard, branch
claude/wizard-job, as 1.0.0.67, with "Smart Casting": area abilities skip allies) -> coatings (20) -> 7 (menu learn diagnostics) -> 10 (JP above the head) -> 8 (two-PC sync; CIC = Claude in Chrome)
-> 4 (Job Board) -> 14 enemy jobs LAST. 19 (equipment limits, ~2-3%) waits for the user's go; 9 skipped; Monk (21)
built in 1.0.0.64. Session rules from the user: commit locally and tell the user about every commit; push only when
the user says "push"; usage estimate before each item; tell the user when each item is done. Cost note: the Monk
(~1% estimate) took about $2 of cloud usage; the Ranger is ~4-6x that.

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

**Older history** (versions 1.0.0.1-1.0.0.54, Part A/B checklists, early decisions, FFT data checks, verified vs.
unverified): `docs/HISTORY.md`.

## Versions from 1.0.0.55 (newest last)

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

**1.0.0.65 (2026-10-14, local session, NOT packaged or seen in game): local checks of 1.0.0.62-64.**
validate_vanilla, check_refs and check_souls (local vanilla data) were clean for 1.0.0.62-64, but a manual look found
the Monk's guessed vanilla passive name wrong: `MartialArts_DextrousAttacks` -> `MartialArts_DextrousUnarmedAttacks`
(vanilla: `MonkWeaponAttackOverride()` when `IsDexterityGreaterThanStrength()`). `RollBonus(Attack,max(...))` is a
vanilla form (`RollBonus(SavingThrow, max(1, Cause.CharismaModifier))`), kept. tools/check_refs.py now also checks
names inside `HasPassive('...')` and `SpellId('...')` (it caught this one).

**1.0.0.66 (2026-10-14, local session, NOT packaged or seen in game): NWP 22, Archer -> Ranger (Fell Seal).** Job id
`Archer` kept (name Ranger, skillset Survival, `startLearned` RootingShot). 11 abilities, `source` custom +
fellseal_ranger (check_fft_data.py now skips `custom`; the pacing sim uses the real costs, Ranger 5600 JP, self-test
OK): Rooting Shot (Projectile_MainHandAttack + Trip Attack's save-in-SpellSuccess -> FFTJ_ROOTED =
ActionResourceBlock(Movement)), Balm (on Target_FFTJ_Remedy), Scout (Shout on Shout_SecondWind, bonus action, short
rest, FFTJ_SCOUTING = Skill(Perception,5) + ReduceCriticalAttackThreshold(1)), Collect Trophy (FFTJ_TROPHY_MARK applied
BEFORE the damage so a killing shot carries it; Effects.CollectTrophy on KilledBy -> Game:TemplateAddTo(trophy,
corpse); config Abilities.TrophyLevels [1,5,9]; bosses none), Know Weakness, Rain of Arrows (Zone on
Zone_ArcaneShot_PiercingArrow, ActionPoint only), Evasion Up, Multishot (Target_Volley, AreaRadius 2, allies allowed),
Countershot (Interrupt_FFTJ_Countershot: OnCastHit + IsRangedAttack + holding Ammunition, UseSpell(OBSERVER_SOURCE,
Projectile_FFTJ_Countershot,...)), Sniper Shot (three DealDamage(MainRangedWeapon), self FFTJ_ROOTED 1, OncePerRest),
Equip Bows (all bows + crossbows). Trophies: data/fft_jobs.json `trophies` + `trophyLook` -> build.py writes their
Object stats (Object_FFTJ.txt: _LuxuryItem, ValueOverride 75/150/300, ObjectCategory cleared so random loot never
rolls them) and root templates (RootTemplates/_merged.lsx now holds the Codex + 3 trophies; souls_gen.codex_attrs +
build.templates_lsx). Retired: the 13 old abilities moved to `leftOut` with `retired` (+ `replacedBy` EquipBows for
EquipCrossbows) -> Data.Retired -> `Rules.MigrateRetired` on load (refund to Unspent, Earned kept, slots cleared or
swapped; Service:OnSessionLoaded, message at StartGameplay). Their stats entries are deleted (FFTJ_Concentration
stays for the Mime, texts now {{str:Concentration.*}}). 11 icons painted on the local GPU (3 kept from seed 12), the
13 old Archer pictures removed (atlas 90). Tests: 3 new (refund on load, MigrateRetired, trophies by level), 212.
Unverified in game: all of it; especially TemplateAddTo into a corpse's loot, the trophy item (first root templates
with a Stats link), ApplyStatus before DealDamage in SpellSuccess, Volley/Piercing Arrow parents for players, the
Countershot interrupt with a bow, removed spells vanishing cleanly from old saves.

**1.0.0.67 (2026-10-14, local session, NOT packaged or seen in game): Counter Tackle fix (user: "isn't working").**
Logs: Shadowheart learned and slotted it in the 2026-10-14 00:2x MP session (Extender Runtime 2026-10-14 01-47-19,
FFTJ_CounterTackle added) and still had it in the last one (05-05-00, 1.0.0.61); the log can't show passive effects.
Cause: in an OnDamaged passive the functors' target is the one who was hit, so `DealDamage(1d4,...);Force(1.5)` hurt
and pushed the Squire itself. Vanilla melee-counter items use `DealDamage(SWAP, ...)` + `not IsRedirectedDamage()`;
there is no vanilla `Force(SWAP...)`, so the push is FFTJ_COUNTER_TACKLE_PUSH applied with SWAP (OnApplyFunctors
Force(1.5), vanilla BEE_KNOCKBACK pattern). Same bug fixed in FFTJ_MagickCounter and FFTJ_Reflect_Counter (2d6 force
on the caster). build.py check_stats now fails an OnDamaged DealDamage/Force without SWAP/SELF. **Pushes (user: Rush
and Throw Stone knockback "never seemed to work"):** the generated stats matched vanilla's form (Force(2)/Force(1)
after DealDamage, also common in vanilla), so the cause is not proven; changed to vanilla's weapon-push pattern
(Pushing Attack: Force first, then the damage) with longer pushes: Rush Force(3), Throw Stone Force(2), Counter Tackle
Force(2). Unverified in game: all pushes (if they still fail, test in game with the SE console:
`Osi.ApplyStatus(<goblin>, 'FFTJ_COUNTER_TACKLE_PUSH', 6, 1, <host>)` shows whether Force works at all), the push
direction (away from the defender), the push status firing on a re-hit in the same turn.

**1.0.0.68 (2026-10-14, local session in its own worktree `bg3-fft-jobs-wizard`, branch `claude/wizard-job`; NOT
packaged or seen in game): the Fell Seal Wizard, a NEW job (user: "you will build the wizard class"; the user pasted
the Fell Seal wiki page).** User's answers: new job beside the Black Mage (not a rework), unlocked at half the maximum
job level as both Black Mage and White Mage (level 4 each); group "FellSeal" (like the Peddler session's job, shown in
the main Jobs list); elements Water = cold + WET, Fire = fire, Earth = bludgeoning, Thunder = lightning; spell slots
Chemist style (Tier I cantrips + `_Slot` roots with the 1-6 level picker, Tier II level 1, Locus level 2 spell
attacks; tools/upcast.py DAMAGE_ROOTS adds dice per level); Smart Casting for every area ability of the mod;
Magic counter = "Return Magic", half the damage back as force (Abilities.ReturnMagicShare 0.5, summed over
ReturnMagicWindowMs 400: the passive's OnDamaged + IsSpell() marks the caster with SWAP, AttackedBy brings the
amount); Boon = attack rolls only (FFTJ_BOON: CriticalHit(AttackRoll,Success,Always), RemoveEvents OnAttack, from a
Dark One's Blessing-style OnDamage kill trigger); mastery = ActionResource(SpellSlot,1,1). JP = Fell Seal AP x 2.5:
4625 in all, Water I / Fire I known from the start. New build step **tools/smartcast.py**: adds
`not (HasPassive('FFTJ_SmartCasting', context.Source) and (Ally() or Self()))` (harmful) or `... and Enemy())`
(helpful) to the TargetConditions of every area spell in our generated spell files except the hotbar menus (31 spells:
Black Mage, Time Mage, Ranger, Dragoon breaths, Dark Knight, Wizard, Soul forms...), with vanilla carriers' fields from
the new cache **data/vanilla_spells.json** (refresh locally: `python tools/smartcast.py --vanilla`; missing parents
are skipped with a build warning); Effects.Spared does the same for the Chemist's Lua flask bursts (Caustic, Unstable,
Fulminate). Abilities can now carry an `"icons"` map (spell -> art key) for per-spell pictures; upcast levels show
their root's picture (also the Chemist's). 16 icons painted (obsidian black). Checks: build, 215 Lua tests, pacing
self-test, validate_vanilla, check_refs all clean. Unverified in game: everything; especially Self()/HasPassive in
TargetConditions sub-clauses, the SWAP status's causee in StatusApplied (Return Magic), Boon surviving the killing
attack's own OnAttack, the Falling Rocks trap carrier's look for a player, Create Water as a damage carrier.

## Open questions for the user

- MP: abilities use cooldowns instead of an FFT MP pool. An MP resource (a custom `ActionResourceDefinition`) is possible later. Wanted?
- JP Boost is not assumed in the pacing numbers. With it equipped, JP is +50% (`DESIGN.md` section 14).
